// Liquidación de vacaciones – Módulo Docente.
// Institución + Legajo, período. VacacionesService + sueldo de TeacherOmniEngine. Export LSD.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/file_saver.dart';
import '../theme/app_colors.dart';
import '../services/instituciones_service.dart';
import '../services/teacher_omni_engine.dart' show TeacherOmniEngine, LiquidacionOmniResult;
import '../services/vacaciones_service.dart';
import '../services/lsd_engine.dart';
import '../utils/docente_input_helper.dart';

class LiquidacionVacacionesDocenteScreen extends StatefulWidget {
  const LiquidacionVacacionesDocenteScreen({super.key});

  @override
  State<LiquidacionVacacionesDocenteScreen> createState() => _LiquidacionVacacionesDocenteScreenState();
}

class _LiquidacionVacacionesDocenteScreenState extends State<LiquidacionVacacionesDocenteScreen> {
  List<Map<String, dynamic>> _instituciones = [];
  List<Map<String, dynamic>> _legajos = [];
  String? _cuitSeleccionado;
  Map<String, dynamic>? _instSeleccionada;
  Map<String, dynamic>? _legajoSeleccionado;

  final _periodoController = TextEditingController(
    text: DateFormat('MMMM yyyy', 'es_AR').format(DateTime.now()),
  );
  final _diasController = TextEditingController();
  final _fechaPagoController = TextEditingController(
    text: DateFormat('dd/MM/yyyy').format(DateTime.now()),
  );

  LiquidacionOmniResult? _refMensual;
  String? _mensajeDias;
  bool _calculando = false;

  @override
  void initState() {
    super.initState();
    _cargarInstituciones();
  }

