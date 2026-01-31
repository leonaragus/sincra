// ========================================================================
// FORMULARIO DE CONCEPTO RECURRENTE
// Crear/editar conceptos con plantillas predefinidas
// ========================================================================

import 'package:flutter/material.dart';
import '../models/concepto_recurrente.dart';
import '../services/conceptos_recurrentes_service.dart';
import '../theme/app_colors.dart';

class ConceptoFormScreen extends StatefulWidget {
  final ConceptoRecurrente? conceptoAEditar;
  final List<String> empleadosFiltro; // Lista de CUILs disponibles
  
  const ConceptoFormScreen({
    super.key,
    this.conceptoAEditar,
    required this.empleadosFiltro,
  });
  
  @override
  State<ConceptoFormScreen> createState() => _ConceptoFormScreenState();
}

class _ConceptoFormScreenState extends State<ConceptoFormScreen> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _codigoController;
  late TextEditingController _nombreController;
  late TextEditingController _valorController;
  late TextEditingController _montoEmbargoController;
  
  String? _empleadoSeleccionado;
  String _tipoSeleccionado = 'fijo';
  String _categoriaSeleccionada = 'remunerativo';
  DateTime _activoDesde = DateTime.now();
  DateTime? _activoHasta;
  bool _activo = true;
  
  bool _esEmbargo = false;
  bool _guardando = false;
  
  @override
  void initState() {
    super.initState();
    
    if (widget.conceptoAEditar != null) {
      final c = widget.conceptoAEditar!;
      _codigoController = TextEditingController(text: c.codigo);
      _nombreController = TextEditingController(text: c.nombre);
      _valorController = TextEditingController(text: c.valor.toString());
      _montoEmbargoController = TextEditingController(
        text: c.montoTotalEmbargo?.toString() ?? '',
      );
      
      _empleadoSeleccionado = c.empleadoCuil;
      _tipoSeleccionado = c.tipo;
      _categoriaSeleccionada = c.categoria;
      _activoDesde = c.activoDesde;
      _activoHasta = c.activoHasta;
      _activo = c.activo;
      _esEmbargo = c.tipo == 'embargo_judicial';
    } else {
      _codigoController = TextEditingController();
      _nombreController = TextEditingController();
      _valorController = TextEditingController();
      _montoEmbargoController = TextEditingController();
      
      if (widget.empleadosFiltro.length == 1) {
        _empleadoSeleccionado = widget.empleadosFiltro.first;
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.conceptoAEditar != null 
            ? 'Editar Concepto' 
            : 'Nuevo Concepto'),
        backgroundColor: AppColors.primary,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Botón de plantillas
            if (widget.conceptoAEditar == null) _buildBotonPlantillas(),
            
            const SizedBox(height: 16),
            
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
            
            // Código
            TextFormField(
              controller: _codigoController,
              decoration: const InputDecoration(
                labelText: 'Código *',
                border: OutlineInputBorder(),
                helperText: 'Ej: VALE_COMIDA, SINDICATO, etc.',
              ),
              validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
            ),
            
            const SizedBox(height: 16),
            
            // Nombre
            TextFormField(
              controller: _nombreController,
              decoration: const InputDecoration(
                labelText: 'Nombre *',
                border: OutlineInputBorder(),
              ),
              validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
            ),
            
            const SizedBox(height: 16),
            
            // Tipo
            DropdownButtonFormField<String>(
              value: _tipoSeleccionado,
              decoration: const InputDecoration(
                labelText: 'Tipo *',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'fijo', child: Text('Monto Fijo')),
                DropdownMenuItem(value: 'porcentaje', child: Text('Porcentaje')),
                DropdownMenuItem(value: 'embargo_judicial', child: Text('Embargo Judicial')),
                DropdownMenuItem(value: 'formula', child: Text('Fórmula Personalizada')),
              ],
              onChanged: (v) {
                setState(() {
                  _tipoSeleccionado = v!;
                  _esEmbargo = v == 'embargo_judicial';
                });
              },
            ),
            
            const SizedBox(height: 16),
            
            // Categoría
            DropdownButtonFormField<String>(
              value: _categoriaSeleccionada,
              decoration: const InputDecoration(
                labelText: 'Categoría *',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'remunerativo', child: Text('Remunerativo')),
                DropdownMenuItem(value: 'no_remunerativo', child: Text('No Remunerativo')),
                DropdownMenuItem(value: 'descuento', child: Text('Descuento')),
              ],
              onChanged: (v) => setState(() => _categoriaSeleccionada = v!),
            ),
            
            const SizedBox(height: 16),
            
            // Valor
            TextFormField(
              controller: _valorController,
              decoration: InputDecoration(
                labelText: _tipoSeleccionado == 'porcentaje' ? 'Porcentaje *' : 'Valor *',
                border: const OutlineInputBorder(),
                prefixText: _tipoSeleccionado == 'porcentaje' ? '' : '\$',
                suffixText: _tipoSeleccionado == 'porcentaje' ? '%' : '',
              ),
              keyboardType: TextInputType.number,
              validator: (v) {
                if (v == null || v.isEmpty) return 'Requerido';
                if (double.tryParse(v) == null) return 'Número inválido';
                return null;
              },
            ),
            
            // Si es embargo, campo adicional
            if (_esEmbargo) ...[
              const SizedBox(height: 16),
              TextFormField(
                controller: _montoEmbargoController,
                decoration: const InputDecoration(
                  labelText: 'Monto Total del Embargo *',
                  border: OutlineInputBorder(),
                  prefixText: '\$',
                  helperText: 'Monto total a descontar (se desactiva al completar)',
                ),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Requerido para embargos';
                  if (double.tryParse(v) == null) return 'Número inválido';
                  return null;
                },
              ),
            ],
            
            const SizedBox(height: 16),
            
            // Fechas
            const Divider(),
            const Text('Vigencia:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            
            ListTile(
              title: const Text('Activo desde'),
              subtitle: Text('${_activoDesde.day}/${_activoDesde.month}/${_activoDesde.year}'),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final fecha = await showDatePicker(
                  context: context,
                  initialDate: _activoDesde,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                );
                if (fecha != null) {
                  setState(() => _activoDesde = fecha);
                }
              },
            ),
            
            ListTile(
              title: const Text('Activo hasta (opcional)'),
              subtitle: Text(_activoHasta != null 
                  ? '${_activoHasta!.day}/${_activoHasta!.month}/${_activoHasta!.year}' 
                  : 'Sin límite'),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final fecha = await showDatePicker(
                  context: context,
                  initialDate: _activoHasta ?? DateTime.now(),
                  firstDate: _activoDesde,
                  lastDate: DateTime(2030),
                );
                setState(() => _activoHasta = fecha);
              },
            ),
            
            SwitchListTile(
              title: const Text('Concepto activo'),
              value: _activo,
              onChanged: (v) => setState(() => _activo = v),
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
                label: Text(_guardando ? 'Guardando...' : 'Guardar Concepto'),
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
  
  Widget _buildBotonPlantillas() {
    return Card(
      color: Colors.blue[50],
      child: ExpansionTile(
        leading: const Icon(Icons.library_books, color: Colors.blue),
        title: const Text('Usar Plantilla Predefinida'),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildChipPlantilla('VALE_COMIDA', 'Vale Comida'),
              _buildChipPlantilla('SINDICATO', 'Cuota Sindical'),
              _buildChipPlantilla('OBRA_SOCIAL_ADICIONAL', 'Obra Social Adicional'),
              _buildChipPlantilla('EMBARGO', 'Embargo Judicial'),
              _buildChipPlantilla('PRESTAMO', 'Préstamo Personal'),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
  
  Widget _buildChipPlantilla(String codigo, String nombre) {
    return ActionChip(
      label: Text(nombre),
      onPressed: () => _aplicarPlantilla(codigo),
    );
  }
  
  void _aplicarPlantilla(String codigoPlantilla) {
    if (_empleadoSeleccionado == null) {
      _mostrarError('Primero selecciona un empleado');
      return;
    }
    
    final concepto = ConceptosRecurrentesService.crearDesdePlantilla(
      _empleadoSeleccionado!,
      codigoPlantilla,
    );
    
    setState(() {
      _codigoController.text = concepto.codigo;
      _nombreController.text = concepto.nombre;
      _valorController.text = concepto.valor.toString();
      _tipoSeleccionado = concepto.tipo;
      _categoriaSeleccionada = concepto.categoria;
      _esEmbargo = concepto.tipo == 'embargo_judicial';
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Plantilla aplicada. Ajusta el valor si es necesario.'),
        backgroundColor: Colors.blue,
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
      final concepto = ConceptoRecurrente(
        id: widget.conceptoAEditar?.id ?? 
            'concepto_${DateTime.now().millisecondsSinceEpoch}',
        empleadoCuil: _empleadoSeleccionado!,
        codigo: _codigoController.text.trim(),
        nombre: _nombreController.text.trim(),
        tipo: _tipoSeleccionado,
        valor: double.parse(_valorController.text),
        categoria: _categoriaSeleccionada,
        activoDesde: _activoDesde,
        activoHasta: _activoHasta,
        activo: _activo,
        montoTotalEmbargo: _esEmbargo && _montoEmbargoController.text.isNotEmpty
            ? double.parse(_montoEmbargoController.text)
            : null,
        montoAcumuladoDescontado: widget.conceptoAEditar?.montoAcumuladoDescontado ?? 0.0,
      );
      
      if (widget.conceptoAEditar != null) {
        await ConceptosRecurrentesService.actualizarConcepto(concepto);
      } else {
        await ConceptosRecurrentesService.agregarConcepto(concepto);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Concepto guardado exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
        
        Navigator.pop(context, true);
      }
    } catch (e) {
      _mostrarError('Error guardando concepto: $e');
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
    _codigoController.dispose();
    _nombreController.dispose();
    _valorController.dispose();
    _montoEmbargoController.dispose();
    super.dispose();
  }
}
