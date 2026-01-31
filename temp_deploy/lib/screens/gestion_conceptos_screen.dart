// ========================================================================
// PANTALLA DE GESTIÓN DE CONCEPTOS RECURRENTES
// Ver, agregar, editar conceptos automáticos por empleado
// ========================================================================

import 'package:flutter/material.dart';
import '../models/concepto_recurrente.dart';
import '../models/empleado_completo.dart';
import '../services/conceptos_recurrentes_service.dart';
import '../services/empleados_service.dart';
import '../theme/app_colors.dart';
import 'concepto_form_screen.dart';

class GestionConceptosScreen extends StatefulWidget {
  final String? empresaCuit;
  final String? empleadoCuilFiltro; // Si viene de un empleado específico
  
  const GestionConceptosScreen({
    super.key,
    this.empresaCuit,
    this.empleadoCuilFiltro,
  });
  
  @override
  State<GestionConceptosScreen> createState() => _GestionConceptosScreenState();
}

class _GestionConceptosScreenState extends State<GestionConceptosScreen> {
  List<ConceptoRecurrente> _conceptos = [];
  List<EmpleadoCompleto> _empleados = [];
  bool _cargando = true;
  
  String? _filtroEmpleado;
  String _filtroCategoria = 'todos'; // todos, remunerativo, no_remunerativo, descuento
  bool _soloActivos = true;
  
  @override
  void initState() {
    super.initState();
    _filtroEmpleado = widget.empleadoCuilFiltro;
    _cargarDatos();
  }
  
  Future<void> _cargarDatos() async {
    setState(() => _cargando = true);
    
    try {
      // Cargar empleados
      _empleados = await EmpleadosService.obtenerEmpleadosActivos(
        empresaCuit: widget.empresaCuit,
      );
      
      // Cargar conceptos
      if (_filtroEmpleado != null) {
        _conceptos = await ConceptosRecurrentesService.obtenerConceptosPorEmpleado(
          _filtroEmpleado!,
        );
      } else {
        // Cargar todos los conceptos de todos los empleados
        _conceptos = [];
        for (final emp in _empleados) {
          final conceptos = await ConceptosRecurrentesService.obtenerConceptosPorEmpleado(emp.cuil);
          _conceptos.addAll(conceptos);
        }
      }
    } catch (e) {
      _mostrarError('Error cargando datos: $e');
    }
    
    setState(() => _cargando = false);
  }
  
  List<ConceptoRecurrente> get _conceptosFiltrados {
    var conceptos = _conceptos;
    
    if (_soloActivos) {
      final ahora = DateTime.now();
      conceptos = conceptos.where((c) => c.estaActivoEn(ahora.month, ahora.year)).toList();
    }
    
    if (_filtroCategoria != 'todos') {
      conceptos = conceptos.where((c) => c.categoria == _filtroCategoria).toList();
    }
    
    return conceptos;
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Conceptos Recurrentes'),
        backgroundColor: AppColors.primary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargarDatos,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildFiltros(),
                Expanded(child: _buildListaConceptos()),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _agregarConcepto,
        icon: const Icon(Icons.add),
        label: const Text('Nuevo Concepto'),
        backgroundColor: AppColors.primary,
      ),
    );
  }
  
  Widget _buildFiltros() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Filtros:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            
            // Filtro de empleado
            DropdownButtonFormField<String?>(
              value: _filtroEmpleado,
              decoration: const InputDecoration(
                labelText: 'Empleado',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('Todos los empleados')),
                ..._empleados.map((e) => DropdownMenuItem(
                  value: e.cuil,
                  child: Text('${e.nombreCompleto} (${e.cuil})'),
                )),
              ],
              onChanged: (v) {
                setState(() => _filtroEmpleado = v);
                _cargarDatos();
              },
            ),
            
            const SizedBox(height: 12),
            
            // Filtros de categoría y estado
            Row(
              children: [
                Expanded(
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'todos', label: Text('Todos')),
                      ButtonSegment(value: 'remunerativo', label: Text('Rem.')),
                      ButtonSegment(value: 'no_remunerativo', label: Text('No Rem.')),
                      ButtonSegment(value: 'descuento', label: Text('Desc.')),
                    ],
                    selected: {_filtroCategoria},
                    onSelectionChanged: (Set<String> selection) {
                      setState(() => _filtroCategoria = selection.first);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                FilterChip(
                  label: const Text('Solo activos'),
                  selected: _soloActivos,
                  onSelected: (v) => setState(() => _soloActivos = v),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildListaConceptos() {
    final conceptos = _conceptosFiltrados;
    
    if (conceptos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No hay conceptos recurrentes',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            const Text(
              'Agrega conceptos que se aplican automáticamente',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: conceptos.length,
      itemBuilder: (context, index) {
        final concepto = conceptos[index];
        final empleado = _empleados.firstWhere(
          (e) => e.cuil == concepto.empleadoCuil,
          orElse: () => EmpleadoCompleto(
            cuil: concepto.empleadoCuil,
            nombreCompleto: 'Empleado no encontrado',
            fechaIngreso: DateTime.now(),
            categoria: '',
            provincia: '',
          ),
        );
        
        return _buildConceptoCard(concepto, empleado);
      },
    );
  }
  
  Widget _buildConceptoCard(ConceptoRecurrente concepto, EmpleadoCompleto empleado) {
    final Color color = concepto.categoria == 'remunerativo'
        ? Colors.green
        : concepto.categoria == 'no_remunerativo'
            ? Colors.blue
            : Colors.red;
    
    final ahora = DateTime.now();
    final activo = concepto.estaActivoEn(ahora.month, ahora.year);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.2),
          child: Icon(
            concepto.categoria == 'descuento' ? Icons.remove_circle : Icons.add_circle,
            color: color,
          ),
        ),
        title: Text(
          concepto.nombre,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            decoration: activo ? null : TextDecoration.lineThrough,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Empleado: ${empleado.nombreCompleto}'),
            Text('Código: ${concepto.codigo} | Valor: \$${concepto.valor.toStringAsFixed(2)}'),
            if (concepto.tipo == 'embargo_judicial' && concepto.montoTotalEmbargo != null)
              Text(
                'Embargo: \$${concepto.montoAcumuladoDescontado.toStringAsFixed(0)} / \$${concepto.montoTotalEmbargo!.toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Chip(
              label: Text(
                activo ? 'ACTIVO' : 'INACTIVO',
                style: const TextStyle(fontSize: 10),
              ),
              backgroundColor: activo ? Colors.green[100] : Colors.grey[300],
            ),
            IconButton(
              icon: const Icon(Icons.edit, size: 20),
              onPressed: () => _editarConcepto(concepto),
            ),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }
  
  void _agregarConcepto() async {
    final resultado = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ConceptoFormScreen(
          empleadosFiltro: widget.empleadoCuilFiltro != null 
              ? [widget.empleadoCuilFiltro!] 
              : _empleados.map((e) => e.cuil).toList(),
        ),
      ),
    );
    
    if (resultado == true) {
      _cargarDatos();
    }
  }
  
  void _editarConcepto(ConceptoRecurrente concepto) async {
    final resultado = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ConceptoFormScreen(
          conceptoAEditar: concepto,
          empleadosFiltro: [concepto.empleadoCuil],
        ),
      ),
    );
    
    if (resultado == true) {
      _cargarDatos();
    }
  }
  
  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), backgroundColor: Colors.red),
    );
  }
}
