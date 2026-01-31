// Liquidación proporcional / por días – Módulo Docente.
// Institución + Legajo, período, días trabajados. Proporcional = (sueldo/30)×días.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_colors.dart';
import '../services/instituciones_service.dart';
import '../services/teacher_omni_engine.dart' show TeacherOmniEngine, LiquidacionOmniResult;
import '../utils/docente_input_helper.dart';

class LiquidacionProporcionalDocenteScreen extends StatefulWidget {
  const LiquidacionProporcionalDocenteScreen({super.key});

  @override
  State<LiquidacionProporcionalDocenteScreen> createState() => _LiquidacionProporcionalDocenteScreenState();
}

class _LiquidacionProporcionalDocenteScreenState extends State<LiquidacionProporcionalDocenteScreen> {
  List<Map<String, dynamic>> _instituciones = [];
  List<Map<String, dynamic>> _legajos = [];
  String? _cuitSeleccionado;
  Map<String, dynamic>? _instSeleccionada;
  Map<String, dynamic>? _legajoSeleccionado;

  final _diasController = TextEditingController(text: '15');
  final _periodoController = TextEditingController(
    text: DateFormat('MMMM yyyy', 'es_AR').format(DateTime.now()),
  );

  LiquidacionOmniResult? _refMensual;
  bool _calculando = false;

  @override
  void initState() {
    super.initState();
    _cargarInstituciones();
  }

  @override
  void dispose() {
    _diasController.dispose();
    _periodoController.dispose();
    super.dispose();
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
      final periodo = _periodoController.text.trim().isEmpty
          ? DateFormat('MMMM yyyy', 'es_AR').format(DateTime.now())
          : _periodoController.text.trim();
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

  double get _sueldoBruto => _refMensual?.totalBrutoRemunerativo ?? 0.0;

  (double proporcional, int dias)? _calcularProporcional() {
    final d = int.tryParse(_diasController.text) ?? 0;
    if (d <= 0 || d > 31 || _sueldoBruto <= 0) return null;
    final prop = (_sueldoBruto / 30) * d;
    return (prop, d);
  }

  @override
  Widget build(BuildContext context) {
    final p = _calcularProporcional();

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
          'Liquidación proporcional / por días',
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
          TextField(
            controller: _periodoController,
            decoration: const InputDecoration(labelText: 'Período (ej. Enero 2026)'),
            onChanged: (_) => _calcular(),
          ),
          TextField(
            controller: _diasController,
            decoration: const InputDecoration(
              labelText: 'Días trabajados en el mes (1-31)',
              hintText: 'Ej. 15',
            ),
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
          ),
          if (_calculando) const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())),
          if (p != null) ...[
            const SizedBox(height: 24),
            _buildResultado(p.$1, p.$2),
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

  Widget _buildResultado(double proporcional, int dias) {
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
          const Text('Detalle proporcional', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _row('Sueldo bruto mensual (referencia)', _sueldoBruto),
          _row('Días trabajados', dias.toDouble(), esEntero: true),
          _row('Proporcional (sueldo/30 × $dias días)', proporcional, bold: true),
        ],
      ),
    );
  }

  Widget _row(String label, double value, {bool bold = false, bool esEntero = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontWeight: bold ? FontWeight.bold : null)),
        Text(
          esEntero ? value.toInt().toString() : '\$${value.toStringAsFixed(2)}',
          style: TextStyle(fontWeight: bold ? FontWeight.bold : null),
        ),
      ],
    ),
  );
}
