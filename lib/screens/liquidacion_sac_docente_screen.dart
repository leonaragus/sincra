// Liquidación de SAC (Aguinaldo) – Módulo Docente. ARCA 2026.
// SAC proporcional: (Mejor_Remuneracion_Semestre/2) * (Dias_Trabajados/180).
// LSD con códigos ARCA 2026 (120000, 810001, 810002, 810003). Reg1 tipo S, Reg2 150ch, Reg3 10 bases 230ch.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/file_saver.dart';
import '../theme/app_colors.dart';
import '../models/teacher_types.dart';
import '../models/teacher_constants.dart';
import '../models/empresa.dart';
import '../models/empleado.dart';
import '../services/instituciones_service.dart';
import '../services/lsd_engine.dart';
import '../services/teacher_omni_engine.dart';
import '../services/perfil_sac_service.dart';
import '../utils/pdf_recibo.dart';
import 'teacher_settlement_review_screen.dart';

class LiquidacionSacDocenteScreen extends StatefulWidget {
  const LiquidacionSacDocenteScreen({super.key});

  @override
  State<LiquidacionSacDocenteScreen> createState() => _LiquidacionSacDocenteScreenState();
}

class _LiquidacionSacDocenteScreenState extends State<LiquidacionSacDocenteScreen> {
  List<Map<String, dynamic>> _instituciones = [];
  List<Map<String, dynamic>> _legajos = [];
  String? _cuitSeleccionado;
  Map<String, dynamic>? _instSeleccionada;
  Map<String, dynamic>? _legajoSeleccionado;

  final _mayorRemuneracionController = TextEditingController();
  final _diasTrabajadosController = TextEditingController(text: '180');
  final _divisorController = TextEditingController(text: '181'); // 181 (1º) / 184 (2º) 2026, o 180
  int _semestre = 1; // 1 = Ene–Jun, 2 = Jul–Dic
  int _anio = DateTime.now().year;
  final _fechaPagoController = TextEditingController(text: '');

  /// Overrides de montos para los 4 conceptos base (sac, jub, os, pami). Si no hay key, se usa el valor del engine.
  final Map<String, double> _overrides = {};
  /// Ítems extras (por % o monto) añadidos por el usuario. Cada uno: descripcion, tipo, valor, esPorcentaje, baseParaPct.
  List<Map<String, dynamic>> _itemsExtras = [];
  int _idExtra = 0;
  List<Map<String, dynamic>> _perfilesSac = [];

  @override
  void initState() {
    super.initState();
    _cargarInstituciones();
    _cargarPerfilesSac();
    final n = DateTime.now();
    _fechaPagoController.text = _fechaPagoController.text.isEmpty
        ? DateFormat('dd/MM/yyyy').format(n)
        : _fechaPagoController.text;
  }

  Future<void> _cargarPerfilesSac() async {
    final list = await PerfilSacService.getPerfiles();
    if (mounted) setState(() => _perfilesSac = list);
  }

  @override
  void dispose() {
    _mayorRemuneracionController.dispose();
    _diasTrabajadosController.dispose();
    _divisorController.dispose();
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
    Map<String, dynamic>? inst;
    for (final e in _instituciones) {
      if ((e['cuit']?.toString() ?? '').replaceAll(RegExp(r'[^\d]'), '') == cuit) {
        inst = e;
        break;
      }
    }
    setState(() {
      _cuitSeleccionado = cuit;
      _instSeleccionada = inst;
      _legajoSeleccionado = null;
    });
    _cargarLegajos();
  }

  void _onLegajoChanged(Map<String, dynamic>? leg) {
    setState(() => _legajoSeleccionado = leg);
  }

  /// Divisor sugerido 2026: 1º sem 181, 2º sem 184. Otros años: 180.
  void _aplicarDivisorSugerido() {
    final d = _anio == 2026 ? (_semestre == 1 ? 181 : 184) : 180;
    if (_divisorController.text != d.toString()) _divisorController.text = d.toString();
  }

  void _irAEdicionPrevisualizacion() {
    final inst = _instSeleccionada;
    final leg = _legajoSeleccionado;
    if (inst == null || leg == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Seleccione institución y empleado')));
      return;
    }
    final conceptos = _getConceptosCompletos();
    double sac = 0, jub = 0, os = 0, pami = 0;
    final extras = <Map<String, dynamic>>[];
    for (final c in conceptos) {
      final m = (c['monto'] as num?)?.toDouble() ?? 0.0;
      switch (c['id']?.toString()) {
        case 'sac': sac = m; break;
        case 'jub': jub = m; break;
        case 'os': os = m; break;
        case 'pami': pami = m; break;
        default:
          if (c['isBase'] != true) extras.add({'descripcion': c['descripcion'], 'tipo': c['tipo'], 'monto': m, 'codigoAfip': null});
      }
    }
    final args = TeacherSettlementReviewArgs(
      inst: inst,
      legajo: leg,
      semestre: _semestre,
      anio: _anio,
      mayorRem: _mayorRemuneracionController.text.trim(),
      dias: _diasTrabajadosController.text.trim(),
      divisor: _divisorController.text.trim(),
      fechaPago: _fechaPagoController.text.trim(),
      sac: sac,
      jub: jub,
      os: os,
      pami: pami,
      extras: extras,
      pctJub: null,
      pctOS: null,
      pctPami: null,
    );
    Navigator.push(context, MaterialPageRoute(
      builder: (c) => TeacherSettlementReviewScreen(args: args),
    ));
  }

