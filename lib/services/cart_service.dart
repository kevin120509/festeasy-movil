import 'package:supabase_flutter/supabase_flutter.dart';

class CartData {
  CartData({
    required this.id,
    required this.clienteUsuarioId,
    required this.estado,
    required this.creadoEn,
    required this.actualizadoEn,
    this.fechaServicioDeseada,
    this.direccionServicio,
  });
  final String id;
  final String clienteUsuarioId;
  final DateTime? fechaServicioDeseada;
  final String? direccionServicio;
  final String estado;
  final DateTime creadoEn;
  final DateTime actualizadoEn;

  static CartData fromMap(Map<String, dynamic> row) {
    return CartData(
      id: row['id'] as String? ?? '',
      clienteUsuarioId: row['cliente_usuario_id'] as String? ?? '',
      fechaServicioDeseada: row['fecha_servicio_deseada'] != null
          ? DateTime.tryParse(row['fecha_servicio_deseada'] as String)
          : null,
      direccionServicio: row['direccion_servicio'] as String?,
      estado: row['estado'] as String? ?? 'activo',
      creadoEn: row['creado_en'] != null 
          ? DateTime.tryParse(row['creado_en'] as String) ?? DateTime.now()
          : DateTime.now(),
      actualizadoEn: row['actualizado_en'] != null
          ? DateTime.tryParse(row['actualizado_en'] as String) ?? DateTime.now()
          : DateTime.now(),
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
    return data
        .map((e) => CartData.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  /// Crea un carrito si no existe, o retorna el existente
  Future<String> createOrGetCart({
    required String categoryId,
    DateTime? fechaServicio,
    String? direccion,
    double? latitud,
    double? longitud,
  }) async {
    final user = _user;

    try {
      // Buscar carrito activo existente más reciente
      final existingResult = await _client
          .from('carrito')
          .select('id, fecha_servicio_deseada, direccion_servicio')
          .eq('cliente_usuario_id', user.id)
          .eq('estado', 'activo')
          .order('actualizado_en', ascending: false)
          .limit(1);

      if ((existingResult as List).isNotEmpty) {
        final existing = (existingResult as List).first;
        final existingDate = existing['fecha_servicio_deseada'] as String?;
        final existingAddr = existing['direccion_servicio'] as String?;
        
        final newDateStr = fechaServicio != null 
            ? fechaServicio.toString().split(' ')[0] 
            : null;

        // Si la fecha o dirección han cambiado significativamente, 
        // asumimos que es una solicitud diferente y creamos un nuevo carrito.
        if (existingDate == newDateStr && existingAddr == direccion) {
          print('[CartService] Reutilizando carrito existente: ${existing['id']}');
          return existing['id'] as String;
        } else {
          print('[CartService] Datos diferentes detectados. Creando nuevo carrito independiente.');
        }
      }

      // Crea nuevo carrito
      final dateStr = fechaServicio != null
          ? fechaServicio.toString().split(' ')[0]
          : null;

      print('[CartService] Creando nuevo carrito...');
      print('[CartService] Usuario: ${user.id}');
      print('[CartService] Fecha: $dateStr, Dirección: $direccion');

      final response = await _client
          .from('carrito')
          .insert({
            'cliente_usuario_id': user.id,
            'fecha_servicio_deseada': dateStr,
            'direccion_servicio': direccion,
            'latitud_servicio': latitud,
            'longitud_servicio': longitud,
            'estado': 'activo',
          })
          .select('id')
          .single();

      final carritoId = response['id'] as String;
      print('[CartService] Carrito creado: $carritoId');
      return carritoId;
    } catch (e) {
      print('[CartService] ERROR: $e');
      throw Exception('Error en createOrGetCart: $e');
    }
  }

  /// Agrega o actualiza un item en el carrito
  Future<void> addItemToCart({
    required String carritoId,
    required String paqueteId,
    required int cantidad,
    required double precioUnitario,
  }) async {
    try {
      print(
        '[CartService] Agregando item: paqueteId=$paqueteId, cantidad=$cantidad, precio=$precioUnitario al carrito=$carritoId',
      );

      // Buscar si el item ya existe
      final existing = await _client
          .from('items_carrito')
          .select('id')
          .eq('carrito_id', carritoId)
          .eq('paquete_id', paqueteId)
          .maybeSingle();

      if (existing != null) {
        // Actualizar cantidad
        print('[CartService] Actualizando cantidad del item existente');
        await _client
            .from('items_carrito')
            .update({'cantidad': cantidad})
            .eq('carrito_id', carritoId)
            .eq('paquete_id', paqueteId);
      } else {
        // Insertar nuevo item
        print('[CartService] Insertando nuevo item');
        await _client.from('items_carrito').insert({
          'carrito_id': carritoId,
          'paquete_id': paqueteId,
          'cantidad': cantidad,
          'precio_unitario_momento': precioUnitario,
        });
      }

      // Actualizar timestamp del carrito
      print('[CartService] Actualizando timestamp del carrito');
      await _client
          .from('carrito')
          .update({'actualizado_en': DateTime.now().toIso8601String()})
          .eq('id', carritoId);

      print('[CartService] Item agregado correctamente');
    } catch (e) {
      print('[CartService] ERROR al agregar item: $e');
      throw Exception('Error en addItemToCart: $e');
    }
  }

  /// Marca un carrito como convertido (después de enviar solicitud)
  Future<void> convertCart(String carritoId) async {
    await _client
        .from('carrito')
        .update({'estado': 'convertido'})
        .eq('id', carritoId);
  }

  /// Obtiene los items de un carrito con información del paquete y proveedor
  Future<Map<String, dynamic>?> getCartItemsWithProvider(
    String carritoId,
  ) async {
    final itemsResponse = await _client
        .from('items_carrito')
        .select('''
          id,
          cantidad,
          precio_unitario_momento,
          paquete_id,
          paquetes_proveedor(
            id,
            nombre,
            precio_base,
            proveedor_usuario_id
          )
          ''')
        .eq('carrito_id', carritoId);

    if ((itemsResponse as List).isEmpty) {
      return null;
    }

    final items = itemsResponse as List<dynamic>;

    // Obtener información del proveedor del primer item
    final firstItem = items.first as Map<String, dynamic>;
    final paquete = firstItem['paquetes_proveedor'] as Map<String, dynamic>;
    final proveedorUsuarioId = paquete['proveedor_usuario_id'] as String;

    // Consulta separada para obtener perfil del proveedor
    final providerProfile = await _client
        .from('perfil_proveedor')
        .select('nombre_negocio, avatar_url')
        .eq('usuario_id', proveedorUsuarioId)
        .maybeSingle();

    // Construir lista de items para CartPage
    final allItems = items.map((item) {
      final paq =
          (item as Map<String, dynamic>)['paquetes_proveedor']
              as Map<String, dynamic>;
      return {
        'id': paq['id'] as String,
        'name': paq['nombre'] as String,
        'price': (paq['precio_base'] as num).toDouble(),
        'description': '',
      };
    }).toList();

    // Construir mapa cartItems (paquete_id -> cantidad)
    final cartItems = <String, int>{};
    for (final item in items) {
      final paq =
          (item as Map<String, dynamic>)['paquetes_proveedor']
              as Map<String, dynamic>;
      cartItems[paq['id'] as String] = item['cantidad'] as int;
    }

    return {
      'cartItems': cartItems,
      'allItems': allItems,
      'providerName':
          providerProfile?['nombre_negocio'] as String? ?? 'Proveedor',
      'providerUserId': proveedorUsuarioId,
      'providerAvatarUrl': providerProfile?['avatar_url'] as String?,
    };
  }

  /// Obtiene todos los items del carrito activo para sincronizar con la sesión local
  Future<List<Map<String, dynamic>>> getCartItemsForLocalSession() async {
    final user = _user;

    // Buscar carritos activos (TODOS)
    final cartResultQuery = await _client
        .from('carrito')
        .select('id')
        .eq('cliente_usuario_id', user.id)
        .eq('estado', 'activo')
        .order('creado_en', ascending: false);

    if ((cartResultQuery as List).isEmpty) return [];
    
    final List<String> cartIds = (cartResultQuery as List).map((row) => row['id'] as String).toList();

    // Obtener items con joins para todos los IDs
    final itemsResponse = await _client.from('items_carrito').select('''
          cantidad,
          precio_unitario_momento,
          paquete_id,
          carrito_id,
          paquetes_proveedor(
            nombre,
            precio_base,
            proveedor_usuario_id
          )
          ''').filter('carrito_id', 'in', cartIds);

    final items = itemsResponse as List<dynamic>;
    final result = <Map<String, dynamic>>[];

    for (final item in items) {
      final p = item['paquetes_proveedor'] as Map<String, dynamic>?;
      final providerId = p?['proveedor_usuario_id'] as String? ?? 'unk';

      // Perfil del proveedor (opcional)
      Map<String, dynamic>? profile;
      if (providerId != 'unk') {
        profile = await _client
            .from('perfil_proveedor')
            .select('nombre_negocio, avatar_url')
            .eq('usuario_id', providerId)
            .maybeSingle();
      }

      result.add({
        'packageId': item['paquete_id'] ?? '',
        'packageName': p?['nombre'] ?? 'Paquete no disponible (Borrador/Privado)',
        'packagePrice': (item['precio_unitario_momento'] as num?)?.toDouble() ?? 0.0,
        'quantity': item['cantidad'] ?? 1,
        'providerUserId': providerId,
        'providerName': profile?['nombre_negocio'] ?? 'Proveedor desconocido',
        'providerAvatarUrl': profile?['avatar_url'] ?? '',
        'carritoId': item['carrito_id'] as String,
      });
    }

    return result;
  }
}
