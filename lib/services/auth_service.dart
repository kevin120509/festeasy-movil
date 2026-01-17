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

  /// Registrar un nuevo usuario con correo y contraseña
  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    required String fullName,
    String? phone,
  }) async {
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: {
          'full_name': fullName,
          'phone': phone,
        },
      );

      // Si el registro es exitoso, crear el usuario en la tabla users y el perfil del cliente
      if (response.user != null) {
        // Insertar en tabla users
        await _client.from('users').insert({
          'id': response.user!.id,
          'correo_electronico': email,
          'contrasena': password, // ¡No guardar en texto plano en producción!
          'rol': 'client',
          'estado': 'active',
        });

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
      throw Exception('Error al registrar usuario: $e');
    }
  }

  /// Crear perfil del cliente en la tabla perfil_cliente
  Future<void> _createClientProfile({
    required String userId,
    required String fullName,
    String? phone,
  }) async {
    try {
      await _client.from('perfil_cliente').insert({
        'usuario_id': userId,
        'nombre_completo': fullName,
        'telefono': phone,
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
