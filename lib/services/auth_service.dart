
import 'package:flutter/material.dart';
import 'package:sincra_app/screens/home_screen.dart';
import 'package:sincra_app/screens/login_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sincra_app/subscription/subscription_service.dart'; // ¡Importante!

class AuthService {
  static final _supabase = Supabase.instance.client;

  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  Future<void> signUp(BuildContext context, String email, String password) async {
    try {
      final AuthResponse res = await _supabase.auth.signUp(
        email: email,
        password: password,
      );
      if (res.user != null) {
        // Usuario nuevo, iniciar el período de prueba
        await SubscriptionService.startTrialIfNeeded();
        _navigateToHome(context);
      } else if (res.session == null) {
        // Podría necesitar confirmación por email, etc.
        _showSnackBar(context, 'Registro exitoso. Por favor, revisá tu email para confirmar tu cuenta.');
        Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const LoginScreen()));
      }
    } on AuthException catch (e) {
      _showSnackBar(context, e.message);
    } catch (e) {
      _showSnackBar(context, 'Ocurrió un error inesperado.');
    }
  }

  Future<void> signIn(BuildContext context, String email, String password) async {
    try {
      final AuthResponse res = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      if (res.user != null) {
        // Usuario existente, verificar/iniciar el período de prueba (no lo reiniciará si ya existe)
        await SubscriptionService.startTrialIfNeeded();
        _navigateToHome(context);
      } 
    } on AuthException catch (e) {
      _showSnackBar(context, e.message);
    } catch (e) {
      _showSnackBar(context, 'Ocurrió un error inesperado.');
    }
  }

  Future<void> signOut(BuildContext context) async {
    try {
      await _supabase.auth.signOut();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false, // Elimina todas las rutas anteriores
      );
    } on AuthException catch (e) {
      _showSnackBar(context, e.message);
    } catch (e) {
      _showSnackBar(context, 'Ocurrió un error inesperado.');
    }
  }

  void _navigateToHome(BuildContext context) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const HomeScreen()),
    );
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
      ),
    );
  }
}
