import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatService {
  ChatService._();
  static final ChatService instance = ChatService._();

  final SupabaseClient _client = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> getConversaciones({
    required String usuarioId,
    required bool isProvider,
  }) async {
    try {
      final columnToMatch = isProvider
          ? 'proveedor_usuario_id'
          : 'cliente_usuario_id';

      // Obtenemos las solicitudes de este usuario
      final query = _client
          .from('solicitudes')
          .select('''
            *
          ''')
          .eq(columnToMatch, usuarioId);

      final List<dynamic> solicitudes = await query;

      List<Map<String, dynamic>> conversaciones = [];

      for (final sol in solicitudes) {
        final solicitudId = sol['id'] as String;

        // Obtener la información de la contraparte
        String nombreContraparte = 'Usuario';
        String? avatarContraparte;

        if (isProvider) {
          final clienteId = sol['cliente_usuario_id'] as String?;
          if (clienteId != null) {
            try {
              final clienteInfo = await _client
                  .from('perfil_cliente')
                  .select('nombre_completo, avatar_url')
                  .eq('usuario_id', clienteId)
                  .maybeSingle();
              if (clienteInfo != null) {
                nombreContraparte =
                    (clienteInfo['nombre_completo'] as String?) ?? 'Cliente';
                avatarContraparte = clienteInfo['avatar_url'] as String?;
              } else {
                debugPrint('⚠️ No se encontró perfil para el cliente $clienteId');
              }
            } catch (e) {
              debugPrint('❌ Error obteniendo perfil de cliente: $e');
            }
          }
        } else {
          final provId = sol['proveedor_usuario_id'] as String?;
          if (provId != null) {
            try {
              final provInfo = await _client
                  .from('perfil_proveedor')
                  .select('nombre_negocio, avatar_url')
                  .eq('usuario_id', provId)
                  .maybeSingle();
              if (provInfo != null) {
                nombreContraparte =
                    (provInfo['nombre_negocio'] as String?) ?? 'Proveedor';
                avatarContraparte = provInfo['avatar_url'] as String?;
              }
            } catch (e) {
              debugPrint('Error obteniendo perfil de proveedor: $e');
            }
          }
        }

        // Obtener el último mensaje
        try {
          final lastMessage = await _client
              .from('mensajes_solicitud')
              .select('mensaje, creado_en')
              .eq('solicitud_id', solicitudId)
              .order('creado_en', ascending: false)
              .limit(1)
              .maybeSingle();

          if (lastMessage != null) {
            conversaciones.add({
              'solicitud_id': solicitudId,
              'nombre_contraparte': nombreContraparte,
              'avatar_contraparte': avatarContraparte,
              'ultimo_mensaje': (lastMessage['mensaje'] as String?) ?? '',
              'fecha_ultimo_mensaje': lastMessage['creado_en'] as String,
              'estado_solicitud': sol['estado'] as String,
              'solicitud': sol,
            });
          } else {
            // Opcional: Aregar también solicitudes sin mensajes si queremos que puedan iniciar chat
            conversaciones.add({
              'solicitud_id': solicitudId,
              'nombre_contraparte': nombreContraparte,
              'avatar_contraparte': avatarContraparte,
              'ultimo_mensaje': 'Sin mensajes aún',
              'fecha_ultimo_mensaje': sol['creado_en'] as String,
              'estado_solicitud': sol['estado'] as String,
              'solicitud': sol,
            });
          }
        } catch (_) {}
      }

      // Ordenar por fecha del último mensaje descendente
      conversaciones.sort((a, b) {
        final dateA = DateTime.parse(a['fecha_ultimo_mensaje'] as String);
        final dateB = DateTime.parse(b['fecha_ultimo_mensaje'] as String);
        return dateB.compareTo(dateA);
      });

      return conversaciones;
    } catch (e) {
      debugPrint('Error en getConversaciones: $e');
      return [];
    }
  }
}
