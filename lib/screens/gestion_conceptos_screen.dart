
// =======================================================================
// PANTALLA DE ASIGNACIÓN MASIVA DE CONCEPTOS (v2.0)
// Permite asignar un concepto a múltiples empleados de forma simultánea.
// =======================================================================

import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:intl/intl.dart';
import '../models/empleado_completo.dart';
import '../models/concepto_recurrente.dart';
import '../services/empleados_service.dart';
import '../services/conceptos_recurrentes_service.dart';
import '../theme/app_colors.dart';
import '../widgets/glass_card.dart';
import '../data/plantillas_conceptos.dart';

class GestionConceptosScreen extends StatefulWidget {
  final String empresaCuit;

  const GestionConceptosScreen({
    super.key,
    required this.empresaCuit,
  });

  @override
  State<GestionConceptosScreen> createState() => _GestionConceptosScreenState();
}

class _GestionConceptosScreenState extends State<GestionConceptosScreen> {
  // Estado de la UI
  bool _cargando = true;
  String _error = '';

  // Datos
  List<EmpleadoCompleto> _empleados = [];
  Map<String, ConceptoRecurrente> _plantillas = {};

  // Estado de la Selección
  String? _plantillaSeleccionadaId;
  final Set<String> _empleadosSeleccionados = {}; // Set de CUILs

