
// ========================================================================
// PANTALLA DE GESTIÓN DE AUSENCIAS (v2.0 con Calendario)
// Interfaz rediseñada con vista de calendario y carga optimizada.
// ========================================================================

// **NOTA IMPORTANTE:** Para que esta pantalla funcione, asegúrate de
// agregar la dependencia `table_calendar` en tu archivo `pubspec.yaml`:
// dependencies:
//   table_calendar: ^3.0.0

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../models/ausencia.dart';
import '../models/empleado_completo.dart';
import '../services/ausencias_service.dart';
import '../services/empleados_service.dart';
import '../theme/app_colors.dart';
import 'ausencia_form_screen.dart';

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

  // Datos maestros
  List<Ausencia> _todasLasAusencias = [];
  List<EmpleadoCompleto> _empleados = [];
  Map<DateTime, List<Ausencia>> _eventos = {};

  // Estado de la UI
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  String _filtroEstado = 'todos'; // todos, pendiente, aprobado
  List<Ausencia> _ausenciasVisibles = [];

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
      _filtrarAusenciasVisibles();
    } catch (e) {
      if (mounted) setState(() => _error = 'Error cargando datos: $e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _filtrarAusenciasVisibles() {
    List<Ausencia> ausenciasDelDia = _selectedDay != null ? _eventos[DateUtils.dateOnly(_selectedDay!)] ?? [] : [];

    if (_filtroEstado != 'todos') {
      ausenciasDelDia = ausenciasDelDia.where((a) => a.estado.name == _filtroEstado).toList();
    }
    if (widget.empleadoCuilFiltro != null) {
      ausenciasDelDia = ausenciasDelDia.where((a) => a.empleadoCuil == widget.empleadoCuilFiltro).toList();
    }

    ausenciasDelDia.sort((a, b) {
      if (a.estado == EstadoAusencia.pendiente && b.estado != EstadoAusencia.pendiente) return -1;
      if (a.estado != EstadoAusencia.pendiente && b.estado == EstadoAusencia.pendiente) return 1;
      return a.fechaDesde.compareTo(b.fechaDesde);
    });

    setState(() => _ausenciasVisibles = ausenciasDelDia);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: (isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark).copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: backgroundColor,
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
                      ? Center(child: Text(_error))
                      : _buildContent(),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(onPressed: _agregarAusencia, backgroundColor: AppColors.accentBlue, child: const Icon(Icons.add, color: Colors.white)),
      ),
    );
  }

  Widget _buildHeader() {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 8, 16, 16),
          decoration: const BoxDecoration(color: AppColors.glassFill, border: Border(bottom: BorderSide(color: AppColors.glassBorder))),
          child: Row(
            children: [
              if (Navigator.canPop(context)) IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
              const SizedBox(width: 8),
              const Text('Gestión de Ausencias', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(icon: const Icon(Icons.refresh, color: AppColors.textSecondary), tooltip: 'Actualizar', onPressed: () => _cargarDatos()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _buildCalendarView()),
        SliverToBoxAdapter(child: _buildFilterChips()),
        SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.all(20), child: Text(DateFormat('EEEE d 'de' MMMM', 'es_AR').format(_selectedDay!), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)))),
        if (_ausenciasVisibles.isEmpty) SliverToBoxAdapter(child: _buildEmptyStateForDay()) else _buildAusenciasList()
      ],
    );
  }

  Widget _buildCalendarView() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: AppColors.glassFill, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.glassBorder)),
      child: TableCalendar(
        locale: 'es_AR',
        firstDay: DateTime.utc(2020, 1, 1),
        lastDay: DateTime.utc(2030, 12, 31),
        focusedDay: _focusedDay,
        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
        onDaySelected: (selectedDay, focusedDay) {
          if (!isSameDay(_selectedDay, selectedDay)) {
            setState(() {
              _selectedDay = selectedDay;
              _focusedDay = focusedDay;
            });
            _filtrarAusenciasVisibles();
          }
        },
        eventLoader: (day) => _eventos[DateUtils.dateOnly(day)] ?? [],
        calendarBuilders: CalendarBuilders(
          markerBuilder: (context, date, events) {
            if (events.isEmpty) return null;
            return Positioned(
              right: 1, bottom: 1,
              child: Container(padding: const EdgeInsets.all(5), decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.accentBlue.withOpacity(0.8)), child: Text('${events.length}', style: const TextStyle(color: Colors.white, fontSize: 10))),
            );
          },
        ),
        calendarStyle: CalendarStyle(selectedDecoration: BoxDecoration(color: AppColors.accentBlue, shape: BoxShape.circle), todayDecoration: BoxDecoration(color: AppColors.accentBlue.withOpacity(0.5), shape: BoxShape.circle)),
        headerStyle: const HeaderStyle(titleCentered: true, formatButtonVisible: false, leftChevronIcon: Icon(Icons.chevron_left, color: AppColors.textPrimary), rightChevronIcon: Icon(Icons.chevron_right, color: AppColors.textPrimary)),
      ),
    );
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: ['todos', 'pendiente', 'aprobado', 'rechazado'].map((estado) {
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: FilterChip(
              label: Text(estado[0].toUpperCase() + estado.substring(1)),
              selected: _filtroEstado == estado,
              onSelected: (_) => setState(() { _filtroEstado = estado; _filtrarAusenciasVisibles(); }),
              backgroundColor: AppColors.glassFillStrong,
              selectedColor: AppColors.accentPink.withOpacity(0.8),
              labelStyle: TextStyle(color: _filtroEstado == estado ? Colors.white : AppColors.textSecondary, fontWeight: FontWeight.w500),
              checkmarkColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: AppColors.glassBorder)),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAusenciasList() {
    return SliverList(delegate: SliverChildBuilderDelegate((context, index) {
      final ausencia = _ausenciasVisibles[index];
      final empleado = _empleados.firstWhere((e) => e.cuil == ausencia.empleadoCuil, orElse: () => EmpleadoCompleto.empty(cuil: ausencia.empleadoCuil));
      return _AusenciaCard(ausencia: ausencia, empleado: empleado, onAction: () => _cargarDatos(showLoading: false));
    }, childCount: _ausenciasVisibles.length));
  }

  Widget _buildEmptyStateForDay() {
    return Container(
      padding: const EdgeInsets.all(48), alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [const Icon(Icons.event_available, size: 60, color: AppColors.textMuted), const SizedBox(height: 16), Text('Sin ausencias registradas para este día', style: TextStyle(color: AppColors.textMuted, fontSize: 16), textAlign: TextAlign.center)],
      ),
    );
  }

  void _agregarAusencia() async {
    final resultado = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => AusenciaFormScreen(empresaCuit: widget.empresaCuit, empleados: _empleados)));
    if (resultado == true) _cargarDatos();
  }
}

