// Liquidación final (cese / desvinculación) – Módulo Docente.
// Indemnización antigüedad, preaviso, integración mes, vacaciones no gozadas, SAC proporcional.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_colors.dart';
import '../services/instituciones_service.dart';
import '../services/teacher_omni_engine.dart' show TeacherOmniEngine, LiquidacionOmniResult;
import '../services/antiguedad_service.dart';
import '../services/vacaciones_service.dart';
import '../utils/docente_input_helper.dart';

class LiquidacionFinalDocenteScreen extends StatefulWidget {
  const LiquidacionFinalDocenteScreen({super.key});

  @override
  State<LiquidacionFinalDocenteScreen> createState() => _LiquidacionFinalDocenteScreenState();
}

class _LiquidacionFinalDocenteScreenState extends State<LiquidacionFinalDocenteScreen> {
  List<Map<String, dynamic>> _instituciones = [];
  List<Map<String, dynamic>> _legajos = [];
  String? _cuitSeleccionado;
  Map<String, dynamic>? _instSeleccionada;
  Map<String, dynamic>? _legajoSeleccionado;

  DateTime _fechaCese = DateTime.now();
  LiquidacionOmniResult? _refMensual;
  bool _calculando = false;

  @override
  void initState() {
    super.initState();
    _cargarInstituciones();
  }

  Future<void> _cargarInstituciones() async {
    final list = await InstitucionesService.getInstituciones();
    if (mounted) setState(() => _instituciones = list);
  }

  Future<void> _cargarLegajos() async {
    final c = _cuitSeleccionado;
    if (c == null || c.isEmpty) return;
    final list = await InstitucionesService.getLegajosDocente(c);
    if (mounted) setState(() => _legajos = list);
  }

  void _onInstitucionChanged(String? cuit) {
    if (cuit == null) return;
    final inst = _instituciones.cast<Map<String, dynamic>?>().firstWhere(
      (e) => (e?['cuit']?.toString() ?? '').replaceAll(RegExp(r'[^\d]'), '') == cuit,
      orElse: () => null,
    );
    setState(() {
      _cuitSeleccionado = cuit;
      _instSeleccionada = inst;
      _legajoSeleccionado = null;
      _refMensual = null;
    });
    _cargarLegajos();
  }

  void _onLegajoChanged(Map<String, dynamic>? leg) {
    setState(() {
      _legajoSeleccionado = leg;
      _refMensual = null;
    });
    if (leg != null) _calcular();
  }

  Future<void> _calcular() async {
    final inst = _instSeleccionada;
    final leg = _legajoSeleccionado;
    if (inst == null || leg == null) return;

    setState(() => _calculando = true);
    try {
      final res = buildDocenteOmniInputFromMaps(inst: inst, legajo: leg);
      final cantidadCargos = (leg['cantidadCargos'] is int)
          ? leg['cantidadCargos'] as int
          : (int.tryParse(leg['cantidadCargos']?.toString() ?? '') ?? 1);
      final periodo = DateFormat('MMMM yyyy', 'es_AR').format(_fechaCese);
      final fechaPago = DateFormat('dd/MM/yyyy').format(DateTime.now());

      final r = TeacherOmniEngine.liquidar(
        res.input,
        periodo: periodo,
        fechaPago: fechaPago,
        cantidadCargos: cantidadCargos,
        conceptosPropios: res.conceptosPropios,
      );
      if (!mounted) return;
      setState(() {
        _refMensual = r;
        _calculando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _calculando = false;
        _refMensual = null;
      });
    }
  }

  double get _sueldo => _refMensual?.totalBrutoRemunerativo ?? 0.0;

