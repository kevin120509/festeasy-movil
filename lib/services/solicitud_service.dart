import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SolicitudData {

  const SolicitudData({
    required this.id,
    required this.numeroSolicitud,
    required this.clienteUsuarioId,
    required this.proveedorUsuarioId,
    required this.fechaServicio,
    required this.direccionServicio,
    required this.montoTotal, required this.montoAnticipo, required this.montoLiquidacion, required this.estado, required this.creadoEn, required this.actualizadoEn, this.tituloEvento,
    this.linkPagoAnticipo,
    this.linkPagoLiquidacion,
    this.expiracionAnticipo,
    this.pinSeguridad,
    this.pinValidadoEn,
    this.providerName,
  });
  final String id;
  final int numeroSolicitud;
  final String clienteUsuarioId;
  final String proveedorUsuarioId;
  final DateTime fechaServicio; // date (we parse as DateTime)
  final String direccionServicio;
  final String? tituloEvento;
  final double montoTotal;
  final double montoAnticipo;
  final double montoLiquidacion;
  final String estado;
  final DateTime creadoEn;
  final DateTime actualizadoEn;
  final String? linkPagoAnticipo;
  final String? linkPagoLiquidacion;
  final DateTime? expiracionAnticipo;
  final String? pinSeguridad;
  final DateTime? pinValidadoEn;
  final String? providerName;

  static DateTime? _parseNullableDateTime(Object? value) {
    if (value == null) return null;
    try {
      return DateTime.parse(value as String).toUtc();
    } catch (_) {
      return null;
    }
  }

  static SolicitudData fromMap(Map<String, dynamic> row) {
    final creado = DateTime.parse(row['creado_en'] as String).toUtc();
    final actualizado = DateTime.parse(row['actualizado_en'] as String).toUtc();
    final fechaServicio =
        _parseNullableDateTime(row['fecha_servicio']) ?? creado;
    final expiracion = _parseNullableDateTime(row['expiracion_anticipo']);
    final pinValidado = _parseNullableDateTime(row['pin_validado_en']);

    String? provName;
    if (row['perfil_proveedor'] != null && row['perfil_proveedor'] is Map) {
      provName = row['perfil_proveedor']['nombre_negocio'] as String?;
    } else if (row['perfil_proveedor'] != null && row['perfil_proveedor'] is List && (row['perfil_proveedor'] as List).isNotEmpty) {
       // In case it returns a list
       provName = (row['perfil_proveedor'] as List).first['nombre_negocio'] as String?;
    }

    return SolicitudData(
      id: row['id'] as String,
      numeroSolicitud: (row['numero_solicitud'] as int?) ?? 0,
      clienteUsuarioId: (row['cliente_usuario_id'] as String?) ?? '',
      proveedorUsuarioId: (row['proveedor_usuario_id'] as String?) ?? '',
      fechaServicio: fechaServicio,
      direccionServicio: (row['direccion_servicio'] as String?) ?? '',
      tituloEvento: row['titulo_evento'] as String?,
      montoTotal: (row['monto_total'] as num?)?.toDouble() ?? 0,
      montoAnticipo: (row['monto_anticipo'] as num?)?.toDouble() ?? 0,
      montoLiquidacion: (row['monto_liquidacion'] as num?)?.toDouble() ?? 0,
      estado: (row['estado'] as String?) ?? 'pendiente_aprobacion',
      creadoEn: creado,
      actualizadoEn: actualizado,
      linkPagoAnticipo: row['link_pago_anticipo'] as String?,
      linkPagoLiquidacion: row['link_pago_liquidacion'] as String?,
      expiracionAnticipo: expiracion,
      pinSeguridad: row['pin_seguridad'] as String?,
      pinValidadoEn: pinValidado,
      providerName: provName,
    );
  }
}

class SolicitudService {
  SolicitudService._();
  static final SolicitudService instance = SolicitudService._();

  SupabaseClient get _client => Supabase.instance.client;

