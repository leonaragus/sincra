
import 'package:flutter/material.dart';
import 'package:sincra_app/theme/app_colors.dart';
import 'package:sincra_app/subscription/pricing_screen.dart';
import 'package:sincra_app/subscription/subscription_service.dart';
import 'package:intl/intl.dart';

class SubscriptionStatusScreen extends StatefulWidget {
  const SubscriptionStatusScreen({super.key});

  @override
  State<SubscriptionStatusScreen> createState() => _SubscriptionStatusScreenState();
}

class _SubscriptionStatusScreenState extends State<SubscriptionStatusScreen> {
  Future<ActiveSubscription?>? _subscriptionFuture;

  @override
  void initState() {
    super.initState();
    _subscriptionFuture = SubscriptionService.getActiveSubscription();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Estado de tu Suscripción'),
        backgroundColor: AppColors.backgroundLight,
      ),
      backgroundColor: AppColors.background,
      body: FutureBuilder<ActiveSubscription?>(
        future: _subscriptionFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
            return _buildErrorState();
          }

          final subscription = snapshot.data!;
          final planDetails = subscription.planDetail;
          final formattedDate = DateFormat.yMMMMd('es_ES').format(subscription.expiresAt);

          return _buildSubscriptionDetails(planDetails.name, formattedDate);
        },
      ),
    );
  }

  Widget _buildSubscriptionDetails(String currentPlanName, String formattedDate) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(20.0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: AppColors.glassFillStrong,
              border: Border.all(color: AppColors.accentBlue, width: 2),
            ),
            child: Column(
              children: [
                const Text(
                  'PLAN ACTUAL',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                ),
                const SizedBox(height: 8),
                Text(
                  currentPlanName,
                  style: const TextStyle(color: AppColors.accentBlue, fontSize: 28, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                const Divider(color: AppColors.glassBorder),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.calendar_today, color: AppColors.textSecondary, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Vence el $formattedDate',
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 16),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Text(
            '¿Necesitás más? ¿O menos?',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Podés cambiar tu plan en cualquier momento. El nuevo plan se activará al finalizar el ciclo de facturación actual.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 15, height: 1.5),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const PricingScreen()));
            },
            icon: const Icon(Icons.shopping_cart_checkout, color: Colors.white),
            label: const Text('Cambiar de Plan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.glassFill,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.textSecondary, size: 24),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Si cancelás tu suscripción, mantendrás acceso premium hasta la fecha de vencimiento. Tus datos nunca serán eliminados.',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: AppColors.danger, size: 48),
            const SizedBox(height: 16),
            const Text(
              'No se pudo cargar tu suscripción',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Parece que no tenés un plan activo o hubo un problema al verificarlo. Por favor, intentá de nuevo o elegí un plan.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 15, height: 1.5),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const PricingScreen()));
              },
              child: const Text('Ver Planes'),
            ),
          ],
        ),
      ),
    );
  }
}
