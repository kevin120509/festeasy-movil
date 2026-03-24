import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class StripeService {
  StripeService._();
  static final StripeService instance = StripeService._();

  static const String publishableKey = 'pk_live_51TBqKo5RaVnnBpuMSZBVbXa9tEXSGNi5Dxf2WMOpF3MaQ0lL5EovLf7byVyaego9kjj3PNqo6H4VEKuMithhgI3P00ffV84Dh9';
  static const String paymentIntentUrl = 'https://ghlosgnopdmrowiygxdm.supabase.co/functions/v1/create-payment-intent';

  /// Inicializa Stripe con la clave pública
  Future<void> init() async {
    Stripe.publishableKey = publishableKey;
    await Stripe.instance.applySettings();
  }

  /// Procesa un pago real usando Stripe Payment Sheet
  Future<bool> processPayment({
    required double amount,
    required String currency,
    required String description,
    required String solicitudId,
  }) async {
    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) throw Exception('Usuario no autenticado');

      // 1. Crear el Payment Intent llamando a la Edge Function de Supabase
      final response = await http.post(
        Uri.parse(paymentIntentUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${session.accessToken}',
        },
        body: jsonEncode({
          'amount': (amount * 100).toInt(), // Stripe requiere el monto en centavos
          'currency': currency,
          'description': description,
          'metadata': {
            'solicitud_id': solicitudId,
          },
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Error al crear el intento de pago: ${response.body}');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      
      debugPrint('Stripe Function Response: $data');

      final paymentIntentClientSecret = data['clientSecret']?.toString();
      final ephemeralKey = data['ephemeralKey']?.toString();
      final customerId = data['customer']?.toString();

      if (paymentIntentClientSecret == null) {
        throw Exception('La respuesta de la función no contiene el clientSecret. Campos recibidos: ${data.keys.toList()}');
      }

      // 2. Inicializar el Payment Sheet de Stripe
      // ephemeralKey y customerId son opcionales si solo quieres procesar el pago sin guardar la tarjeta
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: paymentIntentClientSecret,
          customerEphemeralKeySecret: ephemeralKey,
          customerId: customerId,
          merchantDisplayName: 'Festeasy',
          style: ThemeMode.light,
          appearance: const PaymentSheetAppearance(
            colors: PaymentSheetAppearanceColors(
              primary: Color(0xFFE01D25),
            ),
          ),
        ),
      );

      // 3. Presentar el Payment Sheet al usuario
      await Stripe.instance.presentPaymentSheet();

      return true;
    } on StripeException catch (e) {
      if (e.error.code == FailureCode.Canceled) {
        debugPrint('Pago cancelado por el usuario');
        return false;
      }
      debugPrint('Error de Stripe: ${e.error.localizedMessage}');
      rethrow;
    } catch (e) {
      debugPrint('Error procesando pago: $e');
      rethrow;
    }
  }
}
