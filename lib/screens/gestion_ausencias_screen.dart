
// ========================================================================
// GESTIÓN DE AUSENCIAS v2.1 - CENTRO DE CONTROL DE AUSENTISMO
// Perfeccionado con formulario modal, estadísticas avanzadas y UI refinada.
// ========================================================================

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:collection/collection.dart';

import '../models/ausencia.dart';
import '../models/empleado_completo.dart';
import '../services/ausencias_service.dart';
import '../services/empleados_service.dart';
import '../theme/app_colors.dart';
import '../widgets/glass_card.dart';

class GestionAusenciasScreen extends StatefulWidget {
  final String empresaCuit;
  final String? empleadoCuilFiltro;

  const GestionAusenciasScreen({
    super.key,
    required this.empresaCuit,
    this.empleadoCuilFiltro,
  });

  @override
  State<GestionAusenciasScreen> createState() => _GestionAusenciasScreenState();
}

class _GestionAusenciasScreenState extends State<GestionAusenciasScreen> {
  bool _cargando = true;
  String _error = '';

  // Datos
  List<Ausencia> _todasLasAusencias = [];
  List<EmpleadoCompleto> _empleados = [];
  Map<DateTime, List<Ausencia>> _eventos = {};

  // Estado UI
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  List<Ausencia> _ausenciasDelDiaSeleccionado = [];

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _cargarDatos();
  }

  Future<void> _cargarDatos({bool showLoading = true}) async {
    if (showLoading && mounted) setState(() => _cargando = true);
    try {
      final results = await Future.wait([
        AusenciasService.obtenerAusenciasPorEmpresa(empresaCuit: widget.empresaCuit),
        EmpleadosService.obtenerEmpleadosActivos(empresaCuit: widget.empresaCuit),
      ]);

      if (!mounted) return;
      final ausencias = results[0] as List<Ausencia>;
      final empleados = results[1] as List<EmpleadoCompleto>;
      
      final eventos = <DateTime, List<Ausencia>>{};
      for (final ausencia in ausencias) {
        for (var i = 0; i <= ausencia.fechaHasta.difference(ausencia.fechaDesde).inDays; i++) {
          final day = DateUtils.dateOnly(ausencia.fechaDesde.add(Duration(days: i)));
          (eventos[day] ??= []).add(ausencia);
        }
      }

      setState(() {
        _todasLasAusencias = ausencias;
        _empleados = empleados;
        _eventos = eventos;
        _cargando = false;
        _error = '';
      });
      _actualizarAusenciasSeleccionadas();
    } catch (e) {
      if (mounted) setState(() => _error = 'Error cargando datos: $e');
    } finally {
      if (mounted && _cargando) setState(() => _cargando = false);
    }
  }

  void _actualizarAusenciasSeleccionadas() {
    final selectedDate = DateUtils.dateOnly(_selectedDay ?? _focusedDay);
    final ausenciasBrutas = _eventos[selectedDate] ?? [];
    
    // Aplicar filtro si existe
    final ausenciasFiltradas = widget.empleadoCuilFiltro != null
        ? ausenciasBrutas.where((a) => a.empleadoCuil == widget.empleadoCuilFiltro).toList()
        : ausenciasBrutas;

    ausenciasFiltradas.sort((a, b) => a.fechaDesde.compareTo(b.fechaDesde));

    setState(() => _ausenciasDelDiaSeleccionado = ausenciasFiltradas);
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (!isSameDay(_selectedDay, selectedDay)) {
      setState(() {
        _selectedDay = selectedDay;
        _focusedDay = focusedDay;
      });
      _actualizarAusenciasSeleccionadas();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
              ? Center(child: Text(_error, style: const TextStyle(color: Colors.red)))
              : Column(
                  children: [
                    _buildStatsCard(),
                    Expanded(
                      child: CustomScrollView(
                        slivers: [
                          SliverToBoxAdapter(child: _buildCalendarView()),
                          SliverToBoxAdapter(child: _buildListHeader()),
                          _ausenciasDelDiaSeleccionado.isEmpty
                              ? SliverToBoxAdapter(child: _buildEmptyStateForDay())
                              : _buildAusenciasList(),
                        ],
                      ),
                    ),
                  ],
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _mostrarFormularioAusencia,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      title: const Text('Control de Ausentismo'),
      backgroundColor: AppColors.background.withOpacity(0.8),
      elevation: 0,
      flexibleSpace: ClipRect(child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10), child: Container(color: Colors.transparent))),
      actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: () => _cargarDatos())],
    );
  }

  Widget _buildStatsCard() {
    final ausenciasMesActual = _todasLasAusencias.where((a) => a.fechaDesde.month == _focusedDay.month && a.fechaDesde.year == _focusedDay.year).toList();
    final totalAusencias = ausenciasMesActual.length;
    final tipoMasComun = ausenciasMesActual.isNotEmpty
        ? (groupBy(ausenciasMesActual, (Ausencia a) => a.tipo))
            .entries
            .sortedBy<num>((e) => e.value.length)
            .last
            .key
            .displayName
        : 'N/A';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: GlassCard(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('Ausencias este Mes', totalAusencias.toString(), Icons.event_busy, AppColors.accentOrange),
              _buildStatItem('Tipo más Frecuente', tipoMasComun, Icons.pie_chart, AppColors.accentPink),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Flexible(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary), textAlign: TextAlign.center, overflow: TextOverflow.ellipsis),
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildCalendarView() {
    return GlassCard(
      margin: const EdgeInsets.all(16),
      child: TableCalendar(
        locale: 'es_AR',
        firstDay: DateTime.utc(2020, 1, 1),
        lastDay: DateTime.utc(2030, 12, 31),
        focusedDay: _focusedDay,
        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
        onDaySelected: _onDaySelected,
        eventLoader: (day) => _eventos[DateUtils.dateOnly(day)] ?? [],
        calendarBuilders: CalendarBuilders(
          markerBuilder: (context, date, events) {
            if (events.isEmpty) return null;
            final markers = events
                .map((e) => (e as Ausencia).tipo)
                .toSet()
                .map((tipo) => Container(width: 7, height: 7, margin: const EdgeInsets.symmetric(horizontal: 1.5), decoration: BoxDecoration(color: _getColorForTipo(tipo), shape: BoxShape.circle)))
                .toList();
            return Positioned(bottom: 5, right: 0, left: 0, child: Row(mainAxisAlignment: MainAxisAlignment.center, children: markers));
          },
        ),
        calendarStyle: CalendarStyle(
            selectedDecoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
            todayDecoration: BoxDecoration(color: AppColors.primary.withOpacity(0.5), shape: BoxShape.circle)
        ),
        headerStyle: const HeaderStyle(titleCentered: true, formatButtonVisible: false),
      ),
    );
  }

  Widget _buildListHeader() {
    final formattedDate = DateFormat("EEEE d 'de' MMMM", 'es_AR').format(_selectedDay ?? _focusedDay);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Text(formattedDate, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
    );
  }

  Widget _buildAusenciasList() {
    return SliverList(delegate: SliverChildBuilderDelegate((context, index) {
      final ausencia = _ausenciasDelDiaSeleccionado[index];
      final empleado = _empleados.firstWhereOrNull((e) => e.cuil == ausencia.empleadoCuil);
      return _AusenciaCard(ausencia: ausencia, empleado: empleado, onAction: () => _cargarDatos(showLoading: false));
    }, childCount: _ausenciasDelDiaSeleccionado.length));
  }

  Widget _buildEmptyStateForDay() {
    return const Padding(
      padding: EdgeInsets.all(48.0),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [Icon(Icons.check_circle_outline, size: 50, color: Colors.green), SizedBox(height: 16), Text('Todo el personal presente', style: TextStyle(fontSize: 16, color: AppColors.textSecondary))],
        ),
      ),
    );
  }

  void _mostrarFormularioAusencia({Ausencia? ausencia}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AusenciaFormModal(
        empresaCuit: widget.empresaCuit,
        empleados: _empleados,
        ausencia: ausencia,
        onGuardar: () {
          Navigator.of(context).pop();
          _cargarDatos(showLoading: false);
        },
      ),
    );
  }
  
  Color _getColorForTipo(TipoAusencia tipo) {
    switch (tipo) {
      case TipoAusencia.vacaciones: return Colors.blue;
      case TipoAusencia.enfermedad: return Colors.red;
      case TipoAusencia.examen: return Colors.purple;
      case TipoAusencia.licenciaEspecial: return Colors.orange;
      default: return Colors.grey;
    }
  }
}


