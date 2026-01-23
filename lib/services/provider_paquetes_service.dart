
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Modelo para items dentro de un paquete
class ItemPaqueteData {

  ItemPaqueteData({
    required this.id,
    required this.paqueteId,
    required this.nombreItem,
    required this.cantidad,
    required this.creadoEn, this.unidad,
  });
  final String id;
  final String paqueteId;
  final String nombreItem;
  final int cantidad;
  final String? unidad;
  final DateTime creadoEn;

  static ItemPaqueteData fromMap(Map<String, dynamic> row) {
    return ItemPaqueteData(
      id: row['id'] as String,
      paqueteId: row['paquete_id'] as String,
      nombreItem: row['nombre_item'] as String? ?? '',
      cantidad: row['cantidad'] as int? ?? 1,
      unidad: row['unidad'] as String?,
      creadoEn: DateTime.parse(row['creado_en'] as String).toUtc(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'paquete_id': paqueteId,
      'nombre_item': nombreItem,
      'cantidad': cantidad,
      'unidad': unidad,
    };
  }
}

/// Modelo para paquetes/servicios del proveedor
class PaqueteProveedorData {

  PaqueteProveedorData({
    required this.id,
    required this.proveedorUsuarioId,
    required this.categoriaServicioId,
    required this.nombre,
    required this.precioBase, required this.creadoEn, required this.actualizadoEn, this.descripcion,
    this.estado = 'borrador',
    this.tipoCobro = 'fijo',
    this.fotos = const [],
    this.detallesJson,
    this.items,
  });
  final String id;
  final String proveedorUsuarioId;
  final String categoriaServicioId;
  final String nombre;
  final String? descripcion;
  final double precioBase;
  final String estado; // 'borrador', 'publicado', 'archivado'
  final String tipoCobro; // 'fijo' o 'por_persona'
  final List<String> fotos; // URLs de las fotos del paquete
  final Map<String, dynamic>? detallesJson;
  final List<ItemPaqueteData>? items;
  final DateTime creadoEn;
  final DateTime actualizadoEn;

  static PaqueteProveedorData fromMap(Map<String, dynamic> row) {
    List<ItemPaqueteData>? itemsList;
    if (row['items_paquete'] != null && row['items_paquete'] is List) {
      itemsList = (row['items_paquete'] as List)
          .map((item) => ItemPaqueteData.fromMap(item as Map<String, dynamic>))
          .toList();
    }

    // Extraer tipo de cobro y fotos desde detallesJson
    final detallesJson = row['detalles_json'] as Map<String, dynamic>?;
    final tipoCobro =
        (detallesJson?['tipoCobro'] as String?) ?? 'fijo';
    final fotosJson = detallesJson?['fotos'] as List?;
    final fotos =
        fotosJson?.map((f) => f as String).toList() ?? [];

    return PaqueteProveedorData(
      id: row['id'] as String,
      proveedorUsuarioId: row['proveedor_usuario_id'] as String,
      categoriaServicioId: row['categoria_servicio_id'] as String,
      nombre: row['nombre'] as String? ?? 'Sin nombre',
      descripcion: row['descripcion'] as String?,
      precioBase: (row['precio_base'] as num?)?.toDouble() ?? 0,
      estado: row['estado'] as String? ?? 'borrador',
      tipoCobro: tipoCobro,
      fotos: fotos,
      detallesJson: detallesJson,
      items: itemsList,
      creadoEn: DateTime.parse(row['creado_en'] as String).toUtc(),
      actualizadoEn: DateTime.parse(row['actualizado_en'] as String).toUtc(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'proveedor_usuario_id': proveedorUsuarioId,
      'categoria_servicio_id': categoriaServicioId,
      'nombre': nombre,
      'descripcion': descripcion,
      'precio_base': precioBase,
      'estado': estado,
      'detalles_json': {
        'tipoCobro': tipoCobro,
        'fotos': fotos,
        ...?detallesJson,
      },
    };
  }

  bool get isPublished => estado == 'publicado';
  bool get isDraft => estado == 'borrador';
  bool get isArchived => estado == 'archivado';
  bool get esCobroFijo => tipoCobro == 'fijo';
  bool get esCobroPorPersona => tipoCobro == 'por_persona';
}

/// Servicio para gestionar paquetes/servicios del proveedor
class ProviderPaquetesService {
  ProviderPaquetesService._();
  static final ProviderPaquetesService instance = ProviderPaquetesService._();

  SupabaseClient get _client => Supabase.instance.client;

