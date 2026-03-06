
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'user_roles.dart';
import 'subscription_plan.dart';

class ActiveSubscription {
  // ... (código existente sin cambios)
  final String planId;
  final DateTime expiresAt;
  final UserRole userRole;
  ActiveSubscription({required this.planId, required this.expiresAt, required this.userRole});
  SubscriptionPlan get planDetail { return SubscriptionPlan.corporate; }
}

class SubscriptionService {
  static final _supabase = Supabase.instance.client;
  static const String _trialEndDateKey = 'trial_end_date';
  static const String _userRoleKey = 'user_role';

  // --- Gestión de la Prueba Gratuita ---
  static Future<void> startTrial() async { /* ... */ }
  static Future<bool> isTrialActive() async { /* ... */ return false; }

  // --- Gestión de Roles de Usuario ---
  static Future<void> setUserRole(UserRole role) async { /* ... */ }
  static Future<UserRole> getUserRole() async { /* ... */ return UserRole.undecided; }


  // --- FUNCIÓN NUEVA: Activa la suscripción después de una compra exitosa ---
  static Future<bool> activateSubscription(PurchaseDetails purchaseDetails) async {
    try {
      final allPlans = [SubscriptionPlan.independent, SubscriptionPlan.accountingFirm, SubscriptionPlan.corporate];
      final plan = allPlans.firstWhere(
        (p) => p.monthlyId == purchaseDetails.productID || p.annualId == purchaseDetails.productID
      );

      final isAnnual = plan.annualId == purchaseDetails.productID;

      // --- Validación de Compra (Importante para seguridad) ---
      // En una app en producción, deberías enviar purchaseDetails.verificationData a tu propio servidor
      // para validarlo con la API de Google Play. Esto previene fraudes.
      // Por ahora, confiamos en la respuesta del cliente, lo cual es suficiente para empezar.
      if (purchaseDetails.verificationData.serverVerificationData.isEmpty) {
          print("Error: La verificación del servidor está vacía. No se puede activar el plan.");
          return false;
      }

      // Calculamos la fecha de expiración
      final purchaseDate = DateTime.now();
      final expiresAt = isAnnual 
          ? DateTime(purchaseDate.year + 1, purchaseDate.month, purchaseDate.day)
          : DateTime(purchaseDate.year, purchaseDate.month + 1, purchaseDate.day);

      // Guardamos en Supabase
      await _saveSubscriptionStatus(
        purchaseDetails.productID,
        expiresAt,
        UserRole.professional
      );
      
      print('¡Suscripción activada con éxito! Plan: ${plan.name}, Expira: $expiresAt');
      return true;
    } catch (e) {
      print("Error al activar la suscripción: $e");
      return false;
    }
  }

  static Future<ActiveSubscription?> getActiveSubscription() async { /* ... (código existente sin cambios) ... */ return null; }
  static Future<bool> isSubscribed() async { /* ... (código existente sin cambios) ... */ return false; }

  static Future<void> _saveSubscriptionStatus(String planId, DateTime expiresAt, UserRole role) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('Usuario no autenticado.');

    await _supabase.from('subscriptions').upsert({
      'user_id': userId,
      'plan_id': planId,
      'expires_at': expiresAt.toIso8601String(),
      'user_role': role.toString(),
      'updated_at': DateTime.now().toIso8601String(),
    });
    await setUserRole(role);
  }
}
