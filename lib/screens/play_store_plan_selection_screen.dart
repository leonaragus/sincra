import 'package:flutter/material.dart';
import '../services/subscription_service.dart';
import '../theme/app_colors.dart';

/// Pantalla de selección de planes específica para Play Store
class PlayStorePlanSelectionScreen extends StatefulWidget {
  const PlayStorePlanSelectionScreen({super.key});

  @override
  State<PlayStorePlanSelectionScreen> createState() => _PlayStorePlanSelectionScreenState();
}

class _PlayStorePlanSelectionScreenState extends State<PlayStorePlanSelectionScreen> {
  bool _loading = false;

  Future<void> _purchasePlan(String planType, {bool isTrial = true}) async {
    setState(() => _loading = true);
    
    try {
      await SubscriptionService.purchaseSubscription(planType, isTrial: isTrial);
      
      // Mostrar mensaje de éxito
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('¡Suscripción iniciada correctamente! Disfruta de tus ${isTrial ? '30 días gratis' : 'plan'}'),
          backgroundColor: Colors.green,
        ),
      );
      
      // Regresar a pantalla anterior
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  Widget _buildPlanCard(BuildContext context, {
    required String planType,
    required String name,
    required int price,
    required List<String> features,
    bool isPopular = false,
    bool isFree = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isPopular ? AppColors.primary.withOpacity(0.05) : AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPopular ? AppColors.primary : AppColors.glassBorder,
          width: isPopular ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isPopular)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'MÁS POPULAR',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          
          SizedBox(height: isPopular ? 8 : 0),
          
          Text(
            name,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isPopular ? AppColors.primary : AppColors.textPrimary,
            ),
          ),
          
          const SizedBox(height: 8),
          
          if (!isFree)
            Text(
              '\$$price/mes',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          
          const SizedBox(height: 16),
          
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: features.map((feature) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        feature,
                        style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          
          const SizedBox(height: 20),
          
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _loading ? null : () => _purchasePlan(planType, isTrial: !isFree),
              style: ElevatedButton.styleFrom(
                backgroundColor: isFree ? AppColors.glassFill : AppColors.primary,
                foregroundColor: isFree ? AppColors.textPrimary : Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                isFree ? 'Continuar Gratis' : 'Comenzar Prueba Gratis',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Elegir Plan de Suscripción'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Elige el plan perfecto para ti',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  const Text(
                    'Todos los planes incluyen 30 días de prueba gratis. Cancela cuando quieras.',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Cartel de advertencia para no contadores
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '⚠️ ¿Sos Contador o tenés una Empresa?',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Esta herramienta está diseñada específicamente para contadores y empresas '
                          'que necesitan liquidar sueldos profesionalmente. Si no tenés conocimientos '
                          'contables, te recomendamos usar nuestro Verificador de Recibos gratuito.',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Plan Free
                  _buildPlanCard(
                    context,
                    planType: 'free',
                    name: 'Verificador de Recibo',
                    price: 0,
                    features: const [
                      'Verificador de recibos gratuito',
                      'Acceso ilimitado a verificación',
                      'Sin funciones de liquidación',
                    ],
                    isFree: true,
                  ),
                  
                  // Plan Premium
                  _buildPlanCard(
                    context,
                    planType: 'premium',
                    name: 'Premium',
                    price: 15000,
                    features: const [
                      '2 empresas máximo',
                      '15 empleados por empresa',
                      'Todas las funciones de liquidación',
                      'Soporte prioritario',
                      '30 días gratis de prueba',
                    ],
                    isPopular: true,
                  ),
                  
                  // Plan Profesional
                  _buildPlanCard(
                    context,
                    planType: 'professional',
                    name: 'Profesional',
                    price: 35000,
                    features: const [
                      '10 empresas máximo',
                      '50 empleados por empresa',
                      'Todas las funciones de liquidación',
                      'Soporte premium',
                      '30 días gratis de prueba',
                      'Reportes avanzados',
                    ],
                  ),
                  
                  // Plan Enterprise
                  _buildPlanCard(
                    context,
                    planType: 'enterprise',
                    name: 'Enterprise',
                    price: 75000,
                    features: const [
                      'Empresas ilimitadas',
                      'Empleados ilimitados',
                      'Todas las funciones de liquidación',
                      'Soporte 24/7',
                      '30 días gratis de prueba',
                      'API access',
                      'Custom integrations',
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  const Text(
                    '💡 Todos los pagos se procesan de forma segura a través de Google Play Store. ',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  const Text(
                    'Puedes cancelar tu suscripción en cualquier momento desde la configuración de Google Play.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}