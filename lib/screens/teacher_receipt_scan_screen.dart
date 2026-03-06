import 'package:flutter/material.dart';
import '../models/ocr_confirm_result.dart';
import '../models/teacher_types.dart';
import '../services/teacher_receipt_scan_service.dart' show DocenteOmniOverrides;
import '../theme/app_colors.dart';

class TeacherReceiptScanScreen extends StatelessWidget {
  const TeacherReceiptScanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Escanear Recibo Docente', style: TextStyle(color: AppColors.textPrimary)),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () {
                final result = OcrConfirmResult(
                  nombre: 'Docente Demo',
                  cuil: '27-22233344-9',
                  razonSocial: 'Institución Demo',
                  cuitEmpresa: '30-12345678-9',
                  domicilioEmpresa: 'Av. Demo 123',
                  items: const [],
                  jurisdiccion: Jurisdiccion.buenosAires,
                  tipoGestion: TipoGestion.publica,
                  cargo: TipoNomenclador.maestroGrado,
                  nivel: NivelEducativo.primario,
                  zona: ZonaDesfavorable.a,
                  fechaIngreso: DateTime(2023, 1, 15),
                  cargasFamiliares: 0,
                  horasCatedra: 0,
                  cantidadCargos: 1,
                  codigoRnos: '123456',
                  aporteEstatal: 0.0,
                  overrides: const DocenteOmniOverrides(),
                  updateJurisdiccion: false,
                  jurisdiccionActualizada: Jurisdiccion.buenosAires,
                );
                Navigator.pop(context, result);
              },
              child: const Text('Confirmar demo'),
            ),
          ],
        ),
      ),
    );
  }
}
