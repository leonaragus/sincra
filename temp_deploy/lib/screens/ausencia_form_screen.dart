// ========================================================================
// FORMULARIO DE AUSENCIA
// Registrar ausencias, licencias, suspensiones
// ========================================================================

import 'package:flutter/material.dart';
import '../models/ausencia.dart';
import '../services/ausencias_service.dart';
import '../theme/app_colors.dart';

class AusenciaFormScreen extends StatefulWidget {
  final Ausencia? ausenciaAEditar;
  final List<String> empleadosFiltro;
  final String empresaCuit;
  
  const AusenciaFormScreen({
    super.key,
    this.ausenciaAEditar,
    required this.empleadosFiltro,
    required this.empresaCuit,
  });
  
  @override
  State<AusenciaFormScreen> createState() => _AusenciaFormScreenState();
}

class _AusenciaFormScreenState extends State<AusenciaFormScreen> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _motivoController;
  late TextEditingController _numeroCertificadoController;
  late TextEditingController _porcentajeGoceController;
  
  String? _empleadoSeleccionado;
  TipoAusencia _tipoSeleccionado = TipoAusencia.enfermedad;
  DateTime _fechaDesde = DateTime.now();
  DateTime _fechaHasta = DateTime.now();
  bool _conGoce = true;
  bool _guardando = false;
  
  @override
  void initState() {
    super.initState();
    
    if (widget.ausenciaAEditar != null) {
      final a = widget.ausenciaAEditar!;
      _motivoController = TextEditingController(text: a.motivo ?? '');
      _numeroCertificadoController = TextEditingController(text: a.numeroCertificado ?? '');
      _porcentajeGoceController = TextEditingController(text: a.porcentajeGoce.toString());
      
      _empleadoSeleccionado = a.empleadoCuil;
      _tipoSeleccionado = a.tipo;
      _fechaDesde = a.fechaDesde;
      _fechaHasta = a.fechaHasta;
      _conGoce = a.conGoce;
    } else {
      _motivoController = TextEditingController();
      _numeroCertificadoController = TextEditingController();
      _porcentajeGoceController = TextEditingController(text: '100');
      
      if (widget.empleadosFiltro.length == 1) {
        _empleadoSeleccionado = widget.empleadosFiltro.first;
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.ausenciaAEditar != null ? 'Editar Ausencia' : 'Nueva Ausencia'),
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
            
            // Tipo de ausencia
            DropdownButtonFormField<TipoAusencia>(
              value: _tipoSeleccionado,
              decoration: const InputDecoration(
                labelText: 'Tipo de Ausencia *',
                border: OutlineInputBorder(),
              ),
              items: TipoAusencia.values.map((tipo) {
                return DropdownMenuItem(
                  value: tipo,
                  child: Text(tipo.displayName),
                );
              }).toList(),
              onChanged: (v) => setState(() => _tipoSeleccionado = v!),
            ),
            
            const SizedBox(height: 16),
            
            // Fechas
            Row(
              children: [
                Expanded(
                  child: ListTile(
                    title: const Text('Desde *'),
                    subtitle: Text('${_fechaDesde.day}/${_fechaDesde.month}/${_fechaDesde.year}'),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final fecha = await showDatePicker(
                        context: context,
                        initialDate: _fechaDesde,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (fecha != null) {
                        setState(() => _fechaDesde = fecha);
                      }
                    },
                  ),
                ),
                Expanded(
                  child: ListTile(
                    title: const Text('Hasta *'),
                    subtitle: Text('${_fechaHasta.day}/${_fechaHasta.month}/${_fechaHasta.year}'),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final fecha = await showDatePicker(
                        context: context,
                        initialDate: _fechaHasta,
                        firstDate: _fechaDesde,
                        lastDate: DateTime(2030),
                      );
                      if (fecha != null) {
                        setState(() => _fechaHasta = fecha);
                      }
                    },
                  ),
                ),
              ],
            ),
            
            Card(
              color: Colors.blue[50],
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'Total: ${_fechaHasta.difference(_fechaDesde).inDays + 1} días',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Con/sin goce
            SwitchListTile(
              title: const Text('Con goce de sueldo'),
              value: _conGoce,
              onChanged: (v) => setState(() => _conGoce = v),
            ),
            
            if (_conGoce) ...[
              const SizedBox(height: 8),
              TextFormField(
                controller: _porcentajeGoceController,
                decoration: const InputDecoration(
                  labelText: 'Porcentaje de goce',
                  border: OutlineInputBorder(),
                  suffixText: '%',
                  helperText: '100% = sueldo completo, 50% = medio sueldo',
                ),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Requerido';
                  final num = double.tryParse(v);
                  if (num == null || num < 0 || num > 100) {
                    return 'Debe ser entre 0 y 100';
                  }
                  return null;
                },
              ),
            ],
            
            const SizedBox(height: 16),
            
            // Motivo
            TextFormField(
              controller: _motivoController,
              decoration: const InputDecoration(
                labelText: 'Motivo',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            
            const SizedBox(height: 16),
            
            // Certificado (si aplica)
            if (_tipoSeleccionado.requiereCertificado) ...[
              TextFormField(
                controller: _numeroCertificadoController,
                decoration: InputDecoration(
                  labelText: 'Número de Certificado ${_tipoSeleccionado.requiereCertificado ? '*' : ''}',
                  border: const OutlineInputBorder(),
                ),
                validator: _tipoSeleccionado.requiereCertificado
                    ? (v) => v == null || v.isEmpty ? 'Requerido' : null
                    : null,
              ),
              const SizedBox(height: 8),
              Card(
                color: Colors.amber[50],
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 20, color: Colors.orange),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Este tipo de ausencia requiere certificado médico',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            
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
                label: Text(_guardando ? 'Guardando...' : 'Guardar Ausencia'),
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
      final ausencia = Ausencia(
        id: widget.ausenciaAEditar?.id ?? 
            'ausencia_${DateTime.now().millisecondsSinceEpoch}',
        empleadoCuil: _empleadoSeleccionado!,
        empresaCuit: widget.empresaCuit,
        tipo: _tipoSeleccionado,
        fechaDesde: _fechaDesde,
        fechaHasta: _fechaHasta,
        conGoce: _conGoce,
        porcentajeGoce: _conGoce ? double.parse(_porcentajeGoceController.text) : 0.0,
        motivo: _motivoController.text.trim().isEmpty ? null : _motivoController.text.trim(),
        numeroCertificado: _numeroCertificadoController.text.trim().isEmpty 
            ? null 
            : _numeroCertificadoController.text.trim(),
        estado: EstadoAusencia.pendiente,
        creadoPor: 'Usuario', // Aquí puedes poner el usuario actual
      );
      
      await AusenciasService.guardarAusencia(ausencia);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ausencia guardada exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
        
        Navigator.pop(context, true);
      }
    } catch (e) {
      _mostrarError('Error guardando ausencia: $e');
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
    _motivoController.dispose();
    _numeroCertificadoController.dispose();
    _porcentajeGoceController.dispose();
    super.dispose();
  }
}
