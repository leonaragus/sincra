// Pantalla de liquidación docente: Datos empleado, Simulador, Detalle, Costo empleador, Export.
// Se abre desde "Institución ya creada" (con cuit/razon) o "Liquidación mensual".
// Toda la lógica de cálculo (TeacherOmniEngine, exports, PDF, LSD, Pack ARCA) vive aquí.

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import '../utils/image_bytes_reader.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import '../models/teacher_types.dart';
import '../models/teacher_constants.dart';
import '../models/empresa.dart';
import '../models/empleado.dart';
import '../models/ocr_confirm_result.dart';
import '../theme/app_colors.dart';
import '../data/rnos_docentes_data.dart';
import '../services/teacher_omni_engine.dart' show DocenteOmniInput, TeacherOmniEngine, ConceptoPropioOmni, LiquidacionOmniResult;
import '../services/lsd_mapping_service.dart';
import '../services/teacher_lsd_export.dart';
import '../services/teacher_arca_pack_export.dart';
import '../services/instituciones_service.dart';
import '../services/costo_empleador_service.dart';
import '../services/teacher_receipt_scan_service.dart' show DocenteOmniOverrides;
import '../services/parametros_legales_service.dart';
import '../services/paritarias_service.dart';
import '../utils/pdf_recibo.dart';
import '../utils/formatters.dart';
import '../widgets/teacher_receipt_preview_widget.dart';
import 'teacher_receipt_scan_screen.dart';
import '../utils/app_help.dart';
import '../services/contabilidad_service.dart';
import '../services/contabilidad_config_service.dart';
import '../services/liquidacion_history_service.dart';
import '../services/retroactivo_service.dart';
import '../services/excel_export_service.dart';

class LiquidacionDocenteScreen extends StatefulWidget {
  final String? cuitInstitucion;
  final String? razonSocial;
  /// Si true, pre-configura cargo Hora Cátedra y cant. cargos 0 para liquidar solo horas cátedra.
  final bool soloHorasCatedra;
  /// Modo de liquidación: "mensual", "sac", "vacaciones", "final"
  final String modo;

  const LiquidacionDocenteScreen({
    super.key, 
    this.cuitInstitucion, 
    this.razonSocial, 
    this.soloHorasCatedra = false,
    this.modo = "mensual",
  });

  @override
  State<LiquidacionDocenteScreen> createState() => _LiquidacionDocenteScreenState();
}

class _LiquidacionDocenteScreenState extends State<LiquidacionDocenteScreen> {
  final _nombreController = TextEditingController();
  final _cuilController = TextEditingController();
  final _codigoRnosController = TextEditingController();
  final _cuitEmpresaController = TextEditingController();
  final _razonSocialController = TextEditingController();
  final _domicilioController = TextEditingController();
  final _cargasController = TextEditingController(text: '0');
  final _horasCatController = TextEditingController(text: '0');
  final _cantCargosController = TextEditingController(text: '1');
  final _artPctController = TextEditingController(text: '3.5');
  final _artCuotaFijaController = TextEditingController(text: '800');
  final _valorIndiceController = TextEditingController();
  final _sueldoBasicoOverrideController = TextEditingController();

  // --- Campos para Suite Profesional ---
  final _mejorRemuneracionController = TextEditingController();
  final _diasSACController = TextEditingController(text: '180');
  final _diasVacacionesController = TextEditingController(text: '14');
  final _promedioVariablesController = TextEditingController();
  final _baseIndemnizatoriaController = TextEditingController();
  final _fechaCeseController = TextEditingController();
  String _motivoCese = "renuncia";
  bool _incluyePreaviso = false;

  Jurisdiccion _jurisdiccion = Jurisdiccion.neuquen;
  TipoGestion _tipoGestion = TipoGestion.privada;
  TipoNomenclador _cargo = TipoNomenclador.maestroGrado;
  NivelEducativo _nivel = NivelEducativo.primario;
  ZonaDesfavorable _zona = ZonaDesfavorable.a;
  NivelUbicacion _nivelUbicacion = NivelUbicacion.urbana;
  DateTime _fechaIngreso = DateTime(2023, 1, 15);
  final List<ConceptoPropioOmni> _conceptosPropios = [];
  final Map<String, double> _deduccionesAdicionales = {};
  DocenteOmniOverrides? _ocrOverrides;

  LiquidacionOmniResult? _resultado;
  bool _cargando = false;
  // bool _exportandoMasivo = false; // Removed unused field
  bool _sincronizandoParitarias = false;
  Map<String, dynamic>? _infoSincronizacion;
  bool _savingMaestro = false;
  bool _maestroLoading = false;
  List<Paritaria> _paritariasMaestras = [];

  List<Map<String, dynamic>> _instituciones = [];
  String? _cuitSeleccionado;
  List<Map<String, dynamic>> _legajosDocente = [];
  String? _legajoSeleccionadoCuil;
  
  // === LOGO Y FIRMA DIGITAL (ARCA 2026) ===
  String? _logoPath;
  String? _firmaPath;

  bool get _esZonaPatagonica => [Jurisdiccion.rioNegro, Jurisdiccion.neuquen, Jurisdiccion.chubut, Jurisdiccion.santaCruz, Jurisdiccion.tierraDelFuego].contains(_jurisdiccion);

  @override
  void initState() {
    super.initState();
    if (widget.soloHorasCatedra) {
      _cargo = TipoNomenclador.horaCatedraMedia;
      _cantCargosController.text = '0';
    }
    if (widget.cuitInstitucion != null && widget.cuitInstitucion!.isNotEmpty) {
      _initConInstitucion();
    } else {
      _cargarInstituciones();
    }
    _sincronizarParitarias();
    _nombreController.addListener(_recalcular);
    _cuilController.addListener(_recalcular);
    _cargasController.addListener(_recalcular);
    _horasCatController.addListener(_recalcular);
    _cantCargosController.addListener(_recalcular);
    _valorIndiceController.addListener(_recalcular);
    _sueldoBasicoOverrideController.addListener(_recalcular);
    _recalcular();
  }

  Future<void> _initConInstitucion() async {
    final cuit = (widget.cuitInstitucion ?? '').replaceAll(RegExp(r'[^\d]'), '');
    if (cuit.isEmpty) return;
    setState(() => _cuitSeleccionado = cuit);
    final list = await InstitucionesService.getInstituciones();
    Map<String, dynamic>? found;
    for (final e in list) {
      if ((e['cuit']?.toString() ?? '').replaceAll(RegExp(r'[^\d]'), '') == cuit) {
        found = e;
        break;
      }
    }
    if (found != null && mounted) {
      setState(() => _prefillFromInstitucion(found!));
    }
    await _cargarLegajosDocente();
  }

  Future<void> _sincronizarParitarias() async {
    if (_sincronizandoParitarias) return;
    setState(() => _sincronizandoParitarias = true);
    final res = await ParitariasService.sincronizarParitarias();
    if (mounted) {
      setState(() {
        _infoSincronizacion = res;
        _sincronizandoParitarias = false;
      });
      if (res['success'] == true) _recalcular();
    }
  }

