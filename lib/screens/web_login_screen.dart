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
      // 1. Authenticate with email and password first
      final AuthResponse res = await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final User? user = res.user;
      if (user == null) {
        throw const AuthException('Usuario o contraseña incorrectos.');
      }

      // 2. Verify the fixed verification code
      final expectedCode = user.id.split('-')[0].toUpperCase();
      final enteredCode = _verificationCodeController.text.trim().toUpperCase();

      if (enteredCode != expectedCode) {
        // Sign out if the code is wrong to prevent leaving a partial session
        await Supabase.instance.client.auth.signOut();
        throw const AuthException('El Código de Verificación no es correcto.');
      }

      // If both are correct, navigation will be handled by the auth listener
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/home');
      }

    } on AuthException catch (e) {
      _showErrorSnackBar(e.message);
    } catch (e) {
      _showErrorSnackBar('Ocurrió un error inesperado. Inténtelo de nuevo.');
    }

    if (mounted) {
      setState(() => _isLoading = false);
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
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Bienvenido a Syncra Web',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28, 
                      fontWeight: FontWeight.bold, 
                      color: AppColors.textPrimary
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Inicia sesión para continuar.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 40),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder(), prefixIcon: Icon(Icons.email)),
                    validator: (value) => (value == null || value.isEmpty) ? 'Ingresa tu email' : null,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _passwordController,
                    decoration: const InputDecoration(labelText: 'Contraseña', border: OutlineInputBorder(), prefixIcon: Icon(Icons.lock)),
                    obscureText: true,
                    validator: (value) => (value == null || value.isEmpty) ? 'Ingresa tu contraseña' : null,
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _verificationCodeController,
                    decoration: const InputDecoration(
                      labelText: 'Código de Verificación Web',
                      hintText: 'Encuéntralo en tu perfil de la app',
                      border: OutlineInputBorder(), 
                      prefixIcon: Icon(Icons.vpn_key)
                    ),
                    validator: (value) => (value == null || value.isEmpty) ? 'Ingresa tu código' : null,
                  ),
                  const SizedBox(height: 30),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _signIn,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: AppColors.primary, 
                      foregroundColor: Colors.white,
                    ),
                    child: _isLoading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Iniciar Sesión', style: TextStyle(fontSize: 16)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
