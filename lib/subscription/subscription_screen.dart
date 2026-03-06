
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'subscription_service.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  bool _isLoading = true;
  int _daysRemaining = 0;
  int _claudeCallsLeft = 0;

  @override
  void initState() {
    super.initState();
    _loadSubscriptionStatus();
  }

  Future<void> _loadSubscriptionStatus() async {
    final days = await SubscriptionService.getTrialDaysRemaining();
    final calls = await SubscriptionService.getClaudeCallsRemaining();
    
    if (mounted) {
      setState(() {
        _daysRemaining = days;
        _claudeCallsLeft = calls;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Suscripción'),
        backgroundColor: AppColors.backgroundLight,
      ),
      backgroundColor: AppColors.background,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildTrialStatusCard(),
                  const SizedBox(height: 24),
                  _buildFeatureLimitsCard(),
                  const SizedBox(height: 24),
                  _buildGeneralBenefitsCard(),
                ],
              ),
            ),
    );
  }

  Widget _buildTrialStatusCard() {
    final bool isTrialActive = _daysRemaining > 0;

    return Card(
      color: AppColors.backgroundLight,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const Icon(Icons.card_giftcard, color: Colors.redAccent, size: 48),
            const SizedBox(height: 12),
            const Text(
              'Prueba Gratis de 30 Días', // El mensaje de marketing
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.redAccent),
            ),
            const SizedBox(height: 8),
            Text(
              isTrialActive
                ? 'Te quedan $_daysRemaining días de acceso total. ¡Aprovechá todas las funciones premium de Syncra!'
                : 'Tu período de prueba ha terminado. ¡Esperamos que hayas disfrutado la experiencia!',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 15, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureLimitsCard() {
    return Card(
      color: AppColors.backgroundLight,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Funciones de la Prueba', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 16),
            _BenefitItem(
              icon: Icons.auto_awesome,
              text: _claudeCallsLeft == -1
                  ? 'Análisis con IA (Claude): ilimitado'
                  : 'Análisis con IA (Claude): $_claudeCallsLeft restantes',
              iconColor: AppColors.accentPurple,
            ),
            const _BenefitItem(
              icon: Icons.all_inclusive,
              text: 'Liquidaciones y reportes ilimitados',
              iconColor: AppColors.accentBlue,
            ),
            const _BenefitItem(
              icon: Icons.cloud_done_outlined,
              text: 'Sincronización en la nube',
              iconColor: AppColors.accentBlue,
            ),
            const _BenefitItem(
              icon: Icons.business,
              text: 'Gestión de múltiples empresas y empleados',
              iconColor: AppColors.accentBlue,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGeneralBenefitsCard() {
    return Card(
      color: AppColors.backgroundLight,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: const Padding(
        padding: EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Incluido en todos los planes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            SizedBox(height: 16),
            _BenefitItem(icon: Icons.bolt, text: 'Liquidación Masiva Ultra-Rápida'),
            _BenefitItem(icon: Icons.support_agent, text: 'Soporte Técnico 24/7'),
            _BenefitItem(icon: Icons.security, text: 'Backups automáticos diarios'),
          ],
        ),
      ),
    );
  }
}

class _BenefitItem extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? iconColor;

  const _BenefitItem({required this.icon, required this.text, this.iconColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, color: iconColor ?? AppColors.accentBlue, size: 22),
          const SizedBox(width: 16),
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
