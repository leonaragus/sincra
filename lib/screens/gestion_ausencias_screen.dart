// ========================================================================
// PANTALLA DE GESTIÓN DE AUSENCIAS
// Licencias, ausencias, presentismo
// ========================================================================

import 'package:flutter/material.dart';
import '../models/ausencia.dart';
import '../models/empleado_completo.dart';
import '../services/ausencias_service.dart';
import '../services/empleados_service.dart';
import '../theme/app_colors.dart';
import 'ausencia_form_screen.dart';

class GestionAusenciasScreen extends StatefulWidget {
  final String? empresaCuit;
  final String? empleadoCuilFiltro;
  
  const GestionAusenciasScreen({
    super.key,
    this.empresaCuit,
    this.empleadoCuilFiltro,
  });
  
  @override
  State<GestionAusenciasScreen> createState() => _GestionAusenciasScreenState();
}

class _GestionAusenciasScreenState extends State<GestionAusenciasScreen> {
  List<Ausencia> _ausencias = [];
  List<EmpleadoCompleto> _empleados = [];
  bool _cargando = true;
  
  String? _filtroEmpleado;
  String _filtroEstado = 'todos'; // todos, pendiente, aprobado, rechazado
  String _filtroTipo = 'todos';
  
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
      
      // Cargar ausencias
      _ausencias = [];
      if (_filtroEmpleado != null) {
        _ausencias = await AusenciasService.obtenerAusenciasPorEmpleado(_filtroEmpleado!);
      } else {
        // Cargar todas las ausencias
        for (final emp in _empleados) {
          final ausencias = await AusenciasService.obtenerAusenciasPorEmpleado(emp.cuil);
          _ausencias.addAll(ausencias);
        }
      }
    } catch (e) {
      _mostrarError('Error cargando datos: $e');
    }
    
    setState(() => _cargando = false);
  }
  
  List<Ausencia> get _ausenciasFiltradas {
    var ausencias = _ausencias;
    
    if (_filtroEstado != 'todos') {
      ausencias = ausencias.where((a) => a.estado.name == _filtroEstado).toList();
    }
    
    if (_filtroTipo != 'todos') {
      ausencias = ausencias.where((a) => a.tipo.name == _filtroTipo).toList();
    }
    
    return ausencias;
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Ausencias'),
        backgroundColor: AppColors.primary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargarDatos,
          ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildFiltros(),
                Expanded(child: _buildListaAusencias()),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _agregarAusencia,
        icon: const Icon(Icons.event_busy),
        label: const Text('Nueva Ausencia'),
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
          children: [
            // Filtro empleado
            if (widget.empleadoCuilFiltro == null)
              DropdownButtonFormField<String?>(
                value: _filtroEmpleado,
                decoration: const InputDecoration(
                  labelText: 'Empleado',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Todos')),
                  ..._empleados.map((e) => DropdownMenuItem(
                    value: e.cuil,
                    child: Text(e.nombreCompleto),
                  )),
                ],
                onChanged: (v) {
                  setState(() => _filtroEmpleado = v);
                  _cargarDatos();
                },
              ),
            
            const SizedBox(height: 12),
            
            // Filtros de estado y tipo
            Row(
              children: [
                Expanded(
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'todos', label: Text('Todos')),
                      ButtonSegment(value: 'pendiente', label: Text('Pendientes')),
                      ButtonSegment(value: 'aprobado', label: Text('Aprobados')),
                    ],
                    selected: {_filtroEstado},
                    onSelectionChanged: (Set<String> selection) {
                      setState(() => _filtroEstado = selection.first);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildListaAusencias() {
    final ausencias = _ausenciasFiltradas;
    
    if (ausencias.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_available, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text('No hay ausencias registradas'),
          ],
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: ausencias.length,
      itemBuilder: (context, index) {
        final ausencia = ausencias[index];
        final empleado = _empleados.firstWhere(
          (e) => e.cuil == ausencia.empleadoCuil,
          orElse: () => EmpleadoCompleto(
            cuil: ausencia.empleadoCuil,
            nombreCompleto: 'Empleado no encontrado',
            fechaIngreso: DateTime.now(),
            categoria: '',
            provincia: '',
          ),
        );
        
        return _buildAusenciaCard(ausencia, empleado);
      },
    );
  }
  
  Widget _buildAusenciaCard(Ausencia ausencia, EmpleadoCompleto empleado) {
    final Color estadoColor = ausencia.estado == EstadoAusencia.aprobado
        ? Colors.green
        : ausencia.estado == EstadoAusencia.rechazado
            ? Colors.red
            : Colors.orange;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: estadoColor.withOpacity(0.2),
          child: Icon(
            ausencia.tipo == TipoAusencia.vacaciones ? Icons.beach_access : Icons.event_busy,
            color: estadoColor,
          ),
        ),
        title: Text(
          ausencia.tipo.displayName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Empleado: ${empleado.nombreCompleto}'),
            Text(
              '${ausencia.fechaDesde.day}/${ausencia.fechaDesde.month}/${ausencia.fechaDesde.year} - '
              '${ausencia.fechaHasta.day}/${ausencia.fechaHasta.month}/${ausencia.fechaHasta.year} '
              '(${ausencia.diasTotales} días)',
            ),
          ],
        ),
        trailing: Chip(
          label: Text(
            ausencia.estado.name.toUpperCase(),
            style: const TextStyle(fontSize: 10, color: Colors.white),
          ),
          backgroundColor: estadoColor,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (ausencia.motivo != null) ...[
                  const Text('Motivo:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(ausencia.motivo!),
                  const SizedBox(height: 8),
                ],
                
                Text('Con goce: ${ausencia.conGoce ? 'Sí' : 'No'}'),
                if (ausencia.conGoce && ausencia.porcentajeGoce < 100)
                  Text('Goce: ${ausencia.porcentajeGoce}%'),
                
                const SizedBox(height: 16),
                
                // Botones de acción
                if (ausencia.estado == EstadoAusencia.pendiente)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: () => _rechazarAusencia(ausencia),
                        icon: const Icon(Icons.cancel, color: Colors.red),
                        label: const Text('Rechazar', style: TextStyle(color: Colors.red)),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () => _aprobarAusencia(ausencia),
                        icon: const Icon(Icons.check_circle),
                        label: const Text('Aprobar'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  void _agregarAusencia() async {
    final resultado = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AusenciaFormScreen(
          empleadosFiltro: widget.empleadoCuilFiltro != null 
              ? [widget.empleadoCuilFiltro!] 
              : _empleados.map((e) => e.cuil).toList(),
          empresaCuit: widget.empresaCuit ?? '',
        ),
      ),
    );
    
    if (resultado == true) {
      _cargarDatos();
    }
  }
  
  Future<void> _aprobarAusencia(Ausencia ausencia) async {
    await AusenciasService.actualizarEstadoAusencia(
      ausencia.id,
      EstadoAusencia.aprobado,
      aprobadoPor: 'Usuario', // Aquí puedes poner el usuario actual
    );
    
    _cargarDatos();
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Ausencia aprobada'),
        backgroundColor: Colors.green,
      ),
    );
  }
  
  Future<void> _rechazarAusencia(Ausencia ausencia) async {
    await AusenciasService.actualizarEstadoAusencia(
      ausencia.id,
      EstadoAusencia.rechazado,
      aprobadoPor: 'Usuario',
    );
    
    _cargarDatos();
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Ausencia rechazada'),
        backgroundColor: Colors.red,
      ),
    );
  }
  
  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), backgroundColor: Colors.red),
    );
  }
}