// WIDGET INDEPENDIENTE PARA LA TARJETA DE AUSENCIA
class _AusenciaCard extends StatelessWidget {
  final Ausencia ausencia;
  final EmpleadoCompleto empleado;
  final VoidCallback onAction;

  const _AusenciaCard({required this.ausencia, required this.empleado, required this.onAction});

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
              Expanded(child: Text(empleado.nombreCompleto, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 8),
              Chip(label: Text(ausencia.estado.name.toUpperCase()), backgroundColor: statusColor.withOpacity(0.2), side: BorderSide.none, labelStyle: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold))
            ],
          ),
          const Divider(height: 24, color: AppColors.glassBorder),
          Text('Tipo: ${ausencia.tipo.displayName}', style: const TextStyle(color: AppColors.textSecondary)),
          Text('Período: ${DateFormat.yMd('es_AR').format(ausencia.fechaDesde)} al ${DateFormat.yMd('es_AR').format(ausencia.fechaHasta)} (${ausencia.diasTotales} días)', style: const TextStyle(color: AppColors.textSecondary)),
          if (ausencia.motivo?.isNotEmpty ?? false) Padding(padding: const EdgeInsets.only(top: 8), child: Text('Motivo: ${ausencia.motivo!}', style: const TextStyle(color: AppColors.textSecondary))),
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
          ElevatedButton(onPressed: () => _updateStatus(context, EstadoAusencia.aprobado), style: ElevatedButton.styleFrom(backgroundColor: AppColors.loanActive, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), child: const Text('Aprobar')),
        ],
      ),
    );
  }

  Future<void> _updateStatus(BuildContext context, EstadoAusencia newStatus) async {
    try {
      await AusenciasService.actualizarEstadoAusencia(ausencia.id, newStatus);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ausencia ${newStatus.name}'), backgroundColor: newStatus == EstadoAusencia.aprobado ? AppColors.loanActive : AppColors.error));
      onAction();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
    }
  }

  Color _getStatusColor(EstadoAusencia estado) {
    switch (estado) {
      case EstadoAusencia.aprobado: return AppColors.loanActive;
      case EstadoAusencia.rechazado: return AppColors.error;
      case EstadoAusencia.pendiente: return AppColors.accentOrange;
      default: return AppColors.textMuted;
    }
  }

  IconData _getAusenciaIcon(TipoAusencia tipo) {
    switch (tipo) {
      case TipoAusencia.vacaciones: return Icons.beach_access_outlined;
      case TipoAusencia.enfermedad: return Icons.sick_outlined;
      case TipoAusencia.estudio: return Icons.school_outlined;
      default: return Icons.event_busy_outlined;
    }
  }
}