  /// Jurisdicción y tipo de gestión heredados de la institución seleccionada.
  Jurisdiccion get _jurisdiccion {
    final j = _instSeleccionada?['jurisdiccion']?.toString();
    if (j == null || j.isEmpty) return Jurisdiccion.buenosAires;
    return Jurisdiccion.values.cast<Jurisdiccion?>().firstWhere(
      (e) => e?.name == j,
      orElse: () => Jurisdiccion.buenosAires,
    ) ?? Jurisdiccion.buenosAires;
  }

  TipoGestion get _tipoGestion {
    final t = _instSeleccionada?['tipoGestion']?.toString();
    if (t == null || t.isEmpty) return TipoGestion.publica;
    return TipoGestion.values.cast<TipoGestion?>().firstWhere(
      (e) => e?.name == t,
      orElse: () => TipoGestion.publica,
    ) ?? TipoGestion.publica;
  }

  JurisdiccionConfigOmni? get _config => JurisdiccionDBOmni.get(_jurisdiccion);

  String get _periodoTexto =>
      _semestre == 1 ? 'SAC 1º Semestre $_anio' : 'SAC 2º Semestre $_anio';

  /// SAC 2026: (Mejor_Remuneracion / 2) * (Dias_Trabajados / Divisor_Semestre).
  /// Divisor sugerido: 181 (1º sem), 184 (2º sem) 2026; el contador puede usar 180 si su convenio lo requiere.
  double? _calcularSAC() {
    final mayor = double.tryParse(_mayorRemuneracionController.text.replaceAll(',', '.'));
    if (mayor == null || mayor <= 0) return null;
    final dias = int.tryParse(_diasTrabajadosController.text.replaceAll(RegExp(r'[^\d]'), '')) ?? 0;
    final div = int.tryParse(_divisorController.text.replaceAll(RegExp(r'[^\d]'), '')) ?? 180;
    if (div <= 0) return null;
    final factor = dias >= div ? 1.0 : (dias <= 0 ? 0.0 : dias / div);
    return (mayor / 2.0) * factor;
  }

  /// Aportes según jurisdicción, tipo de gestión y caja de la institución.
  /// Si no hay institución/config: fallback ANSES 11% Jub, 3% OS, 3% PAMI.
  (double jub, double os, double pami) _calcularAportes(double base) {
    final cfg = _config;
    if (cfg == null) {
      return (base * 0.11, base * 0.03, base * 0.03);
    }
    return TeacherOmniEngine.aportes(
      base,
      _tipoGestion,
      cfg.cajaPrevisional,
      cfg.porcentajeAporte,
      porcentajeObraSocial: cfg.porcentajeObraSocial,
    );
  }

  /// Etiquetas para el detalle (porcentajes efectivos según jurisdicción y gestión).
  (String jubLabel, String osLabel) _getAportesEtiquetas() {
    final cfg = _config;
    if (cfg == null) return ('Jubilación (11%)', 'Obra Social (3%)');
    if (_tipoGestion == TipoGestion.privada) {
      return ('Jubilación (11%)', 'Obra Social (3%)');
    }
    if (cfg.cajaPrevisional == TipoCajaPrevisional.issn) {
      return ('Jubilación (14,5%)', 'Obra Social (5,5%)');
    }
    final pctOs = cfg.porcentajeObraSocial ?? 3.0;
    return ('Jubilación (${cfg.porcentajeAporte}%)', 'Obra Social ($pctOs%)');
  }

  double _getSacActual() => _overrides['sac'] ?? _calcularSAC() ?? 0.0;
  void _recalcularBase() => setState(() {
    _overrides.remove('sac');
    _overrides.remove('jub');
    _overrides.remove('os');
    _overrides.remove('pami');
  });

