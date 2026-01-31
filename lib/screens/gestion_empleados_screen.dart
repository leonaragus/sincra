// ========================================================================
// PANTALLA DE GESTIÓN DE EMPLEADOS
// Listar, buscar, crear, editar empleados
// ========================================================================

import 'package:flutter/material.dart';
import '../models/empleado_completo.dart';
import '../services/empleados_service.dart';
import '../theme/app_colors.dart';
import 'empleado_form_screen.dart';

class GestionEmpleadosScreen extends StatefulWidget {
  final String? empresaCuit;
  final String? empresaNombre;
  
  const GestionEmpleadosScreen({
    super.key,
    this.empresaCuit,
    this.empresaNombre,
  });
  
  @override
  State<GestionEmpleadosScreen> createState() => _GestionEmpleadosScreenState();
}

class _GestionEmpleadosScreenState extends State<GestionEmpleadosScreen> {
  List<EmpleadoCompleto> _empleados = [];
  List<EmpleadoCompleto> _empleadosFiltrados = [];
  bool _cargando = true;
  String _filtroEstado = 'todos';
  String _filtroProvincia = 'todas';
  String _filtroSector = 'todos';
  final _searchController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    _cargarEmpleados();
    _searchController.addListener(_filtrar);
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
  
  Future<void> _cargarEmpleados() async {
    setState(() => _cargando = true);
    
    try {
      // Sincronizar desde Supabase primero (si hay conexión)
      await EmpleadosService.sincronizarDesdeSupabase(
        empresaCuit: widget.empresaCuit,
      );
      
      // Cargar desde local
      _empleados = await EmpleadosService.obtenerEmpleados(
        empresaCuit: widget.empresaCuit,
      );
      
      _filtrar();
    } catch (e) {
      _mostrarError('Error cargando empleados: $e');
    }
    
    setState(() => _cargando = false);
  }
  
