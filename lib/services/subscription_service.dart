import 'package:supabase_flutter/supabase_flutter.dart';

import 'play_billing_service.dart';

/// Servicio para gestionar suscripciones y niveles de acceso
class SubscriptionService {
  static const String _subscriptionTable = 'user_subscriptions';
  
  /// Niveles de suscripción disponibles
  static const Map<String, Map<String, dynamic>> subscriptionPlans = {
    'free': {
      'name': 'Verificador de Recibo',
      'price': 0,
      'companies_limit': 0,
      'employees_per_company': 0,
      'features': [
        'Verificador de recibos gratuito',
        'Acceso ilimitado a verificación',
        'Sin funciones de liquidación'
      ],
      'excluded': ['Liquidación de sueldos', 'Gestión de empresas', 'Empleados']
    },
    'premium': {
      'name': 'Premium',
      'price': 15000,
      'companies_limit': 2,
      'employees_per_company': 15,
      'trial_days': 30,
      'features': [
        '2 empresas máximo',
        '15 empleados por empresa',
        'Todas las funciones de liquidación',
        'Soporte prioritario',
        '30 días gratis de prueba'
      ],
      'excluded': ['Verificador de recibo']
    },
    'professional': {
      'name': 'Profesional',
      'price': 35000,
      'companies_limit': 10,
      'employees_per_company': 50,
      'trial_days': 30,
      'features': [
        '10 empresas máximo',
        '50 empleados por empresa',
        'Todas las funciones de liquidación',
        'Soporte premium',
        '30 días gratis de prueba',
        'Reportes avanzados'
      ],
      'excluded': ['Verificador de recibo']
    },
    'enterprise': {
      'name': 'Enterprise',
      'price': 75000,
      'companies_limit': -1, // Ilimitado
      'employees_per_company': -1, // Ilimitado
      'trial_days': 30,
      'features': [
        'Empresas ilimitadas',
        'Empleados ilimitados',
        'Todas las funciones de liquidación',
        'Soporte 24/7',
        '30 días gratis de prueba',
        'API access',
        'Custom integrations'
      ],
      'excluded': ['Verificador de recibo']
    }
  };

  /// Obtener el plan actual del usuario
  static Future<Map<String, dynamic>?> getCurrentUserPlan() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return null;
      
      final response = await Supabase.instance.client
          .from(_subscriptionTable)
          .select()
          .eq('user_id', user.id)
          .maybeSingle();
      
      return response;
    } catch (e) {
      return null;
    }
  }

  /// Verificar si el usuario tiene acceso a una función específica
  static Future<bool> hasAccessToFeature(String feature) async {
    final plan = await getCurrentUserPlan();
    if (plan == null) return false;
    
    final planType = plan['plan_type'] ?? 'free';

    
    // Verificador de recibo solo para plan free
    if (feature == 'verificador_recibo') return planType == 'free';
    
    // Para funciones de liquidación, verificar que no sea free
    if (feature == 'liquidacion' && planType == 'free') return false;
    
    return true;
  }

  /// Verificar límites de empresas
  static Future<bool> canCreateCompany() async {
    final plan = await getCurrentUserPlan();
    if (plan == null) return false;
    
    final planType = plan['plan_type'] ?? 'free';
    final planConfig = subscriptionPlans[planType];
    
    if (planType == 'free') return false;
    if (planConfig?['companies_limit'] == -1) return true;
    
    // Contar empresas actuales del usuario
    final user = Supabase.instance.client.auth.currentUser;
    final PostgrestResponse<dynamic> response = await Supabase.instance.client
        .from('empresas')
        .select()
        .eq('user_id', user!.id)
        .count();
    final int companiesCount = response.count as int;
    
    return companiesCount < (planConfig?['companies_limit'] ?? 0);
  }

  /// Verificar límites de empleados por empresa
  static Future<bool> canCreateEmployee(String companyId) async {
    final plan = await getCurrentUserPlan();
    if (plan == null) return false;
    
    final planType = plan['plan_type'] ?? 'free';
    final planConfig = subscriptionPlans[planType];
    
    if (planType == 'free') return false;
    if (planConfig?['employees_per_company'] == -1) return true;
    
    // Contar empleados actuales de la empresa
    final PostgrestResponse<dynamic> response = await Supabase.instance.client
        .from('empleados')
        .select()
        .eq('empresa_id', companyId)
        .count();
    final int employeesCount = response.count as int;
    
    return employeesCount < (planConfig?['employees_per_company'] ?? 0);
  }

  /// Verificar si está en periodo de prueba
  static Future<bool> isInTrialPeriod() async {
    final plan = await getCurrentUserPlan();
    if (plan == null) return false;
    
    final createdAt = DateTime.parse(plan['created_at']);
    final trialDays = subscriptionPlans[plan['plan_type']]?['trial_days'] ?? 0;
    final trialEnd = createdAt.add(Duration(days: trialDays));
    
    return DateTime.now().isBefore(trialEnd);
  }

  /// Obtener días restantes de prueba
  static Future<int> getTrialDaysRemaining() async {
    final plan = await getCurrentUserPlan();
    if (plan == null) return 0;
    
    final createdAt = DateTime.parse(plan['created_at']);
    final trialDays = subscriptionPlans[plan['plan_type']]?['trial_days'] ?? 0;
    final trialEnd = createdAt.add(Duration(days: trialDays));
    
    final now = DateTime.now();
    if (now.isAfter(trialEnd)) return 0;
    
    return trialEnd.difference(now).inDays;
  }

  /// Iniciar proceso de compra a través de Google Play Billing
  static Future<void> purchaseSubscription(String planType, {bool isTrial = false}) async {
    final billingService = PlayBillingService();
    final isAvailable = await billingService.initialize();
    
    if (!isAvailable) {
      throw Exception('Google Play Billing no está disponible');
    }
    
    final product = await billingService.getProductForPlan(planType, isTrial: isTrial);
    if (product == null) {
      throw Exception('Producto no encontrado en Google Play Console');
    }
    
    await billingService.purchaseProduct(product, isTrial: isTrial);
  }

  /// Verificar suscripciones activas en Google Play
  static Future<bool> hasActivePlayStoreSubscription(String planType) async {
    final billingService = PlayBillingService();
    final isAvailable = await billingService.initialize();
    
    if (!isAvailable) return false;
    
    final productId = PlayBillingService.productIds[planType];
    if (productId == null) return false;
    
    return await billingService.hasActiveSubscription(productId);
  }

  /// Restaurar compras desde Google Play
  static Future<void> restorePurchases() async {
    final billingService = PlayBillingService();
    final isAvailable = await billingService.initialize();
    
    if (!isAvailable) {
      throw Exception('Google Play Billing no está disponible');
    }
    
    await billingService.restorePurchases();
  }
}