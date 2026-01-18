import 'package:supabase_flutter/supabase_flutter.dart';

class SolicitudData {
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

  const SolicitudData({
    required this.id,
    required this.numeroSolicitud,
    required this.clienteUsuarioId,
    required this.proveedorUsuarioId,
    required this.fechaServicio,
    required this.direccionServicio,
    this.tituloEvento,
    required this.montoTotal,
    required this.montoAnticipo,
    required this.montoLiquidacion,
    required this.estado,
    required this.creadoEn,
    required this.actualizadoEn,
    this.linkPagoAnticipo,
    this.linkPagoLiquidacion,
    this.expiracionAnticipo,
    this.pinSeguridad,
    this.pinValidadoEn,
    this.providerName,
  });

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
      tituloEvento: (row['titulo_evento'] as String?),
      montoTotal: (row['monto_total'] as num?)?.toDouble() ?? 0,
      montoAnticipo: (row['monto_anticipo'] as num?)?.toDouble() ?? 0,
      montoLiquidacion: (row['monto_liquidacion'] as num?)?.toDouble() ?? 0,
      estado: (row['estado'] as String?) ?? 'pendiente_aprobacion',
      creadoEn: creado,
      actualizadoEn: actualizado,
      linkPagoAnticipo: (row['link_pago_anticipo'] as String?),
      linkPagoLiquidacion: (row['link_pago_liquidacion'] as String?),
      expiracionAnticipo: expiracion,
      pinSeguridad: (row['pin_seguridad'] as String?),
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
    String? tituloEvento,
    required double montoTotal,
    required Map<String, int> cartItems,
    required List<Map<String, dynamic>> allItems,
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
        orElse: () => <String, Object>{'price': 0.0},
      );
      items.add({
        'solicitud_id': solicitudId,
        'paquete_id': entry.key,
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
    // Considerar cualquier solicitud que no esté en estados terminales.
    final row = await _client
        .from('solicitudes')
        .select()
        .eq('cliente_usuario_id', user.id)
        .neq('estado', 'finalizado')
        .neq('estado', 'cancelada')
        .neq('estado', 'rechazada')
        .neq('estado', 'abandonada')
        .order('creado_en', ascending: false)
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
      final profile = await _client
          .from('perfil_proveedor')
          .select('nombre_negocio')
          .or('usuario_id.eq.$providerId,id.eq.$providerId')
          .maybeSingle();
      return profile?['nombre_negocio'] as String?;
    } catch (_) {
      return null;
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

    return await updateSolicitud(solicitudId, data);
  }
}