  Future<void> _handleAbrirMaestro() async {
    setState(() {
      _maestroLoading = true;
    });
    
    // Mostrar el modal
    _mostrarModalMaestro();

    try {
      final res = await ParitariasService.sincronizarParitarias();
      if (mounted) {
        setState(() {
          final list = res['data'] as List?;
          if (list != null) {
            _paritariasMaestras = list.map((e) => Paritaria.fromMap(e as Map<String, dynamic>)).toList();
          }
          _maestroLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _maestroLoading = false);
      print('Error cargando maestro: $e');
    }
  }

  void _mostrarModalMaestro() {
    showDialog(
      context: context,
      barrierDismissible: !_savingMaestro,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              backgroundColor: AppColors.background,
              title: const Row(
                children: [
                  Icon(Icons.settings, color: Colors.blue),
                  SizedBox(width: 10),
                  Text('Ajustes Locales (Paritarias)', style: TextStyle(color: Colors.white, fontSize: 18)),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: _maestroLoading 
                  ? const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 20),
                        Text('Cargando paritarias...', style: TextStyle(color: Colors.white70)),
                      ],
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: Text(
                            'Personalizá los valores para tus liquidaciones. Estos cambios NO afectan a otros usuarios.',
                            style: TextStyle(color: Colors.white60, fontSize: 12),
                          ),
                        ),
                        Flexible(
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: _paritariasMaestras.length,
                            itemBuilder: (context, index) {
                              final p = _paritariasMaestras[index];
                              return Card(
                                color: AppColors.glassFill,
                                margin: const EdgeInsets.only(bottom: 8),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(p.nombreMostrar, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 10),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: TextField(
                                              decoration: const InputDecoration(labelText: 'Valor Índice', labelStyle: TextStyle(fontSize: 12)),
                                              style: const TextStyle(color: AppColors.accentEmerald, fontSize: 14),
                                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                              controller: TextEditingController(text: p.valorIndice.toString()),
                                              onChanged: (v) => p.valorIndice = double.tryParse(v) ?? p.valorIndice,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          IconButton(
                                            icon: const Icon(Icons.save, color: AppColors.accentEmerald),
                                            onPressed: _savingMaestro ? null : () async {
                                              setModalState(() => _savingMaestro = true);
                                              try {
                                                await ParametrosLegalesService.actualizarParitariaProvincial(
                                                  p.jurisdiccion, 
                                                  {
                                                    'valor_indice': p.valorIndice,
                                                    'piso_salarial': p.pisoSalarial,
                                                    'monto_fonid': p.montoFonid,
                                                    'monto_conectividad': p.montoConectividad,
                                                    'metadata': p.metadata, // Guardar metadata actualizada
                                                    'fuente_legal': 'Ajuste manual local',
                                                    'updated_at': DateTime.now().toIso8601String(),
                                                  }
                                                );
                                                // Recargar cache en memoria del motor
                                                await TeacherOmniEngine.loadParitariasCache();
                                                
                                                if (mounted) {
                                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ajuste local guardado: ${p.nombreMostrar}')));
                                                }
                                              } catch (e) {
                                                if (mounted) {
                                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                                                }
                                              } finally {
                                                setModalState(() => _savingMaestro = false);
                                              }
                                            },
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      const Text('No Docentes (Básicos)', style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: TextField(
                                              decoration: const InputDecoration(labelText: 'Portero', labelStyle: TextStyle(fontSize: 10)),
                                              style: const TextStyle(color: Colors.blueAccent, fontSize: 12),
                                              keyboardType: TextInputType.number,
                                              controller: TextEditingController(text: p.metadata['basico_portero']?.toString() ?? ''),
                                              onChanged: (v) => p.metadata['basico_portero'] = double.tryParse(v) ?? p.metadata['basico_portero'],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: TextField(
                                              decoration: const InputDecoration(labelText: 'Admin.', labelStyle: TextStyle(fontSize: 10)),
                                              style: const TextStyle(color: Colors.blueAccent, fontSize: 12),
                                              keyboardType: TextInputType.number,
                                              controller: TextEditingController(text: p.metadata['basico_administrativo']?.toString() ?? ''),
                                              onChanged: (v) => p.metadata['basico_administrativo'] = double.tryParse(v) ?? p.metadata['basico_administrativo'],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: TextField(
                                              decoration: const InputDecoration(labelText: 'Maestranza', labelStyle: TextStyle(fontSize: 10)),
                                              style: const TextStyle(color: Colors.blueAccent, fontSize: 12),
                                              keyboardType: TextInputType.number,
                                              controller: TextEditingController(text: p.metadata['basico_maestranza']?.toString() ?? ''),
                                              onChanged: (v) => p.metadata['basico_maestranza'] = double.tryParse(v) ?? p.metadata['basico_maestranza'],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
              ),
              actions: [
                TextButton(
                  onPressed: _savingMaestro ? null : () => Navigator.pop(context),
                  child: const Text('Cerrar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _cargarInstituciones() async {
    final list = await InstitucionesService.getInstituciones();
    if (mounted) setState(() => _instituciones = list);
  }

  Future<void> _cargarLegajosDocente() async {
    final cuit = _cuitSeleccionado;
    if (cuit == null || cuit.isEmpty) return;
    final list = await InstitucionesService.getLegajosDocente(cuit);
    if (mounted) setState(() => _legajosDocente = list);
  }

  void _prefillFromInstitucion(Map<String, dynamic> i) {
    _cuitEmpresaController.text = i['cuit']?.toString() ?? '';
    _razonSocialController.text = i['razonSocial']?.toString() ?? '';
    _domicilioController.text = i['domicilio']?.toString() ?? '';
    final j = i['jurisdiccion']?.toString();
    _jurisdiccion = Jurisdiccion.values.cast<Jurisdiccion?>().firstWhere((e) => e?.name == j, orElse: () => Jurisdiccion.buenosAires) ?? Jurisdiccion.buenosAires;
    _tipoGestion = TipoGestion.values.cast<TipoGestion?>().firstWhere((e) => e?.name == (i['tipoGestion']?.toString()), orElse: () => TipoGestion.publica) ?? TipoGestion.publica;
    _artPctController.text = AppNumberFormatter.format(i['artPct'] ?? 3.5, valorIndice: false);
    _artCuotaFijaController.text = AppNumberFormatter.format(i['artCuotaFija'] ?? 800, valorIndice: false);
    // Logo y firma ARCA 2026
    final logo = i['logoPath']?.toString();
    _logoPath = (logo == null || logo.isEmpty || logo == 'No disponible') ? null : logo;
    final firma = i['firmaPath']?.toString();
    _firmaPath = (firma == null || firma.isEmpty || firma == 'No disponible') ? null : firma;
  }

  void _prefillFromLegajoDocente(Map<String, dynamic> l) {
    _nombreController.text = l['nombre']?.toString() ?? '';
    _cuilController.text = l['cuil']?.toString() ?? '';
    _cargasController.text = (l['cargasFamiliares'] is int ? l['cargasFamiliares'] as int : int.tryParse(l['cargasFamiliares']?.toString() ?? '') ?? 0).toString();
    _horasCatController.text = (l['horasCatedra'] is int ? l['horasCatedra'] as int : int.tryParse(l['horasCatedra']?.toString() ?? '') ?? 0).toString();
    _cantCargosController.text = (l['cantidadCargos'] is int ? l['cantidadCargos'] as int : int.tryParse(l['cantidadCargos']?.toString() ?? '') ?? 1).toString();
    _codigoRnosController.text = l['codigoRnos']?.toString() ?? '';
    _valorIndiceController.text = l['valorIndice']?.toString() ?? '';
    _sueldoBasicoOverrideController.text = l['sueldoBasicoOverride']?.toString() ?? '';
    final fi = l['fechaIngreso']?.toString();
    if (fi != null && fi.isNotEmpty) {
      final d = DateTime.tryParse(fi);
      if (d != null) _fechaIngreso = d;
    }
    final c = l['cargo']?.toString();
    if (c != null) _cargo = TipoNomenclador.values.cast<TipoNomenclador?>().firstWhere((e) => e?.name == c, orElse: () => TipoNomenclador.maestroGrado) ?? TipoNomenclador.maestroGrado;
    final z = l['zona']?.toString();
    if (z != null) _zona = ZonaDesfavorable.values.cast<ZonaDesfavorable?>().firstWhere((e) => e?.name == z, orElse: () => ZonaDesfavorable.a) ?? ZonaDesfavorable.a;
    final n = l['nivel']?.toString();
    if (n != null) _nivel = NivelEducativo.values.cast<NivelEducativo?>().firstWhere((e) => e?.name == n, orElse: () => NivelEducativo.primario) ?? NivelEducativo.primario;
    final nu = l['nivelUbicacion']?.toString();
    if (nu != null) _nivelUbicacion = NivelUbicacion.values.cast<NivelUbicacion?>().firstWhere((e) => e?.name == nu, orElse: () => NivelUbicacion.urbana) ?? NivelUbicacion.urbana;
    _conceptosPropios.clear();
    final L = l['conceptosPropiosActivos'];
    if (L is List) {
      for (final m in L) {
        if (m is! Map) continue;
        final mont = (m['monto'] is num) ? (m['monto'] as num).toDouble() : (double.tryParse(m['monto']?.toString() ?? '') ?? 0.0);
        _conceptosPropios.add(ConceptoPropioOmni(
          codigo: (m['nombre'] ?? '').toString().replaceAll(RegExp(r'[^\w]'), '_'),
          descripcion: m['nombre']?.toString() ?? '',
          monto: mont,
          esRemunerativo: (m['naturaleza']?.toString() ?? 'remunerativo') == 'remunerativo',
          codigoAfip: m['codigoAfipArca']?.toString() ?? '011000',
        ));
      }
    }
    final pco = l['puntosCargoOverride'];
    final pho = l['puntosHoraCatedraOverride'];
    _ocrOverrides = DocenteOmniOverrides(
      valorIndiceOverride: l['valorIndice'] != null && l['valorIndice'].toString().trim().isNotEmpty ? double.tryParse(l['valorIndice'].toString()) : null,
      sueldoBasicoOverride: l['sueldoBasicoOverride'] != null && l['sueldoBasicoOverride'].toString().trim().isNotEmpty ? double.tryParse(l['sueldoBasicoOverride'].toString()) : null,
      puntosCargoOverride: pco is int ? pco : (pco != null ? int.tryParse(pco.toString()) : null),
      puntosHoraCatedraOverride: pho is int ? pho : (pho != null ? int.tryParse(pho.toString()) : null),
    );

    // --- Lógica de Suite Profesional para defaults ---
    if (widget.modo == "vacaciones") {
      final ahora = DateTime.now();
      final anos = ahora.year - _fechaIngreso.year;
      if (anos < 5) _diasVacacionesController.text = '14';
      else if (anos < 10) _diasVacacionesController.text = '21';
      else if (anos < 20) _diasVacacionesController.text = '28';
      else _diasVacacionesController.text = '35';
    }
    if (widget.modo == "sac") {
      _diasSACController.text = '180';
    }
    if (widget.modo == "final") {
      _fechaCeseController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
    }
  }

  void _recalcular() {
    final nombre = _nombreController.text.trim();
    final cuilRaw = _cuilController.text.replaceAll(RegExp(r'[^\d]'), '');
    if (nombre.isEmpty || cuilRaw.length != 11) {
      setState(() {
        _resultado = null;
        _calculando = false;
      });
      return;
    }
    setState(() => _calculando = true);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final sbOverride = _sueldoBasicoOverrideController.text.trim().isEmpty
          ? _ocrOverrides?.sueldoBasicoOverride
          : double.tryParse(_sueldoBasicoOverrideController.text.replaceAll(',', '.'));

      final input = DocenteOmniInput(
        nombre: nombre,
        cuil: _cuilController.text.trim(),
        jurisdiccion: _jurisdiccion,
        tipoGestion: _tipoGestion,
        cargoNomenclador: _cargo,
        nivelEducativo: _nivel,
        fechaIngreso: _fechaIngreso,
        cargasFamiliares: int.tryParse(_cargasController.text) ?? 0,
        codigoRnos: _codigoRnosController.text.trim().isEmpty ? null : _codigoRnosController.text.trim(),
        horasCatedra: int.tryParse(_horasCatController.text) ?? 0,
        zona: _zona,
        nivelUbicacion: _nivelUbicacion,
        valorIndiceOverride: _valorIndiceController.text.trim().isEmpty ? _ocrOverrides?.valorIndiceOverride : (double.tryParse(_valorIndiceController.text.replaceAll(',', '.')) ?? _ocrOverrides?.valorIndiceOverride),
        sueldoBasicoOverride: sbOverride,
        puntosCargoOverride: _ocrOverrides?.puntosCargoOverride,
        puntosHoraCatedraOverride: _ocrOverrides?.puntosHoraCatedraOverride,
        esHoraCatedraSecundaria: _cargo == TipoNomenclador.horaCatedraMedia,
        // --- Campos Suite Profesional ---
        modoLiquidacion: widget.modo,
        mejorRemuneracionSemestral: double.tryParse(_mejorRemuneracionController.text.replaceAll(',', '.')),
        diasTrabajadosSemestre: int.tryParse(_diasSACController.text),
        diasVacaciones: int.tryParse(_diasVacacionesController.text),
        promedioVariablesSemestral: double.tryParse(_promedioVariablesController.text.replaceAll(',', '.')),
        fechaCese: _fechaCeseController.text.isNotEmpty ? DateFormat('yyyy-MM-dd').parse(_fechaCeseController.text) : null,
        motivoCese: _motivoCese,
        incluyePreaviso: _incluyePreaviso,
        baseIndemnizatoria: double.tryParse(_baseIndemnizatoriaController.text.replaceAll(',', '.')),
      );

      final r = TeacherOmniEngine.liquidar(
        input,
        periodo: DateFormat('MMMM yyyy', 'es_AR').format(DateTime.now()),
        fechaPago: DateFormat('dd/MM/yyyy').format(DateTime.now()),
        cantidadCargos: int.tryParse(_cantCargosController.text) ?? 1,
        conceptosPropios: _conceptosPropios,
        deduccionesAdicionales: _deduccionesAdicionales,
      );
      
      // VALIDACIÓN CRÍTICA: Embargos y descuentos adicionales (20% del neto máximo)
      bool advertenciaEmbargoLegal = false;
      final deduccionesKeys = _deduccionesAdicionales.keys.where((k) => 
        k.toLowerCase().contains('embargo')).toList();
      double totalEmbargos = 0;
      for (final k in deduccionesKeys) {
        totalEmbargos += _deduccionesAdicionales[k] ?? 0;
      }
      if (totalEmbargos > 0) {
        final limiteEmbargoLegal = r.netoACobrar * 0.20;
        if (totalEmbargos > limiteEmbargoLegal) {
          advertenciaEmbargoLegal = true;
        }
      }
      
      // VALIDACIÓN CRÍTICA: Neto positivo
      bool advertenciaNetoNegativo = false;
      if (r.netoACobrar < 0) {
        advertenciaNetoNegativo = true;
      }
      
      if (!mounted) return;
      setState(() {
        _resultado = r;
        _calculando = false;
      });
      
      // Mostrar advertencias después de calcular
      if (advertenciaEmbargoLegal) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '⚠️ LÍMITE LEGAL: Los embargos (\$${totalEmbargos.toStringAsFixed(2)}) '
                'exceden el 20% del neto (\$${(r.netoACobrar * 0.20).toStringAsFixed(2)}). '
                'Se recomienda revisar los descuentos adicionales.',
              ),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 6),
            ),
          );
        });
      }
      
      if (advertenciaNetoNegativo) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.error, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Neto Negativo'),
                ],
              ),
              content: Text(
                'El total de descuentos (\$${r.totalDescuentos.toStringAsFixed(2)}) '
                'excede los haberes (\$${(r.totalBrutoRemunerativo + r.totalNoRemunerativo).toStringAsFixed(2)}).\n\n'
                'Neto a cobrar: \$${r.netoACobrar.toStringAsFixed(2)}\n\n'
                '⚠️ Esta liquidación es INVÁLIDA y no puede procesarse.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Entendido'),
                ),
              ],
            ),
          );
        });
      }
    });
  }

  Future<void> _guardarLegajoDocente() async {
    final cuit = _cuitSeleccionado;
    if (cuit == null || cuit.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Seleccione una institución')));
      return;
    }
    final cuilEmp = _cuilController.text.replaceAll(RegExp(r'[^\d]'), '');
    if (cuilEmp.length != 11) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('CUIL debe tener 11 dígitos')));
      return;
    }
    try {
      await InstitucionesService.saveLegajoDocente(cuit, {
        'nombre': _nombreController.text.trim(),
        'cuil': _cuilController.text.trim(),
        'fechaIngreso': DateFormat('yyyy-MM-dd').format(_fechaIngreso),
        'cargo': _cargo.name,
        'nivel': _nivel.name,
        'zona': _zona.name,
        'tipoGestion': _tipoGestion.name,
        'nivelUbicacion': _nivelUbicacion.name,
        'cargasFamiliares': int.tryParse(_cargasController.text) ?? 0,
        'horasCatedra': int.tryParse(_horasCatController.text) ?? 0,
        'cantidadCargos': int.tryParse(_cantCargosController.text) ?? 1,
        'codigoRnos': _codigoRnosController.text.trim().isEmpty ? null : _codigoRnosController.text.trim(),
        'valorIndice': _valorIndiceController.text.trim().isEmpty ? null : _valorIndiceController.text.trim(),
        'sueldoBasicoOverride': _sueldoBasicoOverrideController.text.trim().isEmpty ? null : _sueldoBasicoOverrideController.text.trim(),
      });
      await _cargarLegajosDocente();
      if (!mounted) return;
      setState(() => _legajoSeleccionadoCuil = cuilEmp);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Legajo guardado')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _eliminarLegajoDocente() async {
    final cuit = _cuitSeleccionado;
    final cuilEmp = _legajoSeleccionadoCuil ?? _cuilController.text.replaceAll(RegExp(r'[^\d]'), '');
    if (cuit == null || cuilEmp.length < 11) return;
    final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      title: const Text('Eliminar legajo'),
      content: const Text('¿Eliminar este empleado de la lista de legajos?'),
      actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')), TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Eliminar'))],
    ));
    if (ok != true || !mounted) return;
    await InstitucionesService.removeLegajoDocente(cuit, cuilEmp);
    await _cargarLegajosDocente();
    if (!mounted) return;
    setState(() {
      _legajoSeleccionadoCuil = null;
      _nombreController.clear();
      _cuilController.clear();
      _cargasController.text = '0';
      _horasCatController.text = '0';
      _cantCargosController.text = '1';
      _codigoRnosController.clear();
      _valorIndiceController.clear();
      _sueldoBasicoOverrideController.clear();
      _fechaIngreso = DateTime(2023, 1, 15);
      _cargo = TipoNomenclador.maestroGrado;
      _nivel = NivelEducativo.primario;
      _zona = ZonaDesfavorable.a;
      _nivelUbicacion = NivelUbicacion.urbana;
      _tipoGestion = TipoGestion.privada;
    });
    _recalcular();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Legajo eliminado')));
  }

  Future<void> _abrirEscanerRecibo() async {
    final res = await Navigator.push(context, MaterialPageRoute(builder: (c) => const TeacherReceiptScanScreen()));
    if (res == null || res is! OcrConfirmResult || !mounted) return;
    final o = res;
    setState(() {
      if (o.nombre != null && o.nombre!.isNotEmpty) _nombreController.text = o.nombre!;
      if (o.cuil != null && o.cuil!.isNotEmpty) _cuilController.text = o.cuil!;
      if (o.jurisdiccion != null) _jurisdiccion = o.jurisdiccion!;
      if (o.tipoGestion != null) _tipoGestion = o.tipoGestion!;
      if (o.cargo != null) _cargo = o.cargo!;
      if (o.nivel != null) _nivel = o.nivel!;
      if (o.zona != null) _zona = o.zona!;
      if (o.fechaIngreso != null) _fechaIngreso = o.fechaIngreso!;
      if (o.cargasFamiliares != null) _cargasController.text = o.cargasFamiliares.toString();
      if (o.horasCatedra != null) _horasCatController.text = o.horasCatedra.toString();
      if (o.cantidadCargos != null) _cantCargosController.text = o.cantidadCargos.toString();
      if (o.codigoRnos != null) _codigoRnosController.text = o.codigoRnos!;
      _ocrOverrides = o.overrides;
      if (o.overrides.valorIndiceOverride != null) _valorIndiceController.text = o.overrides.valorIndiceOverride!.toStringAsFixed(2).replaceAll('.', ',');
      if (o.overrides.sueldoBasicoOverride != null) _sueldoBasicoOverrideController.text = o.overrides.sueldoBasicoOverride!.toStringAsFixed(2).replaceAll('.', ',');
    });
    _recalcular();
  }

  Future<void> _exportarLsd() async {
    final r = _resultado;
    if (r == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Calcule primero la liquidación'))); return; }
    final cuit = _cuitEmpresaController.text.replaceAll(RegExp(r'[^\d]'), '');
    if (cuit.length != 11) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('CUIT empresa debe tener 11 dígitos'))); return; }
    try {
      final txt = await teacherOmniToLsdTxt(liquidacion: r, cuitEmpresa: cuit, razonSocial: _razonSocialController.text, domicilio: _domicilioController.text);
      final dir = await getApplicationDocumentsDirectory();
      final name = 'LSD_Docente_${r.input.nombre.replaceAll(RegExp(r'[^\w]'), '_')}_${DateFormat('yyyyMMdd').format(DateTime.now())}';
      final f = File('${dir.path}/$name.txt');
      await f.writeAsString(txt, encoding: latin1);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Exportado: ${f.path}')));
      OpenFile.open(f.path);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _generarRecibo() async {
    final r = _resultado;
    if (r == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Calcule la liquidación antes de generar el recibo')));
      return;
    }
    
    final cuit = _cuitEmpresaController.text.replaceAll(RegExp(r'[^\d]'), '');
    if (cuit.length != 11) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('CUIT institución debe tener 11 dígitos')));
      return;
    }

    final empresaData = {
      'razonSocial': _razonSocialController.text.trim(),
      'cuit': _cuitEmpresaController.text.trim(),
      'domicilio': _domicilioController.text.trim(),
    };

    // Mostrar el modal de vista previa profesional
    showDialog(
      context: context,
      builder: (context) => Dialog.fullscreen(
        child: Scaffold(
          appBar: AppBar(
            backgroundColor: AppColors.backgroundDark,
            title: const Text('Vista Previa: Recibo de Sueldo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            actions: [
              IconButton(
                icon: const Icon(Icons.print, color: Colors.blueAccent),
                onPressed: () => _imprimirReciboPdf(r, empresaData),
                tooltip: 'Generar PDF / Imprimir',
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          body: Container(
            color: Colors.grey.shade300,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: SingleChildScrollView(
                  child: Card(
                    margin: const EdgeInsets.all(20),
                    elevation: 10,
                    child: TeacherReceiptPreviewWidget(
                      empresa: empresaData,
                      liquidacion: r,
                    ),
                  ),
                ),
              ),
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _imprimirReciboPdf(r, empresaData),
            label: const Text('Generar PDF'),
            icon: const Icon(Icons.picture_as_pdf),
          ),
        ),
      ),
    );
  }

  Future<void> _imprimirReciboPdf(LiquidacionOmniResult r, Map<String, String> empresaData) async {
    final cargoDesc = NomencladorFederal2026.itemPorTipo(_cargo)?.descripcion ?? _cargo.name;
    final empresa = Empresa(
      razonSocial: empresaData['razonSocial'] ?? '',
      cuit: empresaData['cuit'] ?? '',
      domicilio: empresaData['domicilio'] ?? '',
      convenioId: 'docente_federal_2026',
      convenioNombre: 'Docente Federal 2026',
      convenioPersonalizado: false,
      categorias: [],
      parametros: [],
    );
    
    final empleado = Empleado(
      nombre: r.input.nombre,
      categoria: '$cargoDesc - ${_nivel.name}',
      sueldoBasico: r.sueldoBasico,
      periodo: r.periodo,
      fechaPago: r.fechaPago,
      fechaIngreso: DateFormat('yyyy-MM-dd').format(_fechaIngreso),
      lugarPago: empresaData['domicilio'],
    );

    final conceptos = <ConceptoParaPDF>[
      ConceptoParaPDF(descripcion: 'Sueldo básico', remunerativo: r.sueldoBasico, noRemunerativo: 0, descuento: 0),
      if (r.horasCatedra > 0) ConceptoParaPDF(descripcion: 'Horas cátedra', remunerativo: r.horasCatedra, noRemunerativo: 0, descuento: 0),
      if (r.adicionalAntiguedad > 0) ConceptoParaPDF(descripcion: 'Antigüedad', remunerativo: r.adicionalAntiguedad, noRemunerativo: 0, descuento: 0),
      if (r.adicionalZona > 0) ConceptoParaPDF(descripcion: 'Ad. zona', remunerativo: r.adicionalZona, noRemunerativo: 0, descuento: 0),
      if (r.adicionalZonaPatagonica > 0) ConceptoParaPDF(descripcion: 'Plus Zona Patagónica', remunerativo: r.adicionalZonaPatagonica, noRemunerativo: 0, descuento: 0),
      if (r.plusUbicacion > 0) ConceptoParaPDF(descripcion: 'Plus Ubicación / Ruralidad', remunerativo: r.plusUbicacion, noRemunerativo: 0, descuento: 0),
      if (r.estadoDocente > 0) ConceptoParaPDF(descripcion: 'Estado Docente', remunerativo: r.estadoDocente, noRemunerativo: 0, descuento: 0),
      if (r.materialDidactico > 0) ConceptoParaPDF(descripcion: 'Material Didáctico', remunerativo: r.materialDidactico, noRemunerativo: 0, descuento: 0),
      if (r.fonid > 0) ConceptoParaPDF(descripcion: 'FONID', remunerativo: r.fonid, noRemunerativo: 0, descuento: 0),
      if (r.conectividad > 0) ConceptoParaPDF(descripcion: 'Conectividad', remunerativo: r.conectividad, noRemunerativo: 0, descuento: 0),
      if (r.adicionalGarantiaSalarial > 0) ConceptoParaPDF(descripcion: 'Garantía Salarial Nacional', remunerativo: r.adicionalGarantiaSalarial, noRemunerativo: 0, descuento: 0),
      
      // Conceptos Propios
      ...r.conceptosPropios.map((c) => ConceptoParaPDF(
        descripcion: c.descripcion,
        remunerativo: c.esRemunerativo ? c.monto : 0,
        noRemunerativo: !c.esRemunerativo ? c.monto : 0,
        descuento: 0,
      )),

      ConceptoParaPDF(descripcion: 'Jubilación (11%)', remunerativo: 0, noRemunerativo: 0, descuento: r.aporteJubilacion),
      ConceptoParaPDF(descripcion: 'Obra social (${r.porcentajeObraSocial.toStringAsFixed(1)}%)', remunerativo: 0, noRemunerativo: 0, descuento: r.aporteObraSocial),
      ConceptoParaPDF(descripcion: 'PAMI (3%)', remunerativo: 0, noRemunerativo: 0, descuento: r.aportePami),
      if (r.impuestoGanancias > 0) ConceptoParaPDF(descripcion: 'Retención Ganancias', remunerativo: 0, noRemunerativo: 0, descuento: r.impuestoGanancias),
      
      ...r.deduccionesAdicionales.entries.map((e) => ConceptoParaPDF(
        descripcion: e.key,
        remunerativo: 0,
        noRemunerativo: 0,
        descuento: e.value,
      )),
    ];

    try {
      // Cargar bytes de logo y firma (multiplataforma)
      final logoBytes = await readImageBytes(_logoPath);
      final firmaBytes = await readImageBytes(_firmaPath);
      
      final pdfBytes = await PdfRecibo.generarCompleto(
        empresa: empresa,
        empleado: empleado,
        conceptos: conceptos,
        sueldoBruto: r.totalBrutoRemunerativo,
        totalDeducciones: r.totalDescuentos,
        totalNoRemunerativo: r.totalNoRemunerativo,
        sueldoNeto: r.netoACobrar,
        baseImponibleTopeada: r.baseImponibleTopeada != r.totalBrutoRemunerativo ? r.baseImponibleTopeada : null,
        detallePuntosYValorIndice: r.detallePuntosYValorIndice,
        desgloseBaseBonificable: r.desgloseBaseBonificable,
        logoBytes: logoBytes,
        firmaBytes: firmaBytes,
        incluirBloqueFirmaLey25506: true,
      );

      final dir = await getApplicationDocumentsDirectory();
      final cuilLimpio = r.input.cuil.replaceAll(RegExp(r'[^\d]'), '');
      final file = File('${dir.path}/recibo_docente_${cuilLimpio}_${DateTime.now().millisecondsSinceEpoch}.pdf');
      await file.writeAsBytes(pdfBytes);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('PDF generado: ${file.path}')));
      OpenFile.open(file.path);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al generar PDF: $e')));
    }
  }

  Future<void> _descargarPackCompletoARCA2026() async {
    final r = _resultado;
    if (r == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Calcule primero la liquidación'))); return; }
    final cuit = _cuitEmpresaController.text.replaceAll(RegExp(r'[^\d]'), '');
    if (cuit.length != 11) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('CUIT empresa debe tener 11 dígitos'))); return; }
    try {
      final artPct = double.tryParse(_artPctController.text.replaceAll(',', '.')) ?? 3.5;
      final artCuotaFija = double.tryParse(_artCuotaFijaController.text.replaceAll(',', '.')) ?? 800;
      final res = await generarPackCompletoARCA2026(liquidacion: r, cuitEmpresa: cuit, razonSocial: _razonSocialController.text.trim(), domicilio: _domicilioController.text.trim(), artPct: artPct, artCuotaFija: artCuotaFija);
      if (!mounted) return;
      final fmt = NumberFormat.currency(locale: 'es_AR', symbol: '\$', decimalDigits: 2);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Pack ARCA 2026 generado. Neto: ${fmt.format(res.neto)} | Costo Laboral Real: ${fmt.format(res.costoLaboralReal)}\n${res.carpeta}'), duration: const Duration(seconds: 6), action: SnackBarAction(label: 'Abrir carpeta', onPressed: () => OpenFile.open(res.carpeta))));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error Pack ARCA: $e')));
    }
  }

  void _mostrarInstructivoArca() {
    final r = _resultado;
    final codigosUsados = <String>[];
    
    if (r != null) {
        if (r.sueldoBasico > 0) codigosUsados.add(TeacherLsdCodigos.sueldoBasico);
        if (r.adicionalAntiguedad > 0) codigosUsados.add(TeacherLsdCodigos.antiguedad);
        if (r.fonid > 0) codigosUsados.add(TeacherLsdCodigos.fonid);
        if (r.conectividad > 0) codigosUsados.add(TeacherLsdCodigos.conectividad);
        if (r.materialDidactico > 0) codigosUsados.add(TeacherLsdCodigos.materialDidactico);
        if (r.adicionalZona > 0) codigosUsados.add(TeacherLsdCodigos.adicionalZona);
        if (r.itemAula > 0) codigosUsados.add(TeacherLsdCodigos.itemAula);
        if (r.estadoDocente > 0) codigosUsados.add(TeacherLsdCodigos.estadoDocente);
        if (r.presentismo > 0) codigosUsados.add(TeacherLsdCodigos.presentismo);
        for (final c in r.conceptosPropios) {
            if (c.monto > 0) {
            codigosUsados.add(c.codigo.length > 10 ? c.codigo.substring(0, 10) : c.codigo);
            }
        }
        if (r.aporteJubilacion > 0) codigosUsados.add(TeacherLsdCodigos.jubilacion);
        if (r.aporteObraSocial > 0) codigosUsados.add(TeacherLsdCodigos.obraSocial);
        if (r.aportePami > 0) codigosUsados.add(TeacherLsdCodigos.ley19032);
    } else {
        codigosUsados.addAll([
            TeacherLsdCodigos.sueldoBasico, 
            TeacherLsdCodigos.antiguedad, 
            TeacherLsdCodigos.fonid,
            TeacherLsdCodigos.jubilacion,
            TeacherLsdCodigos.obraSocial
        ]);
    }

    final instructivo = LsdMappingService.generarInstructivo(codigosUsados.toSet().toList());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
            children: [
                Icon(Icons.info_outline, color: Colors.blue),
                SizedBox(width: 8),
                Text('Instructivo Asociación AFIP', style: TextStyle(fontSize: 16)),
            ],
        ),
        content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                        Text('Antes de subir el archivo a AFIP, debe asociar los conceptos por única vez:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        SizedBox(height: 10),
                        Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: SelectableText(instructivo, style: TextStyle(fontFamily: 'monospace', fontSize: 11)),
                        ),
                    ],
                ),
            ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Entendido')),
        ],
      ),
    );
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
                              _recalcular();
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

  Future<void> _guardarEnHistorial() async {
    if (_resultado == null) return;
    if ((_cuitSeleccionado ?? '').isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Seleccione una institución')));
      return;
    }

    setState(() => _savingMaestro = true);
    final success = await LiquidacionHistoryService.guardarLiquidacion(
      cuitInstitucion: _cuitSeleccionado!,
      liquidacion: _resultado!,
    );
    setState(() => _savingMaestro = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(success ? 'Liquidación guardada en historial' : 'Error al guardar en historial'),
        backgroundColor: success ? Colors.green : Colors.red,
      ));
    }
  }

  Future<void> _abrirCalculadoraRetroactivo() async {
    if ((_cuitSeleccionado ?? '').isEmpty || (_legajoSeleccionadoCuil ?? '').isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Seleccione institución y empleado')));
      return;
    }

    // 1. Seleccionar periodo
    final periods = List.generate(12, (i) {
      final d = DateTime.now().subtract(Duration(days: 30 * (i + 1)));
      return DateFormat('MMMM yyyy', 'es_AR').format(d);
    });
    
    String? selectedPeriod;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Seleccionar Período a Reliquidar'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: periods.length,
            itemBuilder: (c, i) => ListTile(
              title: Text(periods[i]),
              onTap: () {
                selectedPeriod = periods[i];
                Navigator.pop(ctx);
              },
            ),
          ),
        ),
      ),
    );

    if (selectedPeriod == null || !mounted) return;

    // 2. Cargar original
    setState(() => _calculando = true);
    final original = await LiquidacionHistoryService.obtenerLiquidacionPorPeriodo(
      cuitInstitucion: _cuitSeleccionado!,
      cuilEmpleado: _legajoSeleccionadoCuil!,
      periodo: selectedPeriod!,
    );
    setState(() => _calculando = false);

    if (original == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se encontró liquidación para ese período')));
      }
      return;
    }

    // 3. Mostrar diálogo de ajuste
    // Usamos variables locales para el estado del diálogo
    final basicoCtrl = TextEditingController(text: original.sueldoBasico.toString());
    final viCtrl = TextEditingController(text: original.input.valorIndiceOverride?.toString() ?? '');
    
    // ignore: use_build_context_synchronously
    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          // Recalcular diferencia en tiempo real (simulado) o al botón
          return AlertDialog(
            title: Text('Ajuste Retroactivo - $selectedPeriod'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Valores Originales:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('Básico: \$${original.sueldoBasico.toStringAsFixed(2)}'),
                  Text('Neto: \$${original.netoACobrar.toStringAsFixed(2)}'),
                  const Divider(),
                  const Text('Nuevos Valores (Simulación):', style: TextStyle(fontWeight: FontWeight.bold)),
                  TextField(
                    controller: basicoCtrl,
                    decoration: const InputDecoration(labelText: 'Nuevo Sueldo Básico'),
                    keyboardType: TextInputType.number,
                  ),
                  TextField(
                    controller: viCtrl,
                    decoration: const InputDecoration(labelText: 'Nuevo Valor Índice (opcional)'),
                    keyboardType: TextInputType.number,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
              ElevatedButton(
                onPressed: () {
                  // Calcular
                  final nuevoBasico = double.tryParse(basicoCtrl.text);
                  final nuevoVi = double.tryParse(viCtrl.text);
                  
                  // Crear input modificado
                  // Necesitamos copiar el input original y modificarlo. 
                  // DocenteOmniInput no tiene copyWith, recreamos usando JSON.
                  final jsonInput = original.input.toJson();
                  if (nuevoBasico != null) jsonInput['sueldoBasicoOverride'] = nuevoBasico;
                  if (nuevoVi != null) jsonInput['valorIndiceOverride'] = nuevoVi;
                  
                  final nuevoInput = DocenteOmniInput.fromJson(jsonInput);
                  
                  final resultado = RetroactivoService.calcularRetroactivo(
                    original: original,
                    nuevoInput: nuevoInput,
                  );
                  
                  Navigator.pop(ctx);
                  _mostrarResultadoRetroactivo(resultado, selectedPeriod!);
                },
                child: const Text('Calcular Diferencia'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _mostrarResultadoRetroactivo(ResultadoRetroactivo res, String periodo) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Resultado Retroactivo'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...res.detalles.map((d) => ListTile(
                title: Text(d.concepto),
                subtitle: Text('Ant: ${d.original.toStringAsFixed(2)} -> Nuevo: ${d.nuevo.toStringAsFixed(2)}'),
                trailing: Text(
                  d.diferencia > 0 ? '+${d.diferencia.toStringAsFixed(2)}' : d.diferencia.toStringAsFixed(2),
                  style: TextStyle(color: d.diferencia >= 0 ? Colors.green : Colors.red, fontWeight: FontWeight.bold),
                ),
              )),
              const Divider(),
              ListTile(
                title: const Text('Dif. Remunerativa (Bruto)'),
                trailing: Text(res.diferenciaBruto.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
              ListTile(
                title: const Text('Dif. No Remunerativa'),
                trailing: Text(res.diferenciaNoRemunerativo.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
              ListTile(
                title: const Text('Dif. Neta Estimada'),
                trailing: Text(res.diferenciaNeto.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar')),
          ElevatedButton(
            onPressed: () {
              // Aplicar a liquidación actual
              setState(() {
                if (res.diferenciaBruto > 0) {
                  _conceptosPropios.add(ConceptoPropioOmni(
                    codigo: 'RETRO_REM',
                    descripcion: 'Retroactivo Remunerativo $periodo',
                    monto: res.diferenciaBruto,
                    esRemunerativo: true,
                  ));
                }
                if (res.diferenciaNoRemunerativo > 0) {
                  _conceptosPropios.add(ConceptoPropioOmni(
                    codigo: 'RETRO_NR',
                    descripcion: 'Retroactivo No Rem. $periodo',
                    monto: res.diferenciaNoRemunerativo,
                    esRemunerativo: false,
                  ));
                }
              });
              _recalcular();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Conceptos retroactivos agregados')));
            },
            child: const Text('Aplicar a Liquidación Actual'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportarAsiento() async {
    if (_resultado == null) return;

    final perfil = await ContabilidadConfigService.cargarPerfil();
    final asiento = ContabilidadService.generarAsientoDocente(
      liquidaciones: [_resultado!],
      perfil: perfil,
    );

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Asiento Contable Preliminar'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Perfil: ${perfil.nombre}'),
              const SizedBox(height: 10),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: asiento.items.length,
                  itemBuilder: (c, i) {
                    final item = asiento.items[i];
                    return ListTile(
                      title: Text('${item.cuentaCodigo} - ${item.cuentaNombre}'),
                      subtitle: Text(
                        'Debe: ${item.debe.toStringAsFixed(2)} | Haber: ${item.haber.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: item.debe > 0 ? Colors.blue : Colors.green,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const Divider(),
              Text('Total Debe: ${asiento.totalDebe.toStringAsFixed(2)}'),
              Text('Total Haber: ${asiento.totalHaber.toStringAsFixed(2)}'),
              if (!asiento.balanceado)
                const Text('¡Diferencia detectada!', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar')),
          ElevatedButton.icon(
            onPressed: () async {
              // Generar CSV
              final csv = ContabilidadService.exportarHolistor(asiento, DateTime.now());
              
              // Guardar archivo
              final directory = await getApplicationDocumentsDirectory();
              final file = File('${directory.path}/asiento_docente_${DateTime.now().millisecondsSinceEpoch}.csv');
              await file.writeAsString(csv);
              
              if (mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Exportado a: ${file.path}')),
                );
                // Abrir archivo (opcional, si hay visor)
                 OpenFile.open(file.path);
              }
            },
            icon: const Icon(Icons.save),
            label: const Text('Guardar CSV (Holistor)'),
          ),
        ],
      ),
    );
  }

  Future<List<LiquidacionOmniResult>> _liquidarTodos() async {
    final liquidaciones = <LiquidacionOmniResult>[];
    
    for (final l in _legajosDocente) {
      try {
        // Parsear datos del legajo
        final nombre = l['nombre']?.toString() ?? '';
        final cuil = l['cuil']?.toString() ?? '';
        
        if (nombre.isEmpty || cuil.length != 11) continue;

        // Parsear enums
        final c = l['cargo']?.toString();
        final cargo = TipoNomenclador.values.cast<TipoNomenclador?>().firstWhere((e) => e?.name == c, orElse: () => TipoNomenclador.maestroGrado) ?? TipoNomenclador.maestroGrado;
        
        final z = l['zona']?.toString();
        final zona = ZonaDesfavorable.values.cast<ZonaDesfavorable?>().firstWhere((e) => e?.name == z, orElse: () => ZonaDesfavorable.a) ?? ZonaDesfavorable.a;
        
        final n = l['nivel']?.toString();
        final nivel = NivelEducativo.values.cast<NivelEducativo?>().firstWhere((e) => e?.name == n, orElse: () => NivelEducativo.primario) ?? NivelEducativo.primario;
        
        final nu = l['nivelUbicacion']?.toString();
        final nivelUbicacion = NivelUbicacion.values.cast<NivelUbicacion?>().firstWhere((e) => e?.name == nu, orElse: () => NivelUbicacion.urbana) ?? NivelUbicacion.urbana;

        final fi = l['fechaIngreso']?.toString();
        DateTime fechaIngreso = DateTime.now();
        if (fi != null && fi.isNotEmpty) {
          final d = DateTime.tryParse(fi);
          if (d != null) fechaIngreso = d;
        }

        // Conceptos propios
        final conceptosPropios = <ConceptoPropioOmni>[];
        final L = l['conceptosPropiosActivos'];
        if (L is List) {
          for (final m in L) {
            if (m is! Map) continue;
            final mont = (m['monto'] is num) ? (m['monto'] as num).toDouble() : (double.tryParse(m['monto']?.toString() ?? '') ?? 0.0);
            conceptosPropios.add(ConceptoPropioOmni(
              codigo: (m['nombre'] ?? '').toString().replaceAll(RegExp(r'[^\w]'), '_'),
              descripcion: m['nombre']?.toString() ?? '',
              monto: mont,
              esRemunerativo: (m['naturaleza']?.toString() ?? 'remunerativo') == 'remunerativo',
              codigoAfip: m['codigoAfipArca']?.toString() ?? '011000',
            ));
          }
        }

        // Overrides
        final pco = l['puntosCargoOverride'];
        final pho = l['puntosHoraCatedraOverride'];
        
        final input = DocenteOmniInput(
          nombre: nombre,
          cuil: cuil,
          jurisdiccion: _jurisdiccion, // Usa la de la institución seleccionada
          tipoGestion: _tipoGestion,   // Usa la de la institución seleccionada
          cargoNomenclador: cargo,
          nivelEducativo: nivel,
          fechaIngreso: fechaIngreso,
          cargasFamiliares: (l['cargasFamiliares'] is int ? l['cargasFamiliares'] as int : int.tryParse(l['cargasFamiliares']?.toString() ?? '') ?? 0),
          codigoRnos: l['codigoRnos']?.toString(),
          horasCatedra: (l['horasCatedra'] is int ? l['horasCatedra'] as int : int.tryParse(l['horasCatedra']?.toString() ?? '') ?? 0),
          zona: zona,
          nivelUbicacion: nivelUbicacion,
          valorIndiceOverride: l['valorIndice'] != null && l['valorIndice'].toString().trim().isNotEmpty ? double.tryParse(l['valorIndice'].toString()) : null,
          sueldoBasicoOverride: l['sueldoBasicoOverride'] != null && l['sueldoBasicoOverride'].toString().trim().isNotEmpty ? double.tryParse(l['sueldoBasicoOverride'].toString()) : null,
          puntosCargoOverride: pco is int ? pco : (pco != null ? int.tryParse(pco.toString()) : null),
          puntosHoraCatedraOverride: pho is int ? pho : (pho != null ? int.tryParse(pho.toString()) : null),
          esHoraCatedraSecundaria: cargo == TipoNomenclador.horaCatedraMedia,
          modoLiquidacion: widget.modo,
        );

        final liq = TeacherOmniEngine.liquidar(
          input,
          periodo: DateFormat('MMMM yyyy', 'es_AR').format(DateTime.now()),
          fechaPago: DateFormat('dd/MM/yyyy').format(DateTime.now()),
          cantidadCargos: (l['cantidadCargos'] is int ? l['cantidadCargos'] as int : int.tryParse(l['cantidadCargos']?.toString() ?? '') ?? 1),
          conceptosPropios: conceptosPropios,
        );
        
        liquidaciones.add(liq);
      } catch (e) {
        print('Error liquidando legajo: $e');
      }
    }
    
    return liquidaciones;
  }

  Future<void> _exportarLibroSueldosExcel() async {
    List<LiquidacionOmniResult> listaParaExportar = [];
    
    if (_resultado != null) {
      listaParaExportar.add(_resultado!);
    } else if (_legajosDocente.isNotEmpty) {
      final confirm = await showDialog<bool>(
        context: context, 
        builder: (c) => AlertDialog(
          title: const Text('Generar Libro de Sueldos'),
          content: Text('No hay liquidación actual. ¿Desea calcular y exportar los ${_legajosDocente.length} legajos de la lista?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Calcular y Exportar')),
          ],
        )
      );
      
      if (confirm != true) return;
      
      setState(() => _exportandoMasivo = true);
      try {
        final liquidaciones = await _liquidarTodos();
        listaParaExportar = liquidaciones;
      } finally {
        if (mounted) setState(() => _exportandoMasivo = false);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No hay datos para exportar')));
      return;
    }

    if (listaParaExportar.isEmpty) return;

    final datosExcel = listaParaExportar.map((liq) {
      return {
        'cuil': liq.input.cuil,
        'nombre': liq.input.nombre,
        'categoria': liq.input.cargoNomenclador.name,
        'basico': liq.sueldoBasico,
        'antiguedad': liq.adicionalAntiguedad,
        'conceptosRemunerativos': liq.totalBrutoRemunerativo - liq.sueldoBasico - liq.adicionalAntiguedad,
        'totalBruto': liq.totalBrutoRemunerativo,
        'totalAportes': liq.totalDescuentos, 
        'descuentos': 0.0, 
        'conceptosNoRemunerativos': liq.totalNoRemunerativo,
        'neto': liq.netoACobrar,
        'totalContribuciones': liq.costoLaboralReal - liq.totalBrutoRemunerativo, // Aprox
      };
    }).toList();

    try {
      final now = DateTime.now();
      final path = await ExcelExportService.generarLibroSueldos(
        mes: now.month, 
        anio: now.year, 
        liquidaciones: datosExcel,
        empresaNombre: _razonSocialController.text,
      );
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Libro de Sueldos generado: $path')),
      );
      OpenFile.open(path);
      
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error Excel: $e')));
    }
  }

  void _mostrarAyuda() {
    final helpContent = AppHelp.getHelpContent('LiquidadorFinalScreen');
    AppHelp.showHelpDialog(
      context,
      helpContent['title']!,
      helpContent['content']!,
    );
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _cuilController.dispose();
    _codigoRnosController.dispose();
    _cuitEmpresaController.dispose();
    _razonSocialController.dispose();
    _domicilioController.dispose();
    _cargasController.dispose();
    _horasCatController.dispose();
    _cantCargosController.dispose();
    _artPctController.dispose();
    _artCuotaFijaController.dispose();
    _valorIndiceController.dispose();
    _sueldoBasicoOverrideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary), onPressed: () => Navigator.pop(context)),
        title: Text('Liquidación${(widget.razonSocial ?? '').isNotEmpty ? ' · ${widget.razonSocial}' : ''}', style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
              ),
              child: const Icon(Icons.help_outline, color: AppColors.primary, size: 20),
            ),
            tooltip: 'Ayuda',
            onPressed: _mostrarAyuda,
          ),
        ],
      ),
      persistentFooterButtons: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
               // Fila 0: Instructivo ARCA
               SizedBox(
                 width: double.infinity,
                 child: TextButton.icon(
                   onPressed: _mostrarInstructivoArca,
                   icon: const Icon(Icons.info_outline, size: 18, color: Colors.blue),
                   label: const Text('Instructivo ARCA: Asociación de Conceptos (Leer antes de subir)'),
                   style: TextButton.styleFrom(
                     foregroundColor: Colors.blue,
                     padding: EdgeInsets.zero,
                   ),
                 ),
               ),
               const SizedBox(height: 4),
              // Fila 1: Exportar LSD y Recibo
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _resultado != null ? _exportarLsd : null,
                      icon: const Icon(Icons.download, size: 20),
                      label: const Text('Exportar LSD'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _resultado != null ? _generarRecibo : null,
                      icon: const Icon(Icons.receipt, size: 20),
                      label: const Text('Generar Recibo'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Fila 1b: Exportar Asiento y Excel
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _resultado != null ? _exportarAsiento : null,
                      icon: const Icon(Icons.account_balance_wallet, size: 20),
                      label: const Text('Exportar Asiento'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _exportarLibroSueldosExcel,
                      icon: const Icon(Icons.table_chart, size: 20, color: Colors.green),
                      label: const Text('Exportar Excel', style: TextStyle(color: Colors.green)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.green),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Fila 1c: Historial y Retroactivos
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _resultado != null ? _guardarEnHistorial : null,
                      icon: const Icon(Icons.save_as, size: 20),
                      label: const Text('Guardar Historial'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _abrirCalculadoraRetroactivo,
                      icon: const Icon(Icons.history, size: 20),
                      label: const Text('Calc. Retroactivo'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Fila 2: Pack ARCA (Main Action)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _resultado != null ? _descargarPackCompletoARCA2026 : null,
                  icon: const Icon(Icons.folder_zip),
                  label: const Text('Descargar Pack ARCA 2026 Completo'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildBannerSincronizacion(),
          if ((widget.cuitInstitucion ?? '').isEmpty) _buildDropdownInstitucion(),
          _buildDatosDocente(),
          _buildPanelesSuiteProfesional(),
          _buildSimuladorNeto(),
          if (_resultado != null) _buildDetalleLiquidacion(_resultado!),
          _buildPanelCostoEmpleador(),
        ],
      ),
    );
  }

  Widget _buildBannerSincronizacion() {
    // MODIFICADO: Siempre mostrar el banner, incluso si no hay info inicial
    final info = _infoSincronizacion;
    final bool hasInfo = info != null;
    final bool success = info?['success'] ?? false;
    final bool isOffline = info?['modo'] == 'offline';
    final DateTime? fecha = info?['fecha'];
    final String fechaStr = fecha != null ? DateFormat('dd/MM/yyyy HH:mm').format(fecha) : 'Desconocida';

    Color bgColor;
    Color borderColor;
    IconData icon;
    String mensajeBanner;

    if (_sincronizandoParitarias) {
      bgColor = Colors.blue.withValues(alpha: 0.1);
      borderColor = Colors.blue.withValues(alpha: 0.3);
      icon = Icons.sync;
      mensajeBanner = 'Sincronizando paritarias oficiales...';
    } else if (!hasInfo) {
      bgColor = Colors.grey.withValues(alpha: 0.1);
      borderColor = Colors.grey.withValues(alpha: 0.3);
      icon = Icons.help_outline;
      mensajeBanner = 'Estado de paritarias desconocido';
    } else if (success) {
      bgColor = Colors.green.withValues(alpha: 0.1);
      borderColor = Colors.green.withValues(alpha: 0.3);
      icon = Icons.check_circle_outline;
      mensajeBanner = 'Paritarias actualizadas al $fechaStr';
    } else if (isOffline) {
      bgColor = Colors.amber.withValues(alpha: 0.1);
      borderColor = Colors.amber.withValues(alpha: 0.3);
      icon = Icons.cloud_off;
      mensajeBanner = 'Modo Offline: Última sync $fechaStr';
    } else {
      bgColor = Colors.red.withValues(alpha: 0.1);
      borderColor = Colors.red.withValues(alpha: 0.3);
      icon = Icons.sync_problem;
      mensajeBanner = 'Error al sincronizar paritarias';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          if (_sincronizandoParitarias)
            const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.pastelBlue))
          else
            Icon(icon, size: 16, color: borderColor.withOpacity(1.0)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              mensajeBanner,
              style: TextStyle(
                fontSize: 12, 
                color: borderColor.withOpacity(1.0), // Usar color del borde como texto oscuro
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (!_sincronizandoParitarias)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.refresh, size: 14),
                  onPressed: _sincronizarParitarias,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  visualDensity: VisualDensity.compact,
                  color: Colors.blue,
                  tooltip: 'Reintentar sincronización',
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.settings, size: 14),
                  onPressed: _handleAbrirMaestro,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  visualDensity: VisualDensity.compact,
                  color: Colors.blue,
                  tooltip: 'Panel Maestro',
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildDropdownInstitucion() {
    if (_instituciones.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.glassFillStrong, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.glassBorder)),
      child: DropdownButtonFormField<String?>(
        value: _cuitSeleccionado,
        decoration: const InputDecoration(labelText: 'Institución'),
        items: [
          const DropdownMenuItem(value: null, child: Text('Seleccione institución')),
          ..._instituciones.where((e) => ((e['cuit']?.toString() ?? '').replaceAll(RegExp(r'[^\d]'), '')).isNotEmpty).map((e) {
            final c = (e['cuit']?.toString() ?? '').replaceAll(RegExp(r'[^\d]'), '');
            return DropdownMenuItem(value: c, child: Text(e['razonSocial']?.toString() ?? c));
          }),
        ],
        onChanged: (cuit) async {
          if (cuit == null) return;
          Map<String, dynamic>? inst;
          for (final e in _instituciones) {
            if ((e['cuit']?.toString() ?? '').replaceAll(RegExp(r'[^\d]'), '') == cuit) { inst = e; break; }
          }
          if (inst != null) {
            setState(() { _cuitSeleccionado = cuit; _prefillFromInstitucion(inst!); });
            await _cargarLegajosDocente();
          }
        },
      ),
    );
  }

  Widget _buildDatosDocente() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Datos del empleado', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          if (_cuitSeleccionado != null) ...[
            Padding(padding: const EdgeInsets.only(bottom: 4), child: Text('Ficha del empleado — Convenio Docente Federal 2026', style: TextStyle(fontSize: 12, color: Colors.grey.shade600))),
            _buildDropdownEmpleado(),
            const SizedBox(height: 8),
            Row(children: [
              FilledButton.icon(onPressed: _guardarLegajoDocente, icon: const Icon(Icons.save, size: 18), label: const Text('Guardar legajo')),
              if (_legajoSeleccionadoCuil != null) ...[const SizedBox(width: 8), OutlinedButton.icon(onPressed: _eliminarLegajoDocente, icon: const Icon(Icons.delete_outline, size: 18), label: const Text('Eliminar legajo'))],
              const SizedBox(width: 8),
              OutlinedButton.icon(onPressed: _abrirEscanerRecibo, icon: const Icon(Icons.document_scanner, size: 18), label: const Text('Escanear recibo')),
            ]),
            const SizedBox(height: 12),
          ],
          TextField(controller: _nombreController, decoration: const InputDecoration(labelText: 'Nombre y apellido'), onChanged: (_) => _recalcular()),
          TextField(controller: _cuilController, decoration: const InputDecoration(labelText: 'CUIL (verificado legal)'), keyboardType: TextInputType.number, onChanged: (_) => _recalcular()),
          DropdownButtonFormField<TipoNomenclador>(
            value: _cargo, 
            decoration: const InputDecoration(labelText: 'Cargo (Nomenclador 2026)'), 
            items: NomencladorFederal2026.items.map((e) => DropdownMenuItem(
              value: e.tipo, 
              child: Text(e.esSueldoFijo ? '${e.descripcion} (Sueldo Fijo)' : '${e.descripcion} (${e.puntos} pts)')
            )).toList(), 
            onChanged: (v) { if (v != null) { setState(() => _cargo = v); _recalcular(); } }
          ),
          DropdownButtonFormField<NivelEducativo>(value: _nivel, decoration: const InputDecoration(labelText: 'Nivel'), items: const [DropdownMenuItem(value: NivelEducativo.inicial, child: Text('Inicial')), DropdownMenuItem(value: NivelEducativo.primario, child: Text('Primario')), DropdownMenuItem(value: NivelEducativo.secundario, child: Text('Secundario')), DropdownMenuItem(value: NivelEducativo.terciario, child: Text('Terciario')), DropdownMenuItem(value: NivelEducativo.superior, child: Text('Superior'))], onChanged: (v) { if (v != null) { setState(() => _nivel = v); _recalcular(); } }),
          DropdownButtonFormField<ZonaDesfavorable>(value: _zona, decoration: const InputDecoration(labelText: 'Zona desfavorable'), items: const [DropdownMenuItem(value: ZonaDesfavorable.a, child: Text('Zona A (0%)')), DropdownMenuItem(value: ZonaDesfavorable.b, child: Text('Zona B (20%)')), DropdownMenuItem(value: ZonaDesfavorable.c, child: Text('Zona C (40%)')), DropdownMenuItem(value: ZonaDesfavorable.d, child: Text('Zona D (80%)')), DropdownMenuItem(value: ZonaDesfavorable.e, child: Text('Zona E (110%)'))], onChanged: (v) { if (v != null) { setState(() => _zona = v); _recalcular(); } }),
          DropdownButtonFormField<NivelUbicacion>(value: _nivelUbicacion, decoration: const InputDecoration(labelText: 'Nivel Ubicación / Ruralidad'), items: const [DropdownMenuItem(value: NivelUbicacion.urbana, child: Text('Urbana (0%)')), DropdownMenuItem(value: NivelUbicacion.alejada, child: Text('Alejada (20%)')), DropdownMenuItem(value: NivelUbicacion.inhospita, child: Text('Inhóspita (40%)')), DropdownMenuItem(value: NivelUbicacion.muyInhospita, child: Text('Muy inhóspita (60%)'))], onChanged: (v) { if (v != null) { setState(() => _nivelUbicacion = v); _recalcular(); } }),
          TextField(controller: _cargasController, decoration: const InputDecoration(labelText: 'Cargas familiares'), keyboardType: TextInputType.number, onChanged: (_) => _recalcular()),
          Row(children: [const Expanded(child: Text('Cant. cargos (FONID):')), SizedBox(width: 80, child: TextField(controller: _cantCargosController, keyboardType: TextInputType.number, onChanged: (_) => _recalcular()))]),
          TextField(controller: _horasCatController, decoration: const InputDecoration(labelText: 'Horas cátedra'), keyboardType: TextInputType.number, onChanged: (_) => _recalcular()),
          ListTile(title: const Text('Fecha ingreso'), subtitle: Text(DateFormat('dd/MM/yyyy').format(_fechaIngreso)), onTap: () async { final d = await showDatePicker(context: context, initialDate: _fechaIngreso, firstDate: DateTime(1950), lastDate: DateTime.now()); if (d != null) { setState(() => _fechaIngreso = d); _recalcular(); } }),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _codigoRnosController,
                  decoration: const InputDecoration(labelText: 'Código RNOS (obra social)'),
                  keyboardType: TextInputType.number,
                  onChanged: (_) => _recalcular(),
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
          TextField(controller: _valorIndiceController, decoration: const InputDecoration(labelText: 'Valor Índice (opcional, si vacío usa el de la jurisdicción)'), keyboardType: const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => _recalcular()),
          TextField(controller: _sueldoBasicoOverrideController, decoration: const InputDecoration(labelText: 'Sueldo básico vigente (opcional)'), keyboardType: const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => _recalcular()),
        ]),
      ),
    );
  }

  Widget _buildDropdownEmpleado() {
    final itemValues = <String?>[null];
    final items = <DropdownMenuItem<String?>>[
      const DropdownMenuItem<String?>(value: null, child: Text('+ Nuevo empleado')),
      ..._legajosDocente.asMap().entries.map((entry) {
        final i = entry.key;
        final l = entry.value;
        final cuilRaw = (l['cuil']?.toString() ?? '').replaceAll(RegExp(r'[^\d]'), '');
        final value = (cuilRaw.length >= 11) ? cuilRaw : 'legajo_$i';
        itemValues.add(value);
        return DropdownMenuItem<String?>(value: value, child: Text('${l['nombre'] ?? ''} — ${l['cuil'] ?? value}'));
      }),
    ];
    final valorValido = _legajoSeleccionadoCuil == null || itemValues.contains(_legajoSeleccionadoCuil);
    return DropdownButtonFormField<String?>(
      value: valorValido ? _legajoSeleccionadoCuil : null,
      decoration: const InputDecoration(labelText: 'Empleado (legajo)'),
      items: items,
      onChanged: (value) {
        if (value == null) {
          setState(() { _legajoSeleccionadoCuil = null; _nombreController.clear(); _cuilController.clear(); _cargasController.text = '0'; _horasCatController.text = '0'; _cantCargosController.text = '1'; _codigoRnosController.clear(); _sueldoBasicoOverrideController.clear(); _fechaIngreso = DateTime(2023, 1, 15); _cargo = TipoNomenclador.maestroGrado; _nivel = NivelEducativo.primario; _zona = ZonaDesfavorable.a; });
          _recalcular();
        } else {
          Map<String, dynamic>? legajo;
          if (value.startsWith('legajo_')) {
            final idx = int.tryParse(value.replaceFirst('legajo_', ''));
            if (idx != null && idx >= 0 && idx < _legajosDocente.length) legajo = _legajosDocente[idx];
          } else {
            final list = _legajosDocente.where((e) => (e['cuil']?.toString() ?? '').replaceAll(RegExp(r'[^\d]'), '') == value).toList();
            if (list.isNotEmpty) legajo = list.first;
          }
          if (legajo != null) { try { _prefillFromLegajoDocente(legajo); } catch (_) {} }
          setState(() => _legajoSeleccionadoCuil = value);
          _recalcular();
        }
      },
    );
  }

  Widget _buildPanelesSuiteProfesional() {
    if (widget.modo == "mensual") return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        color: AppColors.glassFillStrong,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    widget.modo == "sac" ? Icons.card_giftcard : 
                    widget.modo == "vacaciones" ? Icons.beach_access : Icons.exit_to_app,
                    color: AppColors.pastelBlue,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.modo == "sac" ? 'Configuración de Aguinaldo (SAC)' : 
                    widget.modo == "vacaciones" ? 'Liquidación de Vacaciones' : 'Liquidación Final (Cese)',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (widget.modo == "sac") ...[
                TextField(
                  controller: _mejorRemuneracionController,
                  decoration: const InputDecoration(labelText: 'Mejor Remuneración del Semestre'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => _recalcular(),
                ),
                TextField(
                  controller: _diasSACController,
                  decoration: const InputDecoration(labelText: 'Días Trabajados (max 180)'),
                  keyboardType: TextInputType.number,
                  onChanged: (_) => _recalcular(),
                ),
              ],
              if (widget.modo == "vacaciones") ...[
                TextField(
                  controller: _promedioVariablesController,
                  decoration: const InputDecoration(labelText: 'Promedio Variables últimos 6 meses'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => _recalcular(),
                ),
                TextField(
                  controller: _diasVacacionesController,
                  decoration: const InputDecoration(labelText: 'Días de Vacaciones'),
                  keyboardType: TextInputType.number,
                  onChanged: (_) => _recalcular(),
                ),
              ],
              if (widget.modo == "final") ...[
                ListTile(
                  title: const Text('Fecha de Cese', style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
                  subtitle: Text(_fechaCeseController.text.isEmpty ? 'Seleccionar...' : _fechaCeseController.text, style: const TextStyle(color: AppColors.textSecondary)),
                  trailing: const Icon(Icons.calendar_today, size: 18),
                  onTap: () async {
                    final d = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100));
                    if (d != null) {
                      setState(() => _fechaCeseController.text = DateFormat('yyyy-MM-dd').format(d));
                      _recalcular();
                    }
                  },
                ),
                DropdownButtonFormField<String>(
                  value: _motivoCese,
                  decoration: const InputDecoration(labelText: 'Motivo del Cese'),
                  items: const [
                    DropdownMenuItem(value: "renuncia", child: Text('Renuncia')),
                    DropdownMenuItem(value: "despido_sin_causa", child: Text('Despido sin Causa')),
                    DropdownMenuItem(value: "despido_con_causa", child: Text('Despido con Causa')),
                    DropdownMenuItem(value: "fin_suplencia", child: Text('Fin de Suplencia')),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      setState(() => _motivoCese = v);
                      _recalcular();
                    }
                  },
                ),
                if (_motivoCese == "despido_sin_causa") ...[
                  SwitchListTile(
                    title: const Text('Incluye Indemnización Sustitutiva de Preaviso', style: TextStyle(color: AppColors.textPrimary, fontSize: 13)),
                    value: _incluyePreaviso,
                    onChanged: (v) {
                      setState(() => _incluyePreaviso = v);
                      _recalcular();
                    },
                  ),
                ],
                TextField(
                  controller: _baseIndemnizatoriaController,
                  decoration: const InputDecoration(labelText: 'Base Indemnizatoria (Mejor Mensual)'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => _recalcular(),
                ),
              ],
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.amber.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: const Text(
                  '⚠ Los valores automáticos pueden editarse si el contador lo requiere para el Libro Digital.',
                  style: TextStyle(fontSize: 10, color: Colors.amberAccent),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSimuladorNeto() {
    final cfg = JurisdiccionDBOmni.get(_jurisdiccion);
    final valorIndiceEfectivo = _valorIndiceController.text.trim().isEmpty ? (cfg?.valorIndice ?? 0) : (double.tryParse(_valorIndiceController.text.replaceAll(',', '.')) ?? cfg?.valorIndice ?? 0);
    final usaOverride = _sueldoBasicoOverrideController.text.trim().isNotEmpty;
    final r = _resultado;
    final basicoIgualPiso = r != null && cfg != null && !usaOverride && (r.sueldoBasico - (cfg.pisoSalarial)).abs() < 10;
    return Card(
      color: AppColors.pastelBlue.withValues(alpha: 0.15),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Simulador de Sueldo Neto', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.blue.shade200)), child: Text('Valor del Punto / Índice Paritario: \$${valorIndiceEfectivo.toStringAsFixed(2)}. Si sube, Zona, Antigüedad y Ubicación suben en cascada.', style: TextStyle(fontSize: 11, color: Colors.blue.shade900))),
          if (usaOverride && r != null) Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.green.shade700)), child: Row(children: [Icon(Icons.check_circle, size: 18, color: Colors.green.shade800), const SizedBox(width: 8), Expanded(child: Text('Usando sueldo básico vigente: \$${r.sueldoBasico.toStringAsFixed(2)}. El recibo reflejará el acuerdo.', style: TextStyle(fontSize: 11, color: Colors.green.shade900)))])),
          if (basicoIgualPiso) Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: Colors.orange.shade100, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.orange.shade700)), child: Row(children: [Icon(Icons.info_outline, size: 18, color: Colors.orange.shade800), const SizedBox(width: 8), Expanded(child: Text('El básico = piso salarial (\$${cfg.pisoSalarial.toStringAsFixed(0)}). Si su recibo tiene otro básico, complete "Sueldo básico vigente" en Datos del Docente.', style: TextStyle(fontSize: 11, color: Colors.orange.shade900)))])),
          if (_esZonaPatagonica) Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: Colors.amber.shade100, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.amber.shade700)), child: Row(children: [Icon(Icons.map, size: 18, color: Colors.amber.shade800), const SizedBox(width: 8), Text('Zona Patagónica: Plus aplicado (Neuquén 40%)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.amber.shade900))])),
          if (_calculando) const CircularProgressIndicator() else if (_resultado != null) Text('Neto a cobrar: \$${_resultado!.netoACobrar.toStringAsFixed(2)}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)) else const Text('Complete nombre y CUIL para simular.'),
        ]),
      ),
    );
  }

  Widget _buildDetalleLiquidacion(LiquidacionOmniResult r) {
    return ExpansionTile(
      title: const Text('Detalle liquidación'),
      initiallyExpanded: true,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('HABERES REMUNERATIVOS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            _row('Sueldo básico', r.sueldoBasico),
            if (r.horasCatedra > 0) _row('Horas cátedra', r.horasCatedra),
            if (r.adicionalAntiguedad > 0) _row('Antigüedad', r.adicionalAntiguedad),
            if (r.dto23315 > 0) _row('Ad. Rem. Bonif. Dto 233/15', r.dto23315),
            if (r.ubicacionZona > 0) _row('Ubicación por Zona 10%', r.ubicacionZona),
            if (r.adicionalZona > 0) _row('Ad. zona', r.adicionalZona),
            if (r.adicionalZonaPatagonica > 0) _row(r.dto23315 > 0 ? 'Zona 40%' : 'Plus Zona Patagónica', r.adicionalZonaPatagonica),
            if (r.incDocenteLey25053 > 0) _row('Inc. Docente Ley 25053', r.incDocenteLey25053),
            if (r.a5D33516 > 0) _row('A5 D335/16', r.a5D33516),
            if (r.compFonid > 0) _row('Comp Fonid', r.compFonid),
            if (r.ipcFonid > 0) _row('IPC FONID', r.ipcFonid),
            if (r.plusUbicacion > 0) _row('Plus Ubicación / Ruralidad', r.plusUbicacion),
            if (r.estadoDocente > 0) _row('Estado Docente', r.estadoDocente),
            if (r.materialDidactico > 0) _row('Material Didáctico', r.materialDidactico),
            if (r.fonid > 0) _row('FONID', r.fonid),
            if (r.conectividad > 0) _row('Conectividad', r.conectividad),
            if (r.adicionalGarantiaSalarial > 0) _row('Garantía Salarial Nacional', r.adicionalGarantiaSalarial),
            const Divider(),
            _row('Total bruto remunerativo', r.totalBrutoRemunerativo, bold: true),
            if (r.conectividadNacional > 0 || r.conectividadProvincial > 0 || r.redondeoMonto > 0 || r.fondoCompensador > 0) ...[
              const Text('ADICIONALES NO REMUNERATIVOS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              if (r.conectividadNacional > 0) _row('Conec. nacional', r.conectividadNacional),
              if (r.conectividadProvincial > 0) _row('Conect. provincial', r.conectividadProvincial),
              if (r.redondeoMonto > 0) _row('Redondeo', r.redondeoMonto),
              if (r.fondoCompensador > 0) _row('Fondo Compensador', r.fondoCompensador),
              _row('Total no remunerativo', r.totalNoRemunerativo, bold: true),
              const Divider(),
            ],
            const Text('DESCUENTOS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.red)),
            _row('Jubilación', -r.aporteJubilacion),
            _row('Obra social (${r.porcentajeObraSocial.toStringAsFixed(1)}%)', -r.aporteObraSocial),
            _row('PAMI (3%)', -r.aportePami),
            if (r.dec13705 > 0) _row('Dec. Suplementario 137/05 2%', -r.dec13705),
            if (r.impuestoGanancias > 0) _row('Impuesto Ganancias', -r.impuestoGanancias),
            const Divider(),
            _row('Total descuentos', -r.totalDescuentos, bold: true),
            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.green.shade300, width: 2)), child: _row('NETO A COBRAR', r.netoACobrar, bold: true)),
          ]),
        ),
      ],
    );
  }

  Widget _row(String label, double value, {bool bold = false}) => Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: TextStyle(fontWeight: bold ? FontWeight.bold : null)), Text('\$${value.toStringAsFixed(2)}', style: TextStyle(fontWeight: bold ? FontWeight.bold : null))]));

  Widget _buildPanelCostoEmpleador() {
    if (_resultado == null) return const SizedBox.shrink();
    final artPct = double.tryParse(_artPctController.text.replaceAll(',', '.')) ?? 3.5;
    final artCuotaFija = double.tryParse(_artCuotaFijaController.text.replaceAll(',', '.')) ?? 800;
    final costo = calcularCostoPatronal(_resultado!.totalBrutoRemunerativo, artPct: artPct, artCuotaFija: artCuotaFija);
    return ExpansionTile(
      title: const Text('Análisis de Costo Empleador'),
      children: [
        Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _row('Sueldo Bruto', costo.sueldoBruto),
          _row('Contribuciones Patronales (30%)', costo.contribucionesPatronalesTotal),
          _row('ART y Seguros', costo.artYSeguros),
          _row('Provisión SAC y Vacaciones', costo.provisionSACYVacaciones),
          _row('Cargas Sociales s/ Provisiones', costo.cargasSocialesSobreProvisiones),
          const Divider(),
          _row('TOTAL COSTO LABORAL REAL', costo.totalCostoLaboralReal, bold: true),
        ])),
      ],
    );
  }
}
