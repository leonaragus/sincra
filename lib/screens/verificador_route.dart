import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class VerificadorReciboScreen extends StatelessWidget {
  const VerificadorReciboScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Asesor de Recibos IA'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.document_scanner_outlined, size: 64, color: AppColors.primary),
            const SizedBox(height: 16),
            const Text('Escáner de recibos no disponible en este entorno', style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Volver'),
            ),
          ],
        ),
      ),
    );
  }
}