  /// Lista completa para recibo: base 4 + extras con montos resueltos.
  List<Map<String, dynamic>> _getConceptosCompletos() {
    final sac = _getSacActual();
    final (jubLabel, osLabel) = _getAportesEtiquetas();
    final jub = _overrides['jub'] ?? (sac > 0 ? _calcularAportes(sac).$1 : 0.0);
    final os = _overrides['os'] ?? (sac > 0 ? _calcularAportes(sac).$2 : 0.0);
    final pami = _overrides['pami'] ?? (sac > 0 ? _calcularAportes(sac).$3 : 0.0);
    final mayorRem = double.tryParse(_mayorRemuneracionController.text.replaceAll(',', '.')) ?? 0.0;

    final list = <Map<String, dynamic>>[
      {'id': 'sac', 'descripcion': 'SAC (50% mayor remuneración)', 'tipo': 'haber_rem', 'monto': sac, 'isBase': true},
      {'id': 'jub', 'descripcion': jubLabel, 'tipo': 'descuento', 'monto': jub, 'isBase': true},
      {'id': 'os', 'descripcion': osLabel, 'tipo': 'descuento', 'monto': os, 'isBase': true},
      {'id': 'pami', 'descripcion': 'PAMI (3%)', 'tipo': 'descuento', 'monto': pami, 'isBase': true},
    ];
    for (final e in _itemsExtras) {
      final esPct = e['esPorcentaje'] == true;
      final base = (e['baseParaPct']?.toString() == 'mayor_rem') ? mayorRem : sac;
      final m = esPct ? (base * ((e['valor'] as num? ?? 0) / 100)) : ((e['valor'] as num?)?.toDouble() ?? 0);
      list.add({
        'id': 'extra_${e['id']}',
        'descripcion': e['descripcion']?.toString() ?? '',
        'tipo': e['tipo']?.toString() ?? 'haber_rem',
        'monto': m,
        'isBase': false,
        'raw': e,
      });
    }
    return list;
  }

  double _totalHaberesRem() => _getConceptosCompletos().where((c) => c['tipo'] == 'haber_rem').fold(0.0, (a, c) => a + ((c['monto'] as num?)?.toDouble() ?? 0));
  double _totalHaberesNoRem() => _getConceptosCompletos().where((c) => c['tipo'] == 'haber_no_rem').fold(0.0, (a, c) => a + ((c['monto'] as num?)?.toDouble() ?? 0));
  double _totalDescuentos() => _getConceptosCompletos().where((c) => c['tipo'] == 'descuento').fold(0.0, (a, c) => a + ((c['monto'] as num?)?.toDouble() ?? 0));
  double _neto() => _totalHaberesRem() + _totalHaberesNoRem() - _totalDescuentos();

