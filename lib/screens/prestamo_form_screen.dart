// ========================================================================
// FORMULARIO DE PRÉSTAMO
// Crear préstamos con cálculo automático de cuotas
// ========================================================================

import 'package:flutter/material.dart';
import '../models/prestamo.dart';
import '../services/prestamos_service.dart';
import '../theme/app_colors.dart';

class PrestamoFormScreen extends StatefulWidget {
  final List<String> empleadosFiltro;
  final String empresaCuit;
  
  const PrestamoFormScreen({
    super.key,
    required this.empleadosFiltro,
    required this.empresaCuit,
  });
  
  @override
  State<PrestamoFormScreen> createState() => _PrestamoFormScreenState();
}

class _PrestamoFormScreenState extends State<PrestamoFormScreen> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _montoController;
  late TextEditingController _cuotasController;
  late TextEditingController _tasaController;
  late TextEditingController _motivoController;
  
  String? _empleadoSeleccionado;
  DateTime _fechaOtorgamiento = DateTime.now();
  DateTime _fechaPrimeraCuota = DateTime.now();
  double _valorCuotaCalculado = 0.0;
  bool _guardando = false;
  
  @override
  void initState() {
    super.initState();
    
    _montoController = TextEditingController();
    _cuotasController = TextEditingController(text: '12');
    _tasaController = TextEditingController(text: '0');
    _motivoController = TextEditingController();
    
    if (widget.empleadosFiltro.length == 1) {
      _empleadoSeleccionado = widget.empleadosFiltro.first;
    }
    
    _montoController.addListener(_recalcularCuota);
    _cuotasController.addListener(_recalcularCuota);
    _tasaController.addListener(_recalcularCuota);
  }
  
  void _recalcularCuota() {
    final monto = double.tryParse(_montoController.text) ?? 0.0;
    final cuotas = int.tryParse(_cuotasController.text) ?? 1;
    final tasa = double.tryParse(_tasaController.text) ?? 0.0;
    
    setState(() {
      _valorCuotaCalculado = Prestamo.calcularCuota(
        montoTotal: monto,
        tasaInteres: tasa,
        cantidadCuotas: cuotas,
      );
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nuevo Préstamo'),
        backgroundColor: AppColors.primary,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Empleado
            DropdownButtonFormField<String>(
              value: _empleadoSeleccionado,
              decoration: const InputDecoration(
                labelText: 'Empleado *',
                border: OutlineInputBorder(),
              ),
              items: widget.empleadosFiltro.map((cuil) {
                return DropdownMenuItem(value: cuil, child: Text(cuil));
              }).toList(),
              onChanged: (v) => setState(() => _empleadoSeleccionado = v),
              validator: (v) => v == null ? 'Requerido' : null,
            ),
            
            const SizedBox(height: 16),
            
            // Monto
            TextFormField(
              controller: _montoController,
              decoration: const InputDecoration(
                labelText: 'Monto del Préstamo *',
                border: OutlineInputBorder(),
                prefixText: '\$',
              ),
              keyboardType: TextInputType.number,
              validator: (v) {
                if (v == null || v.isEmpty) return 'Requerido';
                final num = double.tryParse(v);
                if (num == null || num <= 0) return 'Debe ser mayor a 0';
                return null;
              },
            ),
            
            const SizedBox(height: 16),
            
            // Cantidad de cuotas
            TextFormField(
              controller: _cuotasController,
              decoration: const InputDecoration(
                labelText: 'Cantidad de Cuotas *',
                border: OutlineInputBorder(),
                helperText: 'Ej: 12 cuotas = 1 año',
              ),
              keyboardType: TextInputType.number,
              validator: (v) {
                if (v == null || v.isEmpty) return 'Requerido';
                final num = int.tryParse(v);
                if (num == null || num <= 0) return 'Debe ser mayor a 0';
                return null;
              },
            ),
            
            const SizedBox(height: 16),
            
            // Tasa de interés
            TextFormField(
              controller: _tasaController,
              decoration: const InputDecoration(
                labelText: 'Tasa de Interés Anual',
                border: OutlineInputBorder(),
                suffixText: '%',
                helperText: '0% = sin interés',
              ),
              keyboardType: TextInputType.number,
              validator: (v) {
                if (v == null || v.isEmpty) return null;
                final num = double.tryParse(v);
                if (num == null || num < 0) return 'Debe ser mayor o igual a 0';
                return null;
              },
            ),
            
            const SizedBox(height: 24),
            
            // Cálculo de cuota
            Card(
              color: Colors.blue[50],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text(
                      'Valor de cada cuota:',
                      style: TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '\$${_valorCuotaCalculado.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Fechas
            ListTile(
              title: const Text('Fecha de otorgamiento'),
              subtitle: Text('${_fechaOtorgamiento.day}/${_fechaOtorgamiento.month}/${_fechaOtorgamiento.year}'),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final fecha = await showDatePicker(
                  context: context,
                  initialDate: _fechaOtorgamiento,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                );
                if (fecha != null) {
                  setState(() => _fechaOtorgamiento = fecha);
                }
              },
            ),
            
            ListTile(
              title: const Text('Fecha de primera cuota'),
              subtitle: Text('${_fechaPrimeraCuota.day}/${_fechaPrimeraCuota.month}/${_fechaPrimeraCuota.year}'),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final fecha = await showDatePicker(
                  context: context,
                  initialDate: _fechaPrimeraCuota,
                  firstDate: _fechaOtorgamiento,
                  lastDate: DateTime(2030),
                );
                if (fecha != null) {
                  setState(() => _fechaPrimeraCuota = fecha);
                }
              },
            ),
            
            const SizedBox(height: 16),
            
            // Motivo
            TextFormField(
              controller: _motivoController,
              decoration: const InputDecoration(
                labelText: 'Motivo del Préstamo',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            
            const SizedBox(height: 32),
            
            // Botón guardar
            SizedBox(
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _guardando ? null : _guardar,
                icon: _guardando 
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.save),
                label: Text(_guardando ? 'Creando...' : 'Crear Préstamo'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate() || _empleadoSeleccionado == null) {
      _mostrarError('Completa todos los campos requeridos');
      return;
    }
    
    setState(() => _guardando = true);
    
    try {
      await PrestamosService.crearPrestamo(
        empleadoCuil: _empleadoSeleccionado!,
        empresaCuit: widget.empresaCuit,
        montoTotal: double.parse(_montoController.text),
        cantidadCuotas: int.parse(_cuotasController.text),
        tasaInteres: double.tryParse(_tasaController.text) ?? 0.0,
        fechaOtorgamiento: _fechaOtorgamiento,
        fechaPrimeraCuota: _fechaPrimeraCuota,
        motivoPrestamo: _motivoController.text.trim().isEmpty ? null : _motivoController.text.trim(),
        creadoPor: 'Usuario',
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Préstamo creado exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
        
        Navigator.pop(context, true);
      }
    } catch (e) {
      _mostrarError('Error creando préstamo: $e');
    }
    
    setState(() => _guardando = false);
  }
  
  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), backgroundColor: Colors.red),
    );
  }
  
  @override
  void dispose() {
    _montoController.dispose();
    _cuotasController.dispose();
    _tasaController.dispose();
    _motivoController.dispose();
    super.dispose();
  }
}
