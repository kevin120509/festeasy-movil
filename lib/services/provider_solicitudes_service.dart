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
    required this.estado, required this.montoTotal, required this.montoAnticipo, required this.montoLiquidacion, required this.creadoEn, required this.actualizadoEn, this.latitudServicio,
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

  bool get isPendiente => estado == 'pendiente_aprobacion';
  bool get isRechazada => estado == 'rechazada';
  bool get espeandoAnticipo => estado == 'esperando_anticipo';
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
      final response = await _client
          .from('solicitudes')
          .update({
            'estado': 'esperando_anticipo',
            'actualizado_en': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', solicitudId)
          .select()
          .single();

      return ProviderSolicitudData.fromMap(response);
    } catch (e) {
      throw Exception('Error aceptando solicitud: $e');
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
}
