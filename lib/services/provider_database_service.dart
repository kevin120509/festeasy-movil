import 'package:supabase_flutter/supabase_flutter.dart';

/// Servicio para buscar proveedores desde la base de datos Supabase
class ProviderDatabaseService {
  ProviderDatabaseService._();
  static final ProviderDatabaseService instance = ProviderDatabaseService._();

  SupabaseClient get _client => Supabase.instance.client;

  /// Busca proveedores de la categoría especificada
  /// Intenta múltiples estrategias de búsqueda
  Future<List<ProviderData>> getProvidersByCategoryName(String categoryName) async {
    try {
      // Normalizar el nombre de categoría para la búsqueda
      final normalizedCategory = categoryName.trim().toLowerCase();
      
      // ESTRATEGIA 1: Buscar por categoria_principal
      try {
        final response = await _client
            .from('perfil_proveedor')
            .select('''
              id,
              usuario_id,
              nombre_negocio,
              descripcion,
              telefono,
              avatar_url,
              direccion_formato,
              latitud,
              longitud,
              radio_cobertura_km,
              tipo_suscripcion_actual,
              categoria_principal
            ''')
            .ilike('categoria_principal', '%$normalizedCategory%');

        final List<dynamic> data = response as List<dynamic>;
        
        if (data.isNotEmpty) {
          return _mapProviderData(data, categoryName);
        }
      } catch (_) {
        // La columna categoria_principal puede no existir, continuar
      }
      
      // ESTRATEGIA 2: Buscar por tabla servicios_proveedor
      final fromServices = await _getProvidersByServiceCategory(categoryName);
      if (fromServices.isNotEmpty) {
        return fromServices;
      }
      
      // ESTRATEGIA 3: Buscar todos los proveedores disponibles
      // (Para desarrollo/testing cuando no hay datos categorizados)
      return await _getAllProvidersForCategory(categoryName);
    } catch (e) {
      // Si todo falla, intentar obtener todos
      return await _getAllProvidersForCategory(categoryName);
    }
  }
  
  /// Mapea los datos de proveedor a objetos ProviderData
  List<ProviderData> _mapProviderData(List<dynamic> data, String categoryName) {
    return data.map((item) => ProviderData(
      id: item['usuario_id'] as String? ?? item['id'] as String,
      perfilId: item['id'] as String?,
      usuarioId: item['usuario_id'] as String?,
      nombreNegocio: item['nombre_negocio'] as String? ?? 'Sin nombre',
      descripcion: item['descripcion'] as String?,
      telefono: item['telefono'] as String?,
      avatarUrl: item['avatar_url'] as String?,
      direccion: item['direccion_formato'] as String?,
      latitud: (item['latitud'] as num?)?.toDouble(),
      longitud: (item['longitud'] as num?)?.toDouble(),
      radioCoberturaKm: item['radio_cobertura_km'] as int? ?? 20,
      tipoSuscripcion: item['tipo_suscripcion_actual'] as String? ?? 'basico',
      categoria: item['categoria_principal'] as String? ?? categoryName,
      paquetes: [],
    )).toList();
  }
  
  /// Obtiene todos los proveedores disponibles (para testing/desarrollo)
  Future<List<ProviderData>> _getAllProvidersForCategory(String categoryName) async {
    try {
      final response = await _client
          .from('perfil_proveedor')
          .select('''
            id,
            usuario_id,
            nombre_negocio,
            descripcion,
            telefono,
            avatar_url,
            direccion_formato,
            latitud,
            longitud,
            radio_cobertura_km,
            tipo_suscripcion_actual
          ''')
          .limit(50);

      final List<dynamic> data = response as List<dynamic>;
      
      return data.map((item) => ProviderData(
        id: item['usuario_id'] as String? ?? item['id'] as String,
        perfilId: item['id'] as String?,
        usuarioId: item['usuario_id'] as String?,
        nombreNegocio: item['nombre_negocio'] as String? ?? 'Sin nombre',
        descripcion: item['descripcion'] as String?,
        telefono: item['telefono'] as String?,
        avatarUrl: item['avatar_url'] as String?,
        direccion: item['direccion_formato'] as String?,
        latitud: (item['latitud'] as num?)?.toDouble(),
        longitud: (item['longitud'] as num?)?.toDouble(),
        radioCoberturaKm: item['radio_cobertura_km'] as int? ?? 20,
        tipoSuscripcion: item['tipo_suscripcion_actual'] as String? ?? 'basico',
        categoria: categoryName,
        paquetes: [],
      )).toList();
    } catch (e) {
      return [];
    }
  }

