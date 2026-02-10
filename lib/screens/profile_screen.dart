import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/subscription_service.dart';
import '../theme/app_colors.dart';
import '../utils/auth_middleware.dart';
import '../services/openai_vision_service.dart';
import 'play_store_plan_selection_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _userInfo;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    try {
      final userInfo = await AuthMiddleware.getCurrentUserInfo();
      setState(() {
        _userInfo = userInfo;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _signOut() async {
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (e) {
      // Ignore errors
    }
  }

  Future<void> _openWhatsAppSupport() async {
    const phone = '+5491123456789'; // Reemplazar con número real
    final url = Uri.parse('https://wa.me/$phone');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  Future<void> _openPlanSelection() async {
    try {
      final userInfo = await AuthMiddleware.getCurrentUserInfo();
      final currentPlan = userInfo?['plan']?['plan_type'] ?? 'free';
      
      if (currentPlan == 'free') {
        // Navegar a pantalla de selección de planes de Play Store
        Navigator.push(
          context,
          MaterialPageRoute(builder: (c) => const PlayStorePlanSelectionScreen()),
        );
      } else {
        // Para usuarios pagos, mostrar opción de gestionar en Play Store
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gestiona tu suscripción desde Google Play Store')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _configurarApiKey() async {
    final currentKey = await OpenAIVisionService.getApiKey() ?? '';
    final ctrl = TextEditingController(text: currentKey);

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Configurar OpenAI API Key'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Ingrese su clave de API de OpenAI para habilitar el reconocimiento avanzado de recibos (Vision GPT-4o).',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: ctrl,
              decoration: const InputDecoration(
                labelText: 'API Key (sk-...)',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              await OpenAIVisionService.setApiKey(ctrl.text.trim());
              if (mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('API Key guardada correctamente')),
                );
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard() {
    if (_userInfo == null) return const SizedBox();
    
    final plan = _userInfo!['plan'];
    final planType = plan?['plan_type'] ?? 'free';
    final planConfig = SubscriptionService.subscriptionPlans[planType];
    final isTrial = _userInfo!['is_trial'] ?? false;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
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
              Icon(
                planType == 'free' ? Icons.verified : Icons.star,
                color: planType == 'free' ? AppColors.primary : Colors.amber,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                planConfig?['name'] ?? 'Verificador de Recibo',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          if (isTrial && planType != 'free')
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green),
              ),
              child: Text(
                'PRUEBA GRATIS - ${_userInfo!['trial_days_remaining']} días restantes',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ),
          
          const SizedBox(height: 12),
          
          if (planType != 'free')
            Text(
              '\$${planConfig?['price']?.toStringAsFixed(0) ?? '0'}/mes',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          
          const SizedBox(height: 8),
          
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: (planConfig?['features'] as List<dynamic>? ?? []).map((feature) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        feature.toString(),
                        style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          
          const SizedBox(height: 16),
          
          if (planType == 'free')
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _openPlanSelection,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('UPGRADE A PREMIUM', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _openPlanSelection,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('GESTIONAR SUSCRIPCIÓN', style: TextStyle(color: AppColors.primary)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildUserInfo() {
    final user = _userInfo?['user'] as User?;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Información de Cuenta',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          
          Row(
            children: [
              const Icon(Icons.email, color: AppColors.textSecondary, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  user?.email ?? 'No email',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          Row(
            children: [
              const Icon(Icons.person, color: AppColors.textSecondary, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Usuario desde: ${user?.createdAt.substring(0, 10) ?? 'N/A'}',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSupportSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Soporte',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          
          ListTile(
            leading: const Icon(Icons.support_agent, color: Colors.green),
            title: const Text('Soporte por WhatsApp'),
            subtitle: const Text('Contactanos 24/7'),
            onTap: _openWhatsAppSupport,
            contentPadding: EdgeInsets.zero,
          ),
          
          ListTile(
            leading: const Icon(Icons.privacy_tip, color: AppColors.primary),
            title: const Text('Políticas de Privacidad'),
            subtitle: const Text('Términos y condiciones'),
            onTap: () {},
            contentPadding: EdgeInsets.zero,
          ),
          
          ListTile(
            leading: const Icon(Icons.key, color: Colors.purple),
            title: const Text('Configuración API (OpenAI)'),
            subtitle: const Text('Mejorar reconocimiento OCR'),
            onTap: _configurarApiKey,
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Perfil'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildPlanCard(),
                  _buildUserInfo(),
                  const SizedBox(height: 20),
                  _buildSupportSection(),
                  const SizedBox(height: 30),
                  
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _signOut,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text(
                        'Cerrar Sesión',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}