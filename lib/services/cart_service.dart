import 'package:supabase_flutter/supabase_flutter.dart';

class CartData {
  final String id;
  final String clienteUsuarioId;
  final DateTime? fechaServicioDeseada;
  final String? direccionServicio;
  final String estado;
  final DateTime creadoEn;
  final DateTime actualizadoEn;

  CartData({
    required this.id,
    required this.clienteUsuarioId,
    this.fechaServicioDeseada,
    this.direccionServicio,
    required this.estado,
    required this.creadoEn,
    required this.actualizadoEn,
  });

  static CartData fromMap(Map<String, dynamic> row) {
    return CartData(
      id: row['id'] as String,
      clienteUsuarioId: row['cliente_usuario_id'] as String,
      fechaServicioDeseada: row['fecha_servicio_deseada'] != null
          ? DateTime.parse(row['fecha_servicio_deseada'] as String)
          : null,
      direccionServicio: row['direccion_servicio'] as String?,
      estado: row['estado'] as String,
      creadoEn: DateTime.parse(row['creado_en'] as String),
      actualizadoEn: DateTime.parse(row['actualizado_en'] as String),
    );
  }
}

class CartService {
  CartService._();
  static final CartService instance = CartService._();

  SupabaseClient get _client => Supabase.instance.client;

  User get _user {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const AuthException('Usuario no autenticado');
    }
    return user;
  }

  Future<List<CartData>> getActiveCarts() async {
    final user = _user;
    final response = await _client
        .from('carrito')
        .select()
        .eq('cliente_usuario_id', user.id)
        .eq('estado', 'activo')
        .order('actualizado_en', ascending: false);

    final data = response as List<dynamic>;
    return data.map((e) => CartData.fromMap(e as Map<String, dynamic>)).toList();
  }
}
