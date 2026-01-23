import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Modelo para el perfil del proveedor
class ProviderPerfilData {

  ProviderPerfilData({
    required this.id,
    required this.nombreNegocio, required this.creadoEn, required this.actualizadoEn, this.usuarioId,
    this.descripcion,
    this.telefono,
    this.avatarUrl,
    this.direccionFormato,
    this.latitud,
    this.longitud,
    this.radioCoberturaKm = 20,
    this.tipoSuscripcion = 'basico',
    this.categoriaPrincipalId,
    this.estado = 'active',
    this.datosBancariosJson,
  });
  final String id;
  final String? usuarioId;
  final String nombreNegocio;
  final String? descripcion;
  final String? telefono;
  final String? avatarUrl;
  final String? direccionFormato;
  final double? latitud;
  final double? longitud;
  final int radioCoberturaKm;
  final String tipoSuscripcion;
  final String? categoriaPrincipalId;
  final String estado;
  final Map<String, dynamic>? datosBancariosJson;
  final DateTime creadoEn;
  final DateTime actualizadoEn;

  static ProviderPerfilData fromMap(Map<String, dynamic> row) {
    return ProviderPerfilData(
      id: row['id'] as String,
      usuarioId: row['usuario_id'] as String?,
      nombreNegocio: row['nombre_negocio'] as String? ?? 'Sin nombre',
      descripcion: row['descripcion'] as String?,
      telefono: row['telefono'] as String?,
      avatarUrl: row['avatar_url'] as String?,
      direccionFormato: row['direccion_formato'] as String?,
      latitud: (row['latitud'] as num?)?.toDouble(),
      longitud: (row['longitud'] as num?)?.toDouble(),
      radioCoberturaKm: row['radio_cobertura_km'] as int? ?? 20,
      tipoSuscripcion: row['tipo_suscripcion_actual'] as String? ?? 'basico',
      categoriaPrincipalId: row['categoria_principal_id'] as String?,
      estado: row['estado'] as String? ?? 'active',
      datosBancariosJson: row['datos_bancarios_json'] as Map<String, dynamic>?,
      creadoEn: DateTime.parse(row['creado_en'] as String).toUtc(),
      actualizadoEn: DateTime.parse(row['actualizado_en'] as String).toUtc(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nombre_negocio': nombreNegocio,
      'descripcion': descripcion,
      'telefono': telefono,
      'avatar_url': avatarUrl,
      'direccion_formato': direccionFormato,
      'latitud': latitud,
      'longitud': longitud,
      'radio_cobertura_km': radioCoberturaKm,
      'categoria_principal_id': categoriaPrincipalId,
    };
  }

  bool get isCompleteProfile =>
      nombreNegocio.isNotEmpty &&
      direccionFormato != null &&
      latitud != null &&
      longitud != null;
}

/// Servicio para gestionar el perfil del proveedor
class ProviderPerfilService {
  ProviderPerfilService._();
  static final ProviderPerfilService instance = ProviderPerfilService._();

  SupabaseClient get _client => Supabase.instance.client;

  /// Obtiene el perfil del proveedor actual por usuario_id
  Future<ProviderPerfilData?> getPerfilByUserId(String usuarioId) async {
    try {
      final response = await _client
          .from('perfil_proveedor')
          .select()
          .eq('usuario_id', usuarioId)
          .single();

      return ProviderPerfilData.fromMap(response);
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST116') {
        // No rows found
        return null;
      }
      rethrow;
    } catch (e) {
      return null;
    }
  }

  /// Crea un nuevo perfil de proveedor (después del registro)
  Future<ProviderPerfilData> createPerfil({
    required String usuarioId,
    required String nombreNegocio,
    String? descripcion,
    String? telefono,
    String? categoriaPrincipalId,
  }) async {
    try {
      final response = await _client.from('perfil_proveedor').insert({
        'usuario_id': usuarioId,
        'nombre_negocio': nombreNegocio,
        'descripcion': descripcion,
        'telefono': telefono,
        'categoria_principal_id': categoriaPrincipalId,
        'tipo_suscripcion_actual': 'basico',
        'estado': 'active',
      }).select().single();

      return ProviderPerfilData.fromMap(response);
    } catch (e) {
      throw Exception('Error creando perfil de proveedor: $e');
    }
  }

  /// Actualiza el perfil del proveedor
  Future<ProviderPerfilData> updatePerfil({
    required String perfilId,
    String? nombreNegocio,
    String? descripcion,
    String? telefono,
    String? avatarUrl,
    String? direccionFormato,
    double? latitud,
    double? longitud,
    int? radioCoberturaKm,
    String? categoriaPrincipalId,
  }) async {
    try {
      final updateData = <String, dynamic>{};
      if (nombreNegocio != null) updateData['nombre_negocio'] = nombreNegocio;
      if (descripcion != null) updateData['descripcion'] = descripcion;
      if (telefono != null) updateData['telefono'] = telefono;
      if (avatarUrl != null) updateData['avatar_url'] = avatarUrl;
      if (direccionFormato != null) updateData['direccion_formato'] = direccionFormato;
      if (latitud != null) updateData['latitud'] = latitud;
      if (longitud != null) updateData['longitud'] = longitud;
      if (radioCoberturaKm != null) updateData['radio_cobertura_km'] = radioCoberturaKm;
      if (categoriaPrincipalId != null) {
        updateData['categoria_principal_id'] = categoriaPrincipalId;
      }
      updateData['actualizado_en'] = DateTime.now().toUtc().toIso8601String();

      final response = await _client
          .from('perfil_proveedor')
          .update(updateData)
          .eq('id', perfilId)
          .select()
          .single();

      return ProviderPerfilData.fromMap(response);
    } catch (e) {
      throw Exception('Error actualizando perfil: $e');
    }
  }

  /// Actualiza la ubicación y cobertura del proveedor
  Future<ProviderPerfilData> updateUbicacion({
    required String perfilId,
    required String direccionFormato,
    required double latitud,
    required double longitud,
    int radioCoberturaKm = 20,
  }) async {
    return updatePerfil(
      perfilId: perfilId,
      direccionFormato: direccionFormato,
      latitud: latitud,
      longitud: longitud,
      radioCoberturaKm: radioCoberturaKm,
    );
  }

  /// Sube el avatar del proveedor a storage
  Future<String?> uploadAvatar({
    required String usuarioId,
    required List<int> fileBytes,
    required String fileName,
  }) async {
    try {
      final filePath = 'provider_avatars/$usuarioId/$fileName';
      
      await _client.storage.from('avatars').uploadBinary(
        filePath,
        Uint8List.fromList(fileBytes),
        fileOptions: const FileOptions(upsert: true),
      );

      final publicUrl =
          _client.storage.from('avatars').getPublicUrl(filePath);
      return publicUrl;
    } catch (e) {
      throw Exception('Error subiendo avatar: $e');
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
}
