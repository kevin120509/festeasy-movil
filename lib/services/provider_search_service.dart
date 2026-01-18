import 'dart:convert';
import 'package:http/http.dart' as http;

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
    final Map<String, String> categoryMap = {
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
}

/// Modelo para los resultados de búsqueda de proveedores
class ProviderResult {
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

  ProviderResult({
    this.placeId,
    required this.title,
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
