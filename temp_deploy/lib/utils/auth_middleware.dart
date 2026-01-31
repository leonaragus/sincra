import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/subscription_service.dart';

/// Middleware para proteger rutas basado en suscripción
class AuthMiddleware {
  /// Verificar acceso a una pantalla específica
  static Future<bool> canAccessScreen(String screenName) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return false;
    
    switch (screenName) {
      case 'verificador_recibo':
        // Todos los usuarios tienen acceso al verificador
        return true;
        
      case 'liquidacion':
      case 'empresas':
      case 'empleados':
        // Solo usuarios con planes pagos
        final plan = await SubscriptionService.getCurrentUserPlan();
        return plan != null && plan['plan_type'] != 'free';
        
      default:
        return true;
    }
  }

  /// Navegar con verificación de suscripción
  static Future<void> navigateWithSubscriptionCheck(
    BuildContext context,
    String routeName, {
    Object? arguments,
  }) async {
    final hasAccess = await canAccessScreen(routeName);
    
    if (!hasAccess) {
      // Mostrar diálogo de upgrade
      _showUpgradeDialog(context);
      return;
    }
    
    Navigator.pushNamed(context, routeName, arguments: arguments);
  }

  /// Mostrar diálogo de upgrade de suscripción
  static void _showUpgradeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Upgrade Requerido'),
        content: const Text(
          'Esta función requiere una suscripción premium. '
          '¿Te gustaría ver nuestros planes?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Navegar a pantalla de planes
            },
            child: const Text('Ver Planes'),
          ),
        ],
      ),
    );
  }

  /// Obtener información del usuario actual
  static Future<Map<String, dynamic>?> getCurrentUserInfo() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return null;
    
    final plan = await SubscriptionService.getCurrentUserPlan();
    final isTrial = await SubscriptionService.isInTrialPeriod();
    final trialDaysRemaining = await SubscriptionService.getTrialDaysRemaining();
    
    return {
      'user': user,
      'plan': plan,
      'is_trial': isTrial,
      'trial_days_remaining': trialDaysRemaining,
      'plan_name': plan != null
          ? (plan['plan_type'] is String
              ? (SubscriptionService.subscriptionPlans[plan['plan_type'] as String]?['name'] ?? 'Free')
              : 'Free')
          : 'Free',
    };
  }
}