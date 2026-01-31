import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_colors.dart';
import '../services/subscription_service.dart';

/// Pantalla moderna de selección de plan antes del registro/login
class PlanSelectionScreen extends StatelessWidget {
  const PlanSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Header
              const SizedBox(height: 40),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.stars_rounded, size: 48, color: AppColors.primary),
                    const SizedBox(height: 16),
                    const Text(
                      'Elige tu Plan Perfecto',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '¡Todos los planes incluyen 30 días GRATIS de prueba!',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),

              // Plan Gratuito - Verificador de Recibo
              _buildPlanCard(
                context,
                plan: SubscriptionService.subscriptionPlans['free']!,
                isPopular: false,
                isFree: true,
              ),

              const SizedBox(height: 24),

              // Planes Pagos
              _buildPlanCard(
                context,
                plan: SubscriptionService.subscriptionPlans['premium']!,
                isPopular: true,
                isFree: false,
              ),

              const SizedBox(height: 16),

              _buildPlanCard(
                context,
                plan: SubscriptionService.subscriptionPlans['professional']!,
                isPopular: false,
                isFree: false,
              ),

              const SizedBox(height: 16),

              _buildPlanCard(
                context,
                plan: SubscriptionService.subscriptionPlans['enterprise']!,
                isPopular: false,
                isFree: false,
              ),

              const SizedBox(height: 32),

              // Guía para usuarios
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.backgroundLight,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.glassBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.help_outline, size: 20, color: AppColors.primary),
                        const SizedBox(width: 8),
                        const Text(
                          '¿No estás seguro qué plan elegir?',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '• Si solo necesitas verificar tu recibo de sueldo → Elige VERIFICADOR GRATUITO\n'
                      '• Si tenés hasta 2 empresas y 15 empleados → Elige PREMIUM\n'
                      '• Si sos contador con múltiples clientes → Elige PROFESIONAL\n'
                      '• Si tenés una empresa grande → Elige ENTERPRISE',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlanCard(BuildContext context, {
    required Map<String, dynamic> plan,
    required bool isPopular,
    required bool isFree,
  }) {
    final price = plan['price'] as int;
    final isUnlimitedCompanies = plan['companies_limit'] == -1;
    final isUnlimitedEmployees = plan['employees_per_company'] == -1;

    return Container(
      decoration: BoxDecoration(
        color: isPopular ? AppColors.primary.withOpacity(0.05) : AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isPopular ? AppColors.primary : AppColors.glassBorder,
          width: isPopular ? 2 : 1,
        ),
      ),
      child: Stack(
        children: [
          if (isPopular)
            Positioned(
              top: -6,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'MÁS POPULAR',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header del plan
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      plan['name'],
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isPopular ? AppColors.primary : AppColors.textPrimary,
                      ),
                    ),
                    if (isFree)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green),
                        ),
                        child: const Text(
                          'SIEMPRE GRATIS',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      )
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${price.toStringAsFixed(0)}/mes',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const Text(
                            '30 días gratis',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.green,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),

                const SizedBox(height: 16),

                // Límites
                if (!isFree)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLimitRow(
                        '🏢 Empresas',
                        isUnlimitedCompanies ? 'Ilimitadas' : '${plan['companies_limit']} empresas',
                      ),
                      const SizedBox(height: 8),
                      _buildLimitRow(
                        '👥 Empleados',
                        isUnlimitedEmployees ? 'Ilimitados' : '${plan['employees_per_company']} por empresa',
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),

                // Características incluidas
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '✅ Incluye:',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...(plan['features'] as List).map((feature) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        '• $feature',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    )).toList(),
                  ],
                ),

                const SizedBox(height: 16),

                // Excluido (solo para planes pagos)
                if (!isFree)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '❌ No incluye:',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...(plan['excluded'] as List).map((excluded) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          '• $excluded',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      )).toList(),
                    ],
                  ),

                const SizedBox(height: 20),

                // Botón de selección
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _onPlanSelected(context, plan['name'].toString().toLowerCase()),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isFree ? AppColors.glassFill : AppColors.primary,
                      foregroundColor: isFree ? AppColors.textPrimary : Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      isFree ? 'Continuar Gratis' : 'Comenzar Prueba Gratis',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLimitRow(String label, String value) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  void _onPlanSelected(BuildContext context, String planType) {
    // Navegar al login/registro con el plan seleccionado
    Navigator.pushNamed(context, '/web-login', arguments: {'plan': planType});
  }
}