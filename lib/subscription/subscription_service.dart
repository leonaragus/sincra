
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'user_roles.dart';
import 'subscription_plan.dart';
import '../services/play_billing_service.dart';


class ActiveSubscription {
  final String planId;
  final DateTime expiresAt;
  final UserRole userRole;
  ActiveSubscription({required this.planId, required this.expiresAt, required this.userRole});

  SubscriptionPlan get planDetail {
      final allPlans = [SubscriptionPlan.independent, SubscriptionPlan.accountingFirm, SubscriptionPlan.corporate];
      try {
        return allPlans.firstWhere(
          (p) => p.monthlyId == planId || p.annualId == planId
        );
      } catch (e) {
        // Fallback para planes no encontrados o por defecto
        return SubscriptionPlan.independent;
      }
  }
}


class SubscriptionService {
  static final _supabase = Supabase.instance.client;
  static final _billing = PlayBillingService();

  // --- Gestión de la Prueba Gratuita (Basada en Lanzamiento) ---

  static final DateTime _promoStartDate = DateTime(2026, 3, 25);
  static const int _promoDurationDays = 30;

  /// Verifica si el usuario actual califica para la promoción de lanzamiento:
  /// 30 días de acceso total gratuito desde el 25 de Marzo de 2026.
  static Future<bool> _isPromoUser() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return false;

    // Bypass rápido para admins
    if (['admin@gmail.com', 'test@gmail.com'].contains(user.email)) return true;

    final now = DateTime.now();
    final daysSinceStart = now.difference(_promoStartDate).inDays;
    
