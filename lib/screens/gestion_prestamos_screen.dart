
// =======================================================================
// GESTIÓN DE PRÉSTAMOS v2.0 - CENTRO DE CONTROL FINANCIERO
// =======================================================================

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/prestamo.dart';
import '../models/empleado_completo.dart';
import '../services/prestamos_service.dart';
import '../services/empleados_service.dart';
import '../theme/app_colors.dart';
import '../widgets/glass_card.dart';

class GestionPrestamosScreen extends StatefulWidget {
  final String empresaCuit;
  final String? empleadoCuilFiltro;

  const GestionPrestamosScreen({
    super.key,
    required this.empresaCuit,
    this.empleadoCuilFiltro,
  });

  @override
  State<GestionPrestamosScreen> createState() => _GestionPrestamosScreenState();
}

class _GestionPrestamosScreenState extends State<GestionPrestamosScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  
  // Data
  List<Prestamo> _allPrestamos = [];
  List<EmpleadoCompleto> _empleados = [];
  
  // UI State
  bool _cargando = true;
  String? _error;
  String? _filtroEmpleadoCuil;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _filtroEmpleadoCuil = widget.empleadoCuilFiltro;
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      _empleados = await EmpleadosService.obtenerEmpleadosActivos(empresaCuit: widget.empresaCuit);
      _allPrestamos = await PrestamosService.obtenerPrestamosPorEmpresa(widget.empresaCuit);
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Error al cargar datos: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _cargando = false);
      }
    }
  }

  List<Prestamo> _getFilteredPrestamos(EstadoPrestamo estado) {
    return _allPrestamos.where((p) {
      final matchesEmpleado = _filtroEmpleadoCuil == null || p.empleadoCuil == _filtroEmpleadoCuil;
      final matchesEstado = p.estado == estado;
      return matchesEmpleado && matchesEstado;
    }).toList();
  }
  
  List<Prestamo> _getFilteredHistorial() {
     return _allPrestamos.where((p) {
      final matchesEmpleado = _filtroEmpleadoCuil == null || p.empleadoCuil == _filtroEmpleadoCuil;
      return matchesEmpleado && (p.estado == EstadoPrestamo.pagado || p.estado == EstadoPrestamo.cancelado);
    }).toList();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : Column(
                  children: [
                    if(widget.empleadoCuilFiltro == null) _buildFiltroEmpleados(),
                    _buildEstadisticas(),
                    _buildTabBar(),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildPrestamosList(_getFilteredPrestamos(EstadoPrestamo.activo), "activos"),
                          _buildPrestamosList(_getFilteredHistorial(), "historial"),
                        ],
                      ),
                    ),
                  ],
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _mostrarFormularioPrestamo(context),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Nuevo Préstamo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primary,
        elevation: 4,
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text('Centro de Préstamos'),
      backgroundColor: AppColors.background.withOpacity(0.8),
      elevation: 0,
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(color: Colors.transparent),
        ),
      ),
       actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _cargarDatos,
          tooltip: 'Recargar',
        ),
      ],
    );
  }

  Widget _buildFiltroEmpleados(){
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: DropdownButtonFormField<String?>(
        value: _filtroEmpleadoCuil,
        decoration: InputDecoration(
          labelText: 'Filtrar por Empleado',
          filled: true,
          fillColor: AppColors.glassFill,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          prefixIcon: const Icon(Icons.person_search),
        ),
        items: [
          const DropdownMenuItem(value: null, child: Text("Todos los empleados")),
          ..._empleados.map((e) => DropdownMenuItem(value: e.cuil, child: Text(e.nombreCompleto))),
        ],
        onChanged: (value) {
          setState(() {
            _filtroEmpleadoCuil = value;
          });
        },
      ),
    );
  }

  Widget _buildEstadisticas() {
    final prestamosActivos = _getFilteredPrestamos(EstadoPrestamo.activo);
    final totalPrestado = prestamosActivos.fold<double>(0, (sum, p) => sum + p.montoTotal);
    final totalRestante = prestamosActivos.fold<double>(0, (sum, p) => sum + p.montoRestante);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: GlassCard(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('Activos', prestamosActivos.length.toString(), Icons.hourglass_top, Colors.amber),
              _buildStatItem('Total Prestado', '\$${(totalPrestado/1000).toStringAsFixed(1)}k', Icons.arrow_upward, Colors.blue),
              _buildStatItem('Saldo Pendiente', '\$${(totalRestante/1000).toStringAsFixed(1)}k', Icons.arrow_downward, Colors.pink),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      ],
    );
  }
  
  Widget _buildTabBar() {
    return TabBar(
      controller: _tabController,
      indicatorColor: AppColors.primary,
      labelColor: AppColors.primary,
      unselectedLabelColor: AppColors.textSecondary,
      tabs: const [
        Tab(icon: Icon(Icons.play_circle_fill), text: 'Activos'),
        Tab(icon: Icon(Icons.history), text: 'Historial'),
      ],
    );
  }

  Widget _buildPrestamosList(List<Prestamo> prestamos, String emptyStateKey) {
    if (prestamos.isEmpty) {
      return Center(
        child: Text(
          emptyStateKey == "activos" 
            ? "No hay préstamos activos."
            : "No hay préstamos en el historial.",
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 16)
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: prestamos.length,
      itemBuilder: (context, index) {
        final prestamo = prestamos[index];
        final empleado = _empleados.firstWhere(
          (e) => e.cuil == prestamo.empleadoCuil,
          orElse: () => EmpleadoCompleto(cuil: 'N/A', nombreCompleto: 'Empleado no encontrado', fechaIngreso: DateTime.now(), categoria: '', provincia: ''),
        );
        return _buildPrestamoCard(prestamo, empleado);
      },
    );
  }

  Widget _buildPrestamoCard(Prestamo prestamo, EmpleadoCompleto empleado) {
    final formatCurrency = NumberFormat.simpleCurrency(locale: 'es_AR', decimalDigits: 2);
    final colorEstado = prestamo.estado == EstadoPrestamo.activo ? Colors.amber : Colors.green;
    
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(empleado.nombreCompleto, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: 4),
            Text('CUIL: ${empleado.cuil}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Saldo Restante', style: TextStyle(color: AppColors.textSecondary)),
                Text(formatCurrency.format(prestamo.montoRestante), style: TextStyle(color: AppColors.primary, fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: prestamo.porcentajePagado / 100,
              backgroundColor: AppColors.glassFill,
              valueColor: AlwaysStoppedAnimation<Color>(colorEstado),
            ),
            const SizedBox(height: 4),
            Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                    Text("Pagado: ${formatCurrency.format(prestamo.montoPagado)} de ${formatCurrency.format(prestamo.montoTotal)}"),
                    Text('${prestamo.porcentajePagado.toStringAsFixed(1)}%'),
                ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () { /* TODO: Implementar vista detallada */ },
                  child: const Text("Ver Detalles"),
                ),
                const SizedBox(width: 8),
                if(prestamo.estado == EstadoPrestamo.activo)
                  ElevatedButton(
                    onPressed: () { /* TODO: Implementar registro de pago */ },
                    child: const Text("Registrar Pago"),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarFormularioPrestamo(BuildContext context, {Prestamo? prestamo}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (_, scrollController) =>_PrestamoFormModal(
            scrollController: scrollController,
            empresaCuit: widget.empresaCuit,
            empleados: _empleados,
            prestamo: prestamo,
            onGuardar: () {
                Navigator.of(context).pop();
                _cargarDatos();
            },
        ),
      ),
    );
  }
}


