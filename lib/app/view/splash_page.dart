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

class _SplashPageState extends State<SplashPage> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0, 0.5)),
    );

    _controller.forward();
    Future.microtask(_checkAuthAndNavigate);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _checkAuthAndNavigate() async {
    // Breve pausa para que se alcance a ver el logo y termine la animación
    await Future.delayed(const Duration(milliseconds: 2500));

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
    return Scaffold(
      backgroundColor: const Color(0xFFF7FCFC),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Image.asset(
                  'assets/icons/logo.png',
                  width: 280,
                  height: 140,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(height: 32),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8D72C2)),
            ),
          ],
        ),
      ),
    );
  }
}
