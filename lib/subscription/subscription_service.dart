
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'user_roles.dart';
import 'subscription_plan.dart';


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

  // --- Gestión de la Prueba Gratuita (Blindado en el Servidor) ---

  /// Inicia el período de prueba para un usuario la primera vez que se registra.
  /// Escribe la fecha de finalización en la tabla 'profiles' de Supabase.
  /// Si el campo ya existe, no hace nada. Es a prueba de reinstalaciones.
  static Future<void> startTrialIfNeeded() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final response = await _supabase
          .from('profiles')
          .select('trial_ends_at')
          .eq('id', userId)
          .single();

      if (response['trial_ends_at'] == null) {
        final trialEndDate = DateTime.now().add(const Duration(days: 20));
        await _supabase.from('profiles').update({
          'trial_ends_at': trialEndDate.toIso8601String()
        }).eq('id', userId);
        print('Período de prueba iniciado para el usuario $userId. Finaliza el $trialEndDate.');
      } else {
        print('El usuario $userId ya tiene un período de prueba registrado.');
      }
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST116') { // "Not a single row was found"
         final trialEndDate = DateTime.now().add(const Duration(days: 20));
         await _supabase.from('profiles').upsert({
            'id': userId,
            'trial_ends_at': trialEndDate.toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
         });
         print('Perfil no encontrado, se creó y se inició el período de prueba para el usuario $userId. Finaliza el $trialEndDate.');
      } else {
        print('Error de Supabase al iniciar la prueba: ${e.message}');
      }
    }
    catch (e) {
      print('Error inesperado al iniciar la prueba: $e');
    }
  }

  /// Verifica si el período de prueba del usuario está activo.
  /// Lee la fecha de finalización desde Supabase, no del dispositivo.
  static Future<bool> isTrialActive() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return false;

    try {
      final response = await _supabase
          .from('profiles')
          .select('trial_ends_at')
          .eq('id', userId)
          .single();

      final trialEndDateStr = response['trial_ends_at'];
      if (trialEndDateStr == null) {
        // Si nunca se inició, se inicia ahora.
        await startTrialIfNeeded();
        return true;
      }

      final trialEndDate = DateTime.parse(trialEndDateStr);
      return DateTime.now().isBefore(trialEndDate);
    } catch (e) {
      print('Error al verificar el estado de la prueba: $e');
      return false;
    }
  }

  // --- Gestión de Roles de Usuario (Blindado en el Servidor) ---

  /// Establece el rol de un usuario en la tabla 'profiles' de Supabase.
  static Future<void> setUserRole(UserRole role) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await _supabase.from('profiles').update({
        'user_role': role.name,
      }).eq('id', userId);
    } catch (e) {
      print('Error al establecer el rol del usuario: $e');
    }
  }

  /// Obtiene el rol de un usuario desde la tabla 'profiles' de Supabase.
  static Future<UserRole> getUserRole() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return UserRole.undecided;

    try {
      final response = await _supabase
          .from('profiles')
          .select('user_role')
          .eq('id', userId)
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
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return null;

    try {
      final response = await _supabase
          .from('subscriptions')
          .select()
          .eq('user_id', userId)
          .order('expires_at', ascending: false)
          .limit(1)
          .single();

      final expiresAt = DateTime.parse(response['expires_at']);
      if (expiresAt.isBefore(DateTime.now())) {
        return null; // La suscripción expiró
      }

      return ActiveSubscription(
        planId: response['plan_id'],
        expiresAt: expiresAt,
        userRole: UserRole.values.firstWhere((e) => e.toString() == response['user_role'], orElse: () => UserRole.professional),
      );
    } catch (e) {
      print('Error al obtener la suscripción activa: $e');
      return null;
    }
  }

  static Future<bool> isSubscribed() async {
    final subscription = await getActiveSubscription();
    return subscription != null;
  }

  static Future<int> getTrialDaysRemaining() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return 0;
    try {
      final response = await _supabase
          .from('profiles')
          .select('trial_ends_at')
          .eq('id', userId)
          .single();
      final endStr = response['trial_ends_at'];
      if (endStr == null) return 0;
      final end = DateTime.parse(endStr);
      final now = DateTime.now();
      if (now.isAfter(end)) return 0;
      return end.difference(now).inDays;
    } catch (_) {
      return 0;
    }
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
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    await startTrialIfNeeded();
  }
}
