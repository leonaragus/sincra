// Formulario Crear/Editar Institución — LSD 2026
// Campos dinámicos por jurisdicción, conceptos propios, costos patronales, validación CUIT 20/30
// ARCA 2026: Soporte para logo y firma digital

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../utils/image_preview.dart';
import '../models/teacher_types.dart';
import '../models/teacher_constants.dart';
import '../models/plantilla_cargo_omni.dart';
import '../models/ocr_confirm_result.dart';
import '../models/concepto_institucional.dart';
import '../services/instituciones_service.dart';
import '../theme/app_colors.dart';
import '../utils/formatters.dart';
import '../utils/validadores.dart';
import '../core/codigos_afip_arca.dart';
import 'teacher_receipt_scan_screen.dart';

class InstitucionFormScreen extends StatefulWidget {
  final Map<String, dynamic>? institucion;

  const InstitucionFormScreen({super.key, this.institucion});

  @override
  State<InstitucionFormScreen> createState() => _InstitucionFormScreenState();
}

class _InstitucionFormScreenState extends State<InstitucionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _cuitController = TextEditingController();
  final _razonSocialController = TextEditingController();
  final _domicilioController = TextEditingController();
  final _artPctController = TextEditingController(text: '3.5');
  final _artCuotaFijaController = TextEditingController(text: '800');
  final _seguroVidaController = TextEditingController(text: '0');
  final _codigoDIEGEPController = TextEditingController();
  final _aporteJubilatorioController = TextEditingController();
  final _aporteMunicipalController = TextEditingController();
  final _aporteCajaProvincialController = TextEditingController();

  Jurisdiccion _jurisdiccion = Jurisdiccion.buenosAires;
  TipoGestion _tipoGestion = TipoGestion.publica;
  ZonaDesfavorable _zonaDefault = ZonaDesfavorable.a;
  NivelUbicacion _nivelUbicacionDefault = NivelUbicacion.urbana;
  RegimenPrevisional _regimenPrevisional = RegimenPrevisional.provincial;
  bool _aplicaItemAula = false;
  bool _zonaPatagonica = false;
  bool _asistenciaPerfecta = false;
  
  // === LOGO Y FIRMA DIGITAL (ARCA 2026) ===
  String? _logoPath;
  String? _firmaPath;

  final List<String> _perfilesPendientes = [];
  List<String> _perfilesInstitucion = [];
  List<Map<String, dynamic>> _listaConceptosPropios = [];

  bool get _isPBA => _jurisdiccion == Jurisdiccion.buenosAires;
  bool get _isCABA => _jurisdiccion == Jurisdiccion.caba;
  bool get _isMendoza => _jurisdiccion == Jurisdiccion.mendoza;
  bool get _isPatagonia =>
      [Jurisdiccion.neuquen, Jurisdiccion.santaCruz, Jurisdiccion.chubut].contains(_jurisdiccion);
  bool get _isSantaFe => _jurisdiccion == Jurisdiccion.santaFe;

  @override
  void initState() {
    super.initState();
    if (widget.institucion != null) {
      final i = widget.institucion!;
      _cuitController.text = i['cuit']?.toString() ?? '';
      _razonSocialController.text = i['razonSocial']?.toString() ?? '';
      _domicilioController.text = i['domicilio']?.toString() ?? '';
      final j = i['jurisdiccion']?.toString();
      _jurisdiccion = Jurisdiccion.values.cast<Jurisdiccion?>().firstWhere(
          (e) => e?.name == j, orElse: () => Jurisdiccion.buenosAires) ?? Jurisdiccion.buenosAires;
      final tg = i['tipoGestion']?.toString();
      _tipoGestion = TipoGestion.values.cast<TipoGestion?>().firstWhere(
          (e) => e?.name == tg, orElse: () => TipoGestion.publica) ?? TipoGestion.publica;
      final zd = i['zonaDefault']?.toString();
      _zonaDefault = ZonaDesfavorable.values.cast<ZonaDesfavorable?>().firstWhere(
          (e) => e?.name == zd, orElse: () => ZonaDesfavorable.a) ?? ZonaDesfavorable.a;
      final rp = i['regimenPrevisional']?.toString();
      _regimenPrevisional = RegimenPrevisional.values.cast<RegimenPrevisional?>().firstWhere(
          (e) => e?.name == rp, orElse: () => RegimenPrevisional.provincial) ?? RegimenPrevisional.provincial;

      _artPctController.text = AppNumberFormatter.format(i['artPct'] ?? 3.5, valorIndice: false);
      _artCuotaFijaController.text = AppNumberFormatter.format(i['artCuotaFija'] ?? 800, valorIndice: false);
      _seguroVidaController.text = AppNumberFormatter.format(i['seguroVidaObligatorio'] ?? 0, valorIndice: false);

      _codigoDIEGEPController.text = i['codigoDIEGEP']?.toString() ?? '';
      _aporteJubilatorioController.text = AppNumberFormatter.format(i['aporteJubilatorio'], valorIndice: false);
      _aporteMunicipalController.text = AppNumberFormatter.format(i['aporteMunicipal'], valorIndice: false);
      _aporteCajaProvincialController.text = AppNumberFormatter.format(i['aporteCajaProvincial'], valorIndice: false);

      _aplicaItemAula = i['aplicaItemAula'] == true;
      _zonaPatagonica = i['zonaPatagonica'] == true;
      _asistenciaPerfecta = i['asistenciaPerfecta'] == true;
      
      // Cargar logo y firma
      final logo = i['logoPath']?.toString();
      _logoPath = (logo == null || logo.isEmpty || logo == 'No disponible') ? null : logo;
      final firma = i['firmaPath']?.toString();
      _firmaPath = (firma == null || firma.isEmpty || firma == 'No disponible') ? null : firma;

      final L = i['listaConceptosPropios'];
      if (L is List) {
        _listaConceptosPropios = L.map((e) => e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{}).toList();
      }

      _cargarPerfilesInstitucion();
    } else {
      _aporteJubilatorioController.text = AppNumberFormatter.format(_isPBA ? 16 : (_isCABA ? 13 : null), valorIndice: false);
      _artPctController.text = AppNumberFormatter.format(3.5, valorIndice: false);
      _artCuotaFijaController.text = AppNumberFormatter.format(800, valorIndice: false);
      _seguroVidaController.text = AppNumberFormatter.format(0, valorIndice: false);
    }
  }

  void _onJurisdiccionChanged(Jurisdiccion? v) {
    if (v == null) return;
    setState(() {
      _jurisdiccion = v;
      if (v == Jurisdiccion.buenosAires) _aporteJubilatorioController.text = '16';
      if (v == Jurisdiccion.caba) _aporteJubilatorioController.text = '13';
    });
  }

  Future<void> _cargarPerfilesInstitucion() async {
    final cuit = _cuitController.text.replaceAll(RegExp(r'[^\d]'), '');
    if (cuit.length != 11) return;
    final list = await InstitucionesService.getPerfilesInstitucion(cuit);
    if (mounted) setState(() => _perfilesInstitucion = list);
  }

  @override
  void dispose() {
    _cuitController.dispose();
    _razonSocialController.dispose();
    _domicilioController.dispose();
    _artPctController.dispose();
    _artCuotaFijaController.dispose();
    _seguroVidaController.dispose();
    _codigoDIEGEPController.dispose();
    _aporteJubilatorioController.dispose();
    _aporteMunicipalController.dispose();
    _aporteCajaProvincialController.dispose();
    super.dispose();
  }

  String? _validatorCuit(String? v) {
    if (v == null || v.trim().isEmpty) return 'Ingrese el CUIT';
    final d = v.replaceAll(RegExp(r'[^\d]'), '');
    if (d.length != 11) return 'CUIT debe tener 11 dígitos';
    if (!RegExp(r'^(20|30)\d{9}$').hasMatch(d)) return 'CUIT debe ser formato 20-XXXXXXXX-X o 30-XXXXXXXX-X';
    if (!validarCUITCUIL(v)) return 'CUIT inválido (verifique los dígitos)';
    return null;
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    final cuit = _cuitController.text.replaceAll(RegExp(r'[^\d]'), '');
    if (cuit.length != 11 || !RegExp(r'^(20|30)\d{9}$').hasMatch(cuit)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('CUIT debe ser 20-XXXXXXXX-X o 30-XXXXXXXX-X')));
      return;
    }
    try {
      final map = <String, dynamic>{
        'cuit': _cuitController.text.trim(),
        'razonSocial': _razonSocialController.text.trim(),
        'domicilio': _domicilioController.text.trim(),
        'jurisdiccion': _jurisdiccion.name,
        'tipoGestion': _tipoGestion.name,
        'zonaDefault': _zonaDefault.name,
        'nivelUbicacionDefault': _nivelUbicacionDefault.name,
        'regimenPrevisional': _regimenPrevisional.name,
        'artPct': double.tryParse(_artPctController.text.replaceAll(',', '.')) ?? 3.5,
        'artCuotaFija': double.tryParse(_artCuotaFijaController.text.replaceAll(',', '.')) ?? 800,
        'seguroVidaObligatorio': double.tryParse(_seguroVidaController.text.replaceAll(',', '.')) ?? 0,
        'listaConceptosPropios': _listaConceptosPropios,
        'aplicaItemAula': _isMendoza && _aplicaItemAula,
        'zonaPatagonica': _isPatagonia && _zonaPatagonica,
        'asistenciaPerfecta': _isSantaFe && _asistenciaPerfecta,
        // Logo y firma ARCA 2026
        'logoPath': _logoPath ?? 'No disponible',
        'firmaPath': _firmaPath ?? 'No disponible',
      };
      if (_isPBA) {
        map['codigoDIEGEP'] = _codigoDIEGEPController.text.trim().isEmpty ? null : _codigoDIEGEPController.text.trim();
        map['aporteJubilatorio'] = double.tryParse(_aporteJubilatorioController.text.replaceAll(',', '.')) ?? 16;
      }
      if (_isCABA) {
        map['aporteMunicipal'] = double.tryParse(_aporteMunicipalController.text.replaceAll(',', '.'));
        map['aporteJubilatorio'] = double.tryParse(_aporteJubilatorioController.text.replaceAll(',', '.')) ?? 13;
      }
      if (_isPatagonia) {
        map['aporteCajaProvincial'] = double.tryParse(_aporteCajaProvincialController.text.replaceAll(',', '.'));
      }

      await InstitucionesService.saveInstitucion(map);
      if (!mounted) return;
      if (widget.institucion == null) {
        for (final id in _perfilesPendientes) {
          await InstitucionesService.addPerfilInstitucion(cuit, id);
        }
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(widget.institucion != null ? 'Institución actualizada' : 'Institución creada'),
        backgroundColor: AppColors.glassFillStrong,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ));
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _abrirEscanerParaPerfil() async {
    final esEdicion = widget.institucion != null;
    final cuit = _cuitController.text.replaceAll(RegExp(r'[^\d]'), '');
    if (esEdicion && cuit.length != 11) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Complete el CUIT para asociar perfiles')));
      return;
    }
    final r = await Navigator.push<dynamic>(context, MaterialPageRoute(builder: (c) => const TeacherReceiptScanScreen()));
    if (r == null || !mounted) return;
    if (r is! OcrConfirmResult) return;
    final perfilCargoId = PlantillaCargoOmni.fromOcrConfirmResult(r, fallbackJurisdiccion: _jurisdiccion);
    if (esEdicion) {
      if (cuit.length != 11) return;
      await InstitucionesService.addPerfilInstitucion(cuit, perfilCargoId);
      if (mounted) _cargarPerfilesInstitucion();
    } else {
      if (!_perfilesPendientes.contains(perfilCargoId)) setState(() => _perfilesPendientes.add(perfilCargoId));
    }
  }

  void _quitarPerfil(String id, {bool esEdicion = false}) async {
    if (esEdicion) {
      final cuit = _cuitController.text.replaceAll(RegExp(r'[^\d]'), '');
      if (cuit.length != 11) return;
      await InstitucionesService.removePerfilInstitucion(cuit, id);
      if (mounted) _cargarPerfilesInstitucion();
    } else {
      setState(() => _perfilesPendientes.remove(id));
    }
  }

  // === LOGO Y FIRMA DIGITAL (ARCA 2026) ===
  Future<void> _elegirImagen(bool esFirma) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.backgroundLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: AppColors.textMuted,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: AppColors.pastelBlue),
              title: const Text('Galería', style: TextStyle(color: AppColors.textPrimary)),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: Icon(Icons.camera_alt, color: AppColors.pastelMint),
              title: const Text('Cámara', style: TextStyle(color: AppColors.textPrimary)),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            if ((esFirma ? _firmaPath : _logoPath) != null)
              ListTile(
                leading: Icon(Icons.delete, color: AppColors.pastelPink),
                title: Text(
                  esFirma ? 'Eliminar firma' : 'Eliminar logo',
                  style: TextStyle(color: AppColors.pastelPink),
                ),
                onTap: () {
                  setState(() {
                    if (esFirma) {
                      _firmaPath = null;
                    } else {
                      _logoPath = null;
                    }
                  });
                  Navigator.pop(context);
                },
              ),
          ],
        ),
      ),
    );

    if (source == null || !mounted) return;

    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (pickedFile != null && mounted) {
        setState(() {
          if (esFirma) {
            _firmaPath = pickedFile.path;
          } else {
            _logoPath = pickedFile.path;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al seleccionar imagen: $e'),
            backgroundColor: AppColors.pastelPink,
          ),
        );
      }
    }
  }

  Widget _buildImagenPreview(String? path, bool esFirma) {
    final width = esFirma ? 120.0 : 80.0;
    final height = esFirma ? 60.0 : 80.0;
    
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: buildImagePreview(
        path: path,
        width: width,
        height: height,
        fit: BoxFit.contain,
        placeholder: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: AppColors.glassFill,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: Icon(
            esFirma ? Icons.draw_outlined : Icons.business,
            color: AppColors.textMuted,
            size: 32,
          ),
        ),
        errorWidget: Container(
          width: width,
          height: height,
          color: AppColors.glassFill,
          child: const Icon(Icons.broken_image, color: AppColors.textMuted),
        ),
      ),
    );
  }

  Future<void> _agregarConceptoPropio() async {
    TipoConceptoInstitucional tp = TipoConceptoInstitucional.sumaFija;
    NaturalezaConcepto nat = NaturalezaConcepto.remunerativo;
    String codSel = CodigosAfipArca.c011000;
    bool codOtro = false;
    String codOtroVal = '';
    String nom = '';

    final res = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) {
          return AlertDialog(
            backgroundColor: AppColors.backgroundLight,
            title: const Text('Agregar concepto propio', style: TextStyle(color: AppColors.textPrimary)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    decoration: const InputDecoration(labelText: 'Nombre', border: OutlineInputBorder()),
                    style: const TextStyle(color: AppColors.textPrimary),
                    onChanged: (v) => nom = v,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<TipoConceptoInstitucional>(
                    initialValue: tp,
                    decoration: const InputDecoration(labelText: 'Tipo', border: OutlineInputBorder()),
                    dropdownColor: AppColors.backgroundLight,
                    style: const TextStyle(color: AppColors.textPrimary),
                    items: const [
                      DropdownMenuItem(value: TipoConceptoInstitucional.sumaFija, child: Text('Suma Fija')),
                      DropdownMenuItem(value: TipoConceptoInstitucional.porcentaje, child: Text('Porcentaje')),
                    ],
                    onChanged: (v) { if (v != null) setD(() => tp = v); },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<NaturalezaConcepto>(
                    initialValue: nat,
                    decoration: const InputDecoration(labelText: 'Naturaleza', border: OutlineInputBorder()),
                    dropdownColor: AppColors.backgroundLight,
                    style: const TextStyle(color: AppColors.textPrimary),
                    items: const [
                      DropdownMenuItem(value: NaturalezaConcepto.remunerativo, child: Text('Remunerativo')),
                      DropdownMenuItem(value: NaturalezaConcepto.noRemunerativo, child: Text('No Remunerativo')),
                    ],
                    onChanged: (v) { if (v != null) setD(() => nat = v); },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: codOtro ? '__otro__' : (CodigosAfipArca.todos.contains(codSel) ? codSel : CodigosAfipArca.c011000),
                    decoration: const InputDecoration(labelText: 'Código AFIP/ARCA', border: OutlineInputBorder()),
                    dropdownColor: AppColors.backgroundLight,
                    style: const TextStyle(color: AppColors.textPrimary),
                    items: [
                      ...CodigosAfipArca.todos.map((c) => DropdownMenuItem(value: c, child: Text(c))),
                      const DropdownMenuItem(value: '__otro__', child: Text('Otro (ingresar)')),
                    ],
                    onChanged: (v) {
                      setD(() {
                        codOtro = v == '__otro__';
                        if (!codOtro && v != null) codSel = v;
                      });
                    },
                  ),
                  if (codOtro) ...[
                    const SizedBox(height: 8),
                    TextField(
                      decoration: const InputDecoration(labelText: 'Código AFIP/ARCA (6 dígitos)', border: OutlineInputBorder()),
                      style: const TextStyle(color: AppColors.textPrimary),
                      onChanged: (v) => codOtroVal = v,
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text('Cancelar')),
              FilledButton(
                onPressed: () {
                  final cod = codOtro ? codOtroVal.trim() : codSel;
                  if (nom.trim().isEmpty) {
                    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Ingrese el nombre')));
                    return;
                  }
                  if (cod.isEmpty) {
                    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Ingrese el código AFIP/ARCA')));
                    return;
                  }
                  Navigator.pop(ctx, {'nombre': nom.trim(), 'tipo': tp.name, 'naturaleza': nat.name, 'codigoAfipArca': cod});
                },
                child: const Text('Agregar'),
              ),
            ],
          );
        },
      ),
    );
    if (res != null && mounted) setState(() => _listaConceptosPropios.add(res));
  }

  void _quitarConceptoPropio(int idx) {
    setState(() => _listaConceptosPropios.removeAt(idx));
  }

  @override
  Widget build(BuildContext context) {
    final esEdicion = widget.institucion != null;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.glassFillStrong,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          esEdicion ? 'Editar Institución' : 'Nueva Institución',
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _buildSeccion('Información Básica', Icons.business, [
              _buildTextField(
                controller: _cuitController,
                label: 'CUIT (20- o 30-XXXXXXXX-X)',
                icon: Icons.badge,
                keyboardType: TextInputType.number,
                readOnly: esEdicion,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(11)],
                validator: _validatorCuit,
              ),
              const SizedBox(height: 16),
              _buildTextField(controller: _razonSocialController, label: 'Razón Social', icon: Icons.business, validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingrese la razón social' : null),
              const SizedBox(height: 16),
              _buildTextField(controller: _domicilioController, label: 'Domicilio legal (calle/numero/ciudad)', icon: Icons.location_on, validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingrese el domicilio legal en formato: calle/numero/ciudad' : null),
              const SizedBox(height: 16),
              DropdownButtonFormField<Jurisdiccion>(
                initialValue: _jurisdiccion,
                decoration: _inputDeco('Jurisdicción', Icons.map),
                dropdownColor: AppColors.backgroundLight,
                style: const TextStyle(color: AppColors.textPrimary),
                items: Jurisdiccion.values.map((j) {
                  final c = JurisdiccionDBOmni.get(j);
                  return DropdownMenuItem(value: j, child: Text(c?.nombre ?? j.name));
                }).toList(),
                onChanged: _onJurisdiccionChanged,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<TipoGestion>(
                initialValue: _tipoGestion,
                decoration: _inputDeco('Gestión', Icons.business),
                dropdownColor: AppColors.backgroundLight,
                style: const TextStyle(color: AppColors.textPrimary),
                items: const [DropdownMenuItem(value: TipoGestion.publica, child: Text('Pública')), DropdownMenuItem(value: TipoGestion.privada, child: Text('Privada'))],
                onChanged: (v) { if (v != null) setState(() => _tipoGestion = v); },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<ZonaDesfavorable>(
                initialValue: _zonaDefault,
                decoration: _inputDeco('Zona', Icons.map_outlined),
                dropdownColor: AppColors.backgroundLight,
                style: const TextStyle(color: AppColors.textPrimary),
                items: const [
                  DropdownMenuItem(value: ZonaDesfavorable.a, child: Text('A')), DropdownMenuItem(value: ZonaDesfavorable.b, child: Text('B')),
                  DropdownMenuItem(value: ZonaDesfavorable.c, child: Text('C')), DropdownMenuItem(value: ZonaDesfavorable.d, child: Text('D')),
                  DropdownMenuItem(value: ZonaDesfavorable.e, child: Text('E')),
                ],
                onChanged: (v) { if (v != null) setState(() => _zonaDefault = v); },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<NivelUbicacion>(
                initialValue: _nivelUbicacionDefault,
                decoration: _inputDeco('Nivel Ubicación / Ruralidad', Icons.place),
                dropdownColor: AppColors.backgroundLight,
                style: const TextStyle(color: AppColors.textPrimary),
                items: const [
                  DropdownMenuItem(value: NivelUbicacion.urbana, child: Text('Urbana (0%)')),
                  DropdownMenuItem(value: NivelUbicacion.alejada, child: Text('Alejada (20%)')),
                  DropdownMenuItem(value: NivelUbicacion.inhospita, child: Text('Inhóspita (40%)')),
                  DropdownMenuItem(value: NivelUbicacion.muyInhospita, child: Text('Muy inhóspita (60%)')),
                ],
                onChanged: (v) { if (v != null) setState(() => _nivelUbicacionDefault = v); },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<RegimenPrevisional>(
                initialValue: _regimenPrevisional,
                decoration: _inputDeco('Régimen previsional', Icons.account_balance),
                dropdownColor: AppColors.backgroundLight,
                style: const TextStyle(color: AppColors.textPrimary),
                items: const [DropdownMenuItem(value: RegimenPrevisional.nacional, child: Text('Nacional')), DropdownMenuItem(value: RegimenPrevisional.provincial, child: Text('Provincial'))],
                onChanged: (v) { if (v != null) setState(() => _regimenPrevisional = v); },
              ),
            ]),
            const SizedBox(height: 20),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              child: _buildCamposPorJurisdiccion(),
            ),
            const SizedBox(height: 20),
            _buildSeccionCostosPatronales(),
            const SizedBox(height: 20),
            // === Logo y Firma Digital (ARCA 2026) ===
            _buildSeccion('Logo y Firma Digital (ARCA 2026)', Icons.verified_user, [
              const Text(
                'Agregue el logo y firma de la institución para incluirlos en los recibos de sueldo digitales según normativa ARCA 2026.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        const Text('Logo', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () => _elegirImagen(false),
                          child: _buildImagenPreview(_logoPath, false),
                        ),
                        TextButton.icon(
                          onPressed: () => _elegirImagen(false),
                          icon: const Icon(Icons.upload, size: 18),
                          label: Text(_logoPath == null ? 'Cargar' : 'Cambiar'),
                          style: TextButton.styleFrom(foregroundColor: AppColors.pastelBlue),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      children: [
                        const Text('Firma Digital', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () => _elegirImagen(true),
                          child: _buildImagenPreview(_firmaPath, true),
                        ),
                        TextButton.icon(
                          onPressed: () => _elegirImagen(true),
                          icon: const Icon(Icons.upload, size: 18),
                          label: Text(_firmaPath == null ? 'Cargar' : 'Cambiar'),
                          style: TextButton.styleFrom(foregroundColor: AppColors.pastelBlue),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ]),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _guardar,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.pastelBlue,
                foregroundColor: AppColors.background,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.save, size: 22),
                  const SizedBox(width: 8),
                  Text(esEdicion ? 'Actualizar Institución' : 'Crear Institución', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _buildSeccionPerfiles(esEdicion),
            const SizedBox(height: 24),
            _buildSeccionConceptosPropios(),
          ],
        ),
      ),
    );
  }

  Widget _buildCamposPorJurisdiccion() {
    final children = <Widget>[];
    if (_isPBA) {
      children.addAll([
        _buildTextField(controller: _codigoDIEGEPController, label: 'Código DIEGEP', icon: Icons.tag),
        const SizedBox(height: 16),
        _buildTextField(controller: _aporteJubilatorioController, label: 'Aporte Jubilatorio % (IPS, ej. 16)', icon: Icons.percent, keyboardType: const TextInputType.numberWithOptions(decimal: true)),
        const SizedBox(height: 16),
      ]);
    }
    if (_isCABA) {
      children.addAll([
        _buildTextField(controller: _aporteMunicipalController, label: 'Aporte Municipal', icon: Icons.account_balance, keyboardType: const TextInputType.numberWithOptions(decimal: true), inputFormatters: [AppNumberFormatter.inputFormatter(valorIndice: false)]),
        const SizedBox(height: 16),
        _buildTextField(controller: _aporteJubilatorioController, label: 'Aporte Jubilación % (Nacional, ej. 13)', icon: Icons.percent, keyboardType: const TextInputType.numberWithOptions(decimal: true), inputFormatters: [AppNumberFormatter.inputFormatter(valorIndice: false)]),
        const SizedBox(height: 16),
      ]);
    }
    if (_isMendoza) {
      children.addAll([
        Row(
          children: [
            const Icon(Icons.school, color: AppColors.textMuted, size: 20),
            const SizedBox(width: 12),
            const Text('Aplica Ítem Aula', style: TextStyle(color: AppColors.textPrimary)),
            const Spacer(),
            Switch(value: _aplicaItemAula, onChanged: (v) => setState(() => _aplicaItemAula = v), activeThumbColor: AppColors.pastelBlue),
          ],
        ),
        const SizedBox(height: 16),
      ]);
    }
    if (_isPatagonia) {
      children.addAll([
        Row(
          children: [
            const Icon(Icons.map, color: AppColors.textMuted, size: 20),
            const SizedBox(width: 12),
            const Text('Zona Patagónica (40%)', style: TextStyle(color: AppColors.textPrimary)),
            const Spacer(),
            Switch(value: _zonaPatagonica, onChanged: (v) => setState(() => _zonaPatagonica = v), activeThumbColor: AppColors.pastelBlue),
          ],
        ),
        const SizedBox(height: 16),
        _buildTextField(controller: _aporteCajaProvincialController, label: 'Aporte Caja Provincial %', icon: Icons.percent, keyboardType: const TextInputType.numberWithOptions(decimal: true), inputFormatters: [AppNumberFormatter.inputFormatter(valorIndice: false)]),
        const SizedBox(height: 16),
      ]);
    }
    if (_isSantaFe) {
      children.addAll([
        Row(
          children: [
            const Icon(Icons.verified_user, color: AppColors.textMuted, size: 20),
            const SizedBox(width: 12),
            const Text('Asistencia Perfecta', style: TextStyle(color: AppColors.textPrimary)),
            const Spacer(),
            Switch(value: _asistenciaPerfecta, onChanged: (v) => setState(() => _asistenciaPerfecta = v), activeThumbColor: AppColors.pastelBlue),
          ],
        ),
        const SizedBox(height: 16),
      ]);
    }
    if (children.isEmpty) return const SizedBox.shrink(key: ValueKey('empty'));
    return _buildSeccion('Campos por Jurisdicción', Icons.business_center, children, key: ValueKey(_jurisdiccion.name));
  }

  Widget _buildSeccionCostosPatronales() {
    return _buildSeccion('Costos Patronales (críticos)', Icons.monetization_on, [
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.pastelOrange.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.pastelOrange.withValues(alpha: 0.4))),
        child: const Text('ART y Seguro de Vida Obligatorio son costos patronales clave para el Libro de Sueldos.', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
      ),
      const SizedBox(height: 16),
      _buildTextField(controller: _artPctController, label: 'ART %', icon: Icons.percent, keyboardType: const TextInputType.numberWithOptions(decimal: true), inputFormatters: [AppNumberFormatter.inputFormatter(valorIndice: false)]),
      const SizedBox(height: 16),
      _buildTextField(controller: _artCuotaFijaController, label: 'ART cuota fija (\$)', icon: Icons.attach_money, keyboardType: const TextInputType.numberWithOptions(decimal: true), inputFormatters: [AppNumberFormatter.inputFormatter(valorIndice: false)]),
      const SizedBox(height: 16),
      _buildTextField(controller: _seguroVidaController, label: 'Seguro de Vida Obligatorio (\$/mes)', icon: Icons.health_and_safety, keyboardType: const TextInputType.numberWithOptions(decimal: true), inputFormatters: [AppNumberFormatter.inputFormatter(valorIndice: false)]),
    ]);
  }

  Widget _buildSeccionConceptosPropios() {
    return _buildSeccion('Conceptos Propios de la Institución', Icons.playlist_add, [
      const Text('Adicionales que el contador puede asignar a cada empleado. Aparecerán en la ficha del empleado.', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: _agregarConceptoPropio,
        icon: const Icon(Icons.add, size: 20),
        label: const Text('Agregar concepto'),
        style: OutlinedButton.styleFrom(foregroundColor: AppColors.pastelBlue, side: const BorderSide(color: AppColors.pastelBlue), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      ),
      if (_listaConceptosPropios.isNotEmpty) ...[
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(_listaConceptosPropios.length, (i) {
            final c = _listaConceptosPropios[i];
            final nom = c['nombre']?.toString() ?? 'Sin nombre';
            return Chip(
              label: Text(nom, style: const TextStyle(fontSize: 12)),
              deleteIcon: const Icon(Icons.close, size: 16, color: AppColors.textMuted),
              onDeleted: () => _quitarConceptoPropio(i),
            );
          }),
        ),
      ],
    ]);
  }

  Widget _buildSeccion(String titulo, IconData icono, List<Widget> children, {Key? key}) {
    return ClipRRect(
      key: key,
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: AppColors.glassFillStrong, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.glassBorder)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: AppColors.pastelBlue.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
                    child: Icon(icono, color: AppColors.pastelBlue, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text(titulo, style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 16),
              ...children,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSeccionPerfiles(bool esEdicion) {
    final lista = esEdicion ? _perfilesInstitucion : _perfilesPendientes;
    return _buildSeccion('Perfiles de pago', Icons.receipt_long, [
      const Text('¿Desea añadir los perfiles de pago ya utilizados? Puede escanear un recibo para asociar un perfil a esta institución.', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: _abrirEscanerParaPerfil,
        icon: const Icon(Icons.document_scanner, size: 20),
        label: const Text('Escanear recibo para añadir perfil'),
        style: OutlinedButton.styleFrom(foregroundColor: AppColors.pastelBlue, side: const BorderSide(color: AppColors.pastelBlue), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      ),
      if (lista.isNotEmpty) ...[
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: lista.map((id) => Chip(label: Text(PlantillaCargoOmni.labelCorto(id), style: const TextStyle(fontSize: 12)), deleteIcon: const Icon(Icons.close, size: 16, color: AppColors.textMuted), onDeleted: () => _quitarPerfil(id, esEdicion: esEdicion))).toList()),
      ],
    ]);
  }

  InputDecoration _inputDeco(String label, IconData icon) => InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.textMuted),
        prefixIcon: Icon(icon, color: AppColors.textMuted),
        filled: true,
        fillColor: AppColors.glassFill,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.glassBorder)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.pastelBlue, width: 2)),
      );

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool readOnly = false,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.textMuted),
        prefixIcon: Icon(icon, color: AppColors.textMuted),
        filled: true,
        fillColor: AppColors.glassFill,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.glassBorder)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.pastelBlue, width: 2)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.red.shade300)),
      ),
      validator: validator,
    );
  }
}