  // Controladores para los detalles del concepto
  final _valorController = TextEditingController();
  final _desdeController = TextEditingController();
  final _hastaController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cargarDatosIniciales();
    _plantillas = { for (var p in PlantillasConceptos.comunes) p['codigo'] as String: ConceptoRecurrente.fromMap(p) };
  }
  
  @override
  void dispose() {
    _valorController.dispose();
    _desdeController.dispose();
    _hastaController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatosIniciales() async {
    setState(() {
      _cargando = true;
      _error = '';
    });

    try {
      // Cargar empleados activos de la empresa
      _empleados = await EmpleadosService.obtenerEmpleadosActivos(empresaCuit: widget.empresaCuit);
    } catch (e) {
      setState(() {
        _error = 'Error cargando empleados: $e';
      });
    } finally {
      setState(() {
        _cargando = false;
      });
    }
  }

  void _onSeleccionarPlantilla(String? plantillaId) {
    if (plantillaId == null) return;
    setState(() {
      _plantillaSeleccionadaId = plantillaId;
      final plantilla = _plantillas[plantillaId];
      if (plantilla != null) {
        _valorController.text = plantilla.valor.toString();
        _desdeController.text = DateFormat('dd/MM/yyyy').format(DateTime.now());
        _hastaController.text = ''; // Por defecto, sin fecha de fin
      }
    });
  }

  void _toggleEmpleado(String cuil) {
    setState(() {
      if (_empleadosSeleccionados.contains(cuil)) {
        _empleadosSeleccionados.remove(cuil);
      } else {
        _empleadosSeleccionados.add(cuil);
      }
    });
  }
  
  void _toggleSeleccionarTodos() {
    setState(() {
      if (_empleadosSeleccionados.length == _empleados.length) {
        _empleadosSeleccionados.clear();
      } else {
        _empleadosSeleccionados.addAll(_empleados.map((e) => e.cuil));
      }
    });
  }

  Future<void> _guardarAsignacionMasiva() async {
    if (_plantillaSeleccionadaId == null || _empleadosSeleccionados.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, selecciona un concepto y al menos un empleado.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final plantilla = _plantillas[_plantillaSeleccionadaId!]!;
    final valor = double.tryParse(_valorController.text);
    if (valor == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El valor ingresado no es válido.'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _cargando = true);
    
    try {
      final formatoFecha = DateFormat('dd/MM/yyyy');
      final activoDesde = formatoFecha.parse(_desdeController.text);
      final activoHasta = _hastaController.text.isNotEmpty ? formatoFecha.parse(_hastaController.text) : null;
      
      final List<ConceptoRecurrente> nuevosConceptos = [];

      for (final cuil in _empleadosSeleccionados) {
        final nuevoConcepto = ConceptoRecurrente(
          id: '', // Será generado por el servicio
          empleadoCuil: cuil,
          empresaCuit: widget.empresaCuit,
          codigo: plantilla.codigo,
          nombre: plantilla.nombre,
          descripcion: plantilla.descripcion,
          tipo: plantilla.tipo,
          categoria: plantilla.categoria,
          subcategoria: plantilla.subcategoria,
          valor: valor,
          activoDesde: activoDesde,
          activoHasta: activoHasta,
        );
        nuevosConceptos.add(nuevoConcepto);
      }

      await ConceptosRecurrentesService.guardarConceptosMasivamente(
        conceptos: nuevosConceptos,
        empresaCuit: widget.empresaCuit,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Se asignó el concepto a ${_empleadosSeleccionados.length} empleados con éxito.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true); // Indicar que se guardó
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _cargando = false);
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Asignación Masiva de Conceptos'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _cargando && _empleados.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
              ? Center(child: Text(_error, style: const TextStyle(color: Colors.red)))
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    _buildPaso1_SeleccionarConcepto(),
                    if (_plantillaSeleccionadaId != null) ...[
                      const SizedBox(height: 24),
                      _buildPaso2_ConfigurarDetalles(),
                      const SizedBox(height: 24),
                      _buildPaso3_SeleccionarEmpleados(),
                    ],
                  ],
                ),
      floatingActionButton: _plantillaSeleccionadaId != null && !_cargando
          ? FloatingActionButton.extended(
              onPressed: _guardarAsignacionMasiva,
              icon: const Icon(Icons.save),
              label: Text('Asignar a ${_empleadosSeleccionados.length} empleados'),
              backgroundColor: AppColors.primary,
            )
          : null,
    );
  }

  Widget _buildPaso1_SeleccionarConcepto() {
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Paso 1: Elige un concepto para asignar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _plantillaSeleccionadaId,
              onChanged: _onSeleccionarPlantilla,
              items: _plantillas.values.map((plantilla) {
                return DropdownMenuItem<String>(
                  value: plantilla.codigo,
                  child: Text(plantilla.nombre),
                );
              }).toList(),
              decoration: const InputDecoration(
                labelText: 'Concepto',
                border: OutlineInputBorder(),
                filled: true,
                fillColor: AppColors.backgroundLight,
              ),
              isExpanded: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaso2_ConfigurarDetalles() {
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             const Text('Paso 2: Define los detalles', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: 16),
            TextField(
              controller: _valorController,
              decoration: const InputDecoration(labelText: 'Valor/Monto', border: OutlineInputBorder(), prefixText: '\$ '),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildDateField(_desdeController, 'Vigente Desde')),
                const SizedBox(width: 16),
                Expanded(child: _buildDateField(_hastaController, 'Vigente Hasta (Opcional)')),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildDateField(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      readOnly: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        suffixIcon: const Icon(Icons.calendar_today),
      ),
      onTap: () async {
        final now = DateTime.now();
        final pickedDate = await showDatePicker(
          context: context,
          initialDate: now,
          firstDate: DateTime(now.year - 5),
          lastDate: DateTime(now.year + 20),
        );
        if (pickedDate != null) {
          controller.text = DateFormat('dd/MM/yyyy').format(pickedDate);
        }
      },
    );
  }

  Widget _buildPaso3_SeleccionarEmpleados() {
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Paso 3: Elige los empleados', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                ActionChip(
                  avatar: Icon(_empleadosSeleccionados.length == _empleados.length ? Icons.check_box : Icons.check_box_outline_blank),
                  label: Text(_empleadosSeleccionados.length == _empleados.length ? 'Deseleccionar Todos' : 'Seleccionar Todos'),
                  onPressed: _toggleSeleccionarTodos,
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Divider(),
            _empleados.isEmpty
                ? const Text('No hay empleados activos en esta empresa.')
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _empleados.length,
                    itemBuilder: (context, index) {
                      final empleado = _empleados[index];
                      return CheckboxListTile(
                        title: Text(empleado.nombreCompleto),
                        subtitle: Text('CUIL: ${empleado.cuil}'),
                        value: _empleadosSeleccionados.contains(empleado.cuil),
                        onChanged: (bool? value) {
                          _toggleEmpleado(empleado.cuil);
                        },
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }
}