  Map<String, double>? _calcularFinal() {
    if (_sueldo <= 0 || _legajoSeleccionado == null) return null;
    final fi = _legajoSeleccionado!['fechaIngreso']?.toString();
    if (fi == null || fi.isEmpty) return null;

    String fiLct = fi;
    if (fi.contains('-')) {
      final d = DateTime.tryParse(fi);
      if (d != null) fiLct = DateFormat('dd/MM/yyyy').format(d);
    }
    final periodoCese = DateFormat('MMMM yyyy', 'es_AR').format(_fechaCese);
    final anios = AntiguedadService.calcularAniosAntiguedad(fiLct, periodoCese);
    if (anios < 0) return null;

    // Indemnización art. 245: 1 mes por año (sueldo = mejor mes, aproximamos con totalBruto)
    final indemnizacionAntiguedad = anios * _sueldo;

    // Preaviso art. 231: 1 mes si antigüedad < 5, 2 si >= 5
    final preaviso = (anios < 5 ? 1.0 : 2.0) * _sueldo;

    // Integración mes art. 245: 1/2 mes
    final integracion = 0.5 * _sueldo;

    // Vacaciones no gozadas: días según antigüedad al cese, monto (sueldo/25)*dias, plus
    final diasVac = VacacionesService.calcularDiasVacaciones(
      fechaIngreso: fiLct,
      periodoLiquidacion: periodoCese,
    );
    final d = diasVac['dias'] as int? ?? 0;
    final montoVac = d > 0 ? VacacionesService.calcularMontoVacaciones(_sueldo, d) : 0.0;
    final plusVac = d > 0 ? VacacionesService.calcularPlusVacacional(_sueldo, d) : 0.0;

    // SAC proporcional: (sueldo/12) * meses trabajados en el semestre
    final semestre = _fechaCese.month <= 6 ? 1 : 2;
    int mesesEnSemestre;
    if (semestre == 1) {
      mesesEnSemestre = _fechaCese.month; // Ene=1 .. Jun=6
    } else {
      mesesEnSemestre = _fechaCese.month - 6; // Jul=1 .. Dic=6
    }
    final sacProporcional = (_sueldo / 12) * mesesEnSemestre;

    final total = indemnizacionAntiguedad + preaviso + integracion + montoVac + plusVac + sacProporcional;
    return {
      'indemnizacionAntiguedad': indemnizacionAntiguedad,
      'preaviso': preaviso,
      'integracion': integracion,
      'vacaciones': montoVac,
      'plusVacacional': plusVac,
      'sacProporcional': sacProporcional,
      'total': total,
    };
  }

  @override
  Widget build(BuildContext context) {
    final vals = _calcularFinal();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Liquidación final (cese)',
          style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildDropdownInstitucion(),
          const SizedBox(height: 16),
          _buildDropdownLegajo(),
          const SizedBox(height: 16),
          ListTile(
            title: const Text('Fecha de cese'),
            subtitle: Text(DateFormat('dd/MM/yyyy').format(_fechaCese)),
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: _fechaCese,
                firstDate: DateTime(2000),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (d != null) {
                setState(() {
                  _fechaCese = d;
                  _calcular();
                });
              }
            },
          ),
          if (_calculando) const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())),
          if (vals != null) ...[
            const SizedBox(height: 24),
            _buildResultado(vals),
          ],
        ],
      ),
    );
  }

  Widget _buildDropdownInstitucion() {
    if (_instituciones.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.glassFillStrong,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: DropdownButtonFormField<String?>(
        value: _cuitSeleccionado,
        decoration: const InputDecoration(labelText: 'Institución'),
        items: [
          const DropdownMenuItem(value: null, child: Text('Seleccione institución')),
          ..._instituciones
              .where((e) => (e['cuit']?.toString() ?? '').replaceAll(RegExp(r'[^\d]'), '').length == 11)
              .map((e) {
            final c = (e['cuit']?.toString() ?? '').replaceAll(RegExp(r'[^\d]'), '');
            return DropdownMenuItem(value: c, child: Text(e['razonSocial']?.toString() ?? c));
          }),
        ],
        onChanged: (v) => _onInstitucionChanged(v),
      ),
    );
  }

  Widget _buildDropdownLegajo() {
    if (_cuitSeleccionado == null || _legajos.isEmpty) return const SizedBox.shrink();
    final items = <Map<String, dynamic>?>[null, ..._legajos];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.glassFillStrong,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: DropdownButtonFormField<Map<String, dynamic>?>(
        value: items.contains(_legajoSeleccionado) ? _legajoSeleccionado : null,
        decoration: const InputDecoration(labelText: 'Empleado'),
        items: items.map((l) => DropdownMenuItem(
          value: l,
          child: Text(l == null ? '+ Seleccione empleado' : '${l['nombre'] ?? ''} — ${l['cuil'] ?? ''}'),
        )).toList(),
        onChanged: (v) => _onLegajoChanged(v),
      ),
    );
  }

  Widget _buildResultado(Map<String, double> v) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.pastelBlue.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Detalle liquidación final', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _row('Indemnización por antigüedad (art. 245 LCT)', v['indemnizacionAntiguedad']!),
          _row('Preaviso (art. 231 LCT)', v['preaviso']!),
          _row('Integración mes (art. 245 LCT)', v['integracion']!),
          _row('Vacaciones no gozadas', v['vacaciones']!),
          _row('Plus vacacional', v['plusVacacional']!),
          _row('SAC proporcional', v['sacProporcional']!),
          const Divider(),
          _row('TOTAL LIQUIDACIÓN FINAL', v['total']!, bold: true),
        ],
      ),
    );
  }

  Widget _row(String label, double value, {bool bold = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(child: Text(label, style: TextStyle(fontWeight: bold ? FontWeight.bold : null, fontSize: 13))),
        Text('\$${value.toStringAsFixed(2)}', style: TextStyle(fontWeight: bold ? FontWeight.bold : null)),
      ],
    ),
  );
}