// WIDGET INTERNO PARA TARJETA DE AUSENCIA
class _AusenciaCard extends StatelessWidget {
  final Ausencia ausencia;
  final EmpleadoCompleto? empleado;
  final VoidCallback onAction;

  const _AusenciaCard({required this.ausencia, this.empleado, required this.onAction});

  // ... (código de la tarjeta sin cambios, solo se asegura que empleado puede ser nulo)
   @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(ausencia.estado);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.glassFill, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.glassBorder)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_getAusenciaIcon(ausencia.tipo), color: statusColor, size: 24),
              const SizedBox(width: 12),
              Expanded(child: Text(empleado?.nombreCompleto ?? 'Empleado no encontrado', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 8),
              Chip(label: Text(ausencia.estado.name.toUpperCase()), backgroundColor: statusColor.withOpacity(0.2), side: BorderSide.none, labelStyle: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold))
            ],
          ),
          const Divider(height: 24, color: AppColors.glassBorder),
          Text('Tipo: ${ausencia.tipo.displayName}'),
          Text('Período: ${DateFormat.yMd('es_AR').format(ausencia.fechaDesde)} al ${DateFormat.yMd('es_AR').format(ausencia.fechaHasta)} (${ausencia.diasTotales} días)'),
          if (ausencia.estado == EstadoAusencia.pendiente) _buildActionButtons(context),
        ],
      ),
    );
  }
  
  Widget _buildActionButtons(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(onPressed: () => _updateStatus(context, EstadoAusencia.rechazado), child: const Text('Rechazar', style: TextStyle(color: AppColors.error))),
          const SizedBox(width: 8),
          ElevatedButton(onPressed: () => _updateStatus(context, EstadoAusencia.aprobado), child: const Text('Aprobar')),
        ],
      ),
    );
  }

  Future<void> _updateStatus(BuildContext context, EstadoAusencia newStatus) async {
    try {
      await AusenciasService.actualizarEstadoAusencia(ausencia.id, newStatus);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ausencia ${newStatus.name}'), backgroundColor: newStatus == EstadoAusencia.aprobado ? Colors.green : Colors.red));
      onAction();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }
   Color _getStatusColor(EstadoAusencia estado) {
    switch (estado) {
      case EstadoAusencia.aprobado: return Colors.green;
      case EstadoAusencia.rechazado: return Colors.red;
      case EstadoAusencia.pendiente: return Colors.orange;
      default: return Colors.grey;
    }
  }

  IconData _getAusenciaIcon(TipoAusencia tipo) {
    switch (tipo) {
      case TipoAusencia.vacaciones: return Icons.beach_access;
      case TipoAusencia.enfermedad: return Icons.sick;
      case TipoAusencia.examen: return Icons.school;
      default: return Icons.event_busy;
    }
  }
}


