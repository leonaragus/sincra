import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Pantalla del Verificador de Recibos Gratuito
class VerificadorRecibosScreen extends StatelessWidget {
  const VerificadorRecibosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verificador de Recibos Gratuito'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        automaticallyImplyLeading: false, // Oculta el botón de back
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.verified_user,
              size: 64,
              color: AppColors.primary,
            ),
            
            const SizedBox(height: 24),
            
            const Text(
              'Verificador de Recibos',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            
            const SizedBox(height: 16),
            
            const Text(
              'Herramienta gratuita para verificar tus recibos de sueldo. '
              'Perfecta para empleados que quieren validar sus liquidaciones.',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 32),
            
            // TODO: Implementar funcionalidad de verificación
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.backgroundLight,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: const Column(
                children: [
                  Icon(Icons.camera_alt, size: 48, color: AppColors.primary),
                  SizedBox(height: 16),
                  Text(
                    'Escanea tu recibo de sueldo',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Usa la cámara para escanear tu recibo y verificar su validez',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            const Text(
              '✅ 100% Gratuito • ✅ Sin suscripciones • ✅ Fácil de usar',
              style: TextStyle(
                fontSize: 14,
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