  Future<void> _mostrarDialogoEditarMonto(String id, String desc, double valorEditable, bool isBase, [Map<String, dynamic>? extraRaw]) async {
    final c = TextEditingController(text: valorEditable.toStringAsFixed(2));
    final label = (extraRaw?['esPorcentaje'] == true) ? 'Porcentaje (%)' : 'Monto (\$)';
    final r = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Editar'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(desc, style: const TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(height: 12),
          TextField(controller: c, decoration: InputDecoration(labelText: label), keyboardType: const TextInputType.numberWithOptions(decimal: true)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Guardar')),
        ],
      ),
    );
    if (r == true && mounted) {
      final v = double.tryParse(c.text.replaceAll(',', '.'));
      if (v != null) {
        setState(() {
          if (isBase) _overrides[id] = v;
          else if (extraRaw != null) extraRaw['valor'] = v;
        });
      }
    }
  }

  Future<void> _mostrarDialogoAgregarItem() async {
    final desc = TextEditingController();
    String tipo = 'haber_rem';
    bool esPorcentaje = false;
    final valorC = TextEditingController();
    String baseParaPct = 'SAC';

    final r = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setDialog) => AlertDialog(
          title: const Text('Agregar ítem'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              TextField(controller: desc, decoration: const InputDecoration(labelText: 'Descripción')),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(value: tipo, decoration: const InputDecoration(labelText: 'Tipo'), items: const [DropdownMenuItem(value: 'haber_rem', child: Text('Haber remunerativo')), DropdownMenuItem(value: 'haber_no_rem', child: Text('Haber no remunerativo')), DropdownMenuItem(value: 'descuento', child: Text('Descuento'))], onChanged: (v) { if (v != null) { tipo = v; setDialog(() {}); } }),
              const SizedBox(height: 8),
              Row(children: [
                const Text('Por porcentaje: '),
                Checkbox(value: esPorcentaje, onChanged: (v) { esPorcentaje = v ?? false; setDialog(() {}); }),
              ]),
              if (esPorcentaje) DropdownButtonFormField<String>(value: baseParaPct, decoration: const InputDecoration(labelText: 'Base del %'), items: const [DropdownMenuItem(value: 'SAC', child: Text('SAC')), DropdownMenuItem(value: 'mayor_rem', child: Text('Mayor remuneración'))], onChanged: (v) { if (v != null) { baseParaPct = v; setDialog(() {}); } }),
              TextField(controller: valorC, decoration: InputDecoration(labelText: esPorcentaje ? 'Porcentaje (%)' : 'Monto (\$)'), keyboardType: const TextInputType.numberWithOptions(decimal: true)),
            ]),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Agregar'))],
        ),
      ),
    );
    if (r == true && mounted && desc.text.trim().isNotEmpty) {
      final v = double.tryParse(valorC.text.replaceAll(',', '.'));
      if (v != null) {
        setState(() {
          final id = ++_idExtra;
          _itemsExtras.add({'id': id, 'descripcion': desc.text.trim(), 'tipo': tipo, 'valor': v, 'esPorcentaje': esPorcentaje, 'baseParaPct': esPorcentaje ? baseParaPct : null});
        });
      }
    }
  }

  Future<void> _mostrarDialogoGuardarPerfil() async {
    final nombreC = TextEditingController();
    final r = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('Guardar perfil'), content: TextField(controller: nombreC, decoration: const InputDecoration(labelText: 'Nombre del perfil')), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Guardar'))]));
    if (r == true && mounted && nombreC.text.trim().isNotEmpty) {
      await PerfilSacService.savePerfil(nombre: nombreC.text.trim(), items: List.from(_itemsExtras));
      await _cargarPerfilesSac();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Perfil guardado')));
    }
  }

  Future<void> _mostrarDialogoCargarPerfil() async {
    if (_perfilesSac.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No hay perfiles guardados'))); return; }
    final sel = await showDialog<Map<String, dynamic>>(context: context, builder: (ctx) => AlertDialog(title: const Text('Cargar perfil'), content: SizedBox(width: 300, child: ListView.builder(shrinkWrap: true, itemCount: _perfilesSac.length, itemBuilder: (_, i) => ListTile(title: Text(_perfilesSac[i]['nombre']?.toString() ?? ''), onTap: () => Navigator.pop(ctx, _perfilesSac[i])))), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar'))]));
    if (sel != null && mounted) {
      final items = (sel['items'] as List<dynamic>?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [];
      setState(() {
        _itemsExtras = [];
        for (final e in items) {
          final m = Map<String, dynamic>.from(e);
          if (m['id'] == null) m['id'] = ++_idExtra;
          _itemsExtras.add(m);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Perfil cargado')));
    }
  }

  Future<void> _generarReciboPdf(Map<String, dynamic> legajo) async {
    final pdfBytes = await _generarBytesReciboPdf(legajo);
    if (pdfBytes == null) return;

    final cuilLimpio = (legajo['cuil']?.toString() ?? '').replaceAll(RegExp(r'[^\d]'), '');
    final nombre = legajo['nombre']?.toString().replaceAll(RegExp(r'[^\w]'), '_') ?? 'empleado';
    final nombreArchivo = 'recibo_sac_${nombre}_$cuilLimpio.pdf';

    final filePath = await saveFile(
      fileName: nombreArchivo,
      bytes: pdfBytes,
      mimeType: 'application/pdf',
    );

    if (mounted && filePath != null) {
      final esWeb = filePath == 'descargado';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(esWeb ? 'Recibo generado y descargado' : 'Recibo: $filePath')),
      );
      if (!esWeb) openFile(filePath);
    }
  }

  /// Genera los bytes del PDF del recibo SAC.
  Future<List<int>?> _generarBytesReciboPdf(Map<String, dynamic> legajo) async {
    final conceptos = _getConceptosCompletos();
    final bruto = _totalHaberesRem();
    final noRem = _totalHaberesNoRem();
    final deduc = _totalDescuentos();
    final neto = _neto();
    final inst = _instSeleccionada;
    if (inst == null) return null;
    final emp = Empresa(razonSocial: inst['razonSocial']?.toString() ?? '', cuit: (inst['cuit']?.toString() ?? '').replaceAll(RegExp(r'[^\d]'), ''), domicilio: inst['domicilio']?.toString() ?? '', convenioId: 'docente_sac', convenioNombre: 'SAC Docente', convenioPersonalizado: false, categorias: [], parametros: []);
    final cargo = legajo['cargo']?.toString().trim() ?? '';
    final empr = Empleado(nombre: legajo['nombre']?.toString() ?? '', categoria: cargo.isEmpty ? 'SAC - $_periodoTexto' : '$cargo - SAC - $_periodoTexto', sueldoBasico: bruto, periodo: _periodoTexto, fechaPago: _fechaPagoController.text.trim(), lugarPago: inst['domicilio']?.toString(), fechaIngreso: legajo['fechaIngreso']?.toString());
    final conceptosPdf = conceptos.map((c) {
      final t = c['tipo']?.toString() ?? '';
      final m = (c['monto'] as num?)?.toDouble() ?? 0;
      return ConceptoParaPDF(descripcion: c['descripcion']?.toString() ?? '', remunerativo: t == 'haber_rem' ? m : 0, noRemunerativo: t == 'haber_no_rem' ? m : 0, descuento: t == 'descuento' ? m : 0);
    }).toList();
    final diasSem = int.tryParse(_diasTrabajadosController.text.replaceAll(RegExp(r'[^\d]'), '')) ?? 180;
    final divisorUsado = int.tryParse(_divisorController.text.replaceAll(RegExp(r'[^\d]'), ''));
    final mayorRem = double.tryParse(_mayorRemuneracionController.text.replaceAll(',', '.')) ?? 0.0;
    final baseDeCalculo = mayorRem > 0 ? (mayorRem / 2.0) : null;
    final mesPeriodo = _semestre == 1 ? 'Junio' : 'Diciembre';
    final leyendaDep = 'Período $mesPeriodo $_anio - Banco ${inst['bancoAcreditacion'] ?? inst['razonSocial'] ?? ''}';
    
    return await PdfRecibo.generarCompleto(
      empresa: emp,
      empleado: empr,
      conceptos: conceptosPdf,
      sueldoBruto: bruto,
      totalDeducciones: deduc,
      totalNoRemunerativo: noRem,
      sueldoNeto: neto,
      diasTrabajadosSemestre: diasSem,
      divisorUsado: (divisorUsado ?? 0) > 0 ? divisorUsado : null,
      baseDeCalculo: baseDeCalculo,
      leyendaUltimoDepositoAportes: leyendaDep,
      incluirBloqueFirmaLey25506: true,
    );
  }

  /// Escribe el archivo LSD ARCA 2026 para [legajo]. Retorna el contenido como String.
  String? _generarContenidoLsd(Map<String, dynamic> legajo) {
    final sac = _getSacActual();
    if (sac <= 0) return null;
    final cuit = _instSeleccionada?['cuit']?.toString().replaceAll(RegExp(r'[^\d]'), '') ?? '';
    if (cuit.length != 11) return null;
    final cuil = (legajo['cuil']?.toString() ?? '').replaceAll(RegExp(r'[^\d]'), '');
    if (cuil.length != 11) return null;
    final fechaPago = _fechaPagoController.text.trim();
    if (fechaPago.isEmpty) return null;
    try {
      final inst = _instSeleccionada!;
      final (jubBase, osBase, pamiBase) = _calcularAportes(sac);
      final jub = _overrides['jub'] ?? (sac > 0 ? jubBase : 0.0);
      final os = _overrides['os'] ?? (sac > 0 ? osBase : 0.0);
      final pami = _overrides['pami'] ?? (sac > 0 ? pamiBase : 0.0);
      final baseTopeada = sac > ParametrosFederales2026Omni.topePrevisional
          ? ParametrosFederales2026Omni.topePrevisional
          : sac;

      final reg1 = LSDGenerator.generateRegistro1(
        cuitEmpresa: cuit,
        periodo: _periodoTexto,
        fechaPago: fechaPago,
        razonSocial: inst['razonSocial']?.toString() ?? '',
        domicilio: inst['domicilio']?.toString() ?? '',
        tipoLiquidacion: 'S',
      );

      final reg2Ref = LSDGenerator.generateRegistro2DatosReferenciales(
        cuilEmpleado: cuil,
        diasBase: 30,
      );

      final reg3Sac = LSDGenerator.generateRegistro3Conceptos(cuilEmpleado: cuil, codigoConcepto: '120000', importe: sac, tipo: 'H', descripcionConcepto: 'SAC (Aguinaldo)');
      final reg3Jub = LSDGenerator.generateRegistro3Conceptos(cuilEmpleado: cuil, codigoConcepto: '810001', importe: jub, tipo: 'D', descripcionConcepto: 'Jubilación');
      final reg3Os = LSDGenerator.generateRegistro3Conceptos(cuilEmpleado: cuil, codigoConcepto: '810003', importe: os, tipo: 'D', descripcionConcepto: 'Obra Social');
      final reg3Pami = LSDGenerator.generateRegistro3Conceptos(cuilEmpleado: cuil, codigoConcepto: '810002', importe: pami, tipo: 'D', descripcionConcepto: 'Ley 19.032 (PAMI)');

      final bases = List<double>.filled(10, 0.0);
      bases[0] = baseTopeada; bases[1] = baseTopeada; bases[2] = baseTopeada; bases[8] = baseTopeada;
      
      final reg4 = LSDGenerator.generateRegistro4Bases(
        cuilEmpleado: cuil,
        bases: bases,
      );
      
      final reg5 = LSDGenerator.generateRegistro5DatosComplementarios(
        cuilEmpleado: cuil,
        codigoRnos: '115404',
      );

      final sb = StringBuffer();
      sb.write(latin1.decode(reg1));
      sb.write(LSDGenerator.eolLsd);
      sb.write(latin1.decode(reg2Ref));
      sb.write(LSDGenerator.eolLsd);
      sb.write(latin1.decode(reg3Sac));
      sb.write(LSDGenerator.eolLsd);
      sb.write(latin1.decode(reg3Jub));
      sb.write(LSDGenerator.eolLsd);
      sb.write(latin1.decode(reg3Os));
      sb.write(LSDGenerator.eolLsd);
      sb.write(latin1.decode(reg3Pami));
      sb.write(LSDGenerator.eolLsd);
      sb.write(latin1.decode(reg4));
      sb.write(LSDGenerator.eolLsd);
      sb.write(latin1.decode(reg5));
      sb.write(LSDGenerator.eolLsd);

      return sb.toString();
    } catch (_) { return null; }
  }

  Future<void> _mostrarDialogoRecibosLote() async {
    final cuit = _cuitSeleccionado;
    if (cuit == null || _legajos.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Seleccione institución con empleados'))); return; }
    if (_getSacActual() <= 0) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ingrese mayor remuneración y calcule'))); return; }
    final Set<String> cuilsSel = {};
    final seleccionados = await showDialog<List<Map<String, dynamic>>>(context: context, builder: (ctx) {
      return StatefulBuilder(builder: (ctx2, setD) => AlertDialog(
        title: const Text('Recibos SAC para empleados de la institución'),
        content: SizedBox(width: 400, child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Se generarán PDF y LSD para los empleados seleccionados.', style: TextStyle(fontSize: 12)),
          const SizedBox(height: 8),
          ..._legajos.map((l) {
            final cuil = (l['cuil']?.toString() ?? '').replaceAll(RegExp(r'[^\d]'), '');
            return CheckboxListTile(title: Text('${l['nombre']} — ${l['cuil']}'), value: cuilsSel.contains(cuil), onChanged: (v) => setD(() { if (v == true) cuilsSel.add(cuil); else cuilsSel.remove(cuil); }));
          }),
        ])),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx, <Map<String, dynamic>>[]), child: const Text('Cancelar')), FilledButton(onPressed: () => Navigator.pop(ctx, _legajos.where((l) => cuilsSel.contains((l['cuil']?.toString() ?? '').replaceAll(RegExp(r'[^\d]'), ''))).toList()), child: const Text('Generar archivos'))],
      ));
    });
    if (seleccionados == null || seleccionados.isEmpty || !mounted) return;

    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));

    int pdfOk = 0, lsdOk = 0;
    for (final leg in seleccionados) {
      final pdfBytes = await _generarBytesReciboPdf(leg);
      if (pdfBytes != null) {
        final cuilLimpio = (leg['cuil']?.toString() ?? '').replaceAll(RegExp(r'[^\d]'), '');
        final nombre = leg['nombre']?.toString().replaceAll(RegExp(r'[^\w]'), '_') ?? 'empleado';
        await saveFile(fileName: 'recibo_sac_${nombre}_$cuilLimpio.pdf', bytes: pdfBytes, mimeType: 'application/pdf');
        pdfOk++;
      }
      
      final lsdContenido = _generarContenidoLsd(leg);
      if (lsdContenido != null) {
        final nombre = leg['nombre']?.toString().replaceAll(RegExp(r'[^\w]'), '_') ?? 'empleado';
        final name = 'LSD_SAC_${nombre}_${DateFormat('yyyyMMdd').format(DateTime.now())}.txt';
        await saveTextFile(fileName: name, content: lsdContenido, mimeType: 'text/plain');
        lsdOk++;
      }
      
      // Pequeño delay para no saturar el navegador con descargas simultáneas
      await Future.delayed(const Duration(milliseconds: 300));
    }

    if (!mounted) return;
    Navigator.pop(context); // cierra el CircularProgressIndicator

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Se procesaron $pdfOk recibos y $lsdOk archivos LSD.'))
    );
  }

  Future<void> _exportarLsd() async {
    final sac = _getSacActual();
    if (sac <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingrese mayor remuneración del semestre')),
      );
      return;
    }
    final cuit = _instSeleccionada?['cuit']?.toString().replaceAll(RegExp(r'[^\d]'), '') ?? '';
    if (cuit.length != 11) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Seleccione institución con CUIT válido')));
      return;
    }
    final cuil = _legajoSeleccionado?['cuil']?.toString().replaceAll(RegExp(r'[^\d]'), '') ?? '';
    if (cuil.length != 11) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Seleccione empleado con CUIL válido')));
      return;
    }
    final fechaPago = _fechaPagoController.text.trim();
    if (fechaPago.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ingrese fecha de pago')));
      return;
    }
    try {
      final inst = _instSeleccionada!;
      final (jubBase, osBase, pamiBase) = _calcularAportes(sac);
      final jub = _overrides['jub'] ?? (sac > 0 ? jubBase : 0.0);
      final os = _overrides['os'] ?? (sac > 0 ? osBase : 0.0);
      final pami = _overrides['pami'] ?? (sac > 0 ? pamiBase : 0.0);
      final baseTopeada = sac > ParametrosFederales2026Omni.topePrevisional
          ? ParametrosFederales2026Omni.topePrevisional
          : sac;

      final reg1 = LSDGenerator.generateRegistro1(
        cuitEmpresa: cuit,
        periodo: _periodoTexto,
        fechaPago: fechaPago,
        razonSocial: inst['razonSocial']?.toString() ?? '',
        domicilio: inst['domicilio']?.toString() ?? '',
        tipoLiquidacion: 'S',
      );
      
      // Registro 2: Datos Referenciales
      final reg2Ref = LSDGenerator.generateRegistro2DatosReferenciales(
        cuilEmpleado: cuil,
        diasBase: 30,
      );
      
      final reg3Sac = LSDGenerator.generateRegistro3Conceptos(cuilEmpleado: cuil, codigoConcepto: '120000', importe: sac, tipo: 'H', descripcionConcepto: 'SAC (Aguinaldo)');
      final reg3Jub = LSDGenerator.generateRegistro3Conceptos(cuilEmpleado: cuil, codigoConcepto: '810001', importe: jub, tipo: 'D', descripcionConcepto: 'Jubilación');
      final reg3Os = LSDGenerator.generateRegistro3Conceptos(cuilEmpleado: cuil, codigoConcepto: '810003', importe: os, tipo: 'D', descripcionConcepto: 'Obra Social');
      final reg3Pami = LSDGenerator.generateRegistro3Conceptos(cuilEmpleado: cuil, codigoConcepto: '810002', importe: pami, tipo: 'D', descripcionConcepto: 'Ley 19.032 (PAMI)');
      final conceptosCompletosExp = _getConceptosCompletos();
      
      final bases = List<double>.filled(10, 0.0);
      bases[0] = baseTopeada; bases[1] = baseTopeada; bases[2] = baseTopeada; bases[8] = baseTopeada;
      
      final reg4 = LSDGenerator.generateRegistro4Bases(
        cuilEmpleado: cuil,
        bases: bases,
      );
      
      final reg5 = LSDGenerator.generateRegistro5DatosComplementarios(
        cuilEmpleado: cuil,
        codigoRnos: '115404',
      );

      final sb = StringBuffer();
      sb.write(latin1.decode(reg1));
      sb.write(LSDGenerator.eolLsd);
      sb.write(latin1.decode(reg2Ref));
      sb.write(LSDGenerator.eolLsd);
      sb.write(latin1.decode(reg3Sac));
      sb.write(LSDGenerator.eolLsd);
      sb.write(latin1.decode(reg3Jub));
      sb.write(LSDGenerator.eolLsd);
      sb.write(latin1.decode(reg3Os));
      sb.write(LSDGenerator.eolLsd);
      sb.write(latin1.decode(reg3Pami));
      sb.write(LSDGenerator.eolLsd);
      for (final c in conceptosCompletosExp) {
        if (c['isBase'] == true) continue;
        final m = (c['monto'] as num?)?.toDouble() ?? 0.0;
        if (m <= 0) continue;
        final t = (c['tipo'] ?? '') == 'descuento' ? 'D' : 'H';
        final cod = LSDGenerator.obtenerCodigoInternoConcepto(c['descripcion']?.toString() ?? '');
        final r3 = LSDGenerator.generateRegistro3Conceptos(cuilEmpleado: cuil, codigoConcepto: cod, importe: m, tipo: t, descripcionConcepto: c['descripcion']?.toString() ?? '');
        sb.write(latin1.decode(r3));
        sb.write(LSDGenerator.eolLsd);
      }
      sb.write(latin1.decode(reg4));
      sb.write(LSDGenerator.eolLsd);
      sb.write(latin1.decode(reg5));
      sb.write(LSDGenerator.eolLsd);

      final name = 'LSD_SAC_Docente_${_legajoSeleccionado!['nombre']?.toString().replaceAll(RegExp(r'[^\w]'), '_') ?? 'empleado'}_${DateFormat('yyyyMMdd').format(DateTime.now())}.txt';
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
    final sac = _getSacActual();
    final mostrarLista = _cuitSeleccionado != null && _legajoSeleccionado != null && sac > 0;

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
          'Liquidación SAC (Aguinaldo)',
          style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      persistentFooterButtons: [
        TextButton(onPressed: _exportarLsd, child: const Text('Exportar LSD')),
        if (mostrarLista) ...[
          TextButton(onPressed: _legajoSeleccionado != null ? () => _generarReciboPdf(_legajoSeleccionado!) : null, child: const Text('Descargar recibo')),
          TextButton(onPressed: _mostrarDialogoRecibosLote, child: const Text('Recibos para todos')),
        ],
      ],
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildDropdownInstitucion(),
          const SizedBox(height: 16),
          _buildDropdownLegajo(),
          const SizedBox(height: 16),
          _buildSemestreYAnio(),
          const SizedBox(height: 16),
          TextField(
            controller: _mayorRemuneracionController,
            decoration: const InputDecoration(
              labelText: 'Mayor remuneración del semestre (\$)',
              hintText: 'Ej. 1850000',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => _recalcularBase(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _diasTrabajadosController,
            decoration: const InputDecoration(
              labelText: 'Días trabajados en el semestre',
              hintText: '180 (completo)',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: false),
            onChanged: (_) => _recalcularBase(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _fechaPagoController,
            decoration: const InputDecoration(labelText: 'Fecha de pago (DD/MM/AAAA)'),
          ),
          if (mostrarLista) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _irAEdicionPrevisualizacion,
              icon: const Icon(Icons.preview, size: 20),
              label: const Text('Edición y previsualización'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                side: const BorderSide(color: AppColors.glassBorder),
              ),
            ),
            const SizedBox(height: 20),
            _buildPanelConceptos(),
          ],
        ],
      ),
    );
  }

  Widget _buildPanelConceptos() {
    final conceptos = _getConceptosCompletos();
    final bruto = _totalHaberesRem();
    final noRem = _totalHaberesNoRem();
    final deduc = _totalDescuentos();
    final neto = _neto();

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
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Detalle recibo (editable)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Wrap(spacing: 8, runSpacing: 4, children: [
              TextButton.icon(onPressed: _recalcularBase, icon: const Icon(Icons.refresh, size: 18), label: const Text('Recalcular')),
              TextButton.icon(onPressed: _mostrarDialogoAgregarItem, icon: const Icon(Icons.add, size: 18), label: const Text('Agregar ítem')),
              TextButton.icon(onPressed: _mostrarDialogoGuardarPerfil, icon: const Icon(Icons.save, size: 18), label: const Text('Guardar perfil')),
              TextButton.icon(onPressed: _mostrarDialogoCargarPerfil, icon: const Icon(Icons.folder_open, size: 18), label: const Text('Cargar perfil')),
            ]),
          ]),
          const SizedBox(height: 12),
          ...conceptos.map((c) {
            final id = c['id']?.toString() ?? '';
            final desc = c['descripcion']?.toString() ?? '';
            final m = (c['monto'] as num?)?.toDouble() ?? 0;
            final isBase = c['isBase'] == true;
            final raw = c['raw'] as Map<String, dynamic>?;
            final isDescuento = c['tipo'] == 'descuento';
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Icon(isDescuento ? Icons.remove_circle_outline : Icons.add_circle_outline, size: 20, color: AppColors.textSecondary),
                  const SizedBox(width: 8),
                  Expanded(child: Text(desc, style: const TextStyle(fontSize: 14))),
                  SizedBox(width: 100, child: Text('\$${m.toStringAsFixed(2)}', textAlign: TextAlign.right, style: const TextStyle(fontSize: 14))),
                  IconButton(icon: const Icon(Icons.edit, size: 20), onPressed: () => _mostrarDialogoEditarMonto(id, desc, isBase ? m : ((raw?['valor'] as num?)?.toDouble() ?? 0), isBase, raw)),
                  if (!isBase) IconButton(icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red), onPressed: () => setState(() => _itemsExtras.removeWhere((e) => 'extra_${e['id']}' == id))),
                ],
              ),
            );
          }),
          const Divider(),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Total Haberes Rem.', style: TextStyle(fontWeight: FontWeight.w600)),
            Text('\$${bruto.toStringAsFixed(2)}'),
          ]),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Total No Rem.', style: TextStyle(fontWeight: FontWeight.w600)),
            Text('\$${noRem.toStringAsFixed(2)}'),
          ]),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Total Descuentos', style: TextStyle(fontWeight: FontWeight.w600)),
            Text('\$${deduc.toStringAsFixed(2)}'),
          ]),
          const Divider(),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('NETO A COBRAR', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            Text('\$${neto.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ]),
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
        initialValue: items.contains(_legajoSeleccionado) ? _legajoSeleccionado : null,
        decoration: const InputDecoration(labelText: 'Empleado'),
        items: items.map((l) {
          return DropdownMenuItem(
            value: l,
            child: Text(l == null ? '+ Seleccione empleado' : '${l['nombre'] ?? ''} — ${l['cuil'] ?? ''}'),
          );
        }).toList(),
        onChanged: (v) => _onLegajoChanged(v),
      ),
    );
  }

  Widget _buildSemestreYAnio() {
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<int>(
            value: _semestre,
            decoration: const InputDecoration(labelText: 'Semestre'),
            items: const [
              DropdownMenuItem(value: 1, child: Text('1º (Enero–Junio)')),
              DropdownMenuItem(value: 2, child: Text('2º (Julio–Diciembre)')),
            ],
            onChanged: (v) => setState(() => _semestre = v ?? 1),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: DropdownButtonFormField<int>(
            initialValue: _anio,
            decoration: const InputDecoration(labelText: 'Año'),
            items: [DateTime.now().year, DateTime.now().year - 1]
                .map((y) => DropdownMenuItem(value: y, child: Text('$y')))
                .toList(),
            onChanged: (v) => setState(() { _anio = v ?? DateTime.now().year; _aplicarDivisorSugerido(); }),
          ),
        ),
      ],
    );
  }

}