  void _filtrar() {
    setState(() {
      _empleadosFiltrados = _empleados.where((e) {
        // Filtro por búsqueda (nombre, CUIL)
        final query = _searchController.text.toLowerCase();
        if (query.isNotEmpty) {
          final matchNombre = e.nombreCompleto.toLowerCase().contains(query);
          final matchCuil = e.cuil.contains(query);
          final matchCategoria = e.categoria.toLowerCase().contains(query);
          if (!matchNombre && !matchCuil && !matchCategoria) return false;
        }
        
        // Filtro por estado
        if (_filtroEstado != 'todos' && e.estado != _filtroEstado) {
          return false;
        }
        
        // Filtro por provincia
        if (_filtroProvincia != 'todas' && e.provincia != _filtroProvincia) {
          return false;
        }
        
        // Filtro por sector
        if (_filtroSector != 'todos' && e.sector != _filtroSector) {
          return false;
        }
        
        return true;
      }).toList();
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.empresaNombre != null 
          ? 'Empleados - ${widget.empresaNombre}' 
          : 'Gestión de Empleados'
        ),
        backgroundColor: AppColors.primary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargarEmpleados,
            tooltip: 'Actualizar',
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _agregarEmpleado,
            tooltip: 'Agregar empleado',
          ),
        ],
      ),
      body: Column(
        children: [
          // Barra de búsqueda y filtros
          _buildBarraBusqueda(),
          
          // Estadísticas rápidas
          _buildEstadisticas(),
          
          // Lista de empleados
          Expanded(
            child: _cargando
                ? const Center(child: CircularProgressIndicator())
                : _empleadosFiltrados.isEmpty
                    ? _buildEmptyState()
                    : _buildListaEmpleados(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _agregarEmpleado,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add),
      ),
    );
  }
  
  Widget _buildBarraBusqueda() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey[100],
      child: Column(
        children: [
          // Campo de búsqueda
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Buscar por nombre, CUIL o categoría...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          
          // Filtros
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildChipFiltro(
                  'Estado',
                  ['todos', 'activo', 'suspendido', 'de_baja', 'licencia'],
                  _filtroEstado,
                  (valor) => setState(() {
                    _filtroEstado = valor;
                    _filtrar();
                  }),
                ),
                const SizedBox(width: 8),
                _buildChipFiltro(
                  'Sector',
                  ['todos', 'sanidad', 'docente', 'cct_generico'],
                  _filtroSector,
                  (valor) => setState(() {
                    _filtroSector = valor;
                    _filtrar();
                  }),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildChipFiltro(
    String label,
    List<String> opciones,
    String valorActual,
    Function(String) onChanged,
  ) {
    return Row(
      children: [
        Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
        ...opciones.map((opcion) {
          final selected = opcion == valorActual;
          return Padding(
            padding: const EdgeInsets.only(right: 4),
            child: FilterChip(
              label: Text(opcion == 'todos' || opcion == 'todas' ? 'Todos' : opcion),
              selected: selected,
              onSelected: (_) => onChanged(opcion),
              backgroundColor: Colors.white,
              selectedColor: AppColors.primary.withOpacity(0.2),
            ),
          );
        }),
      ],
    );
  }
  
  Widget _buildEstadisticas() {
    final activos = _empleados.where((e) => e.estado == 'activo').length;
    final bajas = _empleados.where((e) => e.estado == 'de_baja').length;
    final suspendidos = _empleados.where((e) => e.estado == 'suspendido').length;
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      color: Colors.blue[50],
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatChip('Total', _empleados.length, Colors.blue),
          _buildStatChip('Activos', activos, Colors.green),
          _buildStatChip('Bajas', bajas, Colors.red),
          _buildStatChip('Suspendidos', suspendidos, Colors.orange),
          Text('Mostrando: ${_empleadosFiltrados.length}', 
            style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
  
  Widget _buildStatChip(String label, int valor, Color color) {
    return Row(
      children: [
        Text(
          valor.toString(),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
  
  Widget _buildListaEmpleados() {
    return ListView.builder(
      itemCount: _empleadosFiltrados.length,
      itemBuilder: (context, index) {
        final empleado = _empleadosFiltrados[index];
        return _buildEmpleadoCard(empleado);
      },
    );
  }
  
  Widget _buildEmpleadoCard(EmpleadoCompleto empleado) {
    Color estadoColor;
    IconData estadoIcon;
    
    switch (empleado.estado) {
      case 'activo':
        estadoColor = Colors.green;
        estadoIcon = Icons.check_circle;
        break;
      case 'de_baja':
        estadoColor = Colors.red;
        estadoIcon = Icons.cancel;
        break;
      case 'suspendido':
        estadoColor = Colors.orange;
        estadoIcon = Icons.pause_circle;
        break;
      default:
        estadoColor = Colors.grey;
        estadoIcon = Icons.help;
    }
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: estadoColor.withOpacity(0.2),
          child: Icon(estadoIcon, color: estadoColor),
        ),
        title: Text(
          empleado.nombreCompleto,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('CUIL: ${empleado.cuil}'),
            Text('${empleado.categoria} • ${empleado.provincia}'),
            if (empleado.sector != null)
              Text('Sector: ${empleado.sector}', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${empleado.antiguedadAnios}a ${empleado.antiguedadMeses}m',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: () => _editarEmpleado(empleado),
      ),
    );
  }
  
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            _searchController.text.isEmpty 
              ? 'No hay empleados registrados'
              : 'No se encontraron empleados',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _agregarEmpleado,
            icon: const Icon(Icons.add),
            label: const Text('Agregar empleado'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
  
  void _agregarEmpleado() async {
    final resultado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => EmpleadoFormScreen(
          empresaCuit: widget.empresaCuit,
          empresaNombre: widget.empresaNombre,
        ),
      ),
    );
    
    if (resultado == true) {
      _cargarEmpleados();
    }
  }
  
  void _editarEmpleado(EmpleadoCompleto empleado) async {
    final resultado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => EmpleadoFormScreen(
          empleado: empleado,
          empresaCuit: widget.empresaCuit,
          empresaNombre: widget.empresaNombre,
        ),
      ),
    );
    
    if (resultado == true) {
      _cargarEmpleados();
    }
  }
  
  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: Colors.red,
      ),
    );
  }
}
