import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'play_store_plan_selection_screen.dart';

/// Pantalla de selección de tipo de usuario - Decide si es contador/empresa o no
class UserTypeSelectionScreen extends StatelessWidget {
  const UserTypeSelectionScreen({super.key});

  void _navigateToVerificador(BuildContext context) {
    // Navegar a verificador y reemplazar toda la pila de navegación
    // para que no puedan volver atrás
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/verificador',
      (route) => false,
    );
  }

  void _showNoContadorDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false, // No permitir cerrar tocando fuera
      builder: (context) => AlertDialog(
        title: const Text('⚠️ Herramienta No Recomendada'),
        content: const Text(
          'Esta herramienta está diseñada específicamente para contadores y empresas que necesitan liquidar sueldos de manera profesional.\n\n'
          'Si no eres contador ni tienes una empresa, esta herramienta NO te será útil ya que requiere conocimientos técnicos contables.\n\n'
          'Te recomendamos usar nuestro "Verificador de Recibos" gratuito que es perfecto para verificar tus recibos de sueldo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Volver Atrás'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Cerrar diálogo
              _navigateToVerificador(context); // Ir a verificador
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Ir al Verificador Gratuito'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icono y título principal
              const Icon(
                Icons.business_center,
                size: 64,
                color: AppColors.primary,
              ),
              
              const SizedBox(height: 24),
              
              const Text(
                '¿Sos Contador o tenés una Empresa?',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 16),
              
              // Cartel de advertencia
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '⚠️ Importante:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Esta herramienta está diseñada específicamente para contadores y empresas. '
                      'Si no tenés conocimientos contables o no gestionás nóminas de empleados, '
                      'esta herramienta NO te será útil.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Botón SI - Soy Contador/Empresa
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    // Navegar a selección de planes profesionales
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const PlayStorePlanSelectionScreen(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'SÍ, soy Contador o tengo Empresa',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Botón NO - No soy Contador/Empresa
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => _showNoContadorDialog(context),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.glassBorder),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'NO, solo quiero verificar recibos',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Información adicional
              const Text(
                '💡 El Verificador de Recibos es gratuito y perfecto para verificar tus recibos de sueldo',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}