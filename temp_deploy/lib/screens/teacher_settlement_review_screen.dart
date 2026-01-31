// TeacherSettlementReviewScreen – Edición y Previsualización Final SAC/LSD. Estándar 2026.
// Mesa WYSIWYG: TextFormField dinámicos, recálculo en tiempo real (listeners), conceptos manuales (Nombre, Monto, Código AFIP 6), override % Jub/OS/PAMI.

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import '../theme/app_colors.dart';
import '../models/teacher_types.dart';
import '../models/teacher_constants.dart';
import '../models/empresa.dart';
import '../models/empleado.dart';
import '../services/lsd_engine.dart';
import '../utils/pdf_recibo.dart';

/// Argumentos para navegar a la pantalla de edición y previsualización.
class TeacherSettlementReviewArgs {
  final Map<String, dynamic> inst;
  final Map<String, dynamic> legajo;
  final int semestre;
  final int anio;
  final String mayorRem;
  final String dias;
  final String divisor;
  final String fechaPago;
  final double sac;
  final double jub;
  final double os;
  final double pami;
  final List<Map<String, dynamic>> extras; // [{id, descripcion, tipo, monto, codigoAfip?}]
  final double? pctJub;
  final double? pctOS;
  final double? pctPami;

  TeacherSettlementReviewArgs({
    required this.inst,
    required this.legajo,
    required this.semestre,
    required this.anio,
    required this.mayorRem,
    required this.dias,
    required this.divisor,
    required this.fechaPago,
    required this.sac,
    required this.jub,
    required this.os,
    required this.pami,
    required this.extras,
    this.pctJub,
    this.pctOS,
    this.pctPami,
  });
}

/// Divisor sugerido 2026: 1º sem 181, 2º sem 184. Otros años: 180.
int divisorSugeridoSemestre(int semestre, int anio) {
  if (anio == 2026) return semestre == 1 ? 181 : 184;
  return 180;
}

class TeacherSettlementReviewScreen extends StatefulWidget {
  const TeacherSettlementReviewScreen({super.key, required this.args});

  final TeacherSettlementReviewArgs args;

  @override
  State<TeacherSettlementReviewScreen> createState() => _TeacherSettlementReviewScreenState();
}

class _TeacherSettlementReviewScreenState extends State<TeacherSettlementReviewScreen> {
  late TextEditingController _mayorRemC;
  late TextEditingController _diasC;
  late TextEditingController _divisorC;
  late TextEditingController _fechaPagoC;
  late TextEditingController _sacC;
  late TextEditingController _jubC;
  late TextEditingController _osC;
  late TextEditingController _pamiC;
  late TextEditingController _pctJubC;
  late TextEditingController _pctOSC;
  late TextEditingController _pctPamiC;
  final List<Map<String, dynamic>> _extras = [];
  final Map<int, TextEditingController> _extraMontoC = {};
  int _idExtra = 0;

  void _onAnyChange() => setState(() {});

