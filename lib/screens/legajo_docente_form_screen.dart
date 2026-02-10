// Formulario Crear/Editar legajo docente — hereda configuración de la Institución
// PerfilCargoId en tiempo real, conceptos propios, campos provinciales, CUIL Módulo 11

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/teacher_types.dart';
import '../models/teacher_constants.dart';
import '../models/plantilla_cargo_omni.dart';
import '../services/instituciones_service.dart';
import '../services/plantilla_cargo_service.dart';
import '../services/hybrid_store.dart';
import '../data/rnos_docentes_data.dart';
import '../services/teacher_omni_engine.dart';
import '../theme/app_colors.dart';
import '../utils/validadores.dart';
import '../utils/formatters.dart';

class LegajoDocenteFormScreen extends StatefulWidget {
  final String cuitInstitucion;
  final Map<String, dynamic>? legajoExistente;

  const LegajoDocenteFormScreen({super.key, required this.cuitInstitucion, this.legajoExistente});

  @override
  State<LegajoDocenteFormScreen> createState() => _LegajoDocenteFormScreenState();
}

class _LegajoDocenteFormScreenState extends State<LegajoDocenteFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _cuilController = TextEditingController();
  final _cargasController = TextEditingController(text: '0');
  final _horasCatController = TextEditingController(text: '0');
  final _cantCargosController = TextEditingController(text: '1');
  final _codigoRnosController = TextEditingController();
  final _valorIndiceController = TextEditingController();
  final _sueldoBasicoOverrideController = TextEditingController();
  final _itemAulaMontoController = TextEditingController();
  final _puntosCargoController = TextEditingController(text: '0');
  final _puntosHoraCatController = TextEditingController(text: '0');
  final _montosConceptos = <String, TextEditingController>{}; // nombre -> controller

  TipoNomenclador _cargo = TipoNomenclador.maestroGrado;
  NivelEducativo _nivel = NivelEducativo.primario;
  ZonaDesfavorable _zona = ZonaDesfavorable.a;
  NivelUbicacion _nivelUbicacion = NivelUbicacion.urbana;
  DateTime _fechaIngreso = DateTime(2023, 1, 15);
  bool _asistenciaPerfectaAplica = false;
  int? _puntosCargoOverride;
  int? _puntosHoraCatedraOverride;
  final _porcentajeZonaRuralidadController = TextEditingController();

  Map<String, dynamic>? _institucion;
  bool _cargandoInst = true;
  String _perfilCargoIdActual = '';
  String? _ultimoPerfilAlertado;
  List<Map<String, dynamic>> _conceptosPropiosSeleccionados = []; // {nombre, tipo, naturaleza, codigoAfipArca, monto}
  List<Map<String, String>> _datosComplementarios = []; // {nombre, valor}
  bool _showDatosComplementarios = false;

  Jurisdiccion get _jurisdiccion {
    final j = _institucion?['jurisdiccion']?.toString();
    return Jurisdiccion.values.cast<Jurisdiccion?>().firstWhere((e) => e?.name == j, orElse: () => Jurisdiccion.buenosAires) ?? Jurisdiccion.buenosAires;
  }

  TipoGestion get _tipoGestion {
    final t = _institucion?['tipoGestion']?.toString();
    return TipoGestion.values.cast<TipoGestion?>().firstWhere((e) => e?.name == t, orElse: () => TipoGestion.publica) ?? TipoGestion.publica;
  }

  bool get _aplicaItemAula => _institucion?['aplicaItemAula'] == true;
  bool get _asistenciaPerfectaInst => _institucion?['asistenciaPerfecta'] == true;

  List<Map<String, dynamic>> get _listaConceptosPropios {
    final L = _institucion?['listaConceptosPropios'];
    return L is List ? L.map((e) => e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{}).toList() : [];
  }

  int _antiguedadAnos() {
    final ahora = DateTime.now();
    int a = ahora.year - _fechaIngreso.year;
    if (ahora.month < _fechaIngreso.month || (ahora.month == _fechaIngreso.month && ahora.day < _fechaIngreso.day)) a--;
    return a < 0 ? 0 : a;
  }

  String _buildPerfilCargoId() {
    if (_institucion == null) return '';
    return PlantillaCargoOmni.buildPerfilCargoId(
      jurisdiccion: _jurisdiccion,
      tipoGestion: _tipoGestion,
      tipoNomenclador: _cargo,
      antiguedadAnos: _antiguedadAnos(),
      zona: _zona,
      nivelUbicacion: _nivelUbicacion,
    );
  }

  @override
  void initState() {
    super.initState();
    _cargarInstitucion();
    if (widget.legajoExistente != null) _cargarDesdeLegajo(widget.legajoExistente!);
  }

  Future<void> _cargarInstitucion() async {
    final list = await InstitucionesService.getInstituciones();
    final cuit = (widget.cuitInstitucion).replaceAll(RegExp(r'[^\d]'), '');
    Map<String, dynamic>? found;
    for (final e in list) {
      if ((e['cuit']?.toString() ?? '').replaceAll(RegExp(r'[^\d]'), '') == cuit) {
        found = e;
        break;
      }
    }
    // Buscar también en empresas para codigo_rnos
    String? codigoRnosEmpresa;
    try {
      final empresas = await HybridStore.getEmpresas();
      for (final emp in empresas) {
        if ((emp['cuit']?.toString() ?? '').replaceAll(RegExp(r'[^\d]'), '') == cuit) {
          codigoRnosEmpresa = emp['codigo_rnos']?.toString();
          break;
        }
      }
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _institucion = found;
      _cargandoInst = false;
      if (found != null) {
        final zd = found['zonaDefault']?.toString();
        _zona = ZonaDesfavorable.values.cast<ZonaDesfavorable?>().firstWhere((e) => e?.name == zd, orElse: () => ZonaDesfavorable.a) ?? ZonaDesfavorable.a;
        final nud = found['nivelUbicacionDefault']?.toString();
        _nivelUbicacion = NivelUbicacion.values.cast<NivelUbicacion?>().firstWhere(
            (e) => e?.name == nud, orElse: () => NivelUbicacion.urbana) ?? NivelUbicacion.urbana;
        // Calcular porcentaje inicial
        final pctZona = ZonaConstants.porcentaje(_zona);
        final pctUbic = NivelUbicacionConstants.porcentaje(_nivelUbicacion);
        _porcentajeZonaRuralidadController.text = (pctZona + pctUbic).toString();
        // Establecer horas cátedra normales por defecto si es hora cátedra
        final item = NomencladorFederal2026.itemPorTipo(_cargo);
        if (item?.esHoraCatedra ?? false) {
          final cfg = JurisdiccionDBOmni.get(_jurisdiccion);
          final tope = cfg?.topeHorasCatedra ?? 36;
          final cargos = int.tryParse(_cantCargosController.text) ?? 1;
          _horasCatController.text = (tope * cargos).toString();
        }
        // Heredar codigo_rnos de empresa si existe y el campo está vacío
        if (codigoRnosEmpresa != null && codigoRnosEmpresa.isNotEmpty && _codigoRnosController.text.isEmpty) {
          _codigoRnosController.text = codigoRnosEmpresa;
        }
      }
    });
    if (found != null) _actualizarPerfilIdYRevisarPlantilla();
  }

  void _cargarDesdeLegajo(Map<String, dynamic> l) {
    _nombreController.text = l['nombre']?.toString() ?? '';
    _cuilController.text = l['cuil']?.toString() ?? '';
    _cargasController.text = (l['cargasFamiliares'] is int ? l['cargasFamiliares'] as int : int.tryParse(l['cargasFamiliares']?.toString() ?? '') ?? 0).toString();
    _horasCatController.text = (l['horasCatedra'] is int ? l['horasCatedra'] as int : int.tryParse(l['horasCatedra']?.toString() ?? '') ?? 0).toString();
    _cantCargosController.text = (l['cantidadCargos'] is int ? l['cantidadCargos'] as int : int.tryParse(l['cantidadCargos']?.toString() ?? '') ?? 1).toString();
    _codigoRnosController.text = l['codigoRnos']?.toString() ?? '';
    _valorIndiceController.text = l['valorIndice']?.toString() ?? '';
    _sueldoBasicoOverrideController.text = l['sueldoBasicoOverride']?.toString() ?? '';
    _itemAulaMontoController.text = (l['itemAulaMonto'] is num) ? (l['itemAulaMonto'] as num).toString() : (l['itemAulaMonto']?.toString() ?? '');
    _asistenciaPerfectaAplica = l['asistenciaPerfectaAplica'] == true;
    _puntosCargoOverride = l['puntosCargoOverride'] is int ? l['puntosCargoOverride'] as int : int.tryParse(l['puntosCargoOverride']?.toString() ?? '');
    _puntosHoraCatedraOverride = l['puntosHoraCatedraOverride'] is int ? l['puntosHoraCatedraOverride'] as int : int.tryParse(l['puntosHoraCatedraOverride']?.toString() ?? '');
    _puntosCargoController.text = (_puntosCargoOverride ?? 0).toString();
    _puntosHoraCatController.text = (_puntosHoraCatedraOverride ?? 0).toString();
    final fi = l['fechaIngreso']?.toString();
    if (fi != null && fi.isNotEmpty) { final d = DateTime.tryParse(fi); if (d != null) _fechaIngreso = d; }
    final c = l['cargo']?.toString(); if (c != null) _cargo = TipoNomenclador.values.cast<TipoNomenclador?>().firstWhere((e) => e?.name == c, orElse: () => TipoNomenclador.maestroGrado) ?? TipoNomenclador.maestroGrado;
    final n = l['nivel']?.toString(); if (n != null) _nivel = NivelEducativo.values.cast<NivelEducativo?>().firstWhere((e) => e?.name == n, orElse: () => NivelEducativo.primario) ?? NivelEducativo.primario;
    // Cargar zona y nivel ubicación del legajo si existen, sino heredar de la institución
    final z = l['zona']?.toString(); if (z != null) _zona = ZonaDesfavorable.values.cast<ZonaDesfavorable?>().firstWhere((e) => e?.name == z, orElse: () => _zona) ?? _zona;
    final u = l['nivelUbicacion']?.toString(); if (u != null) _nivelUbicacion = NivelUbicacion.values.cast<NivelUbicacion?>().firstWhere((e) => e?.name == u, orElse: () => _nivelUbicacion) ?? _nivelUbicacion;
    // Calcular porcentaje
    final pctZona = ZonaConstants.porcentaje(_zona);
    final pctUbic = NivelUbicacionConstants.porcentaje(_nivelUbicacion);
    _porcentajeZonaRuralidadController.text = (pctZona + pctUbic).toString();
    final dc = l['datosComplementarios'];
    if (dc is List && dc.isNotEmpty) {
      _datosComplementarios = dc.map((e) => <String, String>{'nombre': (e['nombre'] ?? '').toString(), 'valor': (e['valor'] ?? '').toString()}).toList();
      _showDatosComplementarios = true;
    }
    final L = l['conceptosPropiosActivos'];
    if (L is List) {
      _conceptosPropiosSeleccionados = L.map((e) => e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{}).toList();
      for (final m in _conceptosPropiosSeleccionados) {
        final nom = m['nombre']?.toString() ?? '';
        if (nom.isNotEmpty) _montosConceptos[nom] = TextEditingController(text: (m['monto'] is num) ? (m['monto'] as num).toString() : (m['monto']?.toString() ?? '0'));
      }
    }
  }

  Future<void> _actualizarPerfilIdYRevisarPlantilla() async {
    final id = _buildPerfilCargoId();
    if (id.isEmpty) return;
    final plantilla = await PlantillaCargoService.getByPerfilId(id);
    if (!mounted || plantilla == null || _ultimoPerfilAlertado == id) return;
    _ultimoPerfilAlertado = id;
    final aplicar = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: AppColors.backgroundLight,
        title: const Text('¡Plantilla encontrada!', style: TextStyle(color: AppColors.textPrimary)),
        content: const Text('¿Desea aplicar los valores sugeridos (Básico, Índice, Puntos)?', style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('No')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Sí, aplicar')),
        ],
      ),
    );
    if (aplicar == true && mounted) {
      final esHoraCat = NomencladorFederal2026.itemPorTipo(_cargo)?.esHoraCatedra ?? false;
      setState(() {
        _valorIndiceController.text = AppNumberFormatter.format(plantilla.valorIndice, valorIndice: true);
        _sueldoBasicoOverrideController.text = AppNumberFormatter.format(plantilla.sueldoBasico, valorIndice: false);
        if (plantilla.puntos != null) { if (esHoraCat) {
          _puntosHoraCatedraOverride = plantilla.puntos;
          _puntosHoraCatController.text = (plantilla.puntos ?? 0).toString();
        } else {
          _puntosCargoOverride = plantilla.puntos;
          _puntosCargoController.text = (plantilla.puntos ?? 0).toString();
        } }
      });
    }
  }

  void _toggleConceptoPropio(Map<String, dynamic> c, bool selected) {
    final nom = c['nombre']?.toString() ?? '';
    if (nom.isEmpty) return;
    setState(() {
      if (selected) {
        _conceptosPropiosSeleccionados.add({'nombre': nom, 'tipo': c['tipo'] ?? 'sumaFija', 'naturaleza': c['naturaleza'] ?? 'remunerativo', 'codigoAfipArca': c['codigoAfipArca'] ?? '011000', 'monto': 0.0});
        _montosConceptos[nom] = TextEditingController(text: AppNumberFormatter.format(0, valorIndice: false));
      } else {
        _conceptosPropiosSeleccionados.removeWhere((e) => (e['nombre']?.toString() ?? '') == nom);
        _montosConceptos[nom]?.dispose();
        _montosConceptos.remove(nom);
      }
    });
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
                                _codigoRnosController.text = os.codigoArca;
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

  @override
  void dispose() {
    _nombreController.dispose();
    _cuilController.dispose();
    _cargasController.dispose();
    _horasCatController.dispose();
    _cantCargosController.dispose();
    _codigoRnosController.dispose();
    _valorIndiceController.dispose();
    _sueldoBasicoOverrideController.dispose();
    _itemAulaMontoController.dispose();
    _puntosCargoController.dispose();
    _puntosHoraCatController.dispose();
    _porcentajeZonaRuralidadController.dispose();
    for (final c in _montosConceptos.values) {
      c.dispose();
    }
    super.dispose();
  }

  String? _validatorCuil(String? v) {
    if (v == null || v.trim().isEmpty) return 'Ingrese el CUIL';
    final d = v.replaceAll(RegExp(r'[^\d]'), '');
    if (d.length != 11) return 'CUIL debe tener 11 dígitos';
    if (!validarCUITCUIL(v)) return 'CUIL inválido (Módulo 11)';
    return null;
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    final cuil = _cuilController.text.replaceAll(RegExp(r'[^\d]'), '');
    if (cuil.length != 11 || !validarCUITCUIL(_cuilController.text)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('CUIL inválido (verifique Módulo 11)')));
      return;
    }
    final conceptos = <Map<String, dynamic>>[];
    for (final m in _conceptosPropiosSeleccionados) {
      final nom = m['nombre']?.toString() ?? '';
      final ctrl = _montosConceptos[nom];
      final mont = ctrl != null ? (double.tryParse(ctrl.text.replaceAll(',', '.')) ?? 0.0) : 0.0;
      conceptos.add({'nombre': nom, 'tipo': m['tipo'], 'naturaleza': m['naturaleza'], 'codigoAfipArca': m['codigoAfipArca'], 'monto': mont});
    }
    try {
      final map = <String, dynamic>{
        'nombre': _nombreController.text.trim(),
        'cuil': _cuilController.text.trim(),
        'fechaIngreso': DateFormat('yyyy-MM-dd').format(_fechaIngreso),
        'cargo': _cargo.name, 'nivel': _nivel.name, 'zona': _zona.name, 'nivelUbicacion': _nivelUbicacion.name,
        'cargasFamiliares': int.tryParse(_cargasController.text) ?? 0,
        'horasCatedra': int.tryParse(_horasCatController.text) ?? 0,
        'cantidadCargos': int.tryParse(_cantCargosController.text) ?? 1,
        'codigoRnos': _codigoRnosController.text.trim().isEmpty ? null : _codigoRnosController.text.trim(),
        'valorIndice': _valorIndiceController.text.trim().isEmpty ? null : _valorIndiceController.text.trim(),
        'sueldoBasicoOverride': _sueldoBasicoOverrideController.text.trim().isEmpty ? null : _sueldoBasicoOverrideController.text.trim(),
        'conceptosPropiosActivos': conceptos,
        'itemAulaMonto': _aplicaItemAula ? (double.tryParse(_itemAulaMontoController.text.replaceAll(',', '.'))) : null,
        'asistenciaPerfectaAplica': _asistenciaPerfectaInst && _asistenciaPerfectaAplica,
        'datosComplementarios': _datosComplementarios.where((d) => (d['nombre'] ?? '').toString().trim().isNotEmpty).map((d) => {'nombre': (d['nombre'] ?? '').toString().trim(), 'valor': (d['valor'] ?? '').toString().trim()}).toList(),
      };
      // Agregar puntos con valor por defecto 0 si están vacíos
      final po = _puntosCargoOverride ?? 0;
      final ph = _puntosHoraCatedraOverride ?? 0;
      map['puntosCargoOverride'] = po;
      map['puntosHoraCatedraOverride'] = ph;
      await InstitucionesService.saveLegajoDocente(widget.cuitInstitucion, map);
      if (!mounted) return;
      final agregarOtro = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          backgroundColor: AppColors.backgroundLight,
          title: const Text('¿Desea agregar otro empleado?', style: TextStyle(color: AppColors.textPrimary)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('No')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Sí')),
          ],
        ),
      );
      if (!mounted) return;
      if (agregarOtro == true) {
        _resetFormParaNuevo();
        return;
      }
      Navigator.pop(context, 'ficha_creada');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _resetFormParaNuevo() {
    _nombreController.clear();
    _cuilController.clear();
    _cargasController.text = '0';
    _horasCatController.text = '0';
    _cantCargosController.text = '1';
    _codigoRnosController.clear();
    _valorIndiceController.clear();
    _sueldoBasicoOverrideController.clear();
    _itemAulaMontoController.clear();
    setState(() {
      _asistenciaPerfectaAplica = false;
      _puntosCargoOverride = null;
      _puntosHoraCatedraOverride = null;
      _puntosCargoController.text = '0';
      _puntosHoraCatController.text = '0';
      _conceptosPropiosSeleccionados = [];
      for (final c in _montosConceptos.values) c.dispose();
      _montosConceptos.clear();
    });
  }

  Widget _buildSueldoBasicoConEstimado() {
    final cfg = JurisdiccionDBOmni.get(_jurisdiccion);
    final item = NomencladorFederal2026.itemPorTipo(_cargo);
    final vi = cfg?.valorIndice ?? 0.0;
    final esHoraCat = item?.esHoraCatedra ?? false;
    final hrs = int.tryParse(_horasCatController.text) ?? 0;
    final cnt = int.tryParse(_cantCargosController.text) ?? 1;
    final pts = item != null
        ? (esHoraCat ? item.puntos * hrs : item.puntos * (cnt < 1 ? 1 : cnt))
        : 0.0;
    final est = pts * vi;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTextField(
          controller: _sueldoBasicoOverrideController,
          label: 'Sueldo básico (opcional)',
          icon: Icons.payments,
          keyboardType: TextInputType.number,
        ),
        if (est > 0)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Estimado nacional (solo informativo): \$${est.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ),
      ],
    );
  }

  Widget _buildCamposPuntos() {
    return Row(
      children: [
        Expanded(
          child: _buildTextField(
            controller: _puntosCargoController,
            label: 'Puntos cargo (opcional)',
            icon: Icons.numbers,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            validator: null,
            onChanged: (v) {
              final val = int.tryParse(v ?? '') ?? 0;
              setState(() => _puntosCargoOverride = val > 0 ? val : null);
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildTextField(
            controller: _puntosHoraCatController,
            label: 'Puntos hora cátedra (opcional)',
            icon: Icons.schedule,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            validator: null,
            onChanged: (v) {
              final val = int.tryParse(v ?? '') ?? 0;
              setState(() => _puntosHoraCatedraOverride = val > 0 ? val : null);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBotonGuardarPlantilla() {
    final perfilId = _buildPerfilCargoId();
    if (perfilId.isEmpty) return const SizedBox.shrink();
    return ElevatedButton.icon(
      onPressed: () async {
        final vi = _valorIndiceController.text.trim().isNotEmpty
            ? double.tryParse(_valorIndiceController.text.replaceAll(',', '.'))
            : null;
        final sb = _sueldoBasicoOverrideController.text.trim().isNotEmpty
            ? double.tryParse(_sueldoBasicoOverrideController.text.replaceAll(',', '.'))
            : null;
        final item = NomencladorFederal2026.itemPorTipo(_cargo);
        final esHoraCat = item?.esHoraCatedra ?? false;
        final pt = esHoraCat ? _puntosHoraCatedraOverride : _puntosCargoOverride;
        if (vi == null && sb == null && pt == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Complete valor índice, sueldo básico o puntos para guardar plantilla.')),
          );
          return;
        }
        try {
          await PlantillaCargoService.save(PlantillaCargoOmni(
            perfilCargoId: perfilId,
            valorIndice: vi,
            sueldoBasico: sb,
            puntos: pt,
          ));
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Plantilla guardada. Se sugerirá en futuros legajos con este perfil.')),
          );
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al guardar plantilla: $e')),
          );
        }
      },
      icon: const Icon(Icons.bookmark, size: 18),
      label: const Text('Guardar como plantilla'),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.glassFillStrong,
        foregroundColor: AppColors.textPrimary,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.glassBorder),
        ),
        elevation: 0,
      ),
    );
  }

  InputDecoration _dropdownDecoration(String label, IconData icon) => InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.textMuted),
        prefixIcon: Icon(icon, color: AppColors.textMuted),
        filled: true,
        fillColor: AppColors.glassFill,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.glassBorder)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.pastelBlue, width: 2)),
      );

  /// Secciones dinámicas por jurisdicción (Item Aula, Asistencia Perfecta, Conceptos).
  /// Valida _institucion y accesos para evitar nulos si la institución tarda en cargar.
  List<Widget> _buildSeccionesProvinciales() {
    final list = <Widget>[];
    if (_institucion == null) return list;
    if (_institucion!['aplicaItemAula'] == true) {
      list.add(const SizedBox(height: 24));
      list.add(_buildSeccionItemAula());
    }
    if (_institucion!['asistenciaPerfecta'] == true) {
      list.add(const SizedBox(height: 24));
      list.add(_buildSeccionAsistenciaPerfecta());
    }
    final L = _institucion!['listaConceptosPropios'];
    final conceptos = L is List ? L : <dynamic>[];
    if (conceptos.isNotEmpty) {
      list.add(const SizedBox(height: 24));
      list.add(_buildSeccionConceptosPropios());
    }
    return list;
  }

  Widget _buildSeccionItemAula() {
    return _buildSeccion('Ítem Aula (Mendoza)', Icons.school, [
      _buildTextField(controller: _itemAulaMontoController, label: 'Monto o puntaje Ítem Aula', icon: Icons.attach_money, keyboardType: TextInputType.number),
    ]);
  }

  Widget _buildSeccionAsistenciaPerfecta() {
    return _buildSeccion('Asistencia Perfecta (Santa Fe)', Icons.verified_user, [
      SwitchListTile(
        value: _asistenciaPerfectaAplica,
        onChanged: (v) => setState(() => _asistenciaPerfectaAplica = v),
        title: const Text('Aplica Asistencia Perfecta', style: TextStyle(color: AppColors.textPrimary)),
        activeThumbColor: AppColors.pastelBlue,
      ),
    ]);
  }

  Widget _buildSeccionDatosComplementarios() {
    return _buildSeccion('Datos complementarios', Icons.add_box, [
      InkWell(
        onTap: () => setState(() => _showDatosComplementarios = !_showDatosComplementarios),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Agregar más datos complementarios', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w500)),
              Icon(_showDatosComplementarios ? Icons.expand_less : Icons.expand_more, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
      if (_showDatosComplementarios) ...[
        const SizedBox(height: 12),
        ...List.generate(_datosComplementarios.length, (i) {
          final d = _datosComplementarios[i];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: d['nombre'],
                    decoration: const InputDecoration(labelText: 'Nombre', isDense: true),
                    style: const TextStyle(color: AppColors.textPrimary),
                    onChanged: (v) => setState(() => _datosComplementarios[i] = {'nombre': v, 'valor': d['valor'] ?? ''}),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    initialValue: d['valor'],
                    decoration: const InputDecoration(labelText: 'Valor', isDense: true),
                    style: const TextStyle(color: AppColors.textPrimary),
                    onChanged: (v) => setState(() => _datosComplementarios[i] = {'nombre': d['nombre'] ?? '', 'valor': v}),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline, color: AppColors.textMuted, size: 22),
                  onPressed: () => setState(() => _datosComplementarios.removeAt(i)),
                ),
              ],
            ),
          );
        }),
        TextButton.icon(
          onPressed: () => setState(() => _datosComplementarios.add({'nombre': '', 'valor': ''})),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Agregar más datos complementarios'),
          style: TextButton.styleFrom(foregroundColor: AppColors.pastelBlue),
        ),
      ],
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final esEdicion = widget.legajoExistente != null;
    if (_cargandoInst) {
      return Scaffold(backgroundColor: AppColors.background, appBar: AppBar(backgroundColor: Colors.transparent, title: const Text('Cargando…', style: TextStyle(color: AppColors.textPrimary))), body: const Center(child: CircularProgressIndicator(color: AppColors.pastelBlue)));
    }
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.glassFillStrong, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.glassBorder)), child: const Icon(Icons.arrow_back, color: AppColors.textPrimary)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(esEdicion ? 'Editar Legajo' : 'Nuevo Legajo', style: const TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _buildSeccion('Heredado de la Institución', Icons.business, [
              _buildRowReadOnly('Jurisdicción', JurisdiccionDBOmni.get(_jurisdiccion)?.nombre ?? _jurisdiccion.name),
              _buildRowReadOnly('Gestión', _tipoGestion == TipoGestion.publica ? 'Pública' : 'Privada'),
              const SizedBox(height: 16),
              DropdownButtonFormField<ZonaDesfavorable>(
                value: _zona,
                decoration: _dropdownDecoration('Zona', Icons.location_on),
                dropdownColor: AppColors.backgroundLight,
                style: const TextStyle(color: AppColors.textPrimary),
                items: const [
                  DropdownMenuItem(value: ZonaDesfavorable.a, child: Text('Zona A (0%)')),
                  DropdownMenuItem(value: ZonaDesfavorable.b, child: Text('Zona B (20%)')),
                  DropdownMenuItem(value: ZonaDesfavorable.c, child: Text('Zona C (40%)')),
                  DropdownMenuItem(value: ZonaDesfavorable.d, child: Text('Zona D (80%)')),
                  DropdownMenuItem(value: ZonaDesfavorable.e, child: Text('Zona E (110%)')),
                ],
                onChanged: (v) {
                  if (v != null) {
                    setState(() {
                      _zona = v;
                      final pctZona = ZonaConstants.porcentaje(v);
                      final pctUbic = NivelUbicacionConstants.porcentaje(_nivelUbicacion);
                      _porcentajeZonaRuralidadController.text = (pctZona + pctUbic).toString();
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<NivelUbicacion>(
                value: _nivelUbicacion,
                decoration: _dropdownDecoration('Nivel ubicación / Ruralidad', Icons.landscape),
                dropdownColor: AppColors.backgroundLight,
                style: const TextStyle(color: AppColors.textPrimary),
                items: const [
                  DropdownMenuItem(value: NivelUbicacion.urbana, child: Text('Urbana (0%)')),
                  DropdownMenuItem(value: NivelUbicacion.alejada, child: Text('Alejada (20%)')),
                  DropdownMenuItem(value: NivelUbicacion.inhospita, child: Text('Inhóspita (40%)')),
                  DropdownMenuItem(value: NivelUbicacion.muyInhospita, child: Text('Muy inhóspita (60%)')),
                ],
                onChanged: (v) {
                  if (v != null) {
                    setState(() {
                      _nivelUbicacion = v;
                      final pctZona = ZonaConstants.porcentaje(_zona);
                      final pctUbic = NivelUbicacionConstants.porcentaje(v);
                      _porcentajeZonaRuralidadController.text = (pctZona + pctUbic).toString();
                    });
                  }
                },
              ),
              _buildRowReadOnly('Régimen previsional', (_institucion?['regimenPrevisional']?.toString() ?? 'provincial') == 'nacional' ? 'Nacional' : 'Provincial'),
              _buildRowReadOnly('Aporte jubilatorio', _institucion?['aporteJubilatorio'] != null ? '${(_institucion!['aporteJubilatorio'] as num).toStringAsFixed(1)} %' : '—'),
            ]),
            const SizedBox(height: 24),
            _buildSeccion('Datos personales', Icons.person, [
              _buildTextField(controller: _nombreController, label: 'Nombre y apellido', icon: Icons.person, validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingrese el nombre' : null),
              const SizedBox(height: 16),
              _buildTextField(controller: _cuilController, label: 'CUIL (Módulo 11)', icon: Icons.badge, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(11)], validator: _validatorCuil),
            ]),
            const SizedBox(height: 24),
            _buildSeccion('Cargo y nivel', Icons.work, _buildCargoYNivelChildren()),
            const SizedBox(height: 24),
            _buildSeccion('Otros datos', Icons.tune, [
              ListTile(title: const Text('Fecha ingreso', style: TextStyle(color: AppColors.textPrimary)), subtitle: Text(DateFormat('dd/MM/yyyy').format(_fechaIngreso), style: const TextStyle(color: AppColors.textSecondary)), trailing: const Icon(Icons.calendar_today, color: AppColors.pastelBlue), onTap: () async { final d = await showDatePicker(context: context, initialDate: _fechaIngreso, firstDate: DateTime(1950), lastDate: DateTime.now()); if (d != null) setState(() { _fechaIngreso = d; _actualizarPerfilIdYRevisarPlantilla(); }); }, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), tileColor: AppColors.glassFill),
              const SizedBox(height: 16),
              _buildTextField(controller: _cargasController, label: 'Cargas de familia (hijos, cónyuge — Ganancias 2026)', icon: Icons.family_restroom, keyboardType: TextInputType.number),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _cantCargosController,
                      label: 'Cant. cargos (FONID)',
                      icon: Icons.numbers,
                      keyboardType: TextInputType.number,
                      onChanged: (v) {
                        // Si es hora cátedra y cambia FONID, recalcular horas
                        final item = NomencladorFederal2026.itemPorTipo(_cargo);
                        if (item?.esHoraCatedra ?? false) {
                          final cfg = JurisdiccionDBOmni.get(_jurisdiccion);
                          final tope = cfg?.topeHorasCatedra ?? 36;
                          final cargos = int.tryParse(v ?? '') ?? 1;
                          setState(() => _horasCatController.text = (tope * cargos).toString());
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTextField(
                      controller: _porcentajeZonaRuralidadController,
                      label: 'Porcentaje zona/ruralidad (%)',
                      icon: Icons.percent,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.only(top: 4, bottom: 16),
                child: Text('Modificar a parámetros locales si aplica', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
              ),
              _buildTextField(
                controller: _horasCatController,
                label: 'Horas cátedra',
                icon: Icons.schedule,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _codigoRnosController,
                      label: 'Código RNOS (obra social)',
                      icon: Icons.medical_services,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    onPressed: _mostrarBuscadorRNOS,
                    icon: const Icon(Icons.search),
                    tooltip: 'Buscar en catálogo nacional',
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text('Heredado de la empresa. Editar si el empleado tiene obra social independiente.', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
              ),
              const SizedBox(height: 16),
              _buildTextField(controller: _valorIndiceController, label: 'Valor índice (opcional)', icon: Icons.trending_up, keyboardType: const TextInputType.numberWithOptions(decimal: true)),
              const SizedBox(height: 16),
              _buildSueldoBasicoConEstimado(),
              const SizedBox(height: 16),
              _buildCamposPuntos(),
            ]),
            ..._buildSeccionesProvinciales(),
            const SizedBox(height: 24),
            _buildSeccionDatosComplementarios(),
            const SizedBox(height: 24),
            _buildBotonGuardarPlantilla(),
            const SizedBox(height: 32),
            ElevatedButton(onPressed: _guardar, style: ElevatedButton.styleFrom(backgroundColor: AppColors.pastelBlue, foregroundColor: AppColors.background, padding: const EdgeInsets.symmetric(vertical: 18), shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))), elevation: 0), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.save, size: 22), const SizedBox(width: 8), Text(esEdicion ? 'Actualizar Legajo' : 'Guardar Legajo', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))])),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildCargoYNivelChildren() {
    return [
      DropdownButtonFormField<TipoNomenclador>(
        initialValue: _cargo,
        decoration: _dropdownDecoration('Cargo (Nomenclador 2026)', Icons.badge),
        dropdownColor: AppColors.backgroundLight,
        style: const TextStyle(color: AppColors.textPrimary),
        items: NomencladorFederal2026.items.map((e) => DropdownMenuItem(value: e.tipo, child: Text('${e.descripcion} (${e.puntos} pts)'))).toList(),
        onChanged: (v) {
          if (v != null) {
            setState(() {
              _cargo = v;
              // Si es hora cátedra, establecer horas normales
              final item = NomencladorFederal2026.itemPorTipo(v);
              if (item?.esHoraCatedra ?? false) {
                final cfg = JurisdiccionDBOmni.get(_jurisdiccion);
                final tope = cfg?.topeHorasCatedra ?? 36;
                final cargos = int.tryParse(_cantCargosController.text) ?? 1;
                _horasCatController.text = (tope * cargos).toString();
              }
              _actualizarPerfilIdYRevisarPlantilla();
            });
          }
        },
      ),
      const SizedBox(height: 16),
      DropdownButtonFormField<NivelEducativo>(initialValue: _nivel, decoration: _dropdownDecoration('Nivel', Icons.school), dropdownColor: AppColors.backgroundLight, style: const TextStyle(color: AppColors.textPrimary), items: const [DropdownMenuItem(value: NivelEducativo.inicial, child: Text('Inicial')), DropdownMenuItem(value: NivelEducativo.primario, child: Text('Primario')), DropdownMenuItem(value: NivelEducativo.secundario, child: Text('Secundario')), DropdownMenuItem(value: NivelEducativo.terciario, child: Text('Terciario')), DropdownMenuItem(value: NivelEducativo.superior, child: Text('Superior'))], onChanged: (v) { if (v != null) setState(() => _nivel = v); }),
    ];
  }

  Widget _buildRowReadOnly(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(children: [const Icon(Icons.lock, size: 18, color: AppColors.textMuted), const SizedBox(width: 10), Text('$label: ', style: const TextStyle(color: AppColors.textMuted)), Expanded(child: Text(value, style: const TextStyle(color: AppColors.textPrimary)))])
    );
  }

  Widget _buildSeccionConceptosPropios() {
    return _buildSeccion('Adicionales de la Institución', Icons.playlist_add, [
      const Text('Conceptos propios que se suman al cálculo de este docente.', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
      const SizedBox(height: 12),
      ..._listaConceptosPropios.map((c) {
        final nom = c['nombre']?.toString() ?? '';
        final sel = _conceptosPropiosSeleccionados.any((e) => (e['nombre']?.toString() ?? '') == nom);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CheckboxListTile(
              value: sel,
              onChanged: (v) => _toggleConceptoPropio(c, v ?? false),
              title: Text(nom, style: const TextStyle(color: AppColors.textPrimary)),
              subtitle: Text('${c['tipo']} · ${c['naturaleza']} · AFIP ${c['codigoAfipArca'] ?? ''}', style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
              activeColor: AppColors.pastelBlue,
              controlAffinity: ListTileControlAffinity.leading,
            ),
            if (sel && _montosConceptos[nom] != null) Padding(padding: const EdgeInsets.only(left: 48, bottom: 8), child: SizedBox(height: 48, child: TextFormField(controller: _montosConceptos[nom], decoration: const InputDecoration(labelText: 'Monto', isDense: true, border: OutlineInputBorder()), keyboardType: const TextInputType.numberWithOptions(decimal: true), inputFormatters: [AppNumberFormatter.inputFormatter(valorIndice: false)]))),
          ],
        );
      }),
    ]);
  }

  Widget _buildSeccion(String titulo, IconData icono, List<Widget> children) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: AppColors.glassFillStrong, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.glassBorder)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.pastelBlue.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)), child: Icon(icono, color: AppColors.pastelBlue, size: 20)), const SizedBox(width: 12), Text(titulo, style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold))]),
            const SizedBox(height: 16),
            ...children,
          ]),
        ),
      ),
    );
  }

  Widget _buildTextField({required TextEditingController controller, required String label, required IconData icon, TextInputType? keyboardType, List<TextInputFormatter>? inputFormatters, String? Function(String?)? validator, void Function(String?)? onChanged, String? hint}) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(labelText: label, hintText: hint, labelStyle: const TextStyle(color: AppColors.textMuted), prefixIcon: Icon(icon, color: AppColors.textMuted), filled: true, fillColor: AppColors.glassFill, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.glassBorder)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.pastelBlue, width: 2))),
      validator: validator,
      onChanged: onChanged,
    );
  }
}
