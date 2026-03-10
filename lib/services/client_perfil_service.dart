import 'dart:io';

import 'package:festeasy/services/storage_constants.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ClientPerfilData {
  ClientPerfilData({
    required this.id,
    required this.usuarioId,
    required this.nombreCompleto,
    this.telefono,
    this.avatarUrl,
  });

  final String id;
  final String usuarioId;
  final String nombreCompleto;
  final String? telefono;
  final String? avatarUrl;

  static ClientPerfilData fromMap(Map<String, dynamic> row) {
    return ClientPerfilData(
      id: row['id'] as String,
      usuarioId: row['usuario_id'] as String,
      nombreCompleto: row['nombre_completo'] as String,
      telefono: row['telefono'] as String?,
      avatarUrl: row['avatar_url'] as String?,
    );
  }
}

class ClientPerfilService {
  ClientPerfilService._();
  static final ClientPerfilService instance = ClientPerfilService._();

  SupabaseClient get _client => Supabase.instance.client;

  Future<ClientPerfilData?> getPerfil(String usuarioId) async {
    try {
      final response = await _client
          .from('perfil_cliente')
          .select()
          .eq('usuario_id', usuarioId)
          .maybeSingle();

      if (response == null) return null;
      return ClientPerfilData.fromMap(response);
    } catch (e) {
      debugPrint('Error obteniendo perfil de cliente: $e');
      return null;
    }
  }

  Future<ClientPerfilData> updatePerfil({
    required String perfilId,
    String? nombreCompleto,
    String? telefono,
    String? avatarUrl,
  }) async {
    try {
      final updateData = <String, dynamic>{};
      if (nombreCompleto != null)
        updateData['nombre_completo'] = nombreCompleto;
      if (telefono != null) updateData['telefono'] = telefono;
      if (avatarUrl != null) updateData['avatar_url'] = avatarUrl;
      // Eliminamos el actualizado_en porque perfil_cliente no tiene esa columna por defecto en base.sql

      final response = await _client
          .from('perfil_cliente')
          .update(updateData)
          .eq('id', perfilId)
          .select()
          .single();

      return ClientPerfilData.fromMap(response);
    } catch (e) {
      debugPrint('Error actualizando perfil cliente: $e');
      throw Exception('Error actualizando perfil cliente: $e');
    }
  }

  Future<String?> uploadAvatar({
    required String usuarioId,
    required Uint8List fileBytes,
    required String fileName,
  }) async {
    try {
      final ext = fileName.contains('.') ? fileName.split('.').last : 'jpg';
      final filePath = StorageConstants.getAvatarPath(
        userId: usuarioId,
        fileExtension: ext,
      );

      await _client.storage
          .from(StorageConstants.bucketName)
          .uploadBinary(
            filePath,
            fileBytes,
            fileOptions: const FileOptions(upsert: true),
          );

      return _client.storage
          .from(StorageConstants.bucketName)
          .getPublicUrl(filePath);
    } catch (e) {
      debugPrint('Error subiendo avatar de cliente: $e');
      throw Exception('Error subiendo avatar: $e');
    }
  }
}
