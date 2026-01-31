import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/convenio.dart';
import '../utils/formatters.dart';


class ConvenioFormScreen extends StatefulWidget {
  final Convenio? convenio;

  const ConvenioFormScreen({super.key, this.convenio});

  @override
  State<ConvenioFormScreen> createState() =>
      _ConvenioFormScreenState();
}

class _ConvenioFormScreenState
    extends State<ConvenioFormScreen> {
  final nombreCtrl = TextEditingController();
  final adicionalCtrl = TextEditingController();
  final antiguedadCtrl = TextEditingController();
  final descuentosCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();

    if (widget.convenio != null) {
      nombreCtrl.text = widget.convenio!.nombre;
      adicionalCtrl.text = AppNumberFormatter.format(widget.convenio!.adicional * 100, valorIndice: false);
      antiguedadCtrl.text = AppNumberFormatter.format(widget.convenio!.antiguedad * 100, valorIndice: false);
      descuentosCtrl.text = AppNumberFormatter.format(widget.convenio!.descuentos * 100, valorIndice: false);
    }
  }

  void guardar() {
    final convenio = Convenio(
      nombre: nombreCtrl.text,
      adicional: (double.tryParse(adicionalCtrl.text.replaceAll(',', '.')) ?? 0) / 100,
      antiguedad: (double.tryParse(antiguedadCtrl.text.replaceAll(',', '.')) ?? 0) / 100,
      descuentos: (double.tryParse(descuentosCtrl.text.replaceAll(',', '.')) ?? 0) / 100,
    );

    Navigator.pop(context, convenio);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.convenio == null
              ? 'Nuevo convenio'
              : 'Editar convenio',
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _input(nombreCtrl, 'Nombre del convenio'),
            _input(
              adicionalCtrl,
              'Adicional (%)',
              keyboard: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [AppNumberFormatter.inputFormatter(valorIndice: false)],
            ),
            _input(
              antiguedadCtrl,
              'Antigüedad por año (%)',
              keyboard: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [AppNumberFormatter.inputFormatter(valorIndice: false)],
            ),
            _input(
              descuentosCtrl,
              'Descuentos (%)',
              keyboard: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [AppNumberFormatter.inputFormatter(valorIndice: false)],
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: guardar,
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _input(
    TextEditingController controller,
    String label, {
    TextInputType keyboard = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: keyboard,
        inputFormatters: inputFormatters,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}
