
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_colors.dart';
import 'home_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/animated_logo.dart';
import '../subscription/subscription_service.dart';
import '../subscription/user_roles.dart';


class MobileAuthScreen extends StatefulWidget {
  const MobileAuthScreen({super.key});

  @override
  State<MobileAuthScreen> createState() => _MobileAuthScreenState();
}

class _MobileAuthScreenState extends State<MobileAuthScreen> {
  bool _isLogin = true;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _signIn() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    setState(() {
      _isLoading = true;
    });
    try {
      // MASTER BYPASS PARA PLAY STORE / ADMIN
      const String masterPassword = '123456';
      final List<String> testEmails = ['admin@gmail.com', 'test@gmail.com'];
      final isTestAccount = testEmails.contains(email) && password == masterPassword;
      
      if (isTestAccount) {
        try {
          // Intentar login normal
          await Supabase.instance.client.auth.signInWithPassword(
            email: email,
            password: password,
          );
        } catch (e) {
          // Si falla, intentamos registrarlo (bypass de "usuario no encontrado")
          try {
            await Supabase.instance.client.auth.signUp(
              email: email,
              password: password,
            );
          } catch (_) {
            // Re-intento final de login por si el registro falló porque ya existía
            await Supabase.instance.client.auth.signInWithPassword(
              email: email,
              password: password,
            );
          }
        }
      } else {
        // Flujo normal para otros usuarios
        await Supabase.instance.client.auth.signInWithPassword(
          email: email,
          password: password,
        );
      }
      
      if (mounted) {
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
      }
    } on AuthException catch (e) {
      if (mounted) {
        String errorMessage = e.message;
        if (errorMessage.contains('Invalid API Key')) {
          errorMessage = 'Error de conexión con el servidor (API Key). Por favor, contacte a soporte.';
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.redAccent,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error inesperado: $e'),
          backgroundColor: Colors.redAccent,
        ));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _signUp() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, completa todos los campos.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });
    try {
      final response = await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
      );
      
      // Si el registro es exitoso, Supabase suele iniciar sesión automáticamente
      // o requiere confirmación de email dependiendo de la configuración del proyecto.
      if (response.user != null) {
        // Inicializar el perfil del usuario para la promoción de lanzamiento
        try {
          await SubscriptionService.setUserRole(UserRole.professional);
        } catch (_) {
          // Ignorar errores de creación de perfil, el bypass de SubscriptionService
          // usará la fecha de auth como fallback si no encuentra el perfil.
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('¡Cuenta creada con éxito!')),
          );
          // Redirigir al Home
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        }
      }
    } on AuthException catch (e) {
      if (mounted) {
        String errorMessage = e.message;
        if (errorMessage.contains('Invalid API Key')) {
          errorMessage = 'Error de conexión con el servidor (API Key). Por favor, contacte a soporte.';
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.redAccent,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error inesperado: $e'),
          backgroundColor: Colors.redAccent,
        ));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const AnimatedLogo(),
                const SizedBox(height: 32),
                Text(
                  'SYncra ARG',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.orbitron(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _isLogin ? 'Inicia sesión para continuar' : 'Crea una cuenta para empezar',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.roboto(
                    fontSize: 16,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 40),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(labelText: 'Contraseña'),
                  obscureText: true,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isLoading ? null : (_isLogin ? _signIn : _signUp),
                  child: _isLoading
                      ? const CircularProgressIndicator()
                      : Text(_isLogin ? 'Iniciar Sesión' : 'Registrarse'),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _isLogin = !_isLogin;
                    });
                  },
                  child: Text(_isLogin
                      ? '¿No tienes una cuenta? Regístrate'
                      : '¿Ya tienes una cuenta? Inicia sesión'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
