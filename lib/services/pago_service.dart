import 'package:supabase_flutter/supabase_flutter.dart';

class PagoData {

  PagoData({
    required this.id,
    required this.clienteUsuarioId, required this.proveedorUsuarioId, required this.monto, required this.metodoPago, required this.estado, required this.creadoEn, required this.actualizadoEn, this.cotizacionId,
    this.comprobanteUrl,
    this.motivoRechazo,
    this.solicitudId,
    this.idTransaccionExterna,
    this.tipoPago,
  });
  final String id;
  final String? cotizacionId;
  final String clienteUsuarioId;
  final String proveedorUsuarioId;
  final double monto;
  final String metodoPago;
  final String estado;
  final String? comprobanteUrl;
  final String? motivoRechazo;
  final String? solicitudId;
  final String? idTransaccionExterna;
  final String? tipoPago; // 'anticipo' | 'liquidacion'
  final DateTime creadoEn;
  final DateTime actualizadoEn;

  static DateTime _parseDate(String value) => DateTime.parse(value).toUtc();

  static PagoData fromMap(Map<String, dynamic> row) {
    return PagoData(
      id: row['id'] as String,
      cotizacionId: row['cotizacion_id'] as String?,
      clienteUsuarioId: row['cliente_usuario_id'] as String,
      proveedorUsuarioId: row['proveedor_usuario_id'] as String,
      monto: (row['monto'] as num).toDouble(),
      metodoPago: row['metodo_pago'] as String,
      estado: row['estado'] as String,
      comprobanteUrl: row['comprobante_url'] as String?,
      motivoRechazo: row['motivo_rechazo'] as String?,
      solicitudId: row['solicitud_id'] as String?,
      idTransaccionExterna: row['id_transaccion_externa'] as String?,
      tipoPago: row['tipo_pago'] as String?,
      creadoEn: _parseDate(row['creado_en'] as String),
      actualizadoEn: _parseDate(row['actualizado_en'] as String),
    );
  }
}

class PagoService {
  PagoService._();
  static final PagoService instance = PagoService._();

  SupabaseClient get _client => Supabase.instance.client;

  User get _user {
    final user = _client.auth.currentUser;
    if (user == null) throw const AuthException('Usuario no autenticado');
    return user;
  }

  Future<PagoData> createPago({
    required String proveedorUsuarioId, required double monto, required String metodoPago, String? cotizacionId,
    String? solicitudId,
    String? tipoPago,
  }) async {
    final user = _user;

    final inserted = await _client
        .from('pagos')
        .insert({
          'cotizacion_id': cotizacionId,
          'cliente_usuario_id': user.id,
          'proveedor_usuario_id': proveedorUsuarioId,
          'monto': monto,
          'metodo_pago': metodoPago,
          'estado': 'esperando_comprobante',
          'solicitud_id': solicitudId,
          'tipo_pago': tipoPago,
        })
        .select()
        .single();

    return PagoData.fromMap(inserted);
  }

  Future<List<PagoData>> getPagosForSolicitud(String solicitudId) async {
    final rows =
        await _client.from('pagos').select().eq('solicitud_id', solicitudId)
            as List<dynamic>;

    return rows
        .map((r) => PagoData.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  Future<PagoData> updatePagoEstado(
    String pagoId,
    String nuevoEstado, {
    String? motivoRechazo,
  }) async {
    final updated = await _client
        .from('pagos')
        .update({
          'estado': nuevoEstado,
          if (motivoRechazo != null) 'motivo_rechazo': motivoRechazo,
        })
        .eq('id', pagoId)
        .select()
        .single();

    return PagoData.fromMap(updated);
  }

  Future<PagoData> attachComprobante(
    String pagoId,
    String comprobanteUrl,
  ) async {
    final updated = await _client
        .from('pagos')
        .update({
          'comprobante_url': comprobanteUrl,
          'estado': 'en_revision',
        })
        .eq('id', pagoId)
        .select()
        .single();

    return PagoData.fromMap(updated);
  }
}