  /// Busca proveedores por categoría de servicio usando la tabla servicios_proveedor
  Future<List<ProviderData>> _getProvidersByServiceCategory(String categoryName) async {
    try {
      // Primero buscar el ID de la categoría
      final categoryResponse = await _client
          .from('categorias_servicio')
          .select('id')
          .ilike('nombre', '%$categoryName%')
          .maybeSingle();
      
      if (categoryResponse == null) {
        // No existe la categoría, devolver lista vacía
        return [];
      }
      
      final categoryId = categoryResponse['id'] as String;
      
      // Buscar servicios de esa categoría
      final serviciosResponse = await _client
          .from('servicios_proveedor')
          .select('proveedor_usuario_id')
          .eq('categoria_id', categoryId);
      
      final List<dynamic> serviciosData = serviciosResponse as List<dynamic>;
      
      if (serviciosData.isEmpty) {
        return [];
      }
      
      // Obtener IDs únicos de proveedores
      final providerIds = serviciosData
          .map((s) => s['proveedor_usuario_id'] as String)
          .toSet()
          .toList();
      
      // Buscar perfiles de esos proveedores
      final response = await _client
          .from('perfil_proveedor')
          .select('''
            id,
            usuario_id,
            nombre_negocio,
            descripcion,
            telefono,
            avatar_url,
            direccion_formato,
            latitud,
            longitud,
            radio_cobertura_km,
            tipo_suscripcion_actual,
            categoria_principal
          ''')
          .inFilter('usuario_id', providerIds);

      final List<dynamic> data = response as List<dynamic>;
      
      return data.map((item) => ProviderData(
        id: item['usuario_id'] as String? ?? item['id'] as String,
        perfilId: item['id'] as String?,
        usuarioId: item['usuario_id'] as String?,
        nombreNegocio: item['nombre_negocio'] as String? ?? 'Sin nombre',
        descripcion: item['descripcion'] as String?,
        telefono: item['telefono'] as String?,
        avatarUrl: item['avatar_url'] as String?,
        direccion: item['direccion_formato'] as String?,
        latitud: (item['latitud'] as num?)?.toDouble(),
        longitud: (item['longitud'] as num?)?.toDouble(),
        radioCoberturaKm: item['radio_cobertura_km'] as int? ?? 20,
        tipoSuscripcion: item['tipo_suscripcion_actual'] as String? ?? 'basico',
        categoria: item['categoria_principal'] as String? ?? categoryName,
        paquetes: [],
      )).toList();
    } catch (e) {
      // Si todo falla, devolver lista vacía - NO todos los proveedores
      return [];
    }
  }

  /// Obtiene todas las categorías de servicio disponibles
  Future<List<CategoryData>> getCategories() async {
    try {
      final response = await _client
          .from('categorias_servicio')
          .select('id, nombre, descripcion, icono')
          .eq('activa', true);

      final List<dynamic> data = response as List<dynamic>;
      
      return data.map((item) => CategoryData(
        id: item['id'] as String,
        nombre: item['nombre'] as String,
        descripcion: item['descripcion'] as String?,
        icono: item['icono'] as String?,
      )).toList();
    } catch (e) {
      return [];
    }
  }

  /// Obtiene los paquetes de un proveedor específico
  Future<List<PaqueteData>> getProviderPackages(String proveedorId) async {
    try {
      // Intentar buscar por proveedor_usuario_id primero
      var response = await _client
          .from('paquetes_proveedor')
          .select('''
            id,
            nombre,
            descripcion,
            precio_base,
            proveedor_usuario_id
          ''')
          .eq('proveedor_usuario_id', proveedorId)
          .eq('estado', 'publicado');

      List<dynamic> data = response as List<dynamic>;
      
      // Si no hay resultados, intentar buscar sin filtro de estado
      if (data.isEmpty) {
        response = await _client
            .from('paquetes_proveedor')
            .select('''
              id,
              nombre,
              descripcion,
              precio_base,
              proveedor_usuario_id
            ''')
            .eq('proveedor_usuario_id', proveedorId);
        
        data = response as List<dynamic>;
      }
      
      // Si aún no hay resultados, buscar todos los paquetes para debug
      if (data.isEmpty) {
        // Buscar el perfil del proveedor para obtener su ID correcto
        final perfilResponse = await _client
            .from('perfil_proveedor')
            .select('id, usuario_id')
            .or('usuario_id.eq.$proveedorId,id.eq.$proveedorId')
            .maybeSingle();
        
        if (perfilResponse != null) {
          final realUsuarioId = perfilResponse['usuario_id'] as String?;
          final perfilId = perfilResponse['id'] as String?;
          
          // Intentar con usuario_id del perfil
          if (realUsuarioId != null && realUsuarioId != proveedorId) {
            response = await _client
                .from('paquetes_proveedor')
                .select('''
                  id,
                  nombre,
                  descripcion,
                  precio_base,
                  proveedor_usuario_id
                ''')
                .eq('proveedor_usuario_id', realUsuarioId);
            
            data = response as List<dynamic>;
          }
          
          // Intentar con id del perfil
          if (data.isEmpty && perfilId != null) {
            response = await _client
                .from('paquetes_proveedor')
                .select('''
                  id,
                  nombre,
                  descripcion,
                  precio_base,
                  proveedor_usuario_id
                ''')
                .eq('proveedor_usuario_id', perfilId);
            
            data = response as List<dynamic>;
          }
        }
      }
      
      return data.map((item) => PaqueteData(
        id: item['id'] as String,
        nombre: item['nombre'] as String,
        descripcion: item['descripcion'] as String?,
        precioBase: (item['precio_base'] as num).toDouble(),
        items: [],
      )).toList();
    } catch (e) {
      print('Error al obtener paquetes: $e');
      return [];
    }
  }

  /// Obtiene las reseñas de un proveedor
  Future<List<ResenaData>> getProviderReviews(String proveedorUsuarioId) async {
    try {
      final response = await _client
          .from('resenas')
          .select('''
            id,
            calificacion,
            comentario,
            creado_en,
            perfil_cliente!autor_id(
              nombre_completo,
              avatar_url
            )
          ''')
          .eq('destinatario_id', proveedorUsuarioId)
          .order('creado_en', ascending: false);

      final List<dynamic> data = response as List<dynamic>;
      
      return data.map((item) {
        final cliente = item['perfil_cliente'];
        return ResenaData(
          id: item['id'] as String,
          calificacion: item['calificacion'] as int,
          comentario: item['comentario'] as String?,
          creadoEn: DateTime.parse(item['creado_en'] as String),
          autorNombre: cliente?['nombre_completo'] as String? ?? 'Anónimo',
          autorAvatar: cliente?['avatar_url'] as String?,
        );
      }).toList();
    } catch (e) {
      return [];
    }
  }

  /// Calcula la calificación promedio de un proveedor
  Future<double> getProviderAverageRating(String proveedorUsuarioId) async {
    try {
      final reviews = await getProviderReviews(proveedorUsuarioId);
      if (reviews.isEmpty) return 0;
      
      final total = reviews.fold<int>(0, (sum, r) => sum + r.calificacion);
      return total / reviews.length;
    } catch (e) {
      return 0;
    }
  }
}

/// Modelo de datos para un proveedor
class ProviderData {
  final String id;  // usuario_id preferido, o id del perfil como fallback
  final String? perfilId;  // id del perfil_proveedor
  final String? usuarioId;  // usuario_id del perfil_proveedor
  final String nombreNegocio;
  final String? descripcion;
  final String? telefono;
  final String? avatarUrl;
  final String? direccion;
  final double? latitud;
  final double? longitud;
  final int radioCoberturaKm;
  final String tipoSuscripcion;
  final String categoria;
  final List<PaqueteData> paquetes;
  double? rating;
  int? reviewCount;

  ProviderData({
    required this.id,
    this.perfilId,
    this.usuarioId,
    required this.nombreNegocio,
    this.descripcion,
    this.telefono,
    this.avatarUrl,
    this.direccion,
    this.latitud,
    this.longitud,
    this.radioCoberturaKm = 20,
    this.tipoSuscripcion = 'basico',
    this.categoria = '',
    this.paquetes = const [],
    this.rating,
    this.reviewCount,
  });

  bool get isPlus => tipoSuscripcion == 'plus';
}

/// Modelo de datos para un paquete
class PaqueteData {
  final String id;
  final String nombre;
  final String? descripcion;
  final double precioBase;
  final List<ItemPaquete> items;

  PaqueteData({
    required this.id,
    required this.nombre,
    this.descripcion,
    required this.precioBase,
    this.items = const [],
  });
}

/// Modelo de datos para un item de paquete
class ItemPaquete {
  final String id;
  final String nombre;
  final int cantidad;
  final String? unidad;

  ItemPaquete({
    required this.id,
    required this.nombre,
    required this.cantidad,
    this.unidad,
  });
}

/// Modelo de datos para una categoría
class CategoryData {
  final String id;
  final String nombre;
  final String? descripcion;
  final String? icono;

  CategoryData({
    required this.id,
    required this.nombre,
    this.descripcion,
    this.icono,
  });
}

/// Modelo de datos para una reseña
class ResenaData {
  final String id;
  final int calificacion;
  final String? comentario;
  final DateTime creadoEn;
  final String autorNombre;
  final String? autorAvatar;

  ResenaData({
    required this.id,
    required this.calificacion,
    this.comentario,
    required this.creadoEn,
    required this.autorNombre,
    this.autorAvatar,
  });
}
