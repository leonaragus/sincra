import 'package:flutter/material.dart';
import 'package:syncra_arg/theme/app_colors.dart';
import 'package:url_launcher/url_launcher.dart';

class AcademyPromoDialog extends StatelessWidget {
  final VoidCallback onDownload;

  const AcademyPromoDialog({super.key, required this.onDownload});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.school, color: AppColors.accentBlue, size: 28),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Elevar Formación Técnica',
              style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.accentBlue.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.auto_stories,
                size: 48, color: AppColors.accentBlue),
          ),
          const SizedBox(height: 16),
          const Text(
            '¡Potenciá tu futuro profesional!',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.textPrimary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          const Text(
            'Aprendé a liquidar sueldos desde cero o perfeccionate con nuestros cursos prácticos y actualizados.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () async {
              const url = 'https://www.instagram.com/elevarformaciontecnica/';
              if (await canLaunchUrl(Uri.parse(url))) {
                await launchUrl(Uri.parse(url));
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.surfaceLight,
              foregroundColor: AppColors.accentBlue,
              side: const BorderSide(color: AppColors.accentBlue),
              elevation: 0,
            ),
            child: const Text('Ver Cursos Disponibles'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cerrar', style: TextStyle(color: AppColors.textMuted)),
        ),
        ElevatedButton.icon(
          onPressed: () {
            Navigator.pop(context);
            onDownload();
          },
          icon: const Icon(Icons.download),
          label: const Text('Descargar Informe'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accentGreen,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}
