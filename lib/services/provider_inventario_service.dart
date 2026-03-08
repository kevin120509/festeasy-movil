import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Estados y filtros para el inventario
enum EstadoStock { sinStock, stockBajo, stockAlto }

enum FiltroInventario { todos, bajo, agotado }

/// Modelo para productos del inventario
class ProductoInventarioData {
  ProductoInventarioData({
    required this.id,
    required this.proveedorId,
    required this.nombre,
    required this.descripcion,
    required this.precioUnitario,
    required this.stock,
    required this.categoria,
    required this.imagenUrl,
    required this.destacado,
    required this.creadoEn,
    required this.actualizadoEn,
  });

  final String id;
  final String proveedorId;
  final String nombre;
  final String? descripcion;
  final double precioUnitario;
  final int stock;
  final String categoria;
  final String? imagenUrl;
  final bool destacado;
  final DateTime creadoEn;
  final DateTime actualizadoEn;

  static ProductoInventarioData fromMap(Map<String, dynamic> row) {
    return ProductoInventarioData(
      id: row['id'] as String,
      proveedorId: row['proveedor_id'] as String,
      nombre: row['nombre'] as String? ?? '',
      descripcion: row['descripcion'] as String?,
      precioUnitario: (row['precio_unitario'] as num?)?.toDouble() ?? 0.0,
      stock: row['stock'] as int? ?? 0,
      categoria: row['categoria'] as String? ?? 'General',
      imagenUrl: row['imagen_url'] as String?,
      destacado: row['destacado'] as bool? ?? false,
      creadoEn: DateTime.parse(row['creado_en'] as String).toUtc(),
      actualizadoEn: DateTime.parse(row['actualizado_en'] as String).toUtc(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nombre': nombre,
      'descripcion': descripcion,
      'precio_unitario': precioUnitario,
      'stock': stock,
      'categoria': categoria,
      'imagen_url': imagenUrl,
      'destacado': destacado,
    };
  }

  /// Obtiene el estado del stock basado en la cantidad disponible
  EstadoStock getEstadoStock() {
    if (stock == 0) {
      return EstadoStock.sinStock;
    } else if (stock < 5) {
      return EstadoStock.stockBajo;
    } else {
      return EstadoStock.stockAlto;
    }
  }

  /// Copia un producto con cambios específicos
  ProductoInventarioData copyWith({
    String? id,
    String? proveedorId,
    String? nombre,
    String? descripcion,
    double? precioUnitario,
    int? stock,
    String? categoria,
    String? imagenUrl,
    bool? destacado,
    DateTime? creadoEn,
    DateTime? actualizadoEn,
  }) {
    return ProductoInventarioData(
      id: id ?? this.id,
      proveedorId: proveedorId ?? this.proveedorId,
      nombre: nombre ?? this.nombre,
      descripcion: descripcion ?? this.descripcion,
      precioUnitario: precioUnitario ?? this.precioUnitario,
      stock: stock ?? this.stock,
      categoria: categoria ?? this.categoria,
      imagenUrl: imagenUrl ?? this.imagenUrl,
      destacado: destacado ?? this.destacado,
      creadoEn: creadoEn ?? this.creadoEn,
      actualizadoEn: actualizadoEn ?? this.actualizadoEn,
    );
  }
}

/// Servicio singleton para gestionar el inventario del proveedor
class ProviderInventarioService {
  static final ProviderInventarioService _instance =
      ProviderInventarioService._internal();

  factory ProviderInventarioService() {
    return _instance;
  }

  ProviderInventarioService._internal();

  static ProviderInventarioService get instance => _instance;

  final SupabaseClient _supabase = Supabase.instance.client;

  /// Nombre de la tabla en la base de datos
  static const String _tableName = 'productos';

  /// Bucket de storage para imágenes
  static const String _bucketName = 'inventario';

  /// Obtiene todos los productos de un proveedor
  Future<List<ProductoInventarioData>> getProductos(String proveedorId) async {
    try {
      final response = await _supabase
          .from(_tableName)
          .select()
          .eq('proveedor_id', proveedorId)
          .order('actualizado_en', ascending: false);

      final productos = (response as List)
          .map(
            (item) =>
                ProductoInventarioData.fromMap(item as Map<String, dynamic>),
          )
          .toList();
      return productos;
    } catch (e) {
      throw Exception('Error al cargar productos: $e');
    }
  }