// FORMULARIO MODAL PARA CREAR/EDITAR AUSENCIA
class _AusenciaFormModal extends StatefulWidget {
  final String empresaCuit;
  final List<EmpleadoCompleto> empleados;
  final Ausencia? ausencia;
  final VoidCallback onGuardar;

  const _AusenciaFormModal({required this.empresaCuit, required this.empleados, this.ausencia, required this.onGuardar});

  @override
  State<_AusenciaFormModal> createState() => _AusenciaFormModalState();
}

class _AusenciaFormModalState extends State<_AusenciaFormModal> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  // Form data
  String? _empleadoCuil;
  TipoAusencia _tipo = TipoAusencia.otra;
  DateTime _fechaDesde = DateTime.now();
  DateTime _fechaHasta = DateTime.now();
  final _motivoController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.ausencia != null) {
      final a = widget.ausencia!;
      _empleadoCuil = a.empleadoCuil;
      _tipo = a.tipo;
      _fechaDesde = a.fechaDesde;
      _fechaHasta = a.fechaHasta;
      _motivoController.text = a.motivo ?? '';
    } else {
      if (widget.empleados.isNotEmpty) _empleadoCuil = widget.empleados.first.cuil;
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    
    final nuevaAusencia = Ausencia(
      id: widget.ausencia?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      empresaCuit: widget.empresaCuit,
      empleadoCuil: _empleadoCuil!,
      tipo: _tipo,
      fechaDesde: _fechaDesde,
      fechaHasta: _fechaHasta,
      motivo: _motivoController.text,
      estado: widget.ausencia?.estado ?? EstadoAusencia.pendiente,
    );

    try {
      await AusenciasService.guardarAusencia(nuevaAusencia);
      widget.onGuardar();
    } catch(e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al guardar: $e'), backgroundColor: Colors.red));
    } finally {
      if(mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
            color: AppColors.background.withOpacity(0.9),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(widget.ausencia == null ? 'Registrar Ausencia' : 'Editar Ausencia', style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
                const SizedBox(height: 24),
                DropdownButtonFormField<String>(
                  value: _empleadoCuil,
                  items: widget.empleados.map((e) => DropdownMenuItem(value: e.cuil, child: Text(e.nombreCompleto))).toList(),
                  onChanged: (val) => setState(() => _empleadoCuil = val),
                  decoration: const InputDecoration(labelText: 'Empleado'),
                  validator: (val) => val == null ? 'Debe seleccionar un empleado' : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<TipoAusencia>(
                  value: _tipo,
                  items: TipoAusencia.values.map((t) => DropdownMenuItem(value: t, child: Text(t.displayName))).toList(),
                  onChanged: (val) => setState(() => _tipo = val!),
                  decoration: const InputDecoration(labelText: 'Tipo de Ausencia'),
                ),
                const SizedBox(height: 16),
                _buildDateRangePicker(),
                const SizedBox(height: 16),
                TextFormField(controller: _motivoController, decoration: const InputDecoration(labelText: 'Motivo (opcional)')),
                const SizedBox(height: 24),
                _isSaving
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton.icon(
                        onPressed: _submit,
                        icon: const Icon(Icons.save),
                        label: const Text('Guardar'),
                        style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDateRangePicker() {
    return InputDecorator(
      decoration: const InputDecoration(labelText: 'Período de Ausencia', border: OutlineInputBorder()),
      child: InkWell(
        onTap: () async {
          final range = await showDateRangePicker(
            context: context,
            firstDate: DateTime.now().subtract(const Duration(days: 365)),
            lastDate: DateTime.now().add(const Duration(days: 365)),
            initialDateRange: DateTimeRange(start: _fechaDesde, end: _fechaHasta),
          );
          if (range != null) {
            setState(() {
              _fechaDesde = range.start;
              _fechaHasta = range.end;
            });
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Text(DateFormat.yMMMd('es_AR').format(_fechaDesde)),
              const Icon(Icons.arrow_forward, color: AppColors.textSecondary),
              Text(DateFormat.yMMMd('es_AR').format(_fechaHasta)),
            ],
          ),
        ),
      ),
    );
  }
}
