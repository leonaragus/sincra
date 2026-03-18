
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

  // --- Gestión de la Prueba Gratuita (Basada en Google Play) ---

  static Future<void> startTrialIfNeeded() async {
    if (kIsWeb) return; // No hay trial nativo en web
    
    // La prueba gratuita de 20 días se gestiona automáticamente a través de Google Play Billing
    // No necesitamos implementar lógica de tiempo manual aquí si se configura en la Play Console.
    await _billing.initialize();
  }

  static Future<bool> isTrialActive() async {
    final user = _supabase.auth.currentUser;
    if (user != null && ['admin@gmail.com', 'test@gmail.com'].contains(user.email)) {
      return true;
    }
    
    // PROMOCIÓN LANZAMIENTO: Primeros 30 usuarios / 45 días
    if (await _isPromoUser()) return true;

    // Si Google Play nos dice que hay una suscripción activa, se considera que está en período de prueba o pago.
    // Como Play Store maneja el trial de 20 días, solo necesitamos saber si el usuario tiene acceso.
    return await isSubscribed();
  }

  /// Verifica si el usuario actual califica para la promoción de lanzamiento:
  /// Los primeros 30 usuarios registrados tienen 45 días de acceso total gratuito.
  static Future<bool> _isPromoUser() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return false;

    // Bypass rápido para admins
    if (['admin@gmail.com', 'test@gmail.com'].contains(user.email)) return true;

    try {
      // 1. Obtener la fecha de creación del perfil actual
      final profileRes = await _supabase
          .from('profiles')
          .select('created_at')
          .eq('id', user.id)
          .maybeSingle();
      
      if (profileRes == null) return false;
      
      final createdAt = DateTime.parse(profileRes['created_at']);
      final now = DateTime.now();
      
      // 2. Validar límite de 45 días
      if (now.difference(createdAt).inDays > 45) return false;

      // 3. Validar si es uno de los primeros 30 (contando creados antes o igual)
      final countRes = await _supabase
          .from('profiles')
          .select('id')
          .lte('created_at', profileRes['created_at'])
          .count();
      
      final rank = countRes.count;
      return rank <= 30;
    } catch (e) {
      // Si hay error de red o de tabla, permitimos acceso temporal si la cuenta es nueva (< 45 días)
      // para asegurar que los testers de Play Store no se queden bloqueados.
      try {
        final authCreatedAt = DateTime.parse(user.createdAt);
        return DateTime.now().difference(authCreatedAt).inDays <= 45;
      } catch (_) {
        return false;
      }
    }
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

    // PROMOCIÓN LANZAMIENTO
    if (await _isPromoUser()) {
      try {
        final profileRes = await _supabase.from('profiles').select('created_at').eq('id', user!.id).maybeSingle();
        if (profileRes != null) {
          final createdAt = DateTime.parse(profileRes['created_at']);
          final daysPassed = DateTime.now().difference(createdAt).inDays;
          final remaining = 45 - daysPassed;
          return remaining > 0 ? remaining : 0;
        }
      } catch (_) {}
      return 45;
    }

    // Si queremos mostrar días restantes reales, deberíamos consultar el PurchaseDate de Google.
    // Por ahora, si está suscrito (o en trial), devolvemos un valor positivo para no bloquear.
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
