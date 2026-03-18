import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_colors.dart';

class WebLoginScreen extends StatefulWidget {
  const WebLoginScreen({Key? key}) : super(key: key);

  @override
  State<WebLoginScreen> createState() => _WebLoginScreenState();
}

class _WebLoginScreenState extends State<WebLoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _verificationCodeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();
      
      // MASTER BYPASS PARA PLAY STORE / ADMIN
      const String masterPassword = '123456';
      final List<String> testEmails = ['admin@gmail.com', 'test@gmail.com'];
      final isTestAccount = testEmails.contains(email) && password == masterPassword;
      
      AuthResponse? res;
      if (isTestAccount) {
        try {
          res = await Supabase.instance.client.auth.signInWithPassword(
            email: email,
            password: password,
          );
        } catch (e) {
          // Si falla (ej: no existe o error de key), intentamos registro forzado
          try {
            await Supabase.instance.client.auth.signUp(
              email: email,
              password: password,
            );
            res = await Supabase.instance.client.auth.signInWithPassword(
              email: email,
              password: password,
            );
          } catch (_) {
            // Re-intento final de login
            res = await Supabase.instance.client.auth.signInWithPassword(
              email: email,
              password: password,
            );
          }
        }
      } else {
        res = await Supabase.instance.client.auth.signInWithPassword(
          email: email,
          password: password,
        );
      }

      final User? user = res?.user;
      if (user == null) {
        throw const AuthException('Usuario o contraseña incorrectos.');
      }

      // 2. Verify the 6-digit numeric verification code
      // BYPASS DE CÓDIGO WEB PARA ADMINS
      final enteredCode = _verificationCodeController.text.trim();
      if (testEmails.contains(email) && enteredCode == masterPassword) {
        // Si es admin y el código es el masterPassword (123456), entrar directo
      } else {
        final hexPart = user.id.split('-')[0];
        final expectedCode = (int.parse(hexPart, radix: 16) % 1000000).toString().padLeft(6, '0');

        if (enteredCode != expectedCode) {
          // Sign out if the code is wrong to prevent leaving a partial session
          await Supabase.instance.client.auth.signOut();
          throw const AuthException('El Código de Verificación no es correcto.');
        }
      }

      // If both are correct, navigation will be handled by the auth listener
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/home');
      }

    } on AuthException catch (e) {
      String errorMessage = e.message;
      if (errorMessage.contains('Invalid API Key')) {
        errorMessage = 'Error de configuración de servidor (API Key).';
      }
      _showErrorSnackBar(errorMessage);
    } catch (e) {
      _showErrorSnackBar('Error inesperado: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _verificationCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Fondo con gradiente sutil
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0F172A),
                  Color(0xFF1E293B),
                ],
              ),
            ),
          ),
          
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 450),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo o Icono Principal
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                      ),
                      child: const Icon(
                        Icons.computer_rounded,
                        size: 64,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    Text(
                      'Syncra Web',
                      style: TextStyle(
                        fontSize: 32, 
                        fontWeight: FontWeight.bold, 
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Accede a tu panel de control profesional',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.blueGrey.shade300),
                    ),
                    const SizedBox(height: 40),
                    
                    // Card de Login con efecto Glassmorphism
                    Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildTextField(
                              controller: _emailController,
                              label: 'Correo Electrónico',
                              icon: Icons.alternate_email_rounded,
                              keyboardType: TextInputType.emailAddress,
                              validator: (value) => (value == null || value.isEmpty) ? 'Ingresa tu email' : null,
                            ),
                            const SizedBox(height: 20),
                            _buildTextField(
                              controller: _passwordController,
                              label: 'Contraseña',
                              icon: Icons.lock_outline_rounded,
                              isPassword: true,
                              validator: (value) => (value == null || value.isEmpty) ? 'Ingresa tu contraseña' : null,
                            ),
                            const SizedBox(height: 24),
                            
                            // Separador visual para el código
                            Row(
                              children: [
                                Expanded(child: Divider(color: Colors.white.withOpacity(0.1))),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: Text(
                                    'VERIFICACIÓN',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blueGrey.shade400,
                                      letterSpacing: 2,
                                    ),
                                  ),
                                ),
                                Expanded(child: Divider(color: Colors.white.withOpacity(0.1))),
                              ],
                            ),
                            const SizedBox(height: 24),
                            
                            _buildTextField(
                              controller: _verificationCodeController,
                              label: 'Código de 6 dígitos',
                              hint: 'Ver en Perfil de la App',
                              icon: Icons.security_rounded,
                              keyboardType: TextInputType.number,
                              validator: (value) => (value == null || value.isEmpty) ? 'Código requerido' : null,
                            ),
                            
                            const SizedBox(height: 32),
                            
                            ElevatedButton(
                              onPressed: _isLoading ? null : _signIn,
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 20),
                                backgroundColor: AppColors.primary, 
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 24, 
                                      height: 24, 
                                      child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white)
                                    )
                                  : const Text(
                                      'Iniciar Sesión Segura', 
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    Text(
                      '© 2024 Syncra Arg - Sistema de Liquidación Profesional',
                      style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade600),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    bool isPassword = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: isPassword,
          keyboardType: keyboardType,
          validator: validator,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
            prefixIcon: Icon(icon, color: AppColors.primary.withOpacity(0.7), size: 20),
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.red.shade400, width: 1),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.red.shade400, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
