import 'dart:developer';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Handler para mensajes en background (debe ser top-level function)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  log('📩 Notificación en background: ${message.notification?.title}');
}

class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final _messaging = FirebaseMessaging.instance;
  final _localNotifications = FlutterLocalNotificationsPlugin();
  final _supabase = Supabase.instance.client;

  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  /// Inicializar todo el sistema de notificaciones
  Future<void> initialize() async {
    try {
      // 1. Configurar handler de background
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // 2. Solicitar permisos
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      log('🔔 Permisos de notificación: ${settings.authorizationStatus}');

      // 3. Configurar notificaciones locales (para foreground)
      // Asegurarse de tener un icono @mipmap/ic_launcher en android
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      
      await _localNotifications.initialize(
        settings: const InitializationSettings(android: androidSettings, iOS: iosSettings),
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      // 4. Crear canal de Android (requerido para Android 8+)
      const androidChannel = AndroidNotificationChannel(
        'festeasy_notifications',
        'FestEasy Notificaciones',
        description: 'Notificaciones de solicitudes, pagos y recordatorios',
        importance: Importance.high,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(androidChannel);

      // 5. Obtener FCM Token y guardarlo en Supabase
      _fcmToken = await _messaging.getToken();
      log('🔑 FCM Token: $_fcmToken');
      await _saveTokenToSupabase(_fcmToken);

      // 6. Escuchar renovación de token
      _messaging.onTokenRefresh.listen(_saveTokenToSupabase);

      // 7. Escuchar mensajes en foreground
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // 8. Escuchar cuando el usuario toca una notificación (app en background)
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationOpen);

      // 9. Verificar si la app fue abierta desde una notificación
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationOpen(initialMessage);
      }
    } catch (e) {
      log('Error inicializando notificaciones (quizás falte google-services.json): $e');
    }
  }

  /// Guardar el FCM token en Supabase vinculado al usuario
  Future<void> _saveTokenToSupabase(String? token) async {
    if (token == null) return;
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
      // Tabla: fcm_tokens (debes crearla en Supabase)
      await _supabase.from('fcm_tokens').upsert({
        'usuario_id': userId,
        'token': token,
        'platform': 'android', // Asumiendo android para dev, se podría detectar
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'usuario_id');
      log('✅ FCM Token guardado en Supabase');
    } catch (e) {
      log('❌ Error guardando FCM token: $e');
    }
  }

  /// Mostrar notificación local cuando la app está en foreground
  void _handleForegroundMessage(RemoteMessage message) {
    log('📬 Mensaje en foreground: ${message.notification?.title}');
    final notification = message.notification;
    if (notification == null) return;
    
    _localNotifications.show(
      id: notification.hashCode,
      title: notification.title,
      body: notification.body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'festeasy_notifications',
          'FestEasy Notificaciones',
          icon: '@mipmap/ic_launcher',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: message.data['solicitud_id'],
    );
  }

  /// Cuando el usuario toca la notificación
  void _handleNotificationOpen(RemoteMessage message) {
    log('👆 Notificación abierta: ${message.data}');
    // TODO: Navegar a la pantalla correspondiente según message.data
  }

  void _onNotificationTapped(NotificationResponse response) {
    log('👆 Notificación local tocada: ${response.payload}');
    // TODO: Navegar a la pantalla correspondiente según el payload
  }

  /// Obtener notificaciones desde Supabase (para la bandeja in-app)
  Future<List<Map<String, dynamic>>> getNotifications() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];
    try {
      final response = await _supabase
          .from('notificaciones')
          .select()
          .eq('usuario_id', userId)
          .order('creado_en', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      log('Error getting notifications: $e');
      return [];
    }
  }

  /// Marcar notificación como leída
  Future<void> markAsRead(String notificationId) async {
    try {
      await _supabase
          .from('notificaciones')
          .update({'leida': true})
          .eq('id', notificationId);
    } catch (e) {
      log('Error markAsRead: $e');
    }
  }

  /// Marcar todas como leídas
  Future<void> markAllAsRead() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await _supabase
          .from('notificaciones')
          .update({'leida': true})
          .eq('usuario_id', userId)
          .eq('leida', false);
    } catch (e) {
      log('Error markAllAsRead: $e');
    }
  }

  /// Contar no leídas
  Future<int> getUnreadCount() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return 0;
    try {
      final response = await _supabase
          .from('notificaciones')
          .select()
          .eq('usuario_id', userId)
          .eq('leida', false);
      return (response as List).length;
    } catch (e) {
      return 0;
    }
  }

  /// Escuchar notificaciones en tiempo real (para la bandeja in-app)
  void listenRealtime(void Function(Map<String, dynamic>) onNew) {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    _supabase
        .channel('notificaciones-$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notificaciones',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'usuario_id',
            value: userId,
          ),
          callback: (payload) {
            onNew(payload.newRecord);
          },
        )
        .subscribe();
  }
}
