// OcrReviewScreen - Validación para contadores: Cards editables, comparación con Federal 2026,
// Confirmar Liquidación -> DocenteOmniInput overrides, diálogo para actualizar jurisdicción.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/teacher_types.dart';
import '../utils/formatters.dart';
import '../models/teacher_constants.dart';
import '../models/ocr_confirm_result.dart';
import '../models/plantilla_cargo_omni.dart';
import '../services/teacher_receipt_scan_service.dart';
import '../services/plantilla_cargo_service.dart';
import '../data/rnos_docentes_data.dart';
import '../theme/app_colors.dart';

class OcrReviewScreen extends StatefulWidget {
  final OcrExtractResult extract;

  const OcrReviewScreen({super.key, required this.extract});

  @override
  State<OcrReviewScreen> createState() => _OcrReviewScreenState();
}

class _OcrReviewScreenState extends State<OcrReviewScreen> {
  late TextEditingController _cuilCtr;
  late TextEditingController _nombreCtr;
  late TextEditingController _sueldoBasicoCtr;
  late TextEditingController _antiguedadPctCtr;
  late TextEditingController _puntosCtr;
  late TextEditingController _valorIndiceCtr;
  late TextEditingController _cargasCtr;
  late TextEditingController _horasCatCtr;
  late TextEditingController _cantCargosCtr;
  late TextEditingController _codigoRnosCtr;

  Jurisdiccion _jurisdiccion = Jurisdiccion.neuquen;
  TipoGestion _tipoGestion = TipoGestion.publica;
  TipoNomenclador _cargo = TipoNomenclador.maestroGrado;
  NivelEducativo _nivel = NivelEducativo.primario;
  ZonaDesfavorable _zona = ZonaDesfavorable.a;
  final NivelUbicacion _nivelUbicacion = NivelUbicacion.urbana;
  DateTime _fechaIngreso = DateTime(2020, 3, 1);

  PlantillaCargoOmni? _plantilla;

  int _anosAntiguedad() {
    final ahora = DateTime.now();
    int a = ahora.year - _fechaIngreso.year;
    if (ahora.month < _fechaIngreso.month || (ahora.month == _fechaIngreso.month && ahora.day < _fechaIngreso.day)) a--;
    return a < 0 ? 0 : a;
  }

  @override
  void initState() {
    super.initState();
    _cuilCtr = TextEditingController(text: widget.extract.cuil ?? '');
    _nombreCtr = TextEditingController(text: widget.extract.nombre ?? '');
    _sueldoBasicoCtr = TextEditingController(
      text: widget.extract.sueldoBasico != null ? _fmtNum(widget.extract.sueldoBasico!) : '',
    );
    _antiguedadPctCtr = TextEditingController(
      text: widget.extract.antiguedadPct != null ? _fmtNum(widget.extract.antiguedadPct!) : '',
    );
    _puntosCtr = TextEditingController(
      text: widget.extract.puntos?.toString() ?? '',
    );
    _valorIndiceCtr = TextEditingController(
      text: widget.extract.valorIndice != null ? _fmtNum(widget.extract.valorIndice!) : '',
    );
    _cargasCtr = TextEditingController(text: '0');
    _horasCatCtr = TextEditingController(text: '0');
    _cantCargosCtr = TextEditingController(text: '1');
    _codigoRnosCtr = TextEditingController(text: '');

    if (widget.extract.jurisdiccionRaw != null && widget.extract.jurisdiccionRaw!.isNotEmpty) {
      final j = _parseJurisdiccion(widget.extract.jurisdiccionRaw!);
      if (j != null) _jurisdiccion = j;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => _loadPlantilla());
  }

  Future<void> _loadPlantilla() async {
    final id = PlantillaCargoOmni.buildPerfilCargoId(
      jurisdiccion: _jurisdiccion,
      tipoGestion: _tipoGestion,
      tipoNomenclador: _cargo,
      antiguedadAnos: _anosAntiguedad(),
      zona: _zona,
      nivelUbicacion: _nivelUbicacion,
    );
    final p = await PlantillaCargoService.getByPerfilId(id);
    if (!mounted) return;
    setState(() {
      _plantilla = p;
      if (p != null) {
        if (p.valorIndice != null) _valorIndiceCtr.text = AppNumberFormatter.format(p.valorIndice, valorIndice: true);
        if (p.sueldoBasico != null) _sueldoBasicoCtr.text = AppNumberFormatter.format(p.sueldoBasico, valorIndice: false);
        if (p.puntos != null) _puntosCtr.text = p.puntos.toString();
        if (p.antiguedadPct != null) _antiguedadPctCtr.text = AppNumberFormatter.format(p.antiguedadPct, valorIndice: false);
      }
    });
  }

