
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/cct_completo.dart';
import '../theme/app_colors.dart';

// =======================================================================
// DIÁLOGO DE EDICIÓN DE CONVENIOS
// Formulario para crear o editar un CCTCompleto. Ya no es un simple 
// visualizador, sino un componente de edición activo.
// =======================================================================

class CCTDetailDialog extends StatefulWidget {
  final CCTCompleto convenio;
  final Function(CCTCompleto) onUpdate;
  final bool esNuevo;

  const CCTDetailDialog({
    super.key,
    required this.convenio,
    required this.onUpdate,
    this.esNuevo = false,
  });

  @override
  State<CCTDetailDialog> createState() => _CCTDetailDialogState();
}

class _CCTDetailDialogState extends State<CCTDetailDialog> {
  final _formKey = GlobalKey<FormState>();
  late CCTCompleto _convenioEditable;

  // Controladores para los campos del formulario
  late final TextEditingController _nombreController;
  late final TextEditingController _numeroController;
  late final TextEditingController _descripcionController;
  late final TextEditingController _actividadController;
  late final TextEditingController _presentismoController;
  late final TextEditingController _antiguedadController;
  late final TextEditingController _divisorHorasController;

  @override
  void initState() {
    super.initState();
    _convenioEditable = widget.convenio;

    // Inicializar controladores con los valores del convenio
    _nombreController = TextEditingController(text: _convenioEditable.nombre);
    _numeroController = TextEditingController(text: _convenioEditable.numeroCCT);
    _descripcionController = TextEditingController(text: _convenioEditable.descripcion);
    _actividadController = TextEditingController(text: _convenioEditable.actividad);
    _presentismoController = TextEditingController(text: _convenioEditable.adicionalPresentismo.toString());
    _antiguedadController = TextEditingController(text: _convenioEditable.porcentajeAntiguedadAnual.toString());
    _divisorHorasController = TextEditingController(text: _convenioEditable.horasMensualesDivisor.toString());
  }

  @override
  void dispose() {
    // Limpiar todos los controladores
    _nombreController.dispose();
    _numeroController.dispose();
    _descripcionController.dispose();
    _actividadController.dispose();
    _presentismoController.dispose();
    _antiguedadController.dispose();
    _divisorHorasController.dispose();
    super.dispose();
  }

  void _onSaveChanges() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      final updatedConvenio = _convenioEditable.copyWith(
        nombre: _nombreController.text,
        numeroCCT: _numeroController.text,
        descripcion: _descripcionController.text,
        actividad: _actividadController.text,
        adicionalPresentismo: double.tryParse(_presentismoController.text) ?? 0.0,
        porcentajeAntiguedadAnual: double.tryParse(_antiguedadController.text) ?? 1.0,
        horasMensualesDivisor: double.tryParse(_divisorHorasController.text) ?? 200.0,
        esPersonalizado: true, // Siempre es personalizado si se edita
      );
      
      // Devolver el objeto actualizado a la pantalla anterior
      widget.onUpdate(updatedConvenio);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Form(
        key: _formKey,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 800),
          decoration: BoxDecoration(
            color: AppColors.backgroundCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(),
              _buildFormContent(),
              _buildActions(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.only(topLeft: Radius.circular(19), topRight: Radius.circular(19)),
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Icon(widget.esNuevo ? Icons.add_circle_outline : Icons.edit_note, color: AppColors.primary, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.esNuevo ? 'Nuevo Convenio Personalizado' : 'Editar Convenio',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: AppColors.textSecondary),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildFormContent() {
    return Flexible(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTextField(_nombreController, 'Nombre del Convenio'),
            const SizedBox(height: 16),
            _buildTextField(_numeroController, 'Número de CCT', keyboardType: TextInputType.text),
            const SizedBox(height: 16),
            _buildTextField(_descripcionController, 'Descripción', maxLines: 3),
            const SizedBox(height: 16),
            _buildTextField(_actividadController, 'Actividad Principal'),
            const SizedBox(height: 24),
            const Text('Parámetros de Liquidación', style: TextStyle(color: AppColors.primary, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildTextField(_presentismoController, 'Presentismo (%)', keyboardType: TextInputType.number)),
                const SizedBox(width: 16),
                Expanded(child: _buildTextField(_antiguedadController, 'Antigüedad (% Anual)', keyboardType: TextInputType.number)),
              ],
            ),
            const SizedBox(height: 16),
            _buildTextField(_divisorHorasController, 'Divisor Horas Mensuales', keyboardType: TextInputType.number),
            const SizedBox(height: 16),
            const Divider(color: AppColors.border),
            const SizedBox(height: 16),
            Text(
              'La gestión de Categorías, Zonas y Descuentos estará disponible en una futura actualización.',
              style: TextStyle(color: AppColors.textMuted, fontStyle: FontStyle.italic, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, {int maxLines = 1, TextInputType keyboardType = TextInputType.text}) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        filled: true,
        fillColor: AppColors.background,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Este campo no puede estar vacío.';
        }
        if (keyboardType == TextInputType.number && double.tryParse(value) == null) {
          return 'Debe ser un número válido.';
        }
        return null;
      },
    );
  }

  Widget _buildActions() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(19), bottomRight: Radius.circular(19)),
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar', style: TextStyle(color: AppColors.textSecondary)),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: _onSaveChanges,
            icon: const Icon(Icons.save_alt, size: 18),
            label: const Text('Guardar Cambios'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}