  User get _user {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const AuthException('Usuario no autenticado');
    }
    return user;
  }

  Future<SolicitudData> createSolicitud({
    required String providerUserId,
    required String address,
    required DateTime serviceDateLocal,
    required double montoTotal, required Map<String, int> cartItems, required List<Map<String, dynamic>> allItems, String? tituloEvento,
  }) async {
    final user = _user;

    // fecha_servicio in DB is a `date`. We convert to a YYYY-MM-DD string.
    final serviceDateStr = DateTime(
      serviceDateLocal.year,
      serviceDateLocal.month,
      serviceDateLocal.day,
    ).toIso8601String().split('T').first;

    final inserted = await _client
        .from('solicitudes')
        .insert({
          'cliente_usuario_id': user.id,
          'proveedor_usuario_id': providerUserId,
          'fecha_servicio': serviceDateStr,
          'direccion_servicio': address,
          'titulo_evento': tituloEvento,
          'monto_total': montoTotal,
          'monto_anticipo': 0,
          'monto_liquidacion': 0,
          'estado': 'pendiente_aprobacion',
        })
        .select()
        .single();

    final solicitudId = inserted['id'] as String;

    // Insertar items (si existe la tabla)
    final items = <Map<String, dynamic>>[];
    for (final entry in cartItems.entries) {
      final item = allItems.firstWhere(
        (e) => e['id'] == entry.key,
        orElse: () => <String, Object>{
          'name': 'Paquete desconocido',
          'price': 0.0
        },
      );
      items.add({
        'solicitud_id': solicitudId,
        'paquete_id': entry.key,
        'nombre_paquete_snapshot': (item['name'] as String?) ?? 'Paquete desconocido',
        'cantidad': entry.value,
        'precio_unitario': (item['price'] as num?)?.toDouble() ?? 0,
      });
    }

    if (items.isNotEmpty) {
      try {
        await _client.from('items_solicitud').insert(items);
      } catch (_) {
        // Si la tabla falla, continuamos; la solicitud ya existe.
      }
    }

    return SolicitudData.fromMap(inserted);
  }

  Future<SolicitudData?> getSolicitudById(String solicitudId) async {
    final row = await _client
        .from('solicitudes')
        .select()
        .eq('id', solicitudId)
        .maybeSingle();

    if (row == null) return null;

    final data = SolicitudData.fromMap(row);
    final providerName = await _fetchProviderName(data.proveedorUsuarioId);
    
    return SolicitudData(
      id: data.id,
      numeroSolicitud: data.numeroSolicitud,
      clienteUsuarioId: data.clienteUsuarioId,
      proveedorUsuarioId: data.proveedorUsuarioId,
      fechaServicio: data.fechaServicio,
      direccionServicio: data.direccionServicio,
      tituloEvento: data.tituloEvento,
      montoTotal: data.montoTotal,
      montoAnticipo: data.montoAnticipo,
      montoLiquidacion: data.montoLiquidacion,
      estado: data.estado,
      creadoEn: data.creadoEn,
      actualizadoEn: data.actualizadoEn,
      linkPagoAnticipo: data.linkPagoAnticipo,
      linkPagoLiquidacion: data.linkPagoLiquidacion,
      expiracionAnticipo: data.expiracionAnticipo,
      pinSeguridad: data.pinSeguridad,
      pinValidadoEn: data.pinValidadoEn,
      providerName: providerName,
    );
  }

  Future<SolicitudData?> getActiveSolicitudForCurrentUser() async {
    final user = _user;
    // Solo traer solicitudes que requieren acción o espera activa del cliente
    // Estados que muestran el banner "Esperando respuesta":
    // - pendiente_aprobacion: esperando que el proveedor acepte
    // - esperando_anticipo: esperando que el cliente pague el anticipo
    final row = await _client
        .from('solicitudes')
        .select()
        .eq('cliente_usuario_id', user.id)
        .or('estado.eq.pendiente_aprobacion,estado.eq.esperando_anticipo')
        .order('creado_en', ascending: false)
        .limit(1)
        .maybeSingle();

    if (row == null) return null;

    final data = SolicitudData.fromMap(row);
    final providerName = await _fetchProviderName(data.proveedorUsuarioId);

    return SolicitudData(
      id: data.id,
      numeroSolicitud: data.numeroSolicitud,
      clienteUsuarioId: data.clienteUsuarioId,
      proveedorUsuarioId: data.proveedorUsuarioId,
      fechaServicio: data.fechaServicio,
      direccionServicio: data.direccionServicio,
      tituloEvento: data.tituloEvento,
      montoTotal: data.montoTotal,
      montoAnticipo: data.montoAnticipo,
      montoLiquidacion: data.montoLiquidacion,
      estado: data.estado,
      creadoEn: data.creadoEn,
      actualizadoEn: data.actualizadoEn,
      linkPagoAnticipo: data.linkPagoAnticipo,
      linkPagoLiquidacion: data.linkPagoLiquidacion,
      expiracionAnticipo: data.expiracionAnticipo,
      pinSeguridad: data.pinSeguridad,
      pinValidadoEn: data.pinValidadoEn,
      providerName: providerName,
    );
  }

  Future<String?> _fetchProviderName(String providerId) async {
    try {
      final byUserId = await _client
          .from('perfil_proveedor')
          .select('nombre_negocio')
          .eq('usuario_id', providerId)
          .limit(1)
          .maybeSingle();
      if (byUserId != null) return byUserId['nombre_negocio'] as String?;

      final byProfileId = await _client
          .from('perfil_proveedor')
          .select('nombre_negocio')
          .eq('id', providerId)
          .limit(1)
          .maybeSingle();
      return byProfileId?['nombre_negocio'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// Obtiene TODAS las solicitudes del cliente actual
  Future<List<SolicitudData>> getAllSolicitudesForClient() async {
    final user = _user;
    
    try {
      final rows = await _client
          .from('solicitudes')
          .select()
          .eq('cliente_usuario_id', user.id)
          .order('creado_en', ascending: false);

      debugPrint('📋 Solicitudes encontradas: ${(rows as List).length}');
      
      final solicitudes = <SolicitudData>[];
      for (final row in rows) {
        final data = SolicitudData.fromMap(row);
        // Obtener nombre del proveedor
        final providerName = await _fetchProviderName(data.proveedorUsuarioId);
        solicitudes.add(SolicitudData(
          id: data.id,
          numeroSolicitud: data.numeroSolicitud,
          clienteUsuarioId: data.clienteUsuarioId,
          proveedorUsuarioId: data.proveedorUsuarioId,
          fechaServicio: data.fechaServicio,
          direccionServicio: data.direccionServicio,
          tituloEvento: data.tituloEvento,
          montoTotal: data.montoTotal,
          montoAnticipo: data.montoAnticipo,
          montoLiquidacion: data.montoLiquidacion,
          estado: data.estado,
          creadoEn: data.creadoEn,
          actualizadoEn: data.actualizadoEn,
          linkPagoAnticipo: data.linkPagoAnticipo,
          linkPagoLiquidacion: data.linkPagoLiquidacion,
          expiracionAnticipo: data.expiracionAnticipo,
          pinSeguridad: data.pinSeguridad,
          pinValidadoEn: data.pinValidadoEn,
          providerName: providerName,
        ));
      }
      return solicitudes;
    } catch (e) {
      debugPrint('❌ Error obteniendo solicitudes: $e');
      return [];
    }
  }

  Future<void> cancelSolicitud(String solicitudId) async {
    final user = _user;
    await _client
        .from('solicitudes')
        .update({'estado': 'cancelada'})
        .eq('id', solicitudId)
        .eq('cliente_usuario_id', user.id);
  }

  /// Actualiza campos arbitrarios de una solicitud y devuelve la solicitud actualizada
  Future<SolicitudData> updateSolicitud(
    String solicitudId,
    Map<String, dynamic> updates,
  ) async {
    final updated = await _client
        .from('solicitudes')
        .update(updates)
        .eq('id', solicitudId)
        .select()
        .single();

    return SolicitudData.fromMap(updated);
  }

  /// Obtiene las solicitudes canceladas del usuario actual
  Future<List<SolicitudData>> getCancelledSolicitudes() async {
    final user = _user;
    final rows = await _client
        .from('solicitudes')
        .select()
        .eq('cliente_usuario_id', user.id)
        .eq('estado', 'cancelada')
        .order('creado_en', ascending: false);

    return (rows as List)
        .map((row) => SolicitudData.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  /// Elimina una solicitud cancelada r(solo si está cancelada)
  Future<void> deleteSolicitud(String solicitudId) async {
    final user = _user;
    // Primero eliminar los items de la solicitud
    await _client.from('items_solicitud').delete().eq('solicitud_id', solicitudId);
    // Luego eliminar la solicitud
    await _client
        .from('solicitudes')
        .delete()
        .eq('id', solicitudId)
        .eq('cliente_usuario_id', user.id)
        .eq('estado', 'cancelada'); // Solo permitir eliminar canceladas
  }

  /// Genera o registra un link de pago de anticipo para la solicitud
  Future<SolicitudData> attachAnticipoLink({
    required String solicitudId,
    required double montoAnticipo,
    required String linkPago,
    DateTime? expiracionUtc,
  }) async {
    final data = {
      'monto_anticipo': montoAnticipo,
      'link_pago_anticipo': linkPago,
      'estado': 'esperando_anticipo',
      if (expiracionUtc != null)
        'expiracion_anticipo': expiracionUtc.toIso8601String(),
    };

    return updateSolicitud(solicitudId, data);
  }

  /// Genera un PIN de seguridad aleatorio de 4 dígitos
  String _generarPin() {
    final random = DateTime.now().millisecondsSinceEpoch;
    final pin = ((random % 9000) + 1000).toString();
    return pin;
  }

  /// Simula el pago del anticipo y genera el PIN de seguridad
  /// En producción, esto se llamaría desde un webhook de la pasarela de pago
  Future<SolicitudData> simularPagoAnticipo(String solicitudId) async {
    try {
      debugPrint('💳 [simularPagoAnticipo] Simulando pago para: $solicitudId');
      
      // Obtener datos actuales de la solicitud
      final solicitud = await getSolicitudById(solicitudId);
      if (solicitud == null) {
        throw Exception('Solicitud no encontrada');
      }
      
      // Verificar que esté en estado esperando_anticipo
      if (solicitud.estado != 'esperando_anticipo') {
        throw Exception('La solicitud no está esperando pago de anticipo');
      }
      
      // Generar PIN de 4 dígitos
      final pin = _generarPin();
      debugPrint('🔐 [simularPagoAnticipo] PIN generado: $pin');
      
      // Calcular montos (50% anticipo, 50% liquidación)
      final montoAnticipo = solicitud.montoTotal * 0.5;
      final montoLiquidacion = solicitud.montoTotal * 0.5;
      
      // Actualizar solicitud
      final response = await _client
          .from('solicitudes')
          .update({
            'estado': 'reservado',
            'pin_seguridad': pin,
            'monto_anticipo': montoAnticipo,
            'monto_liquidacion': montoLiquidacion,
            'actualizado_en': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', solicitudId)
          .select()
          .single();

      debugPrint('✅ [simularPagoAnticipo] Pago simulado exitosamente. Estado: reservado');
      return SolicitudData.fromMap(response);
    } catch (e) {
      debugPrint('❌ [simularPagoAnticipo] Error: $e');
      rethrow;
    }
  }

  /// Simula el pago de la liquidación
  /// En producción, esto se llamaría desde un webhook de la pasarela de pago
  Future<SolicitudData> simularPagoLiquidacion(String solicitudId) async {
    try {
      debugPrint('💳 [simularPagoLiquidacion] Simulando pago liquidación para: $solicitudId');
      
      // Obtener datos actuales de la solicitud
      final solicitud = await getSolicitudById(solicitudId);
      if (solicitud == null) {
        throw Exception('Solicitud no encontrada');
      }
      
      // Verificar que esté en estado entregado_pendiente_liq
      if (solicitud.estado != 'entregado_pendiente_liq') {
        throw Exception('La solicitud no está pendiente de liquidación');
      }
      
      // Actualizar solicitud a finalizado
      final response = await _client
          .from('solicitudes')
          .update({
            'estado': 'finalizado',
            'actualizado_en': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', solicitudId)
          .select()
          .single();

      debugPrint('✅ [simularPagoLiquidacion] Pago liquidación simulado. Estado: finalizado');
      return SolicitudData.fromMap(response);
    } catch (e) {
      debugPrint('❌ [simularPagoLiquidacion] Error: $e');
      rethrow;
    }
  }
}