  /// Obtiene todos los paquetes de un proveedor
  Future<List<PaqueteProveedorData>> getPaquetesByProveedor(
    String proveedorUsuarioId,
  ) async {
    try {
      final response = await _client
          .from('paquetes_proveedor')
          .select('*, items_paquete(*)')
          .eq('proveedor_usuario_id', proveedorUsuarioId)
          .order('creado_en', ascending: false);

      return (response as List)
          .map((item) => PaqueteProveedorData.fromMap(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Obtiene paquetes publicados de un proveedor
  Future<List<PaqueteProveedorData>> getPaquetesPublicados(
    String proveedorUsuarioId,
  ) async {
    try {
      final response = await _client
          .from('paquetes_proveedor')
          .select('*, items_paquete(*)')
          .eq('proveedor_usuario_id', proveedorUsuarioId)
          .or('estado.eq.publicado,estado.eq.borrador')
          .order('creado_en', ascending: false);

      return (response as List)
          .map((item) => PaqueteProveedorData.fromMap(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Obtiene un paquete específico por ID
  Future<PaqueteProveedorData?> getPaqueteById(String paqueteId) async {
    try {
      final response = await _client
          .from('paquetes_proveedor')
          .select('*, items_paquete(*)')
          .eq('id', paqueteId)
          .single();

      return PaqueteProveedorData.fromMap(response);
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST116') {
        return null;
      }
      rethrow;
    } catch (e) {
      return null;
    }
  }

  /// Crea un nuevo paquete con tipo de cobro y fotos
  Future<PaqueteProveedorData> createPaquete({
    required String proveedorUsuarioId,
    required String categoriaServicioId,
    required String nombre,
    required double precioBase, String? descripcion,
    String tipoCobro = 'fijo',
    List<String> fotos = const [],
  }) async {
    try {
      final response = await _client
          .from('paquetes_proveedor')
          .insert({
            'proveedor_usuario_id': proveedorUsuarioId,
            'categoria_servicio_id': categoriaServicioId,
            'nombre': nombre,
            'descripcion': descripcion,
            'precio_base': precioBase,
            'estado': 'borrador',
            'detalles_json': {
              'tipoCobro': tipoCobro,
              'fotos': fotos,
            },
          })
          .select('*, items_paquete(*)')
          .single();

      return PaqueteProveedorData.fromMap(response);
    } catch (e) {
      throw Exception('Error creando paquete: $e');
    }
  }

  /// Actualiza un paquete existente
  Future<PaqueteProveedorData> updatePaquete({
    required String paqueteId,
    String? nombre,
    String? descripcion,
    double? precioBase,
    String? estado,
    Map<String, dynamic>? detallesJson,
  }) async {
    try {
      debugPrint('🔍 [updatePaquete] Actualizando paquete: $paqueteId');
      
      final updateData = <String, dynamic>{};
      if (nombre != null) updateData['nombre'] = nombre;
      if (descripcion != null) updateData['descripcion'] = descripcion;
      if (precioBase != null) updateData['precio_base'] = precioBase;
      if (estado != null) updateData['estado'] = estado;
      if (detallesJson != null) updateData['detalles_json'] = detallesJson;
      updateData['actualizado_en'] = DateTime.now().toUtc().toIso8601String();

      final response = await _client
          .from('paquetes_proveedor')
          .update(updateData)
          .eq('id', paqueteId)
          .select('*, items_paquete(*)')
          .single();

      debugPrint('✅ [updatePaquete] Paquete actualizado exitosamente');
      return PaqueteProveedorData.fromMap(response);
    } catch (e) {
      debugPrint('❌ [updatePaquete] Error: $e');
      throw Exception('Error actualizando paquete: $e');
    }
  }

  /// Publica un paquete (cambia estado a 'publicado')
  Future<PaqueteProveedorData> publishPaquete(String paqueteId) async {
    return updatePaquete(
      paqueteId: paqueteId,
      estado: 'publicado',
    );
  }

  /// Archiva un paquete (cambia estado a 'archivado')
  Future<PaqueteProveedorData> archivePaquete(String paqueteId) async {
    return updatePaquete(
      paqueteId: paqueteId,
      estado: 'archivado',
    );
  }

  /// Elimina un paquete (solo borradores)
  Future<void> deletePaquete(String paqueteId) async {
    try {
      debugPrint('🔍 [deletePaquete] Eliminando paquete: $paqueteId');
      await _client.from('paquetes_proveedor').delete().eq('id', paqueteId);
      debugPrint('✅ [deletePaquete] Paquete eliminado exitosamente');
    } catch (e) {
      debugPrint('❌ [deletePaquete] Error: $e');
      throw Exception('Error eliminando paquete: $e');
    }
  }

  /// Agrega un item a un paquete
  Future<ItemPaqueteData> addItemToPaquete({
    required String paqueteId,
    required String nombreItem,
    required int cantidad,
    String? unidad,
  }) async {
    try {
      final response = await _client
          .from('items_paquete')
          .insert({
            'paquete_id': paqueteId,
            'nombre_item': nombreItem,
            'cantidad': cantidad,
            'unidad': unidad,
          })
          .select()
          .single();

      return ItemPaqueteData.fromMap(response);
    } catch (e) {
      throw Exception('Error agregando item: $e');
    }
  }

  /// Elimina un item de un paquete
  Future<void> deleteItemFromPaquete(String itemId) async {
    try {
      await _client.from('items_paquete').delete().eq('id', itemId);
    } catch (e) {
      throw Exception('Error eliminando item: $e');
    }
  }

  /// Obtiene todas las categorías disponibles
  Future<List<Map<String, dynamic>>> getCategorias() async {
    try {
      final response =
          await _client.from('categorias_servicio').select().eq('activa', true);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }

  /// Nombre del bucket de almacenamiento
  static const String _bucketName = 'festeasy';
  static const String _paqueteFotosFolder = 'paquete_fotos';
  
  /// Obtiene la ruta de almacenamiento para una foto de paquete
  static String _getPaqueteFotoPath({
    required String proveedorUsuarioId,
    required String paqueteId,
    required String fileName,
  }) => '$proveedorUsuarioId/$_paqueteFotosFolder/$paqueteId/$fileName';

  /// Sube una foto para un paquete
  Future<String?> uploadFotoPaquete({
    required String proveedorUsuarioId,
    required String paqueteId,
    required List<int> fileBytes,
    required String fileName,
  }) async {
    try {
      final filePath = _getPaqueteFotoPath(
        proveedorUsuarioId: proveedorUsuarioId,
        paqueteId: paqueteId,
        fileName: fileName,
      );

      await _client.storage.from(_bucketName).uploadBinary(
        filePath,
        Uint8List.fromList(fileBytes),
        fileOptions: const FileOptions(upsert: true),
      );

      final publicUrl = _client.storage.from(_bucketName).getPublicUrl(filePath);
      return publicUrl;
    } catch (e) {
      debugPrint('❌ Error subiendo foto: $e');
      throw Exception('Error subiendo foto: $e');
    }
  }
  
  /// Obtiene la URL pública de una foto sin subirla
  String getFotoPublicUrl({
    required String proveedorUsuarioId,
    required String paqueteId,
    required String fileName,
  }) {
    final filePath = _getPaqueteFotoPath(
      proveedorUsuarioId: proveedorUsuarioId,
      paqueteId: paqueteId,
      fileName: fileName,
    );
    return _client.storage.from(_bucketName).getPublicUrl(filePath);
  }

  /// Elimina una foto del storage
  Future<void> deleteFotoPaquete({
    required String proveedorUsuarioId,
    required String paqueteId,
    required String fileName,
  }) async {
    try {
      final filePath = _getPaqueteFotoPath(
        proveedorUsuarioId: proveedorUsuarioId,
        paqueteId: paqueteId,
        fileName: fileName,
      );
      await _client.storage.from(_bucketName).remove([filePath]);
      debugPrint('✅ Foto eliminada: $filePath');
    } catch (e) {
      debugPrint('❌ Error eliminando foto: $e');
      throw Exception('Error eliminando foto: $e');
    }
  }

  /// Elimina una foto usando su URL pública
  Future<void> deleteFotoPaqueteByUrl({
    required String fotoUrl,
  }) async {
    try {
      // Extraer el path del storage desde la URL
      // URL format: https://xxx.supabase.co/storage/v1/object/public/festeasy/{path}
      final uri = Uri.parse(fotoUrl);
      final pathSegments = uri.pathSegments;
      
      // Encontrar el índice de 'festeasy' en los segmentos
      final festeasyIndex = pathSegments.indexOf(_bucketName);
      if (festeasyIndex == -1) {
        throw Exception('URL inválida: no contiene el bucket $_bucketName');
      }
      
      // Construir el path: todo después de 'festeasy'
      final filePath = pathSegments.sublist(festeasyIndex + 1).join('/');
      
      await _client.storage.from(_bucketName).remove([filePath]);
      debugPrint('✅ Foto eliminada por URL: $filePath');
    } catch (e) {
      debugPrint('❌ Error eliminando foto por URL: $e');
      throw Exception('Error eliminando foto: $e');
    }
  }

  /// Actualiza la lista de fotos de un paquete
  Future<PaqueteProveedorData> updateFotosPaquete({
    required String paqueteId,
    required List<String> fotos,
  }) async {
    try {
      final paquete = await getPaqueteById(paqueteId);
      if (paquete == null) throw Exception('Paquete no encontrado');

      return updatePaquete(
        paqueteId: paqueteId,
        detallesJson: {
          ...?paquete.detallesJson,
          'tipoCobro': paquete.tipoCobro,
          'fotos': fotos,
        },
      );
    } catch (e) {
      throw Exception('Error actualizando fotos: $e');
    }
  }

  /// Agrega una foto a un paquete existente
  Future<PaqueteProveedorData> addFotoToPaquete({
    required String paqueteId,
    required String fotoUrl,
  }) async {
    try {
      final paquete = await getPaqueteById(paqueteId);
      if (paquete == null) throw Exception('Paquete no encontrado');

      final fotosList = List<String>.from(paquete.fotos);
      if (!fotosList.contains(fotoUrl)) {
        fotosList.add(fotoUrl);
      }

      return updatePaquete(
        paqueteId: paqueteId,
        detallesJson: {
          ...?paquete.detallesJson,
          'tipoCobro': paquete.tipoCobro,
          'fotos': fotosList,
        },
      );
    } catch (e) {
      throw Exception('Error agregando foto: $e');
    }
  }
}
