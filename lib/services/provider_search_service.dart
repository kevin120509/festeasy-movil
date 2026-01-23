import 'dart:convert';
import 'dart:math' as Math;
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Modelo para proveedor encontrado en búsqueda
class ProviderSearchResult {

  ProviderSearchResult({
    required this.perfilId,
    required this.usuarioId,
    required this.nombreNegocio,
    this.descripcion,
    this.avatarUrl,
    this.direccionFormato,
    this.latitud,
    this.longitud,
    this.distanciaKm,
    this.calificacionPromedio,
    this.totalResenas = 0,
  });

  factory ProviderSearchResult.fromMap(Map<String, dynamic> map) {
    return ProviderSearchResult(
      perfilId: map['id'] as String? ?? '',
      usuarioId: map['usuario_id'] as String? ?? '',
      nombreNegocio: map['nombre_negocio'] as String? ?? 'Sin nombre',
      descripcion: map['descripcion'] as String?,
      avatarUrl: map['avatar_url'] as String?,
      direccionFormato: map['direccion_formato'] as String?,
      latitud: (map['latitud'] as num?)?.toDouble(),
      longitud: (map['longitud'] as num?)?.toDouble(),
      distanciaKm: (map['distancia_km'] as num?)?.toDouble(),
      calificacionPromedio: (map['calificacion_promedio'] as num?)?.toDouble(),
      totalResenas: map['total_resenas'] as int? ?? 0,
    );
  }
  final String perfilId;
  final String usuarioId;
  final String nombreNegocio;
  final String? descripcion;
  final String? avatarUrl;
  final String? direccionFormato;
  final double? latitud;
  final double? longitud;
  final double? distanciaKm;
  final double? calificacionPromedio;
  final int totalResenas;
}

/// Servicio para buscar proveedores usando SerpAPI
class ProviderSearchService {
  ProviderSearchService._();
  static final ProviderSearchService instance = ProviderSearchService._();

  // API Key de SerpAPI
  static const String _apiKey =
      '44602cc38581c73caee60072799897507f5fa02de0ae5167adc785db23cebefc';
  static const String _baseUrl = 'https://serpapi.com/search.json';

