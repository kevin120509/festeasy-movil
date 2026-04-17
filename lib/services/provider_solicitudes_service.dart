import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Modelo para solicitudes recibidas por el proveedor
class ProviderSolicitudData {
  ProviderSolicitudData({
    required this.id,
    required this.numeroSolicitud,
    required this.clienteUsuarioId,
    required this.proveedorUsuarioId,
    required this.fechaServicio,
    required this.direccionServicio,
    required this.estado,
    required this.montoTotal,
    required this.montoAnticipo,
    required this.montoLiquidacion,
    required this.creadoEn,
    required this.actualizadoEn,
    this.latitudServicio,
    this.longitudServicio,
    this.tituloEvento,
    this.clienteNombre,
    this.clienteRating,
  });
  final String id;
  final int numeroSolicitud;
  final String clienteUsuarioId;
  final String proveedorUsuarioId;
  final DateTime fechaServicio;
  final String direccionServicio;
  final double? latitudServicio;
  final double? longitudServicio;
  final String? tituloEvento;
  final String estado;
  final double montoTotal;
  final double montoAnticipo;
  final double montoLiquidacion;
  final DateTime creadoEn;
  final DateTime actualizadoEn;
  final String? clienteNombre;
  final double? clienteRating;

  static DateTime? _parseNullableDateTime(Object? value) {
    if (value == null) return null;
    try {
      return DateTime.parse(value as String).toUtc();
    } catch (_) {
      return null;
    }
  }

  static ProviderSolicitudData fromMap(Map<String, dynamic> row) {
    final creado = DateTime.parse(row['creado_en'] as String).toUtc();
    final actualizado = DateTime.parse(row['actualizado_en'] as String).toUtc();
    final fechaServicio =
        _parseNullableDateTime(row['fecha_servicio']) ?? creado;

    // Extraer datos del cliente
    String? clienteNombre;
    double? clienteRating;
    if (row['perfil_cliente'] != null) {
      final perfil = row['perfil_cliente'] is Map
          ? row['perfil_cliente'] as Map<String, dynamic>
          : null;
      clienteNombre = perfil?['nombre_completo'] as String?;
    }
    // TODO: Agregar lógica para obtener rating del cliente si es necesario

    return ProviderSolicitudData(
      id: row['id'] as String,
      numeroSolicitud: (row['numero_solicitud'] as int?) ?? 0,
      clienteUsuarioId: (row['cliente_usuario_id'] as String?) ?? '',
      proveedorUsuarioId: (row['proveedor_usuario_id'] as String?) ?? '',
      fechaServicio: fechaServicio,
      direccionServicio: (row['direccion_servicio'] as String?) ?? '',
      latitudServicio: (row['latitud_servicio'] as num?)?.toDouble(),
      longitudServicio: (row['longitud_servicio'] as num?)?.toDouble(),
      tituloEvento: row['titulo_evento'] as String?,
      estado: (row['estado'] as String?) ?? 'pendiente_aprobacion',
      montoTotal: (row['monto_total'] as num?)?.toDouble() ?? 0,
      montoAnticipo: (row['monto_anticipo'] as num?)?.toDouble() ?? 0,
      montoLiquidacion: (row['monto_liquidacion'] as num?)?.toDouble() ?? 0,
      creadoEn: creado,
      actualizadoEn: actualizado,
      clienteNombre: clienteNombre,
      clienteRating: clienteRating,
    );
  }

  bool get isPendiente => estado == 'pendiente_aprobacion' && montoAnticipo == 0;
  bool get isCotizacionEnviada =>
      estado == 'pendiente_aprobacion' && montoAnticipo > 0;
  bool get isRechazada => estado == 'rechazada';
  bool get esperandoAnticipo => estado == 'esperando_anticipo';
  bool get isReservado => estado == 'reservado';
  bool get isEnProgreso => estado == 'en_progreso';
}

/// Servicio para gestionar solicitudes recibidas por el proveedor
class ProviderSolicitudesService {
  ProviderSolicitudesService._();
  static final ProviderSolicitudesService instance =
      ProviderSolicitudesService._();

  SupabaseClient get _client => Supabase.instance.client;