    // Si estamos dentro de los 30 días desde el 25 de Marzo, se considera promo activa
    return daysSinceStart >= 0 && daysSinceStart < _promoDurationDays;
  }

  static Future<void> startTrialIfNeeded() async {
    if (kIsWeb) return;
    await _billing.initialize();
  }

  static Future<bool> isTrialActive() async {
    final user = _supabase.auth.currentUser;
    if (user != null && ['admin@gmail.com', 'test@gmail.com'].contains(user.email)) {
      return true;
    }
    
    // PROMOCIÓN LANZAMIENTO (TEST CERRADO)
    if (await _isPromoUser()) return true;

    // Si Google Play nos dice que hay una suscripción activa
    return await isSubscribed();
  }

  // --- Gestión de Roles de Usuario (Blindado en el Servidor) ---

  /// Establece el rol de un usuario en la tabla 'profiles' de Supabase.
  static Future<void> setUserRole(UserRole role) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await _supabase.from('profiles').upsert({
        'id': userId,
        'user_role': role.name,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Error al establecer el rol del usuario: $e');
    }
  }

  /// Obtiene el rol de un usuario desde la tabla 'profiles' de Supabase.
  static Future<UserRole> getUserRole() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return UserRole.undecided;

    // MASTER BYPASS PARA PLAY STORE / ADMIN
    final List<String> testEmails = ['admin@gmail.com', 'test@gmail.com'];
    if (testEmails.contains(user.email)) {
      return UserRole.professional;
    }
    
    // PROMOCIÓN LANZAMIENTO: Primeros 30 usuarios / 45 días
    if (await _isPromoUser()) {
      return UserRole.professional;
    }

    try {
      final response = await _supabase
          .from('profiles')
          .select('user_role')
          .eq('id', user.id)
          .single();

      final roleStr = response['user_role'] as String?;
      if (roleStr == null) {
        return UserRole.undecided;
      }
      return UserRole.values.firstWhere(
        (e) => e.name == roleStr,
        orElse: () => UserRole.undecided,
      );
    } catch (e) {
      print('Error al obtener el rol del usuario: $e');
      return UserRole.undecided;
    }
  }


  // --- Gestión de Suscripciones ---

  static Future<bool> activateSubscription(PurchaseDetails purchaseDetails) async {
    try {
      final allPlans = [SubscriptionPlan.independent, SubscriptionPlan.accountingFirm, SubscriptionPlan.corporate];
      final plan = allPlans.firstWhere(
        (p) => p.monthlyId == purchaseDetails.productID || p.annualId == purchaseDetails.productID
      );

      final isAnnual = plan.annualId == purchaseDetails.productID;

      if (purchaseDetails.verificationData.serverVerificationData.isEmpty) {
          print("Error: La verificación del servidor está vacía. No se puede activar el plan.");
          return false;
      }

      final purchaseDate = DateTime.now();
      final expiresAt = isAnnual 
          ? DateTime(purchaseDate.year + 1, purchaseDate.month, purchaseDate.day)
          : DateTime(purchaseDate.year, purchaseDate.month + 1, purchaseDate.day);

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

  static Future<ActiveSubscription?> getActiveSubscription() async {
    if (kIsWeb) return null; // No hay suscripciones nativas en web
    
    await _billing.initialize();
    final ids = <String, SubscriptionPlan>{
      SubscriptionPlan.independent.monthlyId: SubscriptionPlan.independent,
      SubscriptionPlan.independent.annualId: SubscriptionPlan.independent,
      SubscriptionPlan.accountingFirm.monthlyId: SubscriptionPlan.accountingFirm,
      SubscriptionPlan.accountingFirm.annualId: SubscriptionPlan.accountingFirm,
      SubscriptionPlan.corporate.monthlyId: SubscriptionPlan.corporate,
      SubscriptionPlan.corporate.annualId: SubscriptionPlan.corporate,
    }..removeWhere((key, value) => key.isEmpty);
    for (final entry in ids.entries) {
      final has = await _billing.hasActiveSubscription(entry.key);
      if (has) {
        return ActiveSubscription(
          planId: entry.key,
          expiresAt: DateTime.now().add(const Duration(days: 30)),
          userRole: UserRole.professional,
        );
      }
    }
    return null;
  }

  static Future<bool> isSubscribed() async {
    final user = _supabase.auth.currentUser;
    if (user != null && ['admin@gmail.com', 'test@gmail.com'].contains(user.email)) {
      return true;
    }
    
    // PROMOCIÓN LANZAMIENTO: Primeros 30 usuarios / 45 días
    if (await _isPromoUser()) return true;

    if (kIsWeb) return true; // En la web no hay Google Play Billing, se asume acceso total si está logueado
    final subscription = await getActiveSubscription();
    return subscription != null;
  }

  static Future<int> getTrialDaysRemaining() async {
    final user = _supabase.auth.currentUser;
    if (user != null && ['admin@gmail.com', 'test@gmail.com'].contains(user.email)) {
      return 999;
    }

    // PROMOCIÓN LANZAMIENTO (TEST CERRADO)
    if (await _isPromoUser()) {
      final now = DateTime.now();
      final daysSinceStart = now.difference(_promoStartDate).inDays;
      final remaining = _promoDurationDays - daysSinceStart;
      return remaining > 0 ? remaining : 0;
    }

    final subscribed = await isSubscribed();
    return subscribed ? 20 : 0; 
  }

  static Future<int> _getMonthlyClaudeUsageCount() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return 0;
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1).toIso8601String();
    try {
      final response = await _supabase
          .from('ocr_usage_logs')
          .select('id')
          .eq('user_id', userId)
          .gte('created_at', startOfMonth)
          .count();
      return response.count;
    } catch (_) {
      return 0;
    }
  }

  static Future<bool> canUseClaude() async {
    final used = await _getMonthlyClaudeUsageCount();
    
    // PROMOCIÓN LANZAMIENTO: 50 llamadas mensuales para los primeros 30 usuarios
    if (await _isPromoUser()) {
      return used < 50;
    }

    final active = await getActiveSubscription();
    if (active != null) {
      final plan = active.planDetail;
      if (plan.unlimitedClaudeCalls) return true;
      return used < plan.claudeCallsPerMonth;
    }
    final trialActive = await isTrialActive();
    if (trialActive) {
      return used < SubscriptionPlan.freeTrial.trialClaudeCallsLimit;
    }
    return false;
  }

  static Future<void> recordClaudeCall() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await _supabase.from('ocr_usage_logs').insert({
        'user_id': userId,
        'created_at': DateTime.now().toIso8601String(),
        'scan_type': 'claude_vision',
      });
    } catch (_) {}
  }

  static Future<int> getClaudeCallsRemaining() async {
    final used = await _getMonthlyClaudeUsageCount();

    // PROMOCIÓN LANZAMIENTO: 50 llamadas mensuales para los primeros 30 usuarios
    if (await _isPromoUser()) {
      final remaining = 50 - used;
      return remaining > 0 ? remaining : 0;
    }

    final active = await getActiveSubscription();
    if (active != null) {
      final plan = active.planDetail;
      if (plan.unlimitedClaudeCalls) return -1;
      final limit = plan.claudeCallsPerMonth;
      final remaining = limit - used;
      return remaining > 0 ? remaining : 0;
    }
    final trialActive = await isTrialActive();
    if (!trialActive) return 0;
    final limit = SubscriptionPlan.freeTrial.trialClaudeCallsLimit;
    final remaining = limit - used;
    return remaining > 0 ? remaining : 0;
  }

  static Future<void> _saveSubscriptionStatus(String planId, DateTime expiresAt, UserRole role) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('Usuario no autenticado.');

    await _supabase.from('subscriptions').upsert({
      'user_id': userId,
      'plan_id': planId,
      'expires_at': expiresAt.toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    });

    await setUserRole(role);
  }

  static Future<void> initialize() async {
    await _billing.initialize();
    await _billing.restorePurchases();
  }

  static Future<void> restorePurchases() async {
    await _billing.restorePurchases();
  }
}