  @override
  void dispose() {
    _periodoController.dispose();
    _diasController.dispose();
    _fechaPagoController.dispose();
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
      _mensajeDias = null;
    });
    _cargarLegajos();
  }

  void _onLegajoChanged(Map<String, dynamic>? leg) {
    setState(() {
      _legajoSeleccionado = leg;
      _refMensual = null;
      _mensajeDias = null;
    });
    if (leg != null) _calcular();
  }

  Future<void> _calcular() async {
    final inst = _instSeleccionada;
    final leg = _legajoSeleccionado;
    if (inst == null || leg == null) return;

    final fi = leg['fechaIngreso']?.toString();
    if (fi == null || fi.isEmpty) {
      setState(() => _mensajeDias = 'Falta fecha de ingreso en el legajo');
      return;
    }

    setState(() => _calculando = true);
    try {
      final res = buildDocenteOmniInputFromMaps(inst: inst, legajo: leg);
      final cantidadCargos = (leg['cantidadCargos'] is int)
          ? leg['cantidadCargos'] as int
          : (int.tryParse(leg['cantidadCargos']?.toString() ?? '') ?? 1);
      final periodo = _periodoController.text.trim().isEmpty
          ? DateFormat('MMMM yyyy', 'es_AR').format(DateTime.now())
          : _periodoController.text.trim();
      final fechaPago = _fechaPagoController.text.trim().isEmpty
          ? DateFormat('dd/MM/yyyy').format(DateTime.now())
          : _fechaPagoController.text.trim();

      final r = TeacherOmniEngine.liquidar(
        res.input,
        periodo: periodo,
        fechaPago: fechaPago,
        cantidadCargos: cantidadCargos,
        conceptosPropios: res.conceptosPropios,
      );

      final diasResult = VacacionesService.calcularDiasVacaciones(
        fechaIngreso: fi.contains('-') ? _ddMMyyyyFromIso(fi) : fi,
        periodoLiquidacion: periodo,
      );
      final dias = int.tryParse(_diasController.text) ?? diasResult['dias'] as int? ?? 0;
      final d = dias > 0 ? dias : (diasResult['dias'] as int? ?? 0);
      _mensajeDias = VacacionesService.obtenerMensajeCalculo(diasResult);

      if (!mounted) return;
      setState(() {
        _refMensual = r;
        _mensajeDias = _mensajeDias;
        if (d > 0 && _diasController.text.isEmpty) _diasController.text = '$d';
        _calculando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _calculando = false;
        _mensajeDias = 'Error: $e';
      });
    }
  }

  static String _ddMMyyyyFromIso(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return DateFormat('dd/MM/yyyy').format(d);
  }

  double get _sueldoBruto => _refMensual?.totalBrutoRemunerativo ?? 0.0;

  (int dias, double montoVac, double plus, double total) _calcularVacaciones() {
    final d = int.tryParse(_diasController.text) ?? 0;
    if (d <= 0 || _sueldoBruto <= 0) return (0, 0, 0, 0);
    final monto = VacacionesService.calcularMontoVacaciones(_sueldoBruto, d);
    final plus = VacacionesService.calcularPlusVacacional(_sueldoBruto, d);
    return (d, monto, plus, monto + plus);
  }

  Future<void> _exportarLsd() async {
    final v = _calcularVacaciones();
    if (v.$1 <= 0 || v.$4 <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Calcule primero: seleccione legajo, ingrese días y obtenga sueldo de referencia')),
      );
      return;
    }
    final cuit = _instSeleccionada?['cuit']?.toString().replaceAll(RegExp(r'[^\d]'), '') ?? '';
    final cuil = _legajoSeleccionado?['cuil']?.toString().replaceAll(RegExp(r'[^\d]'), '') ?? '';
    if (cuit.length != 11 || cuil.length != 11) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Institución y empleado con CUIT/CUIL de 11 dígitos')));
      return;
    }
    final fechaPago = _fechaPagoController.text.trim();
    if (fechaPago.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fecha de pago')));
      return;
    }
    try {
      final periodo = _periodoController.text.trim();
      final reg1 = LSDGenerator.generateRegistro1(
        cuitEmpresa: cuit,
        periodo: periodo,
        fechaPago: fechaPago,
        razonSocial: _instSeleccionada!['razonSocial']?.toString() ?? '',
        domicilio: _instSeleccionada!['domicilio']?.toString() ?? '',
      );
      final codVac = LSDGenerator.obtenerCodigoInternoConcepto('Vacaciones');
      final codPlus = LSDGenerator.obtenerCodigoInternoConcepto('Plus Vacacional');
      
      // Registro 2: Datos Referenciales (Nuevo ARCA)
      final reg2 = LSDGenerator.generateRegistro2DatosReferenciales(
        cuilEmpleado: cuil,
        diasBase: 30,
      );
      
      final reg3a = LSDGenerator.generateRegistro3Conceptos(
        cuilEmpleado: cuil,
        codigoConcepto: codVac,
        importe: v.$2,
        descripcionConcepto: 'Vacaciones (${v.$1} días)',
        cantidad: v.$1,
        tipo: 'H',
      );
      final reg3b = LSDGenerator.generateRegistro3Conceptos(
        cuilEmpleado: cuil,
        codigoConcepto: codPlus,
        importe: v.$3,
        descripcionConcepto: 'Plus Vacacional',
        tipo: 'H',
      );
      final base = v.$4;
      
      // Bases imponibles (10 bases)
      final bases = List<double>.filled(10, 0.0);
      bases[0] = base; bases[1] = base; bases[2] = base; bases[8] = base;
      
      final reg4 = LSDGenerator.generateRegistro4Bases(
        cuilEmpleado: cuil,
        bases: bases,
      );
      
      // Datos complementarios
      final reg5 = LSDGenerator.generateRegistro5DatosComplementarios(
        cuilEmpleado: cuil,
        codigoRnos: '115404', // OSDOP default docente
      );
      
      final sb = StringBuffer();
      sb.write(latin1.decode(reg1));
      sb.write(LSDGenerator.eolLsd);
      sb.write(latin1.decode(reg2));
      sb.write(LSDGenerator.eolLsd);
      sb.write(latin1.decode(reg3a));
      sb.write(LSDGenerator.eolLsd);
      sb.write(latin1.decode(reg3b));
      sb.write(LSDGenerator.eolLsd);
      sb.write(latin1.decode(reg4));
      sb.write(LSDGenerator.eolLsd);
      sb.write(latin1.decode(reg5));
      sb.write(LSDGenerator.eolLsd);

      final name = 'LSD_Vacaciones_Docente_${_legajoSeleccionado!['nombre']?.toString().replaceAll(RegExp(r'[^\w]'), '_') ?? 'emp'}_${DateFormat('yyyyMMdd').format(DateTime.now())}.txt';
      final filePath = await saveTextFile(fileName: name, content: sb.toString(), mimeType: 'text/plain');
      
      if (!mounted) return;
      
      final esWeb = filePath == 'descargado';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(esWeb ? 'LSD generado y descargado' : 'Exportado: $filePath')),
      );
      if (!esWeb && filePath != null) openFile(filePath);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = _calcularVacaciones();

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
          'Liquidación de vacaciones',
          style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      persistentFooterButtons: [
        TextButton(onPressed: _exportarLsd, child: const Text('Exportar LSD')),
      ],
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
            decoration: const InputDecoration(labelText: 'Días de vacaciones (opcional: se calculan por antigüedad)'),
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
          ),
          TextField(
            controller: _fechaPagoController,
            decoration: const InputDecoration(labelText: 'Fecha de pago (DD/MM/AAAA)'),
          ),
          if (_mensajeDias != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.pastelMint.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.glassBorder),
                ),
                child: Text(_mensajeDias!, style: const TextStyle(fontSize: 13)),
              ),
            ),
          if (_calculando) const Padding(padding: EdgeInsets.only(top: 16), child: Center(child: CircularProgressIndicator())),
          if (v.$1 > 0 && v.$4 > 0) ...[
            const SizedBox(height: 24),
            _buildResultado(v.$1, v.$2, v.$3, v.$4),
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

  Widget _buildResultado(int dias, double montoVac, double plus, double total) {
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
          const Text('Detalle vacaciones', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _row('Sueldo de referencia (bruto)', _sueldoBruto),
          _row('Vacaciones ($dias días)', montoVac),
          _row('Plus vacacional', plus),
          const Divider(),
          _row('Total bruto vacaciones', total, bold: true),
        ],
      ),
    );
  }

  Widget _row(String label, double value, {bool bold = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontWeight: bold ? FontWeight.bold : null)),
        Text('\$${value.toStringAsFixed(2)}', style: TextStyle(fontWeight: bold ? FontWeight.bold : null)),
      ],
    ),
  );
}
