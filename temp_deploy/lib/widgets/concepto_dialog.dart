import 'package:flutter/material.dart';

import '../models/concepto.dart';
import '../theme/app_colors.dart';

class ConceptoDialog extends StatefulWidget {
  const ConceptoDialog({super.key});

  @override
  State<ConceptoDialog> createState() => _ConceptoDialogState();
}

class _ConceptoDialogState extends State<ConceptoDialog> {
  final _descripcionCtrl = TextEditingController();
  final _valorCtrl = TextEditingController();

  TipoConcepto _tipo = TipoConcepto.remunerativo;
  ModoConcepto _modo = ModoConcepto.fijo;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nuevo concepto'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _descripcionCtrl,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                labelText: 'Descripción',
                labelStyle: const TextStyle(color: AppColors.textMuted),
                filled: true,
                fillColor: AppColors.glassFillStrong,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.glassBorder),
                ),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<TipoConcepto>(
              initialValue: _tipo,
              decoration: InputDecoration(
                labelText: 'Tipo',
                labelStyle: const TextStyle(color: AppColors.textMuted),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                filled: true,
                fillColor: AppColors.glassFillStrong,
              ),
              dropdownColor: AppColors.backgroundLight,
              items: const [
                DropdownMenuItem(
                  value: TipoConcepto.remunerativo,
                  child: Text('Remunerativo'),
                ),
                DropdownMenuItem(
                  value: TipoConcepto.noRemunerativo,
                  child: Text('No remunerativo'),
                ),
                DropdownMenuItem(
                  value: TipoConcepto.descuento,
                  child: Text('Descuento'),
                ),
              ],
              onChanged: (v) => setState(() => _tipo = v!),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<ModoConcepto>(
              initialValue: _modo,
              decoration: InputDecoration(
                labelText: 'Modo',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                filled: true,
                fillColor: AppColors.glassFillStrong,
              ),
              dropdownColor: AppColors.backgroundLight,
              items: const [
                DropdownMenuItem(
                  value: ModoConcepto.fijo,
                  child: Text('Monto fijo'),
                ),
                DropdownMenuItem(
                  value: ModoConcepto.porcentaje,
                  child: Text('Porcentaje'),
                ),
              ],
              onChanged: (v) => setState(() => _modo = v!),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _valorCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                labelText:
                    _modo == ModoConcepto.fijo ? 'Monto' : 'Porcentaje',
                labelStyle: const TextStyle(color: AppColors.textMuted),
                filled: true,
                fillColor: AppColors.glassFillStrong,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.glassBorder),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _guardar,
          child: const Text('Agregar'),
        ),
      ],
    );
  }

  void _guardar() {
    if (_descripcionCtrl.text.isEmpty || _valorCtrl.text.isEmpty) return;

    final concepto = Concepto(
      descripcion: _descripcionCtrl.text,
      tipo: _tipo,
      modo: _modo,
      valor: double.tryParse(_valorCtrl.text.replaceAll(',', '.')) ?? 0,
    );

    Navigator.pop(context, concepto);
  }
}