// =======================================================================
// FORMULARIO MODAL PARA CREAR/EDITAR PRÉSTAMO
// =======================================================================

class _PrestamoFormModal extends StatefulWidget {
  final ScrollController scrollController;
  final String empresaCuit;
  final List<EmpleadoCompleto> empleados;
  final Prestamo? prestamo;
  final VoidCallback onGuardar;

  const _PrestamoFormModal({
    required this.scrollController,
    required this.empresaCuit,
    required this.empleados,
    this.prestamo,
    required this.onGuardar,
  });

  @override
  State<_PrestamoFormModal> createState() => _PrestamoFormModalState();
}

class _PrestamoFormModalState extends State<_PrestamoFormModal> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  late String? _empleadoCuil;
  final _montoController = TextEditingController();
  final _cuotasController = TextEditingController();
  final _fechaController = TextEditingController();
  final _motivoController = TextEditingController();
  
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _empleadoCuil = widget.prestamo?.empleadoCuil ?? (widget.empleados.isNotEmpty ? widget.empleados.first.cuil : null);
    
    if (widget.prestamo != null) {
      _montoController.text = widget.prestamo!.montoTotal.toString();
      _cuotasController.text = widget.prestamo!.cantidadCuotas.toString();
      _fechaController.text = DateFormat('dd/MM/yyyy').format(widget.prestamo!.fechaOtorgamiento);
      _motivoController.text = widget.prestamo!.motivoPrestamo ?? '';
    } else {
        _fechaController.text = DateFormat('dd/MM/yyyy').format(DateTime.now());
    }
  }

  @override
  void dispose() {
    _montoController.dispose();
    _cuotasController.dispose();
    _fechaController.dispose();
    _motivoController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isSaving = true);

    try {
      await PrestamosService.crearPrestamo(
        empleadoCuil: _empleadoCuil!,
        empresaCuit: widget.empresaCuit,
        montoTotal: double.parse(_montoController.text),
        cantidadCuotas: int.parse(_cuotasController.text),
        fechaOtorgamiento: DateFormat('dd/MM/yyyy').parse(_fechaController.text),
        motivoPrestamo: _motivoController.text,
      );
      widget.onGuardar();

    } catch (e) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if(mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.background.withOpacity(0.85),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Form(
          key: _formKey,
          child: ListView(
            controller: widget.scrollController,
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                widget.prestamo == null ? 'Nuevo Préstamo' : 'Editar Préstamo',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                textAlign: TextAlign.center,
              ),
              const Divider(height: 32),
              
              DropdownButtonFormField<String>(
                value: _empleadoCuil,
                items: widget.empleados.map((e) => DropdownMenuItem(value: e.cuil, child: Text(e.nombreCompleto))).toList(),
                onChanged: (value) => setState(() => _empleadoCuil = value),
                decoration: const InputDecoration(labelText: 'Empleado'),
                validator: (value) => value == null ? 'Seleccione un empleado' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _montoController,
                decoration: const InputDecoration(labelText: 'Monto Total', prefixText: '\$ '),
                keyboardType: TextInputType.number,
                validator: (value) => (double.tryParse(value ?? '') == null) ? 'Monto inválido' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _cuotasController,
                decoration: const InputDecoration(labelText: 'Cantidad de Cuotas'),
                keyboardType: TextInputType.number,
                validator: (value) => (int.tryParse(value ?? '') == null) ? 'Número de cuotas inválido' : null,
              ),
              const SizedBox(height: 16),
               TextFormField(
                    controller: _fechaController,
                    readOnly: true,
                    decoration: const InputDecoration(
                        labelText: 'Fecha de Otorgamiento',
                        suffixIcon: Icon(Icons.calendar_today),
                    ),
                    onTap: () async {
                        final picked = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                            _fechaController.text = DateFormat('dd/MM/yyyy').format(picked);
                        }
                    },
                ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _motivoController,
                decoration: const InputDecoration(labelText: 'Motivo (opcional)'),
              ),
              const SizedBox(height: 32),
              _isSaving
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton.icon(
                      onPressed: _submit,
                      icon: const Icon(Icons.save),
                      label: const Text('Guardar Préstamo'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