  /// Obtiene todas las solicitudes pendientes del proveedor
  Future<List<ProviderSolicitudData>> getSolicitudesPendientes(
    String proveedorUsuarioId,
  ) async {
    try {
      debugPrint(
        '🔍 [getSolicitudesPendientes] Buscando solicitudes pendientes para: $proveedorUsuarioId',
      );

      final response = await _client
          .from('solicitudes')
          .select('*, perfil_cliente!cliente_usuario_id(nombre_completo)')
          .eq('proveedor_usuario_id', proveedorUsuarioId)
          .eq('estado', 'pendiente_aprobacion')
          .order('creado_en', ascending: false);

      debugPrint(
        '✅ [getSolicitudesPendientes] Se encontraron ${(response as List).length} solicitudes',
      );

      return (response as List)
          .map(
            (item) =>
                ProviderSolicitudData.fromMap(item as Map<String, dynamic>),
          )
          .toList();
    } catch (e) {
      debugPrint('❌ [getSolicitudesPendientes] Error: $e');
      return [];
    }
  }

  /// Obtiene todas las solicitudes del proveedor (todos los estados)
  Future<List<ProviderSolicitudData>> getAllSolicitudes(
    String proveedorUsuarioId,
  ) async {
    try {
      debugPrint(
        '🔍 [getAllSolicitudes] Buscando solicitudes para proveedor: $proveedorUsuarioId',
      );

      final response = await _client
          .from('solicitudes')
          .select('*, perfil_cliente!cliente_usuario_id(nombre_completo)')
          .eq('proveedor_usuario_id', proveedorUsuarioId)
          .order('creado_en', ascending: false);

      debugPrint(
        '✅ [getAllSolicitudes] Se encontraron ${(response as List).length} solicitudes',
      );

      return (response as List)
          .map(
            (item) =>
                ProviderSolicitudData.fromMap(item as Map<String, dynamic>),
          )
          .toList();
    } catch (e) {
      debugPrint('❌ [getAllSolicitudes] Error: $e');
      return [];
    }
  }

