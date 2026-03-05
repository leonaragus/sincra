
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../models/subscription_plan.dart';

class SubscriptionScreen extends StatelessWidget {
  const SubscriptionScreen({super.key});

  void _mostrarInfoPlan(BuildContext context, String planName) {
    final plan = planName == 'Contador' 
        ? SubscriptionPlan.contador 
        : SubscriptionPlan.businessPro;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.backgroundLight,
        title: Text('Plan ${plan.name}', style: const TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${plan.price} USD / mes', style: const TextStyle(color: AppColors.accentBlue, fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text(
              planName == 'Contador' 
                ? 'Ideal para profesionales independientes y pequeñas pymes.'
                : 'Para grandes contadores y empresas con volumen ilimitado.',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            if (plan.isUnlimited) ...[
              const _BenefitItem(icon: Icons.all_inclusive, text: 'Empresas ilimitadas'),
              const _BenefitItem(icon: Icons.people_alt, text: 'Empleados ilimitados'),
              const _BenefitItem(icon: Icons.analytics, text: 'Informes y reportes ilimitados'),
              const _BenefitItem(icon: Icons.download_for_offline, text: 'Descargas de recibos y LSD ilimitadas'),
            ] else ...[
              _BenefitItem(icon: Icons.business, text: 'Hasta ${plan.maxCompanies} empresas'),
              _BenefitItem(icon: Icons.people, text: 'Hasta ${plan.maxEmployeesPerCompany} empleados por empresa'),
              _BenefitItem(icon: Icons.file_download, text: '${plan.maxMonthlyDownloads} recibos y LSD por mes'),
              const _BenefitItem(icon: Icons.cloud_done, text: 'Sincronización en la nube'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _procesarPagoPlayStore(context, plan.name);
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.accentBlue),
            child: const Text('Suscribirse'),
          ),
        ],
      ),
    );
  }

  void _procesarPagoPlayStore(BuildContext context, String plan) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Conectando con Google Play Store para el Plan $plan...'),
        backgroundColor: AppColors.accentBlue,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Planes y Suscripción'),
        backgroundColor: AppColors.backgroundLight,
      ),
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Tarjeta de Prueba Gratis
            Card(
              color: AppColors.backgroundLight,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Icon(Icons.card_giftcard, color: Colors.redAccent, size: 40),
                    const SizedBox(height: 8),
                    const Text('Prueba Gratis de 30 Días', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.redAccent)),
                    const SizedBox(height: 8),
                    const Text(
                      'Disfrutá de acceso total a todas las funciones premium de SYncra durante tu primer mes.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Tarjeta Plan Contador
            _buildPlanCard(
              context,
              plan: SubscriptionPlan.contador,
              onTap: () => _mostrarInfoPlan(context, 'Contador'),
            ),
            const SizedBox(height: 16),
            // Tarjeta Plan Business Pro
            _buildPlanCard(
              context,
              plan: SubscriptionPlan.businessPro,
              onTap: () => _mostrarInfoPlan(context, 'Business Pro'),
            ),
            const SizedBox(height: 24),
             // Beneficios Premium
            Card(
              color: AppColors.backgroundLight,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: const Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Todos los planes incluyen:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                    SizedBox(height: 16),
                    _BenefitItem(icon: Icons.bolt, text: 'Liquidación Masiva Ultra-Rápida'),
                    _BenefitItem(icon: Icons.cloud_sync, text: 'Sincronización en la Nube'),
                    _BenefitItem(icon: Icons.support_agent, text: 'Soporte Técnico 24/7'),
                    _BenefitItem(icon: Icons.security, text: 'Backups automáticos diarios'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanCard(BuildContext context, {required SubscriptionPlan plan, required VoidCallback onTap}) {
    return Card(
      color: AppColors.glassFill,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.glassBorder),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(plan.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 8),
              Text('${plan.price} USD / mes', style: const TextStyle(color: AppColors.accentBlue, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Text(
                plan.name == 'Contador & Pymes'
                  ? 'Ideal para profesionales independientes y pequeñas pymes.'
                  : 'Para grandes contadores y empresas con volumen ilimitado.',
                style: const TextStyle(color: AppColors.textSecondary, height: 1.5),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: Icon(Icons.arrow_forward, color: AppColors.textSecondary),
              )
            ],
          ),
        ),
      ),
    );
  }
}

class _BenefitItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const _BenefitItem({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: AppColors.accentBlue, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