  @override
  void initState() {
    super.initState();
    final a = widget.args;
    _mayorRemC = TextEditingController(text: a.mayorRem);
    _diasC = TextEditingController(text: a.dias);
    _divisorC = TextEditingController(text: a.divisor);
    _fechaPagoC = TextEditingController(text: a.fechaPago);
    _sacC = TextEditingController(text: a.sac.toStringAsFixed(2));
    _jubC = TextEditingController(text: a.jub.toStringAsFixed(2));
    _osC = TextEditingController(text: a.os.toStringAsFixed(2));
    _pamiC = TextEditingController(text: a.pami.toStringAsFixed(2));
    _pctJubC = TextEditingController(text: (a.pctJub ?? _pctJubDefault).toStringAsFixed(1));
    _pctOSC = TextEditingController(text: (a.pctOS ?? _pctOSDefault).toStringAsFixed(1));
    _pctPamiC = TextEditingController(text: (a.pctPami ?? 3.0).toStringAsFixed(1));

    for (final e in a.extras) {
      final id = _nextId();
      _extras.add({
        'id': id,
        'descripcion': e['descripcion'] ?? '',
        'tipo': e['tipo'] ?? 'haber_rem',
        'monto': (e['monto'] as num?)?.toDouble() ?? 0.0,
        'codigoAfip': e['codigoAfip']?.toString(),
      });
      final c = TextEditingController(text: ((e['monto'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2));
      c.addListener(_onAnyChange);
      _extraMontoC[id] = c;
    }

    for (final c in [_mayorRemC, _diasC, _divisorC, _fechaPagoC, _sacC, _jubC, _osC, _pamiC, _pctJubC, _pctOSC, _pctPamiC]) {
      c.addListener(_onAnyChange);
    }
  }

  int _nextId() => ++_idExtra;

  Jurisdiccion get _jurisdiccion {
    final j = widget.args.inst['jurisdiccion']?.toString();
    if (j == null || j.isEmpty) return Jurisdiccion.buenosAires;
    return Jurisdiccion.values.cast<Jurisdiccion?>().firstWhere(
      (e) => e?.name == j,
      orElse: () => Jurisdiccion.buenosAires,
    ) ?? Jurisdiccion.buenosAires;
  }

  TipoGestion get _tipoGestion {
    final t = widget.args.inst['tipoGestion']?.toString();
    if (t == null || t.isEmpty) return TipoGestion.publica;
    return TipoGestion.values.cast<TipoGestion?>().firstWhere(
      (e) => e?.name == t,
      orElse: () => TipoGestion.publica,
    ) ?? TipoGestion.publica;
  }

  JurisdiccionConfigOmni? get _config => JurisdiccionDBOmni.get(_jurisdiccion);

  double get _pctJubDefault {
    final c = _config;
    if (c == null) return 11.0;
    if (_tipoGestion == TipoGestion.privada) return 11.0;
    return c.porcentajeAporte;
  }

  double get _pctOSDefault {
    final c = _config;
    if (c == null) return 3.0;
    if (_tipoGestion == TipoGestion.privada) return 3.0;
    return (c.porcentajeObraSocial ?? 3.0);
  }

  String get _periodoTexto => 'SAC ${widget.args.semestre}º Semestre ${widget.args.anio}';

  double _num(TextEditingController c) => double.tryParse(c.text.replaceAll(',', '.')) ?? 0.0;
  int _int(TextEditingController c) => int.tryParse(c.text.replaceAll(RegExp(r'[^\d]'), '')) ?? 0;

  double get _totalHaberesRem {
    double t = _num(_sacC);
    for (final e in _extras) {
      if ((e['tipo'] ?? '').toString().startsWith('haber')) t += _num(_extraMontoC[e['id'] as int]!);
    }
    return t;
  }

  double get _totalHaberesNoRem {
    double t = 0;
    for (final e in _extras) {
      if ((e['tipo'] ?? '') == 'haber_no_rem') t += _num(_extraMontoC[e['id'] as int]!);
    }
    return t;
  }

  double get _totalDescuentos {
    double t = _num(_jubC) + _num(_osC) + _num(_pamiC);
    for (final e in _extras) {
      if ((e['tipo'] ?? '') == 'descuento') t += _num(_extraMontoC[e['id'] as int]!);
    }
    return t;
  }

  double get _neto => _totalHaberesRem + _totalHaberesNoRem - _totalDescuentos;

  void _recalcularAportesDesdePct() {
    final base = _num(_sacC);
    if (base <= 0) return;
    final pJ = _num(_pctJubC);
    final pO = _num(_pctOSC);
    final pP = _num(_pctPamiC);
    setState(() {
      _jubC.text = (base * pJ / 100).toStringAsFixed(2);
      _osC.text = (base * pO / 100).toStringAsFixed(2);
      _pamiC.text = (base * pP / 100).toStringAsFixed(2);
    });
  }

  Future<void> _agregarConceptoManual() async {
    final descC = TextEditingController();
    final montoC = TextEditingController(text: '0');
    final codC = TextEditingController(text: '120000');
    String tipo = 'haber_rem';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setD) => AlertDialog(
          title: const Text('Agregar concepto manual'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(controller: descC, decoration: const InputDecoration(labelText: 'Nombre')),
                const SizedBox(height: 8),
                TextField(controller: montoC, decoration: const InputDecoration(labelText: 'Monto (\$)'), keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                const SizedBox(height: 8),
                TextField(controller: codC, decoration: const InputDecoration(labelText: 'Código AFIP (6 dígitos)', hintText: '120000'), keyboardType: TextInputType.number, maxLength: 6),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: tipo,
                  decoration: const InputDecoration(labelText: 'Tipo'),
                  items: const [
                    DropdownMenuItem(value: 'haber_rem', child: Text('Haber remunerativo')),
                    DropdownMenuItem(value: 'haber_no_rem', child: Text('Haber no remunerativo')),
                    DropdownMenuItem(value: 'descuento', child: Text('Deducción')),
                  ],
                  onChanged: (v) => setD(() => tipo = v ?? tipo),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Agregar')),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    final desc = descC.text.trim();
    if (desc.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ingrese nombre')));
      return;
    }
    final m = double.tryParse(montoC.text.replaceAll(',', '.'));
    if (m == null) return;
    final cod = codC.text.replaceAll(RegExp(r'[^\d]'), '').padLeft(6, '0');
    final code = cod.length >= 6 ? cod.substring(0, 6) : cod.padLeft(6, '0');

    final id = _nextId();
    _extras.add({'id': id, 'descripcion': desc, 'tipo': tipo, 'monto': m, 'codigoAfip': code});
    final tc = TextEditingController(text: m.toStringAsFixed(2));
    tc.addListener(_onAnyChange);
    _extraMontoC[id] = tc;
    setState(() {});
  }

  void _quitarExtra(int id) {
    _extraMontoC[id]?.dispose();
    _extraMontoC.remove(id);
    _extras.removeWhere((e) => e['id'] == id);
    setState(() {});
  }

  List<Map<String, dynamic>> _getConceptosParaPdfLsd() {
    final list = <Map<String, dynamic>>[
      {'id': 'sac', 'descripcion': 'SAC (50% mayor remuneración)', 'tipo': 'haber_rem', 'monto': _num(_sacC), 'codigoAfip': '120000'},
      {'id': 'jub', 'descripcion': 'Jubilación', 'tipo': 'descuento', 'monto': _num(_jubC), 'codigoAfip': '810001'},
      {'id': 'os', 'descripcion': 'Obra Social', 'tipo': 'descuento', 'monto': _num(_osC), 'codigoAfip': '810003'},
      {'id': 'pami', 'descripcion': 'Ley 19.032 (PAMI)', 'tipo': 'descuento', 'monto': _num(_pamiC), 'codigoAfip': '810002'},
    ];
    for (final e in _extras) {
      final m = _num(_extraMontoC[e['id'] as int]!);
      final cod = e['codigoAfip']?.toString();
      final codigo = (cod != null && cod.length >= 6)
          ? cod.replaceAll(RegExp(r'[^\d]'), '').padLeft(6, '0').substring(0, 6)
          : LSDGenerator.obtenerCodigoArca2026(e['descripcion']?.toString() ?? '');
      list.add({
        'id': 'extra_${e['id']}',
        'descripcion': e['descripcion'] ?? '',
        'tipo': e['tipo'] ?? 'haber_rem',
        'monto': m,
        'codigoAfip': codigo,
      });
    }
    return list;
  }

  Future<void> _generarPdf() async {
    final inst = widget.args.inst;
    final legajo = widget.args.legajo;
    final conceptos = _getConceptosParaPdfLsd();
    final bruto = _totalHaberesRem;
    final noRem = _totalHaberesNoRem;
    final deduc = _totalDescuentos;
    final neto = _neto;
    final dias = _int(_diasC);
    final divisor = _int(_divisorC);
    if (divisor <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Divisor debe ser > 0')));
      return;
    }
    final mayorRem = _num(_mayorRemC);
    final baseDeCalculo = mayorRem > 0 ? (mayorRem / 2.0) : 0.0;
    final mesPeriodo = widget.args.semestre == 1 ? 'Junio' : 'Diciembre';
    final leyendaDep = 'Período $mesPeriodo ${widget.args.anio} - Banco ${inst['bancoAcreditacion'] ?? inst['razonSocial'] ?? ''}';

    final emp = Empresa(
      razonSocial: inst['razonSocial']?.toString() ?? '',
      cuit: (inst['cuit']?.toString() ?? '').replaceAll(RegExp(r'[^\d]'), ''),
      domicilio: inst['domicilio']?.toString() ?? '',
      convenioId: 'docente_sac',
      convenioNombre: 'SAC Docente',
      convenioPersonalizado: false,
      categorias: [],
      parametros: [],
    );
    final cargo = legajo['cargo']?.toString().trim() ?? '';
    final empr = Empleado(
      nombre: legajo['nombre']?.toString() ?? '',
      categoria: cargo.isEmpty ? 'SAC - $_periodoTexto' : '$cargo - SAC - $_periodoTexto',
      sueldoBasico: bruto,
      periodo: _periodoTexto,
      fechaPago: _fechaPagoC.text.trim(),
      lugarPago: inst['domicilio']?.toString(),
      fechaIngreso: legajo['fechaIngreso']?.toString(),
    );
    final conceptosPdf = conceptos.map((c) {
      final t = c['tipo']?.toString() ?? '';
      final m = (c['monto'] as num?)?.toDouble() ?? 0;
      return ConceptoParaPDF(
        descripcion: c['descripcion']?.toString() ?? '',
        remunerativo: t == 'haber_rem' ? m : 0,
        noRemunerativo: t == 'haber_no_rem' ? m : 0,
        descuento: t == 'descuento' ? m : 0,
      );
    }).toList();

    final pdfBytes = await PdfRecibo.generarCompleto(
      empresa: emp,
      empleado: empr,
      conceptos: conceptosPdf,
      sueldoBruto: bruto,
      totalDeducciones: deduc,
      totalNoRemunerativo: noRem,
      sueldoNeto: neto,
      diasTrabajadosSemestre: dias,
      divisorUsado: divisor,
      baseDeCalculo: baseDeCalculo,
      leyendaUltimoDepositoAportes: leyendaDep,
      incluirBloqueFirmaLey25506: true,
    );

    final dir = await getApplicationDocumentsDirectory();
    final cuilLimpio = (legajo['cuil']?.toString() ?? '').replaceAll(RegExp(r'[^\d]'), '');
    final nombre = legajo['nombre']?.toString().replaceAll(RegExp(r'[^\w]'), '_') ?? 'empleado';
    final f = File('${dir.path}${Platform.pathSeparator}recibo_sac_${nombre}_$cuilLimpio.pdf');
    await f.writeAsBytes(pdfBytes);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('PDF: ${f.path}')));
      OpenFile.open(f.path);
    }
  }

  Future<void> _generarLsd() async {
    final inst = widget.args.inst;
    final legajo = widget.args.legajo;
    final cuit = (inst['cuit']?.toString() ?? '').replaceAll(RegExp(r'[^\d]'), '');
    final cuil = (legajo['cuil']?.toString() ?? '').replaceAll(RegExp(r'[^\d]'), '');
    if (cuit.length != 11 || cuil.length != 11) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('CUIT/CUIL inválido')));
      return;
    }
    final fechaPago = _fechaPagoC.text.trim();
    if (fechaPago.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ingrese fecha de pago')));
      return;
    }

    final conceptos = _getConceptosParaPdfLsd();
    final sac = _num(_sacC);
    final baseTopeada = sac > ParametrosFederales2026Omni.topePrevisional ? ParametrosFederales2026Omni.topePrevisional : sac;

    try {
      final reg1 = LSDGenerator.generateRegistro1(
        cuitEmpresa: cuit,
        periodo: _periodoTexto,
        fechaPago: fechaPago,
        razonSocial: inst['razonSocial']?.toString() ?? '',
        domicilio: inst['domicilio']?.toString() ?? '',
        tipoLiquidacion: 'S',
      );

      final sb = StringBuffer();
      sb.write(latin1.decode(reg1));
      sb.write(LSDGenerator.eolLsd);

      for (final c in conceptos) {
        final m = (c['monto'] as num?)?.toDouble() ?? 0.0;
        if (m <= 0) continue;
        final t = (c['tipo'] ?? '') == 'descuento' ? 'D' : 'H';
        final cod = (c['codigoAfip'] ?? '120000').toString().replaceAll(RegExp(r'[^\d]'), '').padLeft(6, '0').substring(0, 6);
        final reg2 = LSDGenerator.generateRegistro2Arca2026(
          cuilEmpleado: cuil,
          codigoArca6: cod,
          importe: m,
          tipo: t,
          descripcion: c['descripcion']?.toString() ?? '',
        );
        sb.write(latin1.decode(reg2));
        sb.write(LSDGenerator.eolLsd);
      }

      final reg3 = LSDGenerator.generateRegistro3BasesArca2026(
        cuilEmpleado: cuil,
        bases: [baseTopeada, baseTopeada, baseTopeada, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
      );
      sb.write(latin1.decode(reg3));
      sb.write(LSDGenerator.eolLsd);

      final dir = await getApplicationDocumentsDirectory();
      final nombre = legajo['nombre']?.toString().replaceAll(RegExp(r'[^\w]'), '_') ?? 'empleado';
      final f = File('${dir.path}${Platform.pathSeparator}LSD_SAC_${nombre}_${DateFormat('yyyyMMdd').format(DateTime.now())}.txt');
      await f.writeAsString(sb.toString(), encoding: latin1);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('LSD: ${f.path}')));
        OpenFile.open(f.path);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error LSD: $e')));
    }
  }

  @override
  void dispose() {
    for (final c in [_mayorRemC, _diasC, _divisorC, _fechaPagoC, _sacC, _jubC, _osC, _pamiC, _pctJubC, _pctOSC, _pctPamiC]) c.dispose();
    for (final c in _extraMontoC.values) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          'Edición y Previsualización SAC',
          style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _card('Parámetros', [
            _row('Días trabajados', _diasC),
            _row('Divisor del semestre', _divisorC, hint: '181 (1º) / 184 (2º) 2026, o 180'),
            _row('Mejor remuneración (\$)', _mayorRemC),
            _row('Fecha de pago', _fechaPagoC, keyboardType: TextInputType.text),
          ]),
          const SizedBox(height: 16),
          _card('Override % (opcional) – Recalcular aportes desde SAC', [
            _row('Jubilación (%)', _pctJubC),
            _row('Obra Social (%)', _pctOSC),
            _row('PAMI (%)', _pctPamiC),
            TextButton.icon(
              onPressed: _recalcularAportesDesdePct,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Recalcular aportes desde %'),
            ),
          ]),
          const SizedBox(height: 16),
          _card('Haberes y deducciones (editables)', [
            _row('SAC', _sacC),
            _row('Jubilación', _jubC),
            _row('Obra Social', _osC),
            _row('PAMI', _pamiC),
            ..._extras.map((e) {
              final id = e['id'] as int;
              final desc = e['descripcion']?.toString() ?? '';
              final isDesc = (e['tipo'] ?? '') == 'descuento';
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Icon(isDesc ? Icons.remove_circle_outline : Icons.add_circle_outline, size: 20, color: AppColors.textSecondary),
                    const SizedBox(width: 8),
                    Expanded(child: Text(desc, style: const TextStyle(fontSize: 14))),
                    SizedBox(
                      width: 110,
                      child: TextFormField(
                        controller: _extraMontoC[id],
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                    IconButton(icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red), onPressed: () => _quitarExtra(id)),
                  ],
                ),
              );
            }),
            TextButton.icon(onPressed: _agregarConceptoManual, icon: const Icon(Icons.add, size: 18), label: const Text('Agregar concepto manual (Nombre, Monto, Código AFIP)')),
          ]),
          const SizedBox(height: 16),
          _card('Totales (recalculados al instante)', [
            _totRow('Total Haberes Rem.', _totalHaberesRem),
            _totRow('Total No Rem.', _totalHaberesNoRem),
            _totRow('Total Deducciones', _totalDescuentos),
            const Divider(),
            _totRow('NETO A COBRAR', _neto, bold: true),
          ]),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: FilledButton.icon(onPressed: _generarPdf, icon: const Icon(Icons.picture_as_pdf), label: const Text('Generar PDF'))),
              const SizedBox(width: 12),
              Expanded(child: FilledButton.icon(onPressed: _generarLsd, icon: const Icon(Icons.description), label: const Text('Generar LSD'))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _card(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.pastelBlue.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _row(String label, TextEditingController c, {String? hint, TextInputType? keyboardType}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(width: 160, child: Text(label, style: const TextStyle(fontSize: 14))),
          Expanded(
            child: TextFormField(
              controller: c,
              decoration: InputDecoration(isDense: true, hintText: hint),
              keyboardType: keyboardType ?? const TextInputType.numberWithOptions(decimal: true),
            ),
          ),
        ],
      ),
    );
  }

  Widget _totRow(String label, double value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 14, fontWeight: bold ? FontWeight.bold : FontWeight.w500)),
          Text('\$${value.toStringAsFixed(2)}', style: TextStyle(fontSize: bold ? 15 : 14, fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }
}
