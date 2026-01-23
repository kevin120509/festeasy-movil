import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Servicio de autenticación para manejar login, registro y sesión de usuarios.
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  SupabaseClient get _client => Supabase.instance.client;

  /// Obtiene el usuario actual autenticado
  User? get currentUser => _client.auth.currentUser;

  /// Verifica si hay un usuario autenticado
  bool get isAuthenticated => currentUser != null;

  /// Iniciar sesión con correo y contraseña
  /// Retorna el usuario si el login es exitoso, o lanza una excepción si falla.
  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      return response;
    } on AuthException catch (e) {
      throw AuthException(e.message);
    } catch (e) {
      throw Exception('Error al iniciar sesión: $e');
    }
  }

  /// Registrar un nuevo usuario como cliente
  Future<AuthResponse> signUpClientWithEmail({
    required String email,
    required String password,
    required String fullName,
    String? phone,
  }) async {
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': fullName, 'phone': phone},
      );

      // Si el registro es exitoso, crear el perfil del cliente
      // Nota: Supabase Auth ya crea automáticamente el usuario en auth.users
      if (response.user != null) {
        await _createClientProfile(
          userId: response.user!.id,
          fullName: fullName,
          phone: phone,
        );
      }

      return response;
    } on AuthException catch (e) {
      throw AuthException(e.message);
    } catch (e) {
      throw Exception('Error al registrar cliente: $e');
    }
  }

  /// Registrar un nuevo usuario como proveedor
  Future<AuthResponse> signUpProviderWithEmail({
    required String email,
    required String password,
    required String nombreNegocio,
    String? telefono,
  }) async {
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': nombreNegocio, 'phone': telefono},
      );

      // Si el registro es exitoso, crear el perfil del proveedor
      if (response.user != null) {
        await _createProviderProfile(
          userId: response.user!.id,
          nombreNegocio: nombreNegocio,
          telefono: telefono,
        );
      }

      return response;
    } on AuthException catch (e) {
      throw AuthException(e.message);
    } catch (e) {
      throw Exception('Error al registrar proveedor: $e');
    }
  }

  /// Registrar un nuevo usuario con correo y contraseña (DEPRECATED - usar signUpClientWithEmail)
  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    required String fullName,
    String? phone,
  }) async {
    return signUpClientWithEmail(
      email: email,
      password: password,
      fullName: fullName,
      phone: phone,
    );
  }

  /// Crear perfil del cliente en la tabla perfil_cliente
  Future<void> _createClientProfile({
    required String userId,
    required String fullName,
    String? phone,
  }) async {
    try {
      // Verificar si ya existe el perfil
      final existing = await _client
          .from('perfil_cliente')
          .select('id')
          .eq('usuario_id', userId)
          .maybeSingle();

      if (existing != null) {
        debugPrint('✅ Perfil de cliente ya existe para usuario: $userId');
        return;
      }

      await _client.from('perfil_cliente').insert({
        'usuario_id': userId,
        'nombre_completo': fullName,
        'telefono': phone,
      });
      debugPrint('✅ Perfil de cliente creado para usuario: $userId');
    } catch (e) {
      debugPrint('❌ Error creando perfil de cliente: $e');
      // Reintentar una vez más
      try {
        await _client.from('perfil_cliente').upsert({
          'usuario_id': userId,
          'nombre_completo': fullName,
          'telefono': phone,
        }, onConflict: 'usuario_id');
        debugPrint('✅ Perfil de cliente creado (upsert) para usuario: $userId');
      } catch (e2) {
        debugPrint('❌ Error en reintento de crear perfil: $e2');
      }
    }
  }

  /// Asegurar que existe el perfil del cliente actual
  /// Útil para crear el perfil si no existe (usuarios antiguos)
  Future<void> ensureClientProfileExists() async {
    // Deshabilitado - no crear perfiles automáticamente
    return;
  }

  /// Crear perfil del proveedor en la tabla perfil_proveedor
  Future<void> _createProviderProfile({
    required String userId,
    required String nombreNegocio,
    String? telefono,
  }) async {
    try {
      await _client.from('perfil_proveedor').insert({
        'usuario_id': userId,
        'nombre_negocio': nombreNegocio,
        'telefono': telefono,
        'tipo_suscripcion_actual': 'basico',
        'estado': 'active',
      });
    } catch (e) {
      // Si falla la creación del perfil, lo ignoramos por ahora
      // El perfil se puede crear después
    }
  }

  /// Obtener el perfil del cliente actual
  Future<Map<String, dynamic>?> getClientProfile() async {
    if (currentUser == null) return null;

    try {
      final response = await _client
          .from('perfil_cliente')
          .select()
          .eq('usuario_id', currentUser!.id)
          .maybeSingle();
      return response;
    } catch (e) {
      return null;
    }
  }

  /// Obtener el perfil del proveedor actual
  Future<Map<String, dynamic>?> getProviderProfile() async {
    if (currentUser == null) return null;

    try {
      final response = await _client
          .from('perfil_proveedor')
          .select()
          .eq('usuario_id', currentUser!.id)
          .maybeSingle();
      return response;
    } catch (e) {
      return null;
    }
  }

  /// Detectar el rol del usuario actual (client, provider, o null)
  Future<String?> getUserRole() async {
    if (currentUser == null) return null;

    try {
      // Primero intenta obtener cliente
      final clientProfile = await getClientProfile();
      if (clientProfile != null) {
        return 'client';
      }

      // Luego intenta obtener proveedor
      final providerProfile = await getProviderProfile();
      if (providerProfile != null) {
        return 'provider';
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// Cerrar sesión
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  /// Recuperar contraseña
  Future<void> resetPassword(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(email);
    } on AuthException catch (e) {
      throw AuthException(e.message);
    } catch (e) {
      throw Exception('Error al enviar correo de recuperación: $e');
    }
  }

  /// Stream de cambios en el estado de autenticación
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;
}