  String _fmtNum(double n) => n.toStringAsFixed(2).replaceAll('.', ',');

  Jurisdiccion? _parseJurisdiccion(String s) {
    final low = s.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
    for (final e in Jurisdiccion.values) {
      if (e.name.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '') == low) return e;
    }
    return null;
  }

  double? _parseNumFromField(String s) {
    if (s.trim().isEmpty) return null;
    return double.tryParse(s.replaceAll(',', '.'));
  }

  int? _parseIntFromField(String s) {
    if (s.trim().isEmpty) return null;
    return int.tryParse(s);
  }

  @override
  void dispose() {
    _cuilCtr.dispose();
    _nombreCtr.dispose();
    _sueldoBasicoCtr.dispose();
    _antiguedadPctCtr.dispose();
    _puntosCtr.dispose();
    _valorIndiceCtr.dispose();
    _cargasCtr.dispose();
    _horasCatCtr.dispose();
    _cantCargosCtr.dispose();
    _codigoRnosCtr.dispose();
    super.dispose();
  }

  void _mostrarBuscadorRNOS() {
    showDialog(
      context: context,
      builder: (context) {
        String query = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtered = CatalogoRNOS2026.lista.where((e) {
              final search = query.toLowerCase();
              return e.nombreCompleto.toLowerCase().contains(search) ||
                  e.sigla.toLowerCase().contains(search) ||
                  e.codigoArca.contains(search) ||
                  e.jurisdiccion.toLowerCase().contains(search);
            }).toList();

            return AlertDialog(
              backgroundColor: AppColors.backgroundLight,
              title: const Text('Buscador RNOS 2026', style: TextStyle(color: AppColors.textPrimary)),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      autofocus: true,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Buscar por nombre, sigla o provincia...',
                        hintStyle: const TextStyle(color: AppColors.textMuted),
                        prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
                        filled: true,
                        fillColor: AppColors.glassFill,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onChanged: (v) => setModalState(() => query = v),
                    ),
                    const SizedBox(height: 16),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: filtered.length,
                        itemBuilder: (context, i) {
                          final os = filtered[i];
                          return ListTile(
                            title: Text(os.nombreCompleto, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14)),
                            subtitle: Text('${os.sigla} | Código: ${os.codigoArca} | Aporte: ${os.porcentajeAporte}%', 
                              style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                            trailing: Text(os.jurisdiccion, style: const TextStyle(color: AppColors.pastelBlue, fontSize: 11)),
                            onTap: () {
                              setState(() {
                                _codigoRnosCtr.text = os.codigoArca;
                              });
                              Navigator.pop(context);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar')),
              ],
            );
          },
        );
      },
    );
  }

  /// True si el OCR no detectó al menos un dato principal (CUIL, Básico, Puntos, etc.).
  bool get _hasMissingOcrFields {
    final e = widget.extract;
    return (e.cuil == null || e.cuil!.trim().isEmpty) ||
        (e.sueldoBasico == null) ||
        (e.antiguedadPct == null) ||
        (e.puntos == null) ||
        (e.valorIndice == null);
  }

  String? _valorFederal(String key) {
    final cfg = JurisdiccionDBOmni.get(_jurisdiccion);
    switch (key) {
      case 'valorIndice':
        return cfg != null ? _fmtNum(cfg.valorIndice) : null;
      case 'sueldoBasico':
        return cfg != null ? _fmtNum(cfg.pisoSalarial) : null;
      case 'puntos':
        final p = NomencladorFederal2026.puntosPorTipo(_cargo);
        return p.toString();
      default:
        return null;
    }
  }

  String? _valorPlantilla(String key) {
    if (_plantilla == null) return null;
    switch (key) {
      case 'valorIndice': return _plantilla!.valorIndice != null ? _fmtNum(_plantilla!.valorIndice!) : null;
      case 'sueldoBasico': return _plantilla!.sueldoBasico != null ? _fmtNum(_plantilla!.sueldoBasico!) : null;
      case 'puntos': return _plantilla!.puntos?.toString();
      case 'antiguedadPct': return _plantilla!.antiguedadPct != null ? _fmtNum(_plantilla!.antiguedadPct!) : null;
      default: return null;
    }
  }

  bool _difiereDeFederal(String key, String valorEditable) {
    final fed = _valorFederal(key);
    if (fed == null || fed.isEmpty) return false;
    final v = valorEditable.trim().replaceAll(',', '.');
    if (v.isEmpty) return false;
    if (key == 'puntos') {
      final a = int.tryParse(v);
      final b = int.tryParse(fed);
      return a != null && b != null && a != b;
    }
    final a = double.tryParse(v);
    final b = double.tryParse(fed.replaceAll(',', '.'));
    if (a == null || b == null) return v != fed;
    return (a - b).abs() > 0.01;
  }

  bool _difiereDePlantilla(String key, String valorEditable) {
    if (_plantilla == null) return false;
    final v = valorEditable.trim().replaceAll(',', '.');
    if (v.isEmpty) return false;
    if (key == 'puntos') {
      final a = int.tryParse(v);
      final b = _plantilla!.puntos;
      return a != null && b != null && a != b;
    }
    double? ref;
    if (key == 'valorIndice') {
      ref = _plantilla!.valorIndice;
    } else if (key == 'sueldoBasico') ref = _plantilla!.sueldoBasico;
    else if (key == 'antiguedadPct') ref = _plantilla!.antiguedadPct;
    if (ref == null) return false;
    final a = double.tryParse(v);
    if (a == null) return v != _fmtNum(ref);
    return (a - ref).abs() > 0.01;
  }

  Widget _buildCard({
    required String label,
    required String valorDetectado,
    required TextEditingController ctr,
    String? valorFederal,
    String? valorPlantilla,
    bool isNumero = false,
  }) {
    final key = label == 'CUIL'
        ? 'cuil'
        : label == 'Sueldo Básico'
            ? 'sueldoBasico'
            : label == 'Valor Índice'
                ? 'valorIndice'
                : label == 'Puntos'
                    ? 'puntos'
                    : label == 'Antigüedad %'
                        ? 'antiguedadPct'
                        : '';
    final difiereFed = key.isNotEmpty && _difiereDeFederal(key, ctr.text);
    final difierePl = key.isNotEmpty && _difiereDePlantilla(key, ctr.text);
    final difiere = difiereFed || difierePl;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: AppColors.glassFill,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: difiere ? Colors.orange : AppColors.glassBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 12)),
                  if (valorFederal != null && valorFederal.isNotEmpty)
                    Text('Federal 2026: $valorFederal', style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                  if (valorPlantilla != null && valorPlantilla.isNotEmpty)
                    Text('Plantilla: $valorPlantilla', style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                ],
              ),
            ),
            Expanded(flex: 2, child: Text(valorDetectado.isNotEmpty ? valorDetectado : '—', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary))),
            Expanded(
              flex: 3,
              child: TextFormField(
                controller: ctr,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Corregir',
                  hintStyle: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                ),
                keyboardType: isNumero ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
                inputFormatters: (isNumero && key != 'puntos') ? [AppNumberFormatter.inputFormatter(valorIndice: key == 'valorIndice')] : null,
                onChanged: (_) => setState(() {}),
              ),
            ),
            if (difiere)
              Padding(
                padding: const EdgeInsets.only(left: 6, top: 6),
                child: Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 20),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary), onPressed: () => Navigator.pop(context)),
        title: const Text('Revisar datos del recibo', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          if (widget.extract.urlDetectada != null && widget.extract.urlDetectada!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.blue.shade900.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(8)),
                child: Row(children: [
                  const Icon(Icons.link, color: AppColors.pastelBlue, size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text('URL: ${widget.extract.urlDetectada}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary))),
                ]),
              ),
            ),
          if (_hasMissingOcrFields)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.amber.shade900.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.amber.shade700, width: 1)),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, color: Colors.amber.shade700, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Si falta algún dato, complételo a mano en los campos o escanee una foto con mejor resolución.',
                        style: TextStyle(fontSize: 13, color: AppColors.textPrimary, height: 1.3),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 100),
              children: [
                _buildCard(label: 'CUIL', valorDetectado: widget.extract.cuil ?? '—', ctr: _cuilCtr),
                _buildCard(label: 'Nombre', valorDetectado: widget.extract.nombre ?? '—', ctr: _nombreCtr),
                _buildCard(label: 'Sueldo Básico', valorDetectado: AppNumberFormatter.format(widget.extract.sueldoBasico, valorIndice: false).isNotEmpty ? AppNumberFormatter.format(widget.extract.sueldoBasico, valorIndice: false) : '—', ctr: _sueldoBasicoCtr, valorFederal: _valorFederal('sueldoBasico'), valorPlantilla: _valorPlantilla('sueldoBasico'), isNumero: true),
                _buildCard(label: 'Antigüedad %', valorDetectado: AppNumberFormatter.format(widget.extract.antiguedadPct, valorIndice: false).isNotEmpty ? AppNumberFormatter.format(widget.extract.antiguedadPct, valorIndice: false) : '—', ctr: _antiguedadPctCtr, valorPlantilla: _valorPlantilla('antiguedadPct'), isNumero: true),
                _buildCard(label: 'Puntos', valorDetectado: widget.extract.puntos?.toString() ?? '—', ctr: _puntosCtr, valorFederal: _valorFederal('puntos'), valorPlantilla: _valorPlantilla('puntos'), isNumero: true),
                _buildCard(label: 'Valor Índice', valorDetectado: AppNumberFormatter.format(widget.extract.valorIndice, valorIndice: true).isNotEmpty ? AppNumberFormatter.format(widget.extract.valorIndice, valorIndice: true) : '—', ctr: _valorIndiceCtr, valorFederal: _valorFederal('valorIndice'), valorPlantilla: _valorPlantilla('valorIndice'), isNumero: true),
                const Padding(padding: EdgeInsets.only(left: 16, top: 12), child: Text('Parámetros de liquidación', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary))),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: DropdownButtonFormField<Jurisdiccion>(
                    initialValue: _jurisdiccion,
                    decoration: const InputDecoration(labelText: 'Jurisdicción', isDense: true),
                    items: Jurisdiccion.values.map((j) => DropdownMenuItem(value: j, child: Text(JurisdiccionDBOmni.get(j)?.nombre ?? j.name))).toList(),
                    onChanged: (v) { if (v != null) setState(() => _jurisdiccion = v); },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: DropdownButtonFormField<TipoNomenclador>(
                    initialValue: _cargo,
                    decoration: const InputDecoration(labelText: 'Cargo', isDense: true),
                    items: NomencladorFederal2026.items.map((e) => DropdownMenuItem(value: e.tipo, child: Text('${e.descripcion} (${e.puntos} pts)'))).toList(),
                    onChanged: (v) { if (v != null) setState(() => _cargo = v); },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: DropdownButtonFormField<TipoGestion>(initialValue: _tipoGestion, decoration: const InputDecoration(labelText: 'Gestión', isDense: true), items: const [DropdownMenuItem(value: TipoGestion.publica, child: Text('Pública')), DropdownMenuItem(value: TipoGestion.privada, child: Text('Privada'))], onChanged: (v) { if (v != null) setState(() => _tipoGestion = v); }),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: DropdownButtonFormField<NivelEducativo>(initialValue: _nivel, decoration: const InputDecoration(labelText: 'Nivel', isDense: true), items: const [DropdownMenuItem(value: NivelEducativo.inicial, child: Text('Inicial')), DropdownMenuItem(value: NivelEducativo.primario, child: Text('Primario')), DropdownMenuItem(value: NivelEducativo.secundario, child: Text('Secundario')), DropdownMenuItem(value: NivelEducativo.terciario, child: Text('Terciario')), DropdownMenuItem(value: NivelEducativo.superior, child: Text('Superior'))], onChanged: (v) { if (v != null) setState(() => _nivel = v); }),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: DropdownButtonFormField<ZonaDesfavorable>(initialValue: _zona, decoration: const InputDecoration(labelText: 'Zona', isDense: true), items: const [DropdownMenuItem(value: ZonaDesfavorable.a, child: Text('A')), DropdownMenuItem(value: ZonaDesfavorable.b, child: Text('B')), DropdownMenuItem(value: ZonaDesfavorable.c, child: Text('C')), DropdownMenuItem(value: ZonaDesfavorable.d, child: Text('D')), DropdownMenuItem(value: ZonaDesfavorable.e, child: Text('E'))], onChanged: (v) { if (v != null) setState(() => _zona = v); }),
                ),
                ListTile(title: const Text('Fecha ingreso'), subtitle: Text(DateFormat('dd/MM/yyyy').format(_fechaIngreso)), onTap: () async {
                  final d = await showDatePicker(context: context, initialDate: _fechaIngreso, firstDate: DateTime(1950), lastDate: DateTime.now());
                  if (d != null) setState(() => _fechaIngreso = d);
                }),
                Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), child: TextFormField(controller: _cargasCtr, decoration: const InputDecoration(labelText: 'Cargas familiares', isDense: true), keyboardType: TextInputType.number, onChanged: (_) => setState(() {}))),
                Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), child: TextFormField(controller: _horasCatCtr, decoration: const InputDecoration(labelText: 'Horas cátedra', isDense: true), keyboardType: TextInputType.number, onChanged: (_) => setState(() {}))),
                Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), child: TextFormField(controller: _cantCargosCtr, decoration: const InputDecoration(labelText: 'Cant. cargos', isDense: true), keyboardType: TextInputType.number, onChanged: (_) => setState(() {}))),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _codigoRnosCtr,
                          decoration: const InputDecoration(labelText: 'Código RNOS', isDense: true),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        onPressed: _mostrarBuscadorRNOS,
                        icon: const Icon(Icons.search, size: 20),
                        tooltip: 'Buscar en catálogo nacional',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(color: AppColors.backgroundLight),
            child: SafeArea(
              child: FilledButton.icon(
                onPressed: _confirmar,
                icon: const Icon(Icons.check_circle, size: 22),
                label: const Text('Confirmar Liquidación'),
                style: FilledButton.styleFrom(backgroundColor: AppColors.pastelMint, foregroundColor: AppColors.background, padding: const EdgeInsets.symmetric(vertical: 14)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmar() {
    if (_cuilCtr.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Complete al menos el CUIL')));
      return;
    }

    final vi = _parseNumFromField(_valorIndiceCtr.text);
    final sb = _parseNumFromField(_sueldoBasicoCtr.text);
    final pts = _parseIntFromField(_puntosCtr.text);
    final antigPct = _parseNumFromField(_antiguedadPctCtr.text);
    final item = NomencladorFederal2026.itemPorTipo(_cargo);
    final esHoraCat = item?.esHoraCatedra ?? false;
    final tieneNumeric = vi != null || sb != null || pts != null || antigPct != null;

    Future<void> continuarConJurisdiccion(bool? updatePlantilla) async {
      if (updatePlantilla == true && tieneNumeric) {
        final id = PlantillaCargoOmni.buildPerfilCargoId(
          jurisdiccion: _jurisdiccion,
          tipoGestion: _tipoGestion,
          tipoNomenclador: _cargo,
          antiguedadAnos: _anosAntiguedad(),
          zona: _zona,
          nivelUbicacion: _nivelUbicacion,
        );
        await PlantillaCargoService.save(PlantillaCargoOmni(
          perfilCargoId: id,
          valorIndice: vi,
          sueldoBasico: sb,
          puntos: pts,
          antiguedadPct: antigPct,
        ));
      }
      if (!mounted) return;

      showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Actualizar parámetros globales'),
          content: const Text('¿Desea actualizar los parámetros globales de la jurisdicción con estos nuevos valores detectados? (p. ej. Valor Índice)'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sí')),
          ],
        ),
      ).then((actualizar) {
        if (actualizar == null) return;
        if (actualizar == true && vi != null) {
          final cfg = JurisdiccionDBOmni.get(_jurisdiccion);
          if (cfg != null) cfg.valorIndice = vi;
        }

        final overrides = DocenteOmniOverrides(
          valorIndiceOverride: vi,
          sueldoBasicoOverride: sb,
          puntosCargoOverride: esHoraCat ? null : pts,
          puntosHoraCatedraOverride: esHoraCat ? pts : null,
        );

        final result = OcrConfirmResult(
          nombre: _nombreCtr.text.trim().isEmpty ? null : _nombreCtr.text.trim(),
          cuil: _cuilCtr.text.trim(),
          jurisdiccion: _jurisdiccion,
          tipoGestion: _tipoGestion,
          cargo: _cargo,
          nivel: _nivel,
          zona: _zona,
          fechaIngreso: _fechaIngreso,
          cargasFamiliares: _parseIntFromField(_cargasCtr.text) ?? 0,
          horasCatedra: _parseIntFromField(_horasCatCtr.text) ?? 0,
          cantidadCargos: _parseIntFromField(_cantCargosCtr.text) ?? 1,
          codigoRnos: _codigoRnosCtr.text.trim().isEmpty ? null : _codigoRnosCtr.text.trim(),
          overrides: overrides,
          updateJurisdiccion: actualizar == true,
          jurisdiccionActualizada: _jurisdiccion,
        );
        if (!context.mounted) return;
        Navigator.pop(context, result);
      });
    }

    if (tieneNumeric) {
      showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Actualizar plantilla'),
          content: const Text('¿Desea actualizar esta plantilla para futuros cálculos de este perfil de cargo?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sí')),
          ],
        ),
      ).then((v) => continuarConJurisdiccion(v));
    } else {
      continuarConJurisdiccion(false);
    }
  }
}
