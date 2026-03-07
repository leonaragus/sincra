
import 'package:flutter/material.dart';
import 'subscription_service.dart';
import 'user_roles.dart';
import '../theme/app_colors.dart';

class RoleSelectionDialog extends StatelessWidget {
  final VoidCallback onRoleSelected; // Callback para refrescar la UI principal

  const RoleSelectionDialog({super.key, required this.onRoleSelected});

  Future<void> _selectRole(BuildContext context, UserRole role) async {
    await SubscriptionService.setUserRole(role);
    Navigator.of(context).pop(role); // devuelve el rol seleccionado
    onRoleSelected(); // Llama al callback
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: AppColors.backgroundLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '¡Tu prueba ha terminado!',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 12),
              const Text(
                'Para continuar, por favor, contanos cómo vas a usar Syncra.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
              ),
              const SizedBox(height: 28),
              _buildRoleButton(
                context,
                icon: Icons.person_search,
                title: 'Busco Información',
                subtitle: 'Quiero analizar mis recibos y entender mi sueldo.',
                role: UserRole.information,
              ),
              const SizedBox(height: 16),
              _buildRoleButton(
                context,
                icon: Icons.work,
                title: 'Soy Profesional',
                subtitle: 'Uso la app para liquidar sueldos y gestionar clientes.',
                role: UserRole.professional,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleButton(BuildContext context, {required IconData icon, required String title, required String subtitle, required UserRole role}) {
    return InkWell(
      onTap: () => _selectRole(context, role),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.glassBorder, width: 1.5),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.accentBlue, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: AppColors.textSecondary, size: 16),
          ],
        ),
      ),
    );
  }
}