  /// Busca proveedores en Google Maps según la categoría de servicio
  Future<List<ProviderResult>> searchProviders({
    required String query,
    String location = 'Merida, Yucatan, Mexico',
    double? latitude,
    double? longitude,
  }) async {
    try {
      final queryParams = {
        'engine': 'google_maps',
        'q': query,
        'location': location,
        'hl': 'es',
        'gl': 'mx',
        'api_key': _apiKey,
      };

      // Si tenemos coordenadas, usarlas
      if (latitude != null && longitude != null) {
        queryParams['ll'] = '@$latitude,$longitude,15z';
      }

      final uri = Uri.parse(_baseUrl).replace(queryParameters: queryParams);
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final localResults = data['local_results'] as List<dynamic>? ?? [];

        return localResults
            .map(
              (item) => ProviderResult.fromJson(item as Map<String, dynamic>),
            )
            .toList();
      } else {
        throw Exception('Error al buscar proveedores: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  /// Busca proveedores por categoría de servicio
  Future<List<ProviderResult>> searchByCategory(String categoryName) async {
    // Mapear categorías a términos de búsqueda
    final searchTerms = _getCategorySearchTerm(categoryName);
    return searchProviders(query: searchTerms);
  }

  String _getCategorySearchTerm(String category) {
    final categoryMap = <String, String>{
      'Mobiliario': 'Renta de mesas y sillas para eventos',
      'Catering': 'Servicio de banquetes para fiestas',
      'Decoración': 'Decoración para fiestas y eventos',
      'Entretenimiento': 'Animación y entretenimiento para fiestas',
      'Fotografía': 'Fotografía y video para eventos',
      'Música': 'Renta de luz y sonido para eventos',
      'Pasteles': 'Pastelerías para cumpleaños',
      'Locales': 'Renta de locales para fiestas',
      'Flores': 'Florerías para eventos',
      'Transporte': 'Transporte para eventos',
    };

    return categoryMap[category] ?? '$category para eventos en Mérida';
  }

  /// Busca proveedores en NUESTRA BD por categoría, distancia y ubicación
  /// Retorna proveedores registrados en Festeasy cercanos a las coordenadas
  Future<List<ProviderSearchResult>> searchProvidersByCategoryInDatabase({
    required String categoryId,
    required double latitude,
    required double longitude,
    double radiusKm = 25.0,
  }) async {
    try {
      final client = Supabase.instance.client;

      // Query con distancia PostGIS
      final response = await client.rpc<List<dynamic>>(
        'buscar_proveedores_cercanos',
        params: {
          'p_latitud': latitude,
          'p_longitud': longitude,
          'p_categoria_id': categoryId,
          'p_radio_km': radiusKm,
        },
      );

      return response
          .map((item) => ProviderSearchResult.fromMap(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Error buscando proveedores: $e');
    }
  }

  /// Búsqueda por nombre de categoría
  /// Busca proveedores que tengan una categoría con ese nombre
  Future<List<ProviderSearchResult>> searchProvidersByCategory({
    required String categoryId, // Ahora es el nombre de la categoría
    required double latitude,
    required double longitude,
  }) async {
    try {
      final client = Supabase.instance.client;

      // Primero, obtener el ID de la categoría por nombre
      final categoryResponse = await client
          .from('categorias_servicio')
          .select('id')
          .ilike('nombre', '%$categoryId%')
          .limit(1);

      if (categoryResponse.isEmpty) {
        // No se encontró la categoría, retornar lista vacía
        return [];
      }

      final categoryUUID = categoryResponse[0]['id'] as String;

      // Buscar proveedores con esa categoría
      final response = await client
          .from('perfil_proveedor')
          .select(
            '''
            id,
            usuario_id,
            nombre_negocio,
            descripcion,
            avatar_url,
            direccion_formato,
            latitud,
            longitud
            ''',
          )
          .eq('categoria_principal_id', categoryUUID)
          .or('estado.eq.active,estado.eq.pending,estado.eq.draft');

      // Filtrar y calcular distancia en memoria
      final results = <ProviderSearchResult>[];
      for (final item in response) {
        final provLatitude = (item['latitud'] as num?)?.toDouble();
        final provLongitude = (item['longitud'] as num?)?.toDouble();

        if (provLatitude != null && provLongitude != null) {
          final distanciaKm = _calculateDistance(
            latitude,
            longitude,
            provLatitude,
            provLongitude,
          );

          // Solo incluir si está dentro del radio de cobertura
          if (distanciaKm <= 25.0) {
            results.add(
              ProviderSearchResult(
                perfilId: item['id'] as String? ?? '',
                usuarioId: item['usuario_id'] as String? ?? '',
                nombreNegocio: item['nombre_negocio'] as String? ?? 'Sin nombre',
                descripcion: item['descripcion'] as String?,
                avatarUrl: item['avatar_url'] as String?,
                direccionFormato: item['direccion_formato'] as String?,
                latitud: provLatitude,
                longitud: provLongitude,
                distanciaKm: distanciaKm,
              ),
            );
          }
        } else {
          // Agregar proveedor sin ubicación definida
          results.add(
            ProviderSearchResult(
              perfilId: item['id'] as String? ?? '',
              usuarioId: item['usuario_id'] as String? ?? '',
              nombreNegocio: item['nombre_negocio'] as String? ?? 'Sin nombre',
              descripcion: item['descripcion'] as String?,
              avatarUrl: item['avatar_url'] as String?,
              direccionFormato: item['direccion_formato'] as String?,
            ),
          );
        }
      }

      // Ordenar por distancia (los sin ubicación van al final)
      results.sort((a, b) {
        final distA = a.distanciaKm ?? double.infinity;
        final distB = b.distanciaKm ?? double.infinity;
        return distA.compareTo(distB);
      });

      return results;
    } catch (e) {
      throw Exception('Error buscando proveedores: $e');
    }
  }

  /// Calcula distancia entre dos puntos usando la fórmula de Haversine
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const earthRadiusKm = 6371.0;

    final dLat = _toRad(lat2 - lat1);
    final dLon = _toRad(lon2 - lon1);

    final a = (Math.sin(dLat / 2) * Math.sin(dLat / 2)) +
        (Math.cos(_toRad(lat1)) * Math.cos(_toRad(lat2)) * Math.sin(dLon / 2) * Math.sin(dLon / 2));

    final c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  double _toRad(double value) {
    return value * 3.14159265359 / 180;
  }
}

/// Modelo para los resultados de búsqueda de proveedores
class ProviderResult {

  ProviderResult({
    required this.title, this.placeId,
    this.address,
    this.rating,
    this.reviews,
    this.phone,
    this.website,
    this.thumbnail,
    this.latitude,
    this.longitude,
    this.priceLevel,
    this.types,
    this.openNow,
    this.operatingHours,
  });

  factory ProviderResult.fromJson(Map<String, dynamic> json) {
    // Extraer coordenadas del GPS
    double? lat;
    double? lng;
    if (json['gps_coordinates'] != null) {
      lat = (json['gps_coordinates']['latitude'] as num?)?.toDouble();
      lng = (json['gps_coordinates']['longitude'] as num?)?.toDouble();
    }

    return ProviderResult(
      placeId: json['place_id'] as String?,
      title: json['title'] as String? ?? 'Sin nombre',
      address: json['address'] as String?,
      rating: (json['rating'] as num?)?.toDouble(),
      reviews: json['reviews'] as int?,
      phone: json['phone'] as String?,
      website: json['website'] as String?,
      thumbnail: json['thumbnail'] as String?,
      latitude: lat,
      longitude: lng,
      priceLevel: json['price'] as String?,
      types: (json['type'] as String?)?.split(','),
      openNow: json['open_state'] as String?,
      operatingHours: json['operating_hours'] as Map<String, dynamic>?,
    );
  }
  final String? placeId;
  final String title;
  final String? address;
  final double? rating;
  final int? reviews;
  final String? phone;
  final String? website;
  final String? thumbnail;
  final double? latitude;
  final double? longitude;
  final String? priceLevel;
  final List<String>? types;
  final String? openNow;
  final Map<String, dynamic>? operatingHours;

  Map<String, dynamic> toJson() => {
    'place_id': placeId,
    'title': title,
    'address': address,
    'rating': rating,
    'reviews': reviews,
    'phone': phone,
    'website': website,
    'thumbnail': thumbnail,
    'latitude': latitude,
    'longitude': longitude,
    'price_level': priceLevel,
    'types': types,
    'open_now': openNow,
    'operating_hours': operatingHours,
  };
}
