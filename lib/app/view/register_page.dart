import 'package:flutter/material.dart';
import 'package:festeasy/app/view/client_home_page.dart';
import 'package:festeasy/services/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({Key? key}) : super(key: key);

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool showPassword = false;
  bool acceptedTerms = false;
  bool isLoading = false;

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (nameController.text.isEmpty ||
        emailController.text.isEmpty ||
        phoneController.text.isEmpty ||
        passwordController.text.isEmpty) {
      _showSnackBar('Por favor completa todos los campos', Colors.orange);
      return;
    }

    if (passwordController.text.length < 6) {
      _showSnackBar(
        'La contraseña debe tener al menos 6 caracteres',
        Colors.orange,
      );
      return;
    }

    // Validar formato de email
    if (!_isValidEmail(emailController.text.trim())) {
      _showSnackBar('Por favor ingresa un correo válido', Colors.orange);
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final response = await AuthService.instance.signUpWithEmail(
        email: emailController.text.trim(),
        password: passwordController.text,
        fullName: nameController.text.trim(),
        phone: phoneController.text.trim(),
      );

      if (!mounted) return;

      if (response.user != null) {
        _showSnackBar('¡Cuenta creada exitosamente!', Colors.green);
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (context) => ClientHomePage(
              userName: nameController.text.trim(),
            ),
          ),
        );
      } else if (response.user == null && response.session == null) {
        // Si no hay usuario ni sesión, mostrar el mensaje de error de Supabase
        _showSnackBar(
          'No se pudo crear la cuenta. Revisa tus datos.',
          Colors.red,
        );
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      _showSnackBar('AuthException: ${e.message}', Colors.red);
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Error: ${e.toString()}', Colors.red);
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  String _getErrorMessage(String error) {
    if (error.contains('User already registered')) {
      return 'Este correo ya está registrado';
    } else if (error.contains('Invalid email')) {
      return 'Correo electrónico inválido';
    } else if (error.contains('Password should be at least')) {
      return 'La contraseña es muy débil';
    }
    return 'Error: $error';
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FFFF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        centerTitle: true,
        title: const Text(
          'Regístrate',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 16),
              // Logo y título
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons
                        .emoji_emotions, // Cambia por un asset de globo si tienes uno
                    color: Colors.white,
                    size: 60,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'FestEasy',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Tu fiesta fácil y a un click de distancia',
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF7B7B7B),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              // Campo Nombre
              Align(
                alignment: Alignment.centerLeft,
                child: const Text(
                  'Nombre',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  hintText: 'Tu nombre completo',
                  prefixIcon: const Icon(
                    Icons.person_outline,
                    color: Colors.red,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Campo Correo
              Align(
                alignment: Alignment.centerLeft,
                child: const Text(
                  'Correo',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  hintText: 'ejemplo@correo.com',
                  prefixIcon: const Icon(Icons.mail_outline, color: Colors.red),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Campo Celular
              Align(
                alignment: Alignment.centerLeft,
                child: const Text(
                  'Celular',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  hintText: '300 000 0000',
                  prefixIcon: const Icon(
                    Icons.phone_android,
                    color: Colors.red,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Campo Contraseña
              Align(
                alignment: Alignment.centerLeft,
                child: const Text(
                  'Contraseña',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: passwordController,
                obscureText: !showPassword,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  hintText: '••••••••••',
                  prefixIcon: const Icon(Icons.lock_outline, color: Colors.red),
                  suffixIcon: IconButton(
                    icon: Icon(
                      showPassword ? Icons.visibility : Icons.visibility_off,
                      color: Colors.grey,
                    ),
                    onPressed: () {
                      setState(() {
                        showPassword = !showPassword;
                      });
                    },
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Checkbox Términos
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: acceptedTerms,
                    onChanged: (v) {
                      setState(() {
                        acceptedTerms = v ?? false;
                      });
                    },
                    activeColor: Colors.red,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 12.0),
                      child: RichText(
                        text: const TextSpan(
                          text: 'He leído y acepto los ',
                          style: TextStyle(color: Colors.black, fontSize: 13),
                          children: [
                            TextSpan(
                              text: 'términos y condiciones',
                              style: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            TextSpan(
                              text: ' y la política de privacidad de FestEasy.',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Botón Crear mi cuenta
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 4,
                  ),
                  onPressed: (acceptedTerms && !isLoading)
                      ? _handleRegister
                      : null,
                  child: isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Crear mi cuenta',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 20),
              // Ya tienes cuenta
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    '¿Ya tienes una cuenta? ',
                    style: TextStyle(color: Colors.grey),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).pop();
                    },
                    child: const Text(
                      'Inicia sesión',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
