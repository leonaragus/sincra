import 'dart:math';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_colors.dart';
import '../services/educational_concepts_service.dart';

class AcademyAdBanner extends StatefulWidget {
  const AcademyAdBanner({super.key});

  @override
  State<AcademyAdBanner> createState() => _AcademyAdBannerState();
}

class _AcademyAdBannerState extends State<AcademyAdBanner> {
  final List<String> _messages = [
    "¿Querés aprender a liquidar sueldos como un profesional? Mirá nuestros cursos.",
    "Potenciá tu carrera con nuestra formación técnica en liquidación.",
    "Convertite en experto en liquidación de sueldos. ¡Inscribite hoy!",
    "¿Dudas con la liquidación? Aprendé con los mejores en Academia Elevar.",
    "Capacitación práctica y actualizada para liquidadores exigentes."
  ];

  late String _currentMessage;

  @override
  void initState() {
    super.initState();
    _currentMessage = _messages[Random().nextInt(_messages.length)];
  }

  Future<void> _launchWhatsApp() async {
    final phone = EducationalConceptsService.contactoAcademia;
    final url = Uri.parse('https://wa.me/$phone?text=Hola! Me gustaría recibir información sobre los cursos de liquidación de sueldos.');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      margin: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark 
              ? [AppColors.secondary, AppColors.secondary.withOpacity(0.8)]
              : [Colors.white, Colors.grey.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: isDark 
              ? AppColors.glassBorder.withOpacity(0.5) 
              : AppColors.glassBorderLightMode.withOpacity(0.5),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.accentBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.school, color: AppColors.accentBlue, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Elevar Formación Técnica',
                      style: TextStyle(
                        color: isDark ? AppColors.textPrimary : AppColors.textPrimaryLightMode,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _currentMessage,
                      style: TextStyle(
                        color: isDark ? AppColors.textSecondary : AppColors.textSecondaryLightMode,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _launchWhatsApp,
              icon: const Icon(Icons.chat_bubble_outline, size: 18),
              label: const Text('Consultar por WhatsApp'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentBlue,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
