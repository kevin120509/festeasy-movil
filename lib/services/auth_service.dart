import 'package:festeasy/services/notification_service.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart' as g_auth;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Servicio de autenticación para manejar login, registro y sesión de usuarios.
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();
  
  // Instancia fija del cliente de Google con parámetros explícitos
  final g_auth.GoogleSignIn _googleSignIn = g_auth.GoogleSignIn(
    // ID de cliente de aplicación web proporcionado por el usuario
    serverClientId: '454333124674-70liqm8i6mp9psstu3thvmbilt8phh6n.apps.googleusercontent.com', 
    scopes: <String>['email', 'profile', 'openid'],
  );

  SupabaseClient get _client => Supabase.instance.client;

  /// Obtiene el usuario actual autenticado
  User? get currentUser => _client.auth.currentUser;

  /// Verifica si hay un usuario autenticado
  bool get isAuthenticated => currentUser != null;

  /// Iniciar sesión con correo y contraseña
  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null) {
        try {
          await NotificationService.instance.initialize();
        } catch (e) {
          debugPrint('Error initializing notification service: $e');
        }
      }

      return response;
    } on AuthException catch (e) {
      throw AuthException(e.message);
    } catch (e) {
      throw Exception('Error al iniciar sesión: $e');
    }
  }

  /// ************************************************************
  /// * DEBUG: SI VES ESTO, EL ARCHIVO SE ACTUALIZO CORRECTAMENTE *
  /// ************************************************************  /// Iniciar sesión con Google
  Future<AuthResponse> signInWithGoogle() async {
    try {
      debugPrint('--- DEBUG: INICIANDO signInWithGoogle ---');
      
      // Forzamos cerrar sesión previa en el plugin de Google 
      // para que SIEMPRE nos pida elegir cuenta
      await _googleSignIn.signOut();
      
      final googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        debugPrint('--- DEBUG: El usuario canceló la selección de cuenta ---');
        throw 'Cancelado por el usuario';
      }

      debugPrint('--- DEBUG: Cuenta seleccionada: ${googleUser.email} ---');

      // 2. Obtener tokens
      final googleAuth = await googleUser.authentication;
      final accessToken = googleAuth.accessToken;
      final idToken = googleAuth.idToken;

      debugPrint('--- DEBUG: idToken obtenido: ${idToken != null ? "SI" : "NO"} ---');
      debugPrint('--- DEBUG: accessToken obtenido: ${accessToken != null ? "SI" : "NO"} ---');

      if (idToken == null) {
        throw 'No se pudo obtener el ID Token de Google. ¿Cuentas con el SHA-1 configurado en Google Cloud?';
      }

      // 3. Autenticar en Supabase con el IdToken
      debugPrint('--- DEBUG: Intentando autenticar en Supabase... ---');
      final response = await _client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      debugPrint('--- DEBUG: Supabase Auth exitoso para el usuario: ${response.user?.id} ---');

      if (response.user != null) {
        try {
          await NotificationService.instance.initialize();
        } catch (e) {
          debugPrint('Error initializing notification service: $e');
        }
      }

      return response;
    } on AuthException catch (e) {
      debugPrint('--- DEBUG ERROR AuthException: ${e.message} ---');
      throw AuthException(e.message);
    } catch (e) {
      debugPrint('--- DEBUG ERROR Exception: $e ---');
      if (e == 'Cancelado por el usuario') rethrow;
      throw Exception('Error al iniciar sesión con Google: $e');
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

  /// Crear perfil del cliente en la tabla perfil_cliente
  Future<void> _createClientProfile({
    required String userId,
    required String fullName,
    String? phone,
  }) async {
    try {
      final existing = await _client
          .from('perfil_cliente')
          .select('id')
          .eq('usuario_id', userId)
          .maybeSingle();

      if (existing != null) {
        return;
      }

      await _client.from('perfil_cliente').insert({
        'usuario_id': userId,
        'nombre_completo': fullName,
        'telefono': phone,
      });
    } catch (e) {
      debugPrint('Error creando perfil de cliente: $e');
    }
  }

  /// Crear perfil después de un inicio de sesión social
  Future<void> createProfileAfterSocialLogin({
    required String fullName,
    String? phone,
    bool isProvider = false,
    String? nombreNegocio,
  }) async {
    final user = currentUser;
    if (user == null) throw Exception('Usuario no autenticado');

    if (isProvider) {
      await _createProviderProfile(
        userId: user.id,
        nombreNegocio: nombreNegocio ?? fullName,
        telefono: phone,
      );
    } else {
      await _createClientProfile(
        userId: user.id,
        fullName: fullName,
        phone: phone,
      );
    }
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
      debugPrint('Error creando perfil de proveedor: $e');
    }
  }

  /// Obtener perfiles y roles
  Future<Map<String, dynamic>?> getClientProfile() async {
    if (currentUser == null) return null;
    try {
      return await _client
          .from('perfil_cliente')
          .select()
          .eq('usuario_id', currentUser!.id)
          .maybeSingle();
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> getProviderProfile() async {
    if (currentUser == null) return null;
    try {
      return await _client
          .from('perfil_proveedor')
          .select()
          .eq('usuario_id', currentUser!.id)
          .maybeSingle();
    } catch (e) {
      return null;
    }
  }

  Future<String?> getUserRole() async {
    if (currentUser == null) return null;
    try {
      final clientProfile = await getClientProfile();
      if (clientProfile != null) return 'client';

      final providerProfile = await getProviderProfile();
      if (providerProfile != null) return 'provider';

      return null;
    } catch (e) {
      return null;
    }
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  Future<void> resetPassword(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(email);
    } on AuthException catch (e) {
      throw AuthException(e.message);
    } catch (e) {
      throw Exception('Error al enviar correo de recuperación: $e');
    }
  }

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;
}
