import 'dart:math';

/// Constantes para Storage de Supabase
///
/// IMPORTANTE: Esta estructura de rutas DEBE ser idéntica en web y móvil
/// para que las imágenes sean visibles en ambas plataformas.
///
/// Estructura de carpetas (sincronizada con web):
/// ```
/// festeasy/
/// ├── packages/{userId}-{timestamp}-{random}.{ext}  <- Fotos de paquetes
/// ├── avatars/{userId}-{timestamp}-{random}.{ext}   <- Avatares
/// └── comprobantes/{oderId}-{timestamp}.{ext}       <- Comprobantes
/// ```
///
/// Ver ESTRUCTURA_STORAGE.md para documentación completa.
class StorageConstants {
  StorageConstants._();

  /// Nombre del bucket principal en Supabase Storage
  static const String bucketName = 'festeasy';

  /// Carpeta para fotos de paquetes/servicios (sincronizado con web)
  static const String packagesFolder = 'packages';

  /// Carpeta para avatares de usuarios
  static const String avatarsFolder = 'avatars';

  /// Carpeta para comprobantes de pago
  static const String comprobantesFolder = 'comprobantes';

  /// Límite de tamaño de archivo en bytes (5MB)
  static const int maxFileSizeBytes = 5 * 1024 * 1024; // 5MB

  /// Tipos MIME permitidos para imágenes
  static const List<String> allowedMimeTypes = [
    'image/jpeg',
    'image/png',
    'image/gif',
    'image/webp',
  ];

  /// Extensiones de archivo permitidas
  static const List<String> allowedExtensions = [
    '.jpg',
    '.jpeg',
    '.png',
    '.gif',
    '.webp',
  ];

  /// Genera un string aleatorio de 7 caracteres (igual que web)
  static String _generateRandomString() {
    const chars = '0123456789abcdefghijklmnopqrstuvwxyz';
    final random = Random();
    return List.generate(7, (_) => chars[random.nextInt(chars.length)]).join();
  }

  /// Genera la ruta para una foto de paquete
  ///
  /// IMPORTANTE: Formato sincronizado con web:
  /// packages/{userId}-{timestamp}-{random}.{ext}
  ///
  /// Ejemplo de uso:
  /// ```dart
  /// final path = StorageConstants.getPaqueteFotoPath(
  ///   userId: 'a1b2c3d4-e5f6-7890-abcd-1234567890ab',
  ///   fileExtension: 'jpg',
  /// );
  /// // Resultado: packages/a1b2c3d4-e5f6-7890-abcd-1234567890ab-1737849600000-x7k2m9p.jpg
  /// ```
  static String getPaqueteFotoPath({
    required String userId,
    required String fileExtension,
  }) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomStr = _generateRandomString();
    final ext = fileExtension.startsWith('.') 
        ? fileExtension.substring(1) 
        : fileExtension;
    return '$packagesFolder/$userId-$timestamp-$randomStr.$ext';
  }

  /// Genera la ruta para un avatar de usuario
  ///
  /// Formato: avatars/{userId}-{timestamp}-{random}.{ext}
  static String getAvatarPath({
    required String userId,
    required String fileExtension,
  }) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomStr = _generateRandomString();
    final ext = fileExtension.startsWith('.') 
        ? fileExtension.substring(1) 
        : fileExtension;
    return '$avatarsFolder/$userId-$timestamp-$randomStr.$ext';
  }

  /// Genera la ruta para un comprobante de pago
  ///
  /// Formato: comprobantes/{oderId}-{timestamp}.{ext}
  static String getComprobantePath({
    required String oderId,
    required String fileExtension,
  }) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final ext = fileExtension.startsWith('.') 
        ? fileExtension.substring(1) 
        : fileExtension;
    return '$comprobantesFolder/$oderId-$timestamp.$ext';
  }

  /// Genera un nombre de archivo único usando timestamp y random
  /// Formato: {userId}-{timestamp}-{random}.{ext}
  static String generateFileName({
    required String userId,
    String extension = 'jpg',
  }) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomStr = _generateRandomString();
    final ext = extension.startsWith('.') ? extension.substring(1) : extension;
    return '$userId-$timestamp-$randomStr.$ext';
  }

  /// Extrae el path del storage desde una URL pública de Supabase
  ///
  /// Ejemplo:
  /// URL: https://xxx.supabase.co/storage/v1/object/public/festeasy/a1b2c3/paquete_fotos/paq-001/foto.jpg
  /// Resultado: a1b2c3/paquete_fotos/paq-001/foto.jpg
  static String? extractPathFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final pathSegments = uri.pathSegments;

      // Buscar el índice del bucket name
      final bucketIndex = pathSegments.indexOf(bucketName);
      if (bucketIndex == -1) return null;

      // Retornar todo después del bucket name
      return pathSegments.sublist(bucketIndex + 1).join('/');
    } catch (e) {
      return null;
    }
  }

  /// Valida si una extensión de archivo es permitida
  static bool isValidExtension(String fileName) {
    final lowerName = fileName.toLowerCase();
    return allowedExtensions.any(lowerName.endsWith);
  }

  /// Valida si un tipo MIME es permitido
  static bool isValidMimeType(String mimeType) {
    return allowedMimeTypes.contains(mimeType.toLowerCase());
  }
}