  /// Obtiene una solicitud específica
  Future<ProviderSolicitudData?> getSolicitudById(String solicitudId) async {
    try {
      final response = await _client
          .from('solicitudes')
          .select('*, perfil_cliente!cliente_usuario_id(nombre_completo)')
          .eq('id', solicitudId)
          .single();

      return ProviderSolicitudData.fromMap(response);
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST116') {
        return null;
      }
      rethrow;
    } catch (e) {
      return null;
    }
  }

  /// Obtiene solicitudes por estado
  Future<List<ProviderSolicitudData>> getSolicitudesByEstado(
    String proveedorUsuarioId,
    String estado,
  ) async {
    try {
      debugPrint(
        '🔍 [getSolicitudesByEstado] Buscando solicitudes - proveedor: $proveedorUsuarioId, estado: $estado',
      );

      final response = await _client
          .from('solicitudes')
          .select()
          .eq('proveedor_usuario_id', proveedorUsuarioId)
          .eq('estado', estado)
          .order('creado_en', ascending: false);

      debugPrint(
        '✅ [getSolicitudesByEstado] Se encontraron ${(response as List).length} solicitudes',
      );

      return (response as List)
          .map(
            (item) =>
                ProviderSolicitudData.fromMap(item as Map<String, dynamic>),
          )
          .toList();
    } catch (e) {
      debugPrint('❌ [getSolicitudesByEstado] Error: $e');
      return [];
    }
  }

  /// Acepta una solicitud (cambia estado a 'esperando_anticipo')
  Future<ProviderSolicitudData> aceptarSolicitud(String solicitudId) async {
    try {
      // Establecer expiración de anticipo en 24 horas
      final expiracionAnticipo = DateTime.now().toUtc().add(
        const Duration(hours: 24),
      );

      final response = await _client
          .from('solicitudes')
          .update({
            'estado': 'esperando_anticipo',
            'expiracion_anticipo': expiracionAnticipo.toIso8601String(),
            'actualizado_en': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', solicitudId)
          .select()
          .single();

      // Deducir el inventario (proceso secundario, no debe bloquear el flujo principal si falla)
      try {
        final itemsData = await _client
            .from('items_solicitud')
            .select('paquete_id, cantidad, nombre_paquete_snapshot')
            .eq('solicitud_id', solicitudId);
        
        if (itemsData != null && itemsData is List) {
          final itemList = List<Map<String, dynamic>>.from(itemsData);
          
          // Obtener el proveedor de la solicitud para filtrar inventario
          final solData = await _client
              .from('solicitudes')
              .select('proveedor_usuario_id')
              .eq('id', solicitudId)
              .maybeSingle();
          
          final provId = solData?['proveedor_usuario_id'] as String?;

          for (final item in itemList) {
            final cant = (item['cantidad'] as num?)?.toInt() ?? 1;
            
            if (item['paquete_id'] != null) {
              // Es un paquete base
              final pkgId = item['paquete_id'] as String;
              final pData = await _client
                  .from('paquetes_proveedor')
                  .select('detalles_json')
                  .eq('id', pkgId)
                  .maybeSingle();
              
              if (pData != null && pData['detalles_json'] != null) {
                final json = Map<String, dynamic>.from(pData['detalles_json'] as Map);
                if (json.containsKey('stock')) {
                  final currentStock = int.tryParse(json['stock'].toString()) ?? 0;
                  int newStock = currentStock - cant;
                  if (newStock < 0) newStock = 0;
                  json['stock'] = newStock;
                  await _client
                      .from('paquetes_proveedor')
                      .update({'detalles_json': json})
                      .eq('id', pkgId);
                }
              }
            } else {
              // Es un artículo extra de inventario
              final nombreProd = item['nombre_paquete_snapshot'] as String?;
              if (nombreProd != null && provId != null) {
                final prodData = await _client
                    .from('inventario_proveedor')
                    .select('id, stock')
                    .eq('proveedor_id', provId)
                    .eq('nombre', nombreProd)
                    .limit(1);
                    
                if (prodData != null && (prodData as List).isNotEmpty) {
                  final pData = (prodData as List).first as Map<String, dynamic>;
                  if (pData['stock'] != null) {
                    final currentStock = int.tryParse(pData['stock'].toString()) ?? 0;
                    int newStock = currentStock - cant;
                    if (newStock < 0) newStock = 0;
                    await _client
                        .from('inventario_proveedor')
                        .update({'stock': newStock})
                        .eq('id', pData['id']);
                  }
                }
              }
            }
          }
        }
      } catch (innerError) {
        debugPrint('⚠️ Error no-crítico en deducción de inventario: $innerError');
      }

      return ProviderSolicitudData.fromMap(response as Map<String, dynamic>);
    } catch (e) {
      debugPrint('❌ Error fatal en aceptarSolicitud: $e');
      throw Exception('Error aceptando solicitud: $e');
    }
  }

  /// Envía cotización final (cambia estado de vuelta a pendiente_aprobacion o cotizacion_enviada, lo dejaremos en pendiente_aprobacion para que el cliente lo acepte)
  Future<ProviderSolicitudData> enviarCotizacion({
    required String solicitudId,
    required double nuevoMontoTotal,
    required double nuevoMontoAnticipo,
    required double nuevoMontoLiquidacion,
    String? baseItemId,
    double? baseItemPrecio,
    int? baseItemCantidad,
    List<Map<String, dynamic>>? extraItems,
  }) async {
    try {
      final updateData = {
        'estado': 'pendiente_aprobacion',
        'monto_total': nuevoMontoTotal,
        'monto_anticipo': nuevoMontoAnticipo,
        'monto_liquidacion': nuevoMontoLiquidacion,
        'actualizado_en': DateTime.now().toUtc().toIso8601String(),
      };

      if (baseItemId != null && baseItemPrecio != null && baseItemCantidad != null) {
        await _client.from('items_solicitud').update({
          'precio_unitario': baseItemPrecio,
          'cantidad': baseItemCantidad,
        }).eq('id', baseItemId);
      }

      final response = await _client
          .from('solicitudes')
          .update(updateData)
          .eq('id', solicitudId)
          .select()
          .single();

      // Antes de insertar los nuevos ítems extras, purgamos todos los que ya existían
      // (sabemos que son ítems extras si su paquete_id es nulo).
      await _client.from('items_solicitud')
          .delete()
          .eq('solicitud_id', solicitudId)
          .filter('paquete_id', 'is', null);

      if (extraItems != null && extraItems.isNotEmpty) {
        final itemsToInsert = extraItems.map((item) {
          return {
            'solicitud_id': solicitudId,
            'paquete_id': null, // Es un producto de inventario, no un paquete oficial
            'nombre_paquete_snapshot': item['nombre'],
            'cantidad': item['cantidad'],
            'precio_unitario': item['precio'],
          };
        }).toList();

        await _client.from('items_solicitud').insert(itemsToInsert);
      }

      return ProviderSolicitudData.fromMap(response);
    } catch (e) {
      throw Exception('Error enviando cotización: $e');
    }
  }

  /// Rechaza una solicitud con un motivo
  Future<ProviderSolicitudData> rechazarSolicitud({
    required String solicitudId,
    required String motivo,
  }) async {
    try {
      // Guardar el motivo en detalles de la solicitud
      final solicitudActual = await getSolicitudById(solicitudId);
      if (solicitudActual == null) {
        throw Exception('Solicitud no encontrada');
      }

      final response = await _client
          .from('solicitudes')
          .update({
            'estado': 'rechazada',
            'actualizado_en': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', solicitudId)
          .select()
          .single();

      // TODO: Guardar el motivo en una tabla de auditoría o en detalles_json si existe

      return ProviderSolicitudData.fromMap(response);
    } catch (e) {
      throw Exception('Error rechazando solicitud: $e');
    }
  }

  /// Cuenta solicitudes pendientes
  Future<int> countSolicitudesPendientes(String proveedorUsuarioId) async {
    try {
      final response = await _client
          .from('solicitudes')
          .select('id')
          .eq('proveedor_usuario_id', proveedorUsuarioId)
          .eq('estado', 'pendiente_aprobacion');

      return (response as List).length;
    } catch (e) {
      return 0;
    }
  }

  /// Valida el PIN de entrega ingresado por el proveedor
  /// Si es correcto, cambia estado a 'entregado_pendiente_liq'
  Future<ProviderSolicitudData> validarPinEntrega({
    required String solicitudId,
    required String pinIngresado,
  }) async {
    try {
      debugPrint(
        '🔐 [validarPinEntrega] Validando PIN para solicitud: $solicitudId',
      );

      // Obtener el PIN real de la BD
      final solicitud = await _client
          .from('solicitudes')
          .select('pin_validacion, estado')
          .eq('id', solicitudId)
          .single();

      final pinReal = solicitud['pin_validacion'] as String?;
      final estadoActual = solicitud['estado'] as String?;

      // Verificar que la solicitud esté en estado 'reservado'
      if (estadoActual != 'reservado') {
        throw Exception('La solicitud no está en estado reservado');
      }

      // Verificar que exista un PIN
      if (pinReal == null || pinReal.isEmpty) {
        throw Exception('Esta solicitud no tiene PIN asignado');
      }

      // Comparar PINs
      if (pinIngresado != pinReal) {
        throw Exception('PIN incorrecto. Verifica con el cliente.');
      }

      // PIN correcto - actualizar estado
      debugPrint('✅ [validarPinEntrega] PIN correcto! Actualizando estado...');

      final response = await _client
          .from('solicitudes')
          .update({
            'estado': 'entregado_pendiente_liq',
            'pin_validado_en': DateTime.now().toUtc().toIso8601String(),
            'actualizado_en': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', solicitudId)
          .select()
          .single();

      debugPrint(
        '✅ [validarPinEntrega] Estado actualizado a entregado_pendiente_liq',
      );
      return ProviderSolicitudData.fromMap(response);
    } catch (e) {
      debugPrint('❌ [validarPinEntrega] Error: $e');
      rethrow;
    }
  }

  /// Marca la liquidación como pagada (simulado)
  /// Cambia estado a 'finalizado'
  Future<ProviderSolicitudData> marcarLiquidacionPagada(
    String solicitudId,
  ) async {
    try {
      debugPrint(
        '💰 [marcarLiquidacionPagada] Marcando liquidación pagada: $solicitudId',
      );

      final response = await _client
          .from('solicitudes')
          .update({
            'estado': 'finalizado',
            'actualizado_en': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', solicitudId)
          .select()
          .single();

      debugPrint('✅ [marcarLiquidacionPagada] Estado actualizado a finalizado');
      return ProviderSolicitudData.fromMap(response);
    } catch (e) {
      debugPrint('❌ [marcarLiquidacionPagada] Error: $e');
      rethrow;
    }
  }
}
