// Opciones de liquidación docente. Pantalla con botones para cada tipo de liquidación.

import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'liquidacion_docente_screen.dart';

class OpcionesLiquidacionDocenteScreen extends StatelessWidget {
  const OpcionesLiquidacionDocenteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.glassFillStrong,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Opciones de liquidación',
          style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildPanelOpciones(context),
        ],
      ),
    );
  }

  void _onOpcionTap(BuildContext context, String id) {
    switch (id) {
      case 'mensual':
        Navigator.push(context, MaterialPageRoute(
          builder: (c) => const LiquidacionDocenteScreen(modo: "mensual"),
        ));
        break;
      case 'sac':
        Navigator.push(context, MaterialPageRoute(
          builder: (c) => const LiquidacionDocenteScreen(modo: "sac"),
        ));
        break;
      case 'vacaciones':
        Navigator.push(context, MaterialPageRoute(
          builder: (c) => const LiquidacionDocenteScreen(modo: "vacaciones"),
        ));
        break;
      case 'final':
        Navigator.push(context, MaterialPageRoute(
          builder: (c) => const LiquidacionDocenteScreen(modo: "final"),
        ));
        break;
      case 'proporcional':
        Navigator.push(context, MaterialPageRoute(
          builder: (c) => const LiquidacionDocenteScreen(modo: "proporcional"),
        ));
        break;
      case 'horas_catedra':
        Navigator.push(context, MaterialPageRoute(
          builder: (c) => const LiquidacionDocenteScreen(soloHorasCatedra: true, modo: "mensual"),
        ));
        break;
      default:
        break;
    }
  }

  Widget _buildPanelOpciones(BuildContext context) {
    final opciones = [
      (id: 'mensual', icon: Icons.calendar_month, label: 'Liquidación mensual'),
      (id: 'sac', icon: Icons.card_giftcard, label: 'Liquidación de SAC (Aguinaldo)'),
      (id: 'vacaciones', icon: Icons.beach_access, label: 'Liquidación de vacaciones'),
      (id: 'final', icon: Icons.handshake, label: 'Liquidación final (cese / desvinculación)'),
      (id: 'proporcional', icon: Icons.pie_chart_outline, label: 'Liquidación proporcional / por días'),
      (id: 'horas_catedra', icon: Icons.schedule, label: 'Liquidación de horas cátedra'),
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.glassFillStrong,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.glassBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Elegí el tipo de liquidación',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 16),
          ...opciones.asMap().entries.map((e) {
            final i = e.key;
            final o = e.value;
            return Padding(
              padding: EdgeInsets.only(bottom: i < opciones.length - 1 ? 12 : 0),
              child: OutlinedButton.icon(
                onPressed: () => _onOpcionTap(context, o.id),
                icon: Icon(o.icon, size: 22, color: AppColors.textPrimary),
                label: Text(
                  o.label,
                  style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
                ),
                style: OutlinedButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  side: const BorderSide(color: AppColors.glassBorder),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
