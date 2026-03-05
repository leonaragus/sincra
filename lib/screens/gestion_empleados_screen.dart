
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/empleado_completo.dart';
import '../services/empleados_service.dart';
import '../theme/app_colors.dart';
import 'empleado_form_screen.dart';
import 'gestion_prestamos_screen.dart'; // Para acciones rápidas

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
  String _error = '';

  // Estado de los filtros
  String _filtroEstado = 'activo';
  final _searchController = TextEditingController();

  // **NUEVO** Estado para acciones en lote
  bool _isSelectionMode = false;
  final Set<String> _selectedCuils = {};

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
    if (!mounted) return;
    setState(() => _cargando = true);
    try {
      await EmpleadosService.sincronizarDesdeSupabase(empresaCuit: widget.empresaCuit);
      final empleados = await EmpleadosService.obtenerEmpleados(empresaCuit: widget.empresaCuit);
      if (mounted) {
        setState(() {
          _empleados = empleados;
          _cargando = false;
          _filtrar(); 
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error cargando empleados: $e';
          _cargando = false;
        });
      }
    }
  }

  void _filtrar() {
    setState(() {
      _empleadosFiltrados = _empleados.where((e) {
        final query = _searchController.text.toLowerCase();
        if (query.isNotEmpty && !e.nombreCompleto.toLowerCase().contains(query) && !e.cuil.contains(query)) {
          return false;
        }
        if (_filtroEstado != 'todos' && e.estado != _filtroEstado) {
          return false;
        }
        return true;
      }).toList();
    });
  }

  // **NUEVO** Métodos para modo de selección
  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      _selectedCuils.clear();
    });
  }

  void _onEmployeeSelected(EmpleadoCompleto empleado, bool isSelected) {
    setState(() {
      if (isSelected) {
        _selectedCuils.add(empleado.cuil);
      } else {
        _selectedCuils.remove(empleado.cuil);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;
    
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: (isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark).copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: backgroundColor,
          systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: backgroundColor,
        body: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _cargando
                  ? const Center(child: CircularProgressIndicator(color: AppColors.accentBlue))
                  : _error.isNotEmpty
                      ? Center(child: Text(_error)) // Mejorar vista de error
                      : CustomScrollView(
                          slivers: [
                            SliverToBoxAdapter(child: _buildFilterBar()),
                            SliverToBoxAdapter(child: _buildStatsBar()),
                            if (_empleadosFiltrados.isEmpty)
                              SliverToBoxAdapter(child: _buildEmptyState())
                            else
                              _buildEmployeeList(),
                          ],
                        ),
            ),
          ],
        ),
        floatingActionButton: !_isSelectionMode
            ? FloatingActionButton.extended(
                onPressed: _agregarEmpleado,
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text('Nuevo Empleado', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                backgroundColor: AppColors.accentBlue,
                elevation: 8,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              )
            : null,
      ),
    );
  }

  Widget _buildHeader() {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 8, 16, 16),
          decoration: const BoxDecoration(
            color: AppColors.glassFill,
            border: Border(bottom: BorderSide(color: AppColors.glassBorder)),
          ),
          child: _isSelectionMode ? _buildSelectionHeader() : _buildNormalHeader(),
        ),
      ),
    );
  }

  Widget _buildNormalHeader() {
    return Row(
      children: [
        const Icon(Icons.people_outline, color: AppColors.textPrimary),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            widget.empresaNombre ?? 'Gestión de Empleados',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.check_box_outline_blank, color: AppColors.textSecondary),
          tooltip: 'Seleccionar Varios',
          onPressed: _toggleSelectionMode,
        ),
        IconButton(
          icon: const Icon(Icons.refresh, color: AppColors.textSecondary),
          tooltip: 'Actualizar',
          onPressed: _cargarEmpleados,
        ),
      ],
    );
  }

  Widget _buildSelectionHeader() {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.close, color: AppColors.textPrimary),
          onPressed: _toggleSelectionMode,
        ),
        const SizedBox(width: 16),
        Text('${_selectedCuils.length} seleccionados', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.low_priority, color: AppColors.textSecondary),
          tooltip: 'Cambiar Estado',
          onPressed: () { /* Lógica para cambiar estado en lote */ },
        ),
        IconButton(
          icon: const Icon(Icons.archive_outlined, color: AppColors.textSecondary),
          tooltip: 'Archivar Seleccionados',
          onPressed: () { /* Lógica para archivar en lote */ },
        ),
      ],
    );
  }

  Widget _buildFilterBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Buscar por nombre o CUIL...',
              hintStyle: const TextStyle(color: AppColors.textMuted),
              prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
              filled: true,
              fillColor: AppColors.glassFillStrong,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['todos', 'activo', 'suspendido', 'de_baja', 'licencia'].map((estado) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: FilterChip(
                    label: Text(estado[0].toUpperCase() + estado.substring(1)),
                    selected: _filtroEstado == estado,
                    onSelected: (bool selected) {
                      if (selected) setState(() { _filtroEstado = estado; _filtrar(); });
                    },
                    backgroundColor: AppColors.glassFillStrong,
                    selectedColor: AppColors.accentBlue.withOpacity(0.8),
                    labelStyle: TextStyle(color: _filtroEstado == estado ? Colors.white : AppColors.textSecondary, fontWeight: FontWeight.w500),
                    checkmarkColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: AppColors.glassBorder)),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsBar() {
    final activos = _empleados.where((e) => e.estado == 'activo').length;
    final deBaja = _empleados.where((e) => e.estado == 'de_baja').length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Mostrando: ${_empleadosFiltrados.length} de ${_empleados.length}', style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
          Row(
            children: [
              _buildStatChip('Activos', activos, AppColors.loanActive),
              const SizedBox(width: 16),
              _buildStatChip('De Baja', deBaja, AppColors.loanCancelled),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildStatChip(String label, int value, Color color) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(color: AppColors.textSecondary)),
        const SizedBox(width: 6),
        Text(value.toString(), style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildEmployeeList() {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final empleado = _empleadosFiltrados[index];
          return _buildEmpleadoCard(empleado);
        },
        childCount: _empleadosFiltrados.length,
      ),
    );
  }

  Widget _buildEmpleadoCard(EmpleadoCompleto empleado) {
    final isSelected = _selectedCuils.contains(empleado.cuil);
    final statusColor = _getStatusColor(empleado.estado);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.accentBlue.withOpacity(0.15) : AppColors.glassFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isSelected ? AppColors.accentBlue.withOpacity(0.5) : AppColors.glassBorder),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: () => _isSelectionMode ? _onEmployeeSelected(empleado, !isSelected) : _editarEmpleado(empleado),
          onLongPress: () {
            if (!_isSelectionMode) _toggleSelectionMode();
            _onEmployeeSelected(empleado, true);
          },
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                if (_isSelectionMode)
                  Padding(
                    padding: const EdgeInsets.only(right: 16.0),
                    child: Checkbox(value: isSelected, onChanged: (val) => _onEmployeeSelected(empleado, val ?? false), activeColor: AppColors.accentBlue),
                  ),
                if (!_isSelectionMode)
                   Padding(
                     padding: const EdgeInsets.only(right: 16.0),
                     child: CircleAvatar(backgroundColor: statusColor.withOpacity(0.2), child: Icon(_getStatusIcon(empleado.estado), color: statusColor, size: 20)),
                   ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(empleado.nombreCompleto, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                      const SizedBox(height: 4),
                      Text('CUIL: ${empleado.cuil}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                      Text(empleado.categoria, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    ],
                  ),
                ),
                if (!_isSelectionMode)
                  _buildQuickActionsMenu(empleado),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionsMenu(EmpleadoCompleto empleado) {
    return PopupMenuButton<String>(
      onSelected: (value) {
        if (value == 'editar') _editarEmpleado(empleado);
        if (value == 'prestamos') {
          Navigator.push(context, MaterialPageRoute(builder: (_) => GestionPrestamosScreen(empresaCuit: widget.empresaCuit, empleadoCuilFiltro: empleado.cuil)));
        }
      },
      icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
      color: AppColors.backgroundCard,
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        const PopupMenuItem<String>(value: 'editar', child: ListTile(leading: Icon(Icons.edit_outlined, color: AppColors.textSecondary), title: Text('Editar Ficha', style: TextStyle(color: AppColors.textPrimary)))),
        const PopupMenuItem<String>(value: 'recibos', child: ListTile(leading: Icon(Icons.receipt_long_outlined, color: AppColors.textSecondary), title: Text('Ver Recibos', style: TextStyle(color: AppColors.textPrimary)))),
        const PopupMenuItem<String>(value: 'prestamos', child: ListTile(leading: Icon(Icons.account_balance_wallet_outlined, color: AppColors.textSecondary), title: Text('Gestionar Préstamos', style: TextStyle(color: AppColors.textPrimary)))),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(value: 'baja', child: ListTile(leading: Icon(Icons.person_remove_outlined, color: AppColors.error), title: Text('Dar de Baja', style: TextStyle(color: AppColors.error)))),
      ],
    );
  }
  
  Color _getStatusColor(String? estado) {
    switch (estado) {
      case 'activo': return AppColors.loanActive;
      case 'de_baja': return AppColors.error;
      case 'suspendido': return AppColors.accentOrange;
      case 'licencia': return AppColors.accentPink;
      default: return AppColors.textMuted;
    }
  }
  
  IconData _getStatusIcon(String? estado) {
    switch (estado) {
      case 'activo': return Icons.check_circle_outline;
      case 'de_baja': return Icons.cancel_outlined;
      case 'suspendido': return Icons.pause_circle_outline;
      case 'licencia': return Icons.beach_access_outlined;
      default: return Icons.help_outline;
    }
  }

  Widget _buildEmptyState() {
    // ... Similar al de las otras pantallas, pero adaptado
    return Container();
  }

  void _agregarEmpleado() async {
    final resultado = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => EmpleadoFormScreen(empresaCuit: widget.empresaCuit)));
    if (resultado == true) _cargarEmpleados();
  }

  void _editarEmpleado(EmpleadoCompleto empleado) async {
    final resultado = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => EmpleadoFormScreen(empleado: empleado, empresaCuit: widget.empresaCuit)));
    if (resultado == true) _cargarEmpleados();
  }
}