  /// Crea un nuevo producto en el inventario
  Future<ProductoInventarioData> createProducto({
    required String proveedorId,
    required String nombre,
    required String categoria,
    required double precioUnitario,
    required int stock,
    String? descripcion,
    String? imagenUrl,
  }) async {
    try {
      final Map<String, dynamic> data = {
        'proveedor_id': proveedorId,
        'nombre': nombre,
        'categoria': categoria,
        'precio_unitario': precioUnitario,
        'stock': stock,
        'descripcion': descripcion,
        'imagen_url': imagenUrl,
        'destacado': false,
        'creado_en': DateTime.now().toUtc().toIso8601String(),
        'actualizado_en': DateTime.now().toUtc().toIso8601String(),
      };

      final response =
          await _supabase.from(_tableName).insert(data).select().single()
              as Map<String, dynamic>;

      return ProductoInventarioData.fromMap(response);
    } catch (e) {
      throw Exception('Error al crear producto: $e');
    }
  }

  /// Actualiza un producto existente
  Future<ProductoInventarioData> updateProducto({
    required String productoId,
    String? nombre,
    String? descripcion,
    String? categoria,
    double? precioUnitario,
    int? stock,
    String? imagenUrl,
    bool? destacado,
  }) async {
    try {
      final Map<String, dynamic> data = {
        'actualizado_en': DateTime.now().toUtc().toIso8601String(),
      };

      if (nombre != null) data['nombre'] = nombre;
      if (descripcion != null) data['descripcion'] = descripcion;
      if (categoria != null) data['categoria'] = categoria;
      if (precioUnitario != null) data['precio_unitario'] = precioUnitario;
      if (stock != null) data['stock'] = stock;
      if (imagenUrl != null) data['imagen_url'] = imagenUrl;
      if (destacado != null) data['destacado'] = destacado;

      final response =
          await _supabase
                  .from(_tableName)
                  .update(data)
                  .eq('id', productoId)
                  .select()
                  .single()
              as Map<String, dynamic>;

      return ProductoInventarioData.fromMap(response);
    } catch (e) {
      throw Exception('Error al actualizar producto: $e');
    }
  }

  /// Elimina un producto del inventario
  Future<void> deleteProducto(String productoId) async {
    try {
      await _supabase.from(_tableName).delete().eq('id', productoId);
    } catch (e) {
      throw Exception('Error al eliminar producto: $e');
    }
  }

  /// Alterna el estado destacado de un producto
  Future<ProductoInventarioData> toggleDestacado(
    String productoId,
    bool nuevoEstado,
  ) async {
    return updateProducto(productoId: productoId, destacado: nuevoEstado);
  }

  /// Sube una imagen a Supabase Storage
  /// Retorna la URL pública de la imagen
  Future<String> uploadProductImage({
    required File imageFile,
    required String proveedorId,
  }) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileExtension = imageFile.path.split('.').last;
      final fileName = 'products/$proveedorId/$timestamp.$fileExtension';

      await _supabase.storage
          .from(_bucketName)
          .upload(
            fileName,
            imageFile,
            fileOptions: const FileOptions(upsert: false),
          );

      // Obtener URL pública
      final publicUrl = _supabase.storage
          .from(_bucketName)
          .getPublicUrl(fileName);

      return publicUrl;
    } catch (e) {
      throw Exception('Error al subir imagen: $e');
    }
  }

  /// Elimina una imagen de Supabase Storage
  Future<void> deleteProductImage(String imagenUrl) async {
    try {
      // Extraer la ruta del archivo de la URL pública
      if (imagenUrl.contains('/storage/v1/object/public/inventario/')) {
        final filePath = imagenUrl
            .split('/storage/v1/object/public/inventario/')
            .last;

        await _supabase.storage.from(_bucketName).remove([filePath]);
      }
    } catch (e) {
      throw Exception('Error al eliminar imagen: $e');
    }
  }

  /// Filtra productos según el criterio
  static List<ProductoInventarioData> filtrarProductos(
    List<ProductoInventarioData> productos,
    FiltroInventario filtro,
  ) {
    return productos.where((producto) {
      switch (filtro) {
        case FiltroInventario.todos:
          return true;
        case FiltroInventario.bajo:
          return producto.stock > 0 && producto.stock < 5;
        case FiltroInventario.agotado:
          return producto.stock == 0;
      }
    }).toList();
  }
}
