import 'package:festeasy/app/view/client_home_page.dart';
import 'package:festeasy/app/view/provider_home_page.dart';
import 'package:festeasy/features/home/view/home_page.dart';
import 'package:festeasy/services/auth_service.dart';
import 'package:festeasy/services/notification_service.dart';
import 'package:flutter/material.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(_checkAuthAndNavigate);
  }

  Future<void> _checkAuthAndNavigate() async {
    if (!mounted) return;

    final session = AuthService.instance.currentUser;
    if (session != null) {
      try {
        final role = await AuthService.instance.getUserRole();
        if (!mounted) return;
        
        try {
          // Inicializar notificaciones para sesiones persistentes
          await NotificationService.instance.initialize();
        } catch (e) {
          debugPrint('Error inicializando notificaciones: $e');
        }

        if (role == 'provider') {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute<void>(
              builder: (context) => const ProviderHomePage(),
            ),
          );
          return;
        } else if (role == 'client') {
          final profile = await AuthService.instance.getClientProfile();
          final userName =
              (profile?['nombre_completo'] as String?) ??
              session.email?.split('@').first ??
              'Cliente';

          if (!mounted) return;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute<void>(
              builder: (context) => ClientHomePage(userName: userName),
            ),
          );
          return;
        }
      } catch (e) {
        debugPrint('Error recovering session: $e');
      }
    }

    // Si no hay sesión o si ocurre un fallo al recuperar el perfil, vamos a la pantalla principal (login/registro).
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (context) => const HomePage(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFF7FCFC),
      body: Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8D72C2)),
        ),
      ),
    );
  }
}
