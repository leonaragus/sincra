// --- Pantalla de Liquidación de Sanidad (CCT 122/75 y otros) - ARCA 2026 ---
// Arquitectura rediseñada a un "Asistente Guiado" para mejorar el flujo de trabajo.
// v3.1 - Implementación de Exportación Masiva y validaciones de neto.

import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/cct_model.dart';
import '../models/ocr_confirm_result.dart';
import '../models/teacher_types.dart'; // Para Jurisdiccion

import '../services/sanidad_omni_engine.dart';
import '../services/pdf_service.dart';
import '../services/sanidad_company_service.dart';
import '../services/sanidad_empleado_service.dart';
import '../services/lsd_mapping_service.dart';
import '../services/sanidad_lsd_export.dart';
import '../services/contabilidad_service.dart';
import '../services/sanidad_paritarias_service.dart';
import '../services/sanidad_excel_export.dart';
import '../services/sanidad_history_service.dart';
import '../services/sanidad_retroactivo_service.dart';
import '../utils/validaciones_arca.dart';
import '../providers/cct_provider.dart';
import '../theme/app_colors.dart';
import '../utils/app_help.dart';
import '../utils/file_saver.dart';
import '../utils/formatters.dart';
import '../widgets/sanidad_receipt_preview.dart';
import 'sanidad_receipt_scan_screen.dart';

// --- Modelos Locales ---
class SanidadEmpresa {
  final String cuit;
  final String razonSocial;
  final String? domicilio;
  final String? cctId;
  final String? actividad;
  final Jurisdiccion? jurisdiccion;

  const SanidadEmpresa({
    required this.cuit,
    required this.razonSocial,
    this.domicilio,
    this.cctId,
    this.actividad,
    this.jurisdiccion,
  });

  SanidadEmpresa copyWith({
    String? cuit,
    String? razonSocial,
    String? domicilio,
    String? cctId,
    String? actividad,
    Jurisdiccion? jurisdiccion,
  }) {
    return SanidadEmpresa(
      cuit: cuit ?? this.cuit,
      razonSocial: razonSocial ?? this.razonSocial,
      domicilio: domicilio ?? this.domicilio,
      cctId: cctId ?? this.cctId,
      actividad: actividad ?? this.actividad,
      jurisdiccion: jurisdiccion ?? this.jurisdiccion,
    );
  }

  factory SanidadEmpresa.fromMap(Map<String, dynamic> map) {
    return SanidadEmpresa(
      cuit: map['cuit']?.toString() ?? '',
      razonSocial: map['razonSocial']?.toString() ?? '',
      domicilio: map['domicilio']?.toString(),
      cctId: map['cctId']?.toString(),
      actividad: map['actividad']?.toString(),
      jurisdiccion: map['jurisdiccion'] != null 
          ? Jurisdiccion.values.firstWhere((j) => j.name == map['jurisdiccion'], orElse: () => Jurisdiccion.buenosAires)
          : null,
    );
  }

  Map<String, dynamic> toMap() => {
    'cuit': cuit,
    'razonSocial': razonSocial,
    'domicilio': domicilio,
    'cctId': cctId,
    'actividad': actividad,
    'jurisdiccion': jurisdiccion?.name,
  };
}

class SanidadEmpleado {
  final String cuil; // Cambiado de cuit a cuil para consistencia
  final String nombre;
  final String? puesto;
  final DateTime fechaIngreso;
  final CategoriaSanidad categoria;
  final NivelTituloSanidad nivelTitulo;
  final bool tareaCriticaRiesgo;
  final bool cuotaSindicalAtsa;
  final bool manejoEfectivoCaja;
  final int horasNocturnas;
  final String? codigoRnos;
  final int cantidadFamiliares;
  final String? cbu;
  final String? domicilio;
  final String? localidad;
  final String? codigoPostal;
  final String? codigoModalidad;
  final String? codigoSituacion;

  const SanidadEmpleado({
    required this.cuil,
    required this.nombre,
    this.puesto,
    required this.fechaIngreso,
    required this.categoria,
    this.nivelTitulo = NivelTituloSanidad.sinTitulo,
    this.tareaCriticaRiesgo = false,
    this.cuotaSindicalAtsa = false,
    this.manejoEfectivoCaja = false,
    this.horasNocturnas = 0,
    this.codigoRnos,
    this.cantidadFamiliares = 0,
    this.cbu,
    this.domicilio,
    this.localidad,
    this.codigoPostal,
    this.codigoModalidad,
    this.codigoSituacion,
  });

  factory SanidadEmpleado.fromMap(Map<String, dynamic> map) {
    return SanidadEmpleado(
      cuil: map['cuil']?.toString() ?? map['cuit']?.toString() ?? '',
      nombre: map['nombre']?.toString() ?? '',
      puesto: map['puesto']?.toString(),
      fechaIngreso: map['fechaIngreso'] != null ? DateTime.parse(map['fechaIngreso']) : DateTime.now(),
      categoria: CategoriaSanidad.values.firstWhere((e) => e.name == map['categoria'], orElse: () => CategoriaSanidad.servicios),
      nivelTitulo: NivelTituloSanidad.values.firstWhere((e) => e.name == map['nivelTitulo'], orElse: () => NivelTituloSanidad.sinTitulo),
      tareaCriticaRiesgo: map['tareaCriticaRiesgo'] == true,
      cuotaSindicalAtsa: map['cuotaSindicalAtsa'] == true,
      manejoEfectivoCaja: map['manejoEfectivoCaja'] == true,
      horasNocturnas: map['horasNocturnas'] ?? 0,
      codigoRnos: map['codigoRnos']?.toString(),
      cantidadFamiliares: map['cantidadFamiliares'] ?? 0,
      cbu: map['cbu']?.toString(),
      domicilio: map['domicilio']?.toString(),
      localidad: map['localidad']?.toString(),
      codigoPostal: map['codigoPostal']?.toString(),
      codigoModalidad: map['codigoModalidad']?.toString(),
      codigoSituacion: map['codigoSituacion']?.toString(),
    );
  }

  Map<String, dynamic> toMap() => {
    'cuil': cuil,
    'nombre': nombre,
    'puesto': puesto,
    'fechaIngreso': fechaIngreso.toIso8601String(),
    'categoria': categoria.name,
    'nivelTitulo': nivelTitulo.name,
    'tareaCriticaRiesgo': tareaCriticaRiesgo,
    'cuotaSindicalAtsa': cuotaSindicalAtsa,
    'manejoEfectivoCaja': manejoEfectivoCaja,
    'horasNocturnas': horasNocturnas,
    'codigoRnos': codigoRnos,
    'cantidadFamiliares': cantidadFamiliares,
    'cbu': cbu,
    'domicilio': domicilio,
    'localidad': localidad,
    'codigoPostal': codigoPostal,
    'codigoModalidad': codigoModalidad,
    'codigoSituacion': codigoSituacion,
  };
}

enum _WizardStep { welcome, selectCompany, manageCompanies, selectEmployee, fillData }

class SanidadInterfaceScreen extends StatefulWidget {
  final SanidadEmpresa? initialEmpresa;
  final OcrConfirmResult? initialOcrResult;

  const SanidadInterfaceScreen({super.key, this.initialEmpresa, this.initialOcrResult});

  @override
  State<SanidadInterfaceScreen> createState() => _SanidadInterfaceScreenState();
}

class _SanidadInterfaceScreenState extends State<SanidadInterfaceScreen> {
  // --- Servicios ---
  final _pdfService = PdfService();

  // --- Estado del Asistente y UI ---
  _WizardStep _currentStep = _WizardStep.welcome;
  String _wizardTitle = "Liquidador Sanidad (CCT 122/75)";
  Timer? _debounce;
  bool _isSaving = false;
  SanidadEmpresa? _editingCompany;
  bool _exportandoMasivo = false;

  // --- Estado de Datos: Empresa y Empleado ---
  SanidadEmpresa? _empresa;
  SanidadEmpleado? _empleado;
  List<SanidadEmpresa> _listaEmpresas = [];
  List<SanidadEmpleado> _listaEmpleados = [];
  
  // --- Estado de Liquidación ---
  DateTime _periodoSeleccionado = DateTime.now();
  DateTime _fechaPago = DateTime.now();
  ModoLiquidacionSanidad _modoLiquidacion = ModoLiquidacionSanidad.mensual;
  LiquidacionSanidadResult? _resultado;
  bool _calculando = false;

  // === LIQUIDACIÓN FINAL ===
  DateTime? _fechaEgreso;
  String _motivoEgreso = 'renuncia';
  bool _incluyePreaviso = false;
  bool _incluyeIntegracionMes = false;
  
  // --- Controladores Empresa ---
  final _razonSocialController = TextEditingController();
  final _cuitController = TextEditingController();
  final _domicilioController = TextEditingController();

  // --- Controladores Empleado ---
  final _nombreController = TextEditingController();
  final _cuilController = TextEditingController();
  final _puestoController = TextEditingController();
  final _codigoRnosController = TextEditingController();
  final _cantidadFamiliaresController = TextEditingController(text: '0');
  final _horasNocturnasController = TextEditingController(text: '0');
  final _cbuController = TextEditingController();
  final _localidadController = TextEditingController();
  final _codigoPostalController = TextEditingController();
  final _domicilioEmpleadoController = TextEditingController();
  final _horasExtras50Controller = TextEditingController(text: '0');
  final _horasExtras100Controller = TextEditingController(text: '0');
  final _adelantosController = TextEditingController(text: '0');
  final _embargosController = TextEditingController(text: '0');
  final _prestamosController = TextEditingController(text: '0');
  final _mejorRemuneracionController = TextEditingController();
  final _diasSACController = TextEditingController(text: '180');
  final _diasVacacionesController = TextEditingController(text: '14');

  // --- Estado Empleado ---
  DateTime _fechaIngreso = DateTime.now().subtract(const Duration(days: 365 * 5));
  CategoriaSanidad _categoria = CategoriaSanidad.profesional;
  NivelTituloSanidad _nivelTitulo = NivelTituloSanidad.sinTitulo;
  bool _tareaCriticaRiesgo = false;
  bool _cuotaSindicalAtsa = false;
  bool _manejoEfectivoCaja = false;
  String _modalidadContratacion = '008'; // Tiempo indeterminado
  String _situacionRevista = '01';       // Activo
  Jurisdiccion _jurisdiccion = Jurisdiccion.buenosAires;

  bool get _esZonaPatagonica =>
      [Jurisdiccion.rioNegro, Jurisdiccion.neuquen, Jurisdiccion.chubut, Jurisdiccion.santaCruz, Jurisdiccion.tierraDelFuego].contains(_jurisdiccion);
  
  // --- Paritarias ---
  List<ParitariaSanidad> _paritariasMaestras = [];
  bool _maestroLoading = false;
  bool _savingMaestro = false;
  DateTime? _ultimaSincronizacion;
  String _modoSincronizacion = '';
  
  Cct? _convenio;

  @override
  void initState() {
    super.initState();
    _cargarParitarias();
    _setupDebouncedRecalculation();

    if (widget.initialEmpresa != null) {
      _seleccionarEmpresa(widget.initialEmpresa!);
    } else if (widget.initialOcrResult != null) {
      _goToStep(_WizardStep.fillData);
      _prefillFromOcr(widget.initialOcrResult!);
    }
  }

  void _setupDebouncedRecalculation() {
    final allControllers = [
      _nombreController, _cuilController, _cantidadFamiliaresController, _horasNocturnasController,
      _horasExtras50Controller, _horasExtras100Controller, _adelantosController, _embargosController,
      _prestamosController, _mejorRemuneracionController, _diasSACController, _diasVacacionesController
    ];
    for (var controller in allControllers) {
      controller.addListener(_onInputChanged);
    }
  }

  void _onInputChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 750), () {
      if (mounted) {
        _recalcular();
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _razonSocialController.dispose();
    _cuitController.dispose();
    _domicilioController.dispose();
    _nombreController.dispose();
    _cuilController.dispose();
    _puestoController.dispose();
    _codigoRnosController.dispose();
    _cantidadFamiliaresController.dispose();
    _horasNocturnasController.dispose();
    _cbuController.dispose();
    _localidadController.dispose();
    _codigoPostalController.dispose();
    _domicilioEmpleadoController.dispose();
    _horasExtras50Controller.dispose();
    _horasExtras100Controller.dispose();
    _adelantosController.dispose();
    _embargosController.dispose();
    _prestamosController.dispose();
    _mejorRemuneracionController.dispose();
    _diasSACController.dispose();
    _diasVacacionesController.dispose();
    super.dispose();
  }

  // === NAVEGACIÓN Y ESTRUCTURA DEL ASISTENTE ===
  void _goToStep(_WizardStep step) {
    setState(() {
      _currentStep = step;
      switch (step) {
        case _WizardStep.welcome:
          _wizardTitle = "Liquidador Sanidad (CCT 122/75)";
          break;
        case _WizardStep.selectCompany:
          _wizardTitle = "Paso 1: Seleccione Empresa";
          _cargarEmpresas();
          break;
        case _WizardStep.manageCompanies:
          _wizardTitle = "Gestión de Empresas";
          break;
        case _WizardStep.selectEmployee:
          _wizardTitle = "Paso 2: Seleccione Empleado";
          _cargarEmpleados();
          break;
        case _WizardStep.fillData:
          _wizardTitle = "Paso 3: Cargar Novedades y Simular";
          _recalcular();
          break;
      }
    });
  }

  void _goBack() {
    switch (_currentStep) {
      case _WizardStep.manageCompanies:
        _goToStep(_WizardStep.selectCompany);
        break;
      case _WizardStep.selectCompany:
        _goToStep(_WizardStep.welcome);
        break;
      case _WizardStep.selectEmployee:
        _goToStep(_WizardStep.selectCompany);
        break;
      case _WizardStep.fillData:
        if (_empleado != null) {
          _goToStep(_WizardStep.selectEmployee);
        } else if (_empresa != null) {
           _goToStep(_WizardStep.selectEmployee);
        } else {
          _goToStep(_WizardStep.selectCompany);
        }
        break;
      default:
        _goToStep(_WizardStep.welcome);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    _convenio = Provider.of<CctProvider>(context).getConvenio('sanidad-122-75');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDark.withValues(alpha: 0.5),
        elevation: 0,
        leading: (_currentStep != _WizardStep.welcome)
            ? IconButton(icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary), onPressed: _goBack)
            : null,
        title: Text(_wizardTitle, style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
        actions: [
          if (_currentStep != _WizardStep.welcome)
            IconButton(
              icon: const Icon(Icons.settings, color: Colors.tealAccent),
              tooltip: 'Ajustes Locales (Paritarias)',
              onPressed: _handleAbrirMaestro,
            ),
          AppHelp.buildHelpButton(context, 'SanidadInterfaceScreen'),
        ],
      ),
      body: _buildCurrentStep(),
       persistentFooterButtons: _currentStep == _WizardStep.fillData ? _buildFooterButtons() : null,
    );
  }

  List<Widget> _buildFooterButtons() {
    final bool isMasivoDisabled = _exportandoMasivo || _listaEmpleados.isEmpty;
    return [
      Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
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
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: isMasivoDisabled ? null : _exportarLsdMasivo,
                      icon: _exportandoMasivo
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.file_copy, size: 18),
                      label: Text('LSD Todos (${_listaEmpleados.length})'),
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.teal, side: const BorderSide(color: Colors.teal)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: isMasivoDisabled ? null : _generarPackARCA,
                      icon: _exportandoMasivo
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.folder_zip, size: 18),
                      label: const Text('Pack ARCA ZIP'),
                      style: FilledButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
    ];
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case _WizardStep.welcome:
        return _buildWelcomeStep();
      case _WizardStep.selectCompany:
        return _buildSelectCompanyStep();
      case _WizardStep.manageCompanies:
        return _buildManageCompaniesStep();
      case _WizardStep.selectEmployee:
        return _buildSelectEmployeeStep();
      case _WizardStep.fillData:
        return _buildFillDataStep();
    }
  }

  // === PASO 0: BIENVENIDA ===
  Widget _buildWelcomeStep() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text("Asistente de Liquidación de Sanidad", textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: 16),
            Text("Herramienta para liquidar sueldos bajo el CCT 122/75 y otros convenios de Sanidad.", textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: AppColors.textSecondary)),
            const SizedBox(height: 40),
            _buildWelcomeOption(
              icon: Icons.calculate_outlined,
              title: "Liquidar un Nuevo Sueldo",
              subtitle: "Inicie el asistente para liquidar un empleado.",
              onTap: () => _goToStep(_WizardStep.selectCompany),
              isPrimary: true,
            ),
            const SizedBox(height: 16),
             _buildWelcomeOption(
              icon: Icons.settings,
              title: "Editor de Escalas Salariales",
              subtitle: "Ajuste los básicos y adicionales por provincia.",
              onTap: _handleAbrirMaestro,
            ),
            const SizedBox(height: 16),
            _buildWelcomeOption(
              icon: Icons.business_outlined,
              title: "Gestionar mis Empresas",
              subtitle: "Añada, edite o elimine las empresas para las que liquida.",
              onTap: () => _goToStep(_WizardStep.manageCompanies),
            ),
            const SizedBox(height: 16),
            _buildWelcomeOption(
              icon: Icons.document_scanner_outlined,
              title: "Replicar desde un Recibo",
              subtitle: "Use el scanner para pre-cargar datos desde un recibo existente.",
              onTap: _abrirEscanerRecibo,
            ),
             const SizedBox(height: 24),
            _buildBannerSincronizacion(),
          ],
        ),
      ),
    );
  }
  
  Widget _buildWelcomeOption({required IconData icon, required String title, required String subtitle, required VoidCallback onTap, bool isPrimary = false}) {
    return Card(
      elevation: isPrimary ? 6 : 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: isPrimary ? const BorderSide(color: AppColors.primary, width: 1) : BorderSide.none),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              Icon(icon, size: 32, color: isPrimary ? AppColors.primary : AppColors.textSecondary),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: isPrimary ? AppColors.textPrimary : AppColors.textPrimary.withValues(alpha: 0.9))),
                    const SizedBox(height: 4),
                    Text(subtitle, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }

  // === PASO 1: EMPRESAS ===
  Future<void> _cargarEmpresas() async {
    final companies = await SanidadCompanyService.getCompanies();
    if (mounted) {
      setState(() {
        _listaEmpresas = companies.map((e) => SanidadEmpresa.fromMap(e)).toList();
      });
    }
  }

  void _seleccionarEmpresa(SanidadEmpresa empresa) {
    setState(() {
      _empresa = empresa;
      _jurisdiccion = empresa.jurisdiccion ?? Jurisdiccion.buenosAires;
    });
    _goToStep(_WizardStep.selectEmployee);
  }

  Widget _buildSelectCompanyStep() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      children: [
        if (_listaEmpresas.isEmpty)
          Padding(
            padding: const EdgeInsets.all(40.0),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.business_center_outlined, size: 48, color: AppColors.textMuted),
                  const SizedBox(height: 16),
                  const Text("No hay empresas cargadas.", style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Crear la primera'),
                    onPressed: () => _goToStep(_WizardStep.manageCompanies),
                  ),
                ],
              ),
            ),
          ),
        ..._listaEmpresas.map((emp) {
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              title: Text(emp.razonSocial, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text("CUIT: ${emp.cuit}", style: const TextStyle(color: AppColors.textSecondary)),
              onTap: () => _seleccionarEmpresa(emp),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.textMuted),
            ),
          );
        }),
        const SizedBox(height: 24),
        if (_listaEmpresas.isNotEmpty)
          OutlinedButton.icon(
            icon: const Icon(Icons.settings_outlined),
            label: const Text("Gestionar Empresas"),
            onPressed: () => _goToStep(_WizardStep.manageCompanies),
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
          ),
      ],
    );
  }

  Widget _buildManageCompaniesStep() {
    return ListView(
      padding: const EdgeInsets.all(24.0),
      children: [
        _buildCompanyForm(),
        const Divider(height: 40, thickness: 0.5),
        const Text("Empresas Guardadas", style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        if (_listaEmpresas.isEmpty)
          const Center(child: Text("Aún no has añadido ninguna empresa.", style: TextStyle(color: AppColors.textSecondary))),
        ..._listaEmpresas.map((emp) {
            return Card(
              elevation: 1,
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                title: Text(emp.razonSocial),
                subtitle: Text(emp.cuit),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(icon: const Icon(Icons.edit, size: 20, color: AppColors.accentBlue), onPressed: () => _editCompany(emp)),
                    IconButton(icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.accentRed), onPressed: () => _deleteCompany(emp.cuit)),
                  ],
                ),
              ),
            );
        }),
      ],
    );
  }
  
  Widget _buildCompanyForm() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_editingCompany == null ? "Añadir Nueva Empresa" : "Editando Empresa", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: 16),
            TextField(controller: _razonSocialController, decoration: const InputDecoration(labelText: 'Razón Social')),
            TextField(controller: _cuitController, decoration: const InputDecoration(labelText: 'CUIT')),
            TextField(controller: _domicilioController, decoration: const InputDecoration(labelText: 'Domicilio Legal')),
            DropdownButtonFormField<Jurisdiccion>(
              value: _editingCompany?.jurisdiccion ?? Jurisdiccion.buenosAires,
              decoration: const InputDecoration(labelText: 'Jurisdicción'),
              items: Jurisdiccion.values.map((j) => DropdownMenuItem(value: j, child: Text(j.name))).toList(),
              onChanged: (val) {
                if (val != null && _editingCompany != null) {
                  setState(() {
                    _editingCompany = _editingCompany!.copyWith(jurisdiccion: val);
                  });
                }
              },
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (_editingCompany != null) TextButton(child: const Text("Cancelar"), onPressed: _clearCompanyForm),
                const SizedBox(width: 12),
                FilledButton.icon(
                  icon: const Icon(Icons.save),
                  label: Text(_isSaving ? "Guardando..." : "Guardar"),
                  onPressed: _isSaving ? null : _saveCompany,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // === PASO 2: EMPLEADOS ===
  Future<void> _cargarEmpleados() async {
    if (_empresa == null) return;
    final employees = await SanidadEmpleadoService.getEmployees(_empresa!.cuit);
    if (mounted) {
      setState(() {
        _listaEmpleados = employees.map((e) => SanidadEmpleado.fromMap(e)).toList();
      });
    }
  }

  Widget _buildSelectEmployeeStep() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      children: [
        Center(child: Text("Empleados de: ${_empresa?.razonSocial ?? 'N/A'}", style: const TextStyle(color: AppColors.textSecondary, fontSize: 16, fontWeight: FontWeight.bold))),
        const SizedBox(height: 20),
        
        FilledButton.icon(
          icon: const Icon(Icons.person_add_alt_1_outlined),
          label: const Text('Añadir Nuevo Empleado'),
          onPressed: _crearNuevoEmpleado,
          style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
        ),
        const SizedBox(height: 24),

        if (_listaEmpleados.isNotEmpty) ...[
          const Text("O seleccione un legajo existente:", style: TextStyle(color: AppColors.textPrimary)),
          const SizedBox(height: 12),
        ],

        if (_listaEmpleados.isEmpty)
          const Padding(
            padding: EdgeInsets.all(40.0),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline, size: 48, color: AppColors.textMuted),
                  SizedBox(height: 16),
                  Text("No hay legajos guardados para esta empresa.", style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
                ],
              ),
            ),
          ),
          
        ..._listaEmpleados.map((emp) {
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: CircleAvatar(child: Text(emp.nombre.isNotEmpty ? emp.nombre.substring(0, 1) : "-")),
              title: Text(emp.nombre, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text("CUIL: ${emp.cuil}", style: const TextStyle(color: AppColors.textSecondary)),
              onTap: () => _seleccionarEmpleado(emp),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.textMuted),
            ),
          );
        }),
      ],
    );
  }

  // === PASO 3: LIQUIDACIÓN ===
  Widget _buildFillDataStep() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
         _buildSelectorPeriodoYModo(),
         const SizedBox(height: 24),
         _buildDatosEmpleado(),
         const SizedBox(height: 24),
         _buildSimuladorNeto(),
         if (_resultado != null) ...[
           const SizedBox(height: 24),
           _buildDetalleLiquidacion(_resultado!),
         ],
      ],
    );
  }

  Widget _buildDatosEmpleado() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                 Text(_empleado == null ? 'Nuevo Empleado' : 'Editando Empleado', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                 Row(
                   children: [
                     TextButton.icon(
                       onPressed: _saveEmployee,
                       icon: const Icon(Icons.save, size: 18),
                       label: const Text("Guardar Legajo"),
                     ),
                     if (_empleado != null)
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: AppColors.accentRed),
                        onPressed: _deleteEmployee,
                        tooltip: "Eliminar Legajo",
                      ),
                   ],
                 )
              ],
            ),
            const SizedBox(height: 12),
            
            TextField(
              controller: _nombreController,
              decoration: const InputDecoration(labelText: 'Nombre', prefixIcon: Icon(Icons.person_outline)),
            ),
            TextField(
              controller: _cuilController,
              decoration: InputDecoration(
                labelText: 'CUIL',
                prefixIcon: const Icon(Icons.badge_outlined),
                suffixIcon: _cuilController.text.isNotEmpty 
                    ? Icon(
                        ValidacionesARCA.validarCUITCUIL(_cuilController.text) ? Icons.check_circle : Icons.error,
                        color: ValidacionesARCA.validarCUITCUIL(_cuilController.text) ? Colors.green : Colors.red,
                        size: 20,
                      )
                    : null,
              ),
              keyboardType: TextInputType.number,
              maxLength: 13,
            ),
            TextField(
              controller: _puestoController,
              decoration: const InputDecoration(labelText: 'Puesto / Cargo', prefixIcon: Icon(Icons.work_outline)),
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Fecha de ingreso'),
              subtitle: Text(DateFormat('dd/MM/yyyy').format(_fechaIngreso)),
              trailing: const Icon(Icons.edit_calendar),
              onTap: () async {
                final d = await showDatePicker(context: context, initialDate: _fechaIngreso, firstDate: DateTime(1950), lastDate: DateTime.now());
                if (d != null) {
                  setState(() => _fechaIngreso = d);
                  _recalcular();
                }
              },
            ),
            DropdownButtonFormField<CategoriaSanidad>(
              value: _categoria,
              decoration: const InputDecoration(labelText: 'Categoría', prefixIcon: Icon(Icons.work_outline)),
              items: CategoriaSanidad.values.map((e) => DropdownMenuItem(value: e, child: Text(e.name))).toList(), // Simplificado
              onChanged: (v) {
                if (v != null) {
                  setState(() => _categoria = v);
                  _recalcular();
                }
              },
            ),
            DropdownButtonFormField<NivelTituloSanidad>(
              value: _nivelTitulo,
              decoration: const InputDecoration(labelText: 'Nivel de Título', prefixIcon: Icon(Icons.school_outlined)),
              items: NivelTituloSanidad.values.map((e) => DropdownMenuItem(value: e, child: Text(e.name))).toList(),
              onChanged: (v) {
                if (v != null) {
                  setState(() => _nivelTitulo = v);
                  _recalcular();
                }
              },
            ),
            SwitchListTile(title: const Text('Tarea Crítica / Riesgo'), value: _tareaCriticaRiesgo, onChanged: (v) => setState(() { _tareaCriticaRiesgo = v; _recalcular(); })),
            SwitchListTile(title: const Text('Cuota Sindical ATSA'), value: _cuotaSindicalAtsa, onChanged: (v) => setState(() { _cuotaSindicalAtsa = v; _recalcular(); })),
            if (_categoria == CategoriaSanidad.administrativo)
              SwitchListTile(title: const Text('Manejo de Efectivo / Cobranzas'), value: _manejoEfectivoCaja, onChanged: (v) => setState(() { _manejoEfectivoCaja = v; _recalcular(); })),
            
            // --- Secciones Colapsables ---
            const SizedBox(height: 16),
            ExpansionTile(
              title: const Text("Adicionales y Novedades"),
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    children: [
                      TextField(controller: _horasNocturnasController, decoration: const InputDecoration(labelText: 'Horas Nocturnas', prefixIcon: Icon(Icons.nightlight_round)), keyboardType: TextInputType.number),
                      TextField(controller: _horasExtras50Controller, decoration: const InputDecoration(labelText: 'Horas Extras 50%', prefixIcon: Icon(Icons.schedule)), keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                      TextField(controller: _horasExtras100Controller, decoration: const InputDecoration(labelText: 'Horas Extras 100%', prefixIcon: Icon(Icons.nights_stay)), keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                    ],
                  ),
                ),
              ],
            ),
            ExpansionTile(
              title: const Text("Descuentos y Préstamos"),
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    children: [
                       TextField(controller: _adelantosController, decoration: const InputDecoration(labelText: 'Adelantos', prefixIcon: Icon(Icons.payments)), keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                       TextField(controller: _embargosController, decoration: const InputDecoration(labelText: 'Embargos', prefixIcon: Icon(Icons.gavel)), keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                       TextField(controller: _prestamosController, decoration: const InputDecoration(labelText: 'Préstamos / Cuotas', prefixIcon: Icon(Icons.account_balance)), keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                    ],
                  ),
                ),
              ],
            ),
             ExpansionTile(
              title: const Text("Datos para LSD y Bancarios"),
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    children: [
                      TextField(controller: _cbuController, decoration: InputDecoration(labelText: 'CBU', prefixIcon: const Icon(Icons.account_balance_wallet), suffixIcon: _cbuController.text.isNotEmpty ? (ValidacionesARCA.validarCBU(_cbuController.text) ? const Icon(Icons.check_circle, color: Colors.green) : const Icon(Icons.error, color: Colors.red)) : null), keyboardType: TextInputType.number, maxLength: 22),
                      TextField(controller: _domicilioEmpleadoController, decoration: const InputDecoration(labelText: 'Domicilio del Empleado', prefixIcon: Icon(Icons.home))),
                      TextField(controller: _localidadController, decoration: const InputDecoration(labelText: 'Localidad', prefixIcon: Icon(Icons.location_city))),
                      TextField(controller: _codigoPostalController, decoration: const InputDecoration(labelText: 'Código Postal', prefixIcon: Icon(Icons.pin_drop)), keyboardType: TextInputType.number),
                      TextField(controller: _codigoRnosController, decoration: const InputDecoration(labelText: 'Código RNOS (Obra Social)'), keyboardType: TextInputType.number),
                      TextField(controller: _cantidadFamiliaresController, decoration: const InputDecoration(labelText: 'Cantidad de familiares a cargo'), keyboardType: TextInputType.number),
                      DropdownButtonFormField<String>(value: _modalidadContratacion, decoration: const InputDecoration(labelText: 'Modalidad Contratación'), items: const [DropdownMenuItem(value: '008', child: Text('Tiempo Indeterminado')), /* ...otros... */], onChanged: (v) => setState(() => _modalidadContratacion = v ?? '008')),
                      DropdownButtonFormField<String>(value: _situacionRevista, decoration: const InputDecoration(labelText: 'Situación Revista'), items: const [DropdownMenuItem(value: '01', child: Text('Activo')), /* ...otros... */], onChanged: (v) => setState(() => _situacionRevista = v ?? '01')),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

   Widget _buildSimuladorNeto() {
    return Card(
      color: AppColors.pastelBlue.withValues(alpha: 0.15),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Simulador de Sueldo Neto', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            if (_calculando)
              const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator()))
            else if (_resultado != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('\$${_resultado!.netoACobrar.toStringAsFixed(2)}', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                  if (_resultado!.totalBrutoRemunerativo > 0) ...[
                     const SizedBox(height: 8),
                    Text('Bruto: \$${_resultado!.totalBrutoRemunerativo.toStringAsFixed(2)}'),
                    Text('Descuentos: \$${_resultado!.totalDescuentos.toStringAsFixed(2)}'),
                  ]
                ],
              )
            else
              const Text('Complete los datos para simular.'),
          ],
        ),
      ),
    );
  }

  Widget _buildDetalleLiquidacion(LiquidacionSanidadResult r) {
     return ExpansionTile(
      title: const Text('Detalle de la Liquidación'),
      initiallyExpanded: true,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _row('Sueldo básico', r.sueldoBasico),
              if (r.adicionalAntiguedad > 0) _row('Antigüedad', r.adicionalAntiguedad),
              if (r.adicionalTitulo > 0) _row('Adicional Título', r.adicionalTitulo),
              if (r.adicionalTareaCriticaRiesgo > 0) _row('Tarea Crítica/Riesgo', r.adicionalTareaCriticaRiesgo),
              if (r.adicionalZonaPatagonica > 0) _row('Plus Zona Patagónica', r.adicionalZonaPatagonica),
              if (r.nocturnidad > 0) _row('Horas Nocturnas', r.nocturnidad),
              if (r.falloCaja > 0) _row('Fallo de Caja', r.falloCaja),
              if (r.totalHorasExtras > 0) _row('Horas Extras', r.totalHorasExtras),
              const Divider(),
              _row('Total Bruto', r.totalBrutoRemunerativo, bold: true),
              const SizedBox(height: 12),
              _row('Jubilación (11%)', -r.aporteJubilacion, isDiscount: true),
              _row('Ley 19.032 (3%)', -r.aporteLey19032, isDiscount: true),
              _row('Obra Social (3%)', -r.aporteObraSocial, isDiscount: true),
              if (r.cuotaSindicalAtsa > 0) _row('Cuota Sindical ATSA (2%)', -r.cuotaSindicalAtsa, isDiscount: true),
              if (r.totalDescuentosAdicionales > 0) _row('Otros Descuentos', -r.totalDescuentosAdicionales, isDiscount: true),
              const Divider(),
              _row('Total Descuentos', -r.totalDescuentos, bold: true, isDiscount: true),
              const SizedBox(height: 12),
              _row('NETO A COBRAR', r.netoACobrar, bold: true),
            ],
          ),
        ),
      ],
    );
  }

  Widget _row(String label, double value, {bool bold = false, bool isDiscount = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
          Text('\$${value.abs().toStringAsFixed(2)}', style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal, color: isDiscount ? Colors.red : null)),
        ],
      ),
    );
  }

  // === AUXILIARES DE UI ===
  Widget _buildBannerSincronizacion() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.amber.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.amber.withValues(alpha: 0.3))),
      child: Row(
        children: [
          const Icon(Icons.sync, color: Colors.amber),
          const SizedBox(width: 12),
          const Expanded(child: Text("Las paritarias se sincronizan automáticamente con la nube.", style: TextStyle(fontSize: 12))),
          TextButton(onPressed: _cargarParitarias, child: const Text("Sincronizar")),
        ],
      ),
    );
  }

  Widget _buildSelectorPeriodoYModo() {
    return Row(
      children: [
        Expanded(
          child: ListTile(
            title: const Text('Período'),
            subtitle: Text(DateFormat('MMMM yyyy').format(_periodoSeleccionado)),
            onTap: () async {
              // Selector de mes/año simplificado
              final d = await showDatePicker(context: context, initialDate: _periodoSeleccionado, firstDate: DateTime(2020), lastDate: DateTime(2100));
              if (d != null) {
                setState(() => _periodoSeleccionado = d);
                _recalcular();
              }
            },
          ),
        ),
        Expanded(
          child: DropdownButtonFormField<ModoLiquidacionSanidad>(
            value: _modoLiquidacion,
            items: const [
              DropdownMenuItem(value: ModoLiquidacionSanidad.mensual, child: Text('Mensual')),
              DropdownMenuItem(value: ModoLiquidacionSanidad.quincenal1, child: Text('1era Quincena')),
              DropdownMenuItem(value: ModoLiquidacionSanidad.quincenal2, child: Text('2da Quincena')),
              DropdownMenuItem(value: ModoLiquidacionSanidad.finalDirecta, child: Text('Final')),
            ],
            onChanged: (v) {
              if (v != null) {
                setState(() => _modoLiquidacion = v);
                _recalcular();
              }
            },
          ),
        ),
      ],
    );
  }

  // === LÓGICA DE NEGOCIO ===
  Future<void> _cargarParitarias() async {
    setState(() => _maestroLoading = true);
    try {
      final paritarias = await SanidadParitariasService.getParitarias();
      if (mounted) {
        setState(() {
          _paritariasMaestras = paritarias;
          _maestroLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _maestroLoading = false);
    }
  }

  void _recalcular() {
    if (_calculando) return;
    setState(() => _calculando = true);
    
    // Simular retraso para UX
    Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      
      final input = SanidadEmpleadoInput(
        nombre: _nombreController.text,
        cuil: _cuilController.text,
        fechaIngreso: _fechaIngreso,
        categoria: _categoria,
        nivelTitulo: _nivelTitulo,
        jurisdiccion: _jurisdiccion,
        tareaCriticaRiesgo: _tareaCriticaRiesgo,
        cuotaSindicalAtsa: _cuotaSindicalAtsa,
        manejoEfectivoCaja: _manejoEfectivoCaja,
        horasNocturnas: int.tryParse(_horasNocturnasController.text) ?? 0,
        horasExtras50: double.tryParse(_horasExtras50Controller.text) ?? 0,
        horasExtras100: double.tryParse(_horasExtras100Controller.text) ?? 0,
        adelantos: double.tryParse(_adelantosController.text) ?? 0,
        embargos: double.tryParse(_embargosController.text) ?? 0,
        prestamos: double.tryParse(_prestamosController.text) ?? 0,
        mejorRemuneracionSemestral: double.tryParse(_mejorRemuneracionController.text),
        diasSAC: int.tryParse(_diasSACController.text) ?? 180,
        diasVacaciones: int.tryParse(_diasVacacionesController.text) ?? 14,
        codigoRnos: _codigoRnosController.text,
      );

      final res = SanidadOmniEngine.liquidar(input, _paritariasMaestras, _periodoSeleccionado, _modoLiquidacion);
      
      setState(() {
        _resultado = res;
        _calculando = false;
      });
    });
  }

  void _editCompany(SanidadEmpresa emp) {
    setState(() {
      _editingCompany = emp;
      _razonSocialController.text = emp.razonSocial;
      _cuitController.text = emp.cuit;
      _domicilioController.text = emp.domicilio ?? '';
    });
  }

  Future<void> _saveCompany() async {
    if (_razonSocialController.text.isEmpty || _cuitController.text.isEmpty) return;
    setState(() => _isSaving = true);
    
    final companyData = {
      'razonSocial': _razonSocialController.text,
      'cuit': _cuitController.text,
      'domicilio': _domicilioController.text,
      'jurisdiccion': (_editingCompany?.jurisdiccion ?? Jurisdiccion.buenosAires).name,
    };

    if (_editingCompany == null) {
      await SanidadCompanyService.saveCompany(companyData);
    } else {
      await SanidadCompanyService.updateCompany(_editingCompany!.cuit, companyData);
    }

    await _cargarEmpresas();
    _clearCompanyForm();
    setState(() => _isSaving = false);
  }

  Future<void> _deleteCompany(String cuit) async {
    await SanidadCompanyService.deleteCompany(cuit);
    await _cargarEmpresas();
  }

  void _clearCompanyForm() {
    setState(() {
      _editingCompany = null;
      _razonSocialController.clear();
      _cuitController.clear();
      _domicilioController.clear();
    });
  }

  void _seleccionarEmpleado(SanidadEmpleado emp) {
    setState(() {
      _empleado = emp;
      _nombreController.text = emp.nombre;
      _cuilController.text = emp.cuil;
      _puestoController.text = emp.puesto ?? '';
      _fechaIngreso = emp.fechaIngreso;
      _categoria = emp.categoria;
      _nivelTitulo = emp.nivelTitulo;
      _tareaCriticaRiesgo = emp.tareaCriticaRiesgo;
      _cuotaSindicalAtsa = emp.cuotaSindicalAtsa;
      _manejoEfectivoCaja = emp.manejoEfectivoCaja;
      _horasNocturnasController.text = emp.horasNocturnas.toString();
      _codigoRnosController.text = emp.codigoRnos ?? '';
      _cantidadFamiliaresController.text = emp.cantidadFamiliares.toString();
      _cbuController.text = emp.cbu ?? '';
      _domicilioEmpleadoController.text = emp.domicilio ?? '';
      _localidadController.text = emp.localidad ?? '';
      _codigoPostalController.text = emp.codigoPostal ?? '';
      _modalidadContratacion = emp.codigoModalidad ?? '008';
      _situacionRevista = emp.codigoSituacion ?? '01';
    });
    _goToStep(_WizardStep.fillData);
  }

  void _crearNuevoEmpleado() {
    setState(() {
      _empleado = null;
      _nombreController.clear();
      _cuilController.clear();
      _puestoController.clear();
      _fechaIngreso = DateTime.now().subtract(const Duration(days: 365));
      _categoria = CategoriaSanidad.servicios;
      _nivelTitulo = NivelTituloSanidad.sinTitulo;
      _tareaCriticaRiesgo = false;
      _cuotaSindicalAtsa = false;
      _manejoEfectivoCaja = false;
      _horasNocturnasController.text = '0';
      _codigoRnosController.clear();
      _cantidadFamiliaresController.text = '0';
      _cbuController.clear();
      _domicilioEmpleadoController.clear();
      _localidadController.clear();
      _codigoPostalController.clear();
    });
    _goToStep(_WizardStep.fillData);
  }

  Future<void> _saveEmployee() async {
    if (_empresa == null || _nombreController.text.isEmpty || _cuilController.text.isEmpty) return;
    
    final employeeData = SanidadEmpleado(
      cuil: _cuilController.text,
      nombre: _nombreController.text,
      puesto: _puestoController.text,
      fechaIngreso: _fechaIngreso,
      categoria: _categoria,
      nivelTitulo: _nivelTitulo,
      tareaCriticaRiesgo: _tareaCriticaRiesgo,
      cuotaSindicalAtsa: _cuotaSindicalAtsa,
      manejoEfectivoCaja: _manejoEfectivoCaja,
      horasNocturnas: int.tryParse(_horasNocturnasController.text) ?? 0,
      codigoRnos: _codigoRnosController.text,
      cantidadFamiliares: int.tryParse(_cantidadFamiliaresController.text) ?? 0,
      cbu: _cbuController.text,
      domicilio: _domicilioEmpleadoController.text,
      localidad: _localidadController.text,
      codigoPostal: _codigoPostalController.text,
      codigoModalidad: _modalidadContratacion,
      codigoSituacion: _situacionRevista,
    ).toMap();

    if (_empleado == null) {
      await SanidadEmpleadoService.saveEmployee(_empresa!.cuit, employeeData);
    } else {
      await SanidadEmpleadoService.updateEmployee(_empresa!.cuit, _empleado!.cuil, employeeData);
    }

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Legajo guardado correctamente'), backgroundColor: Colors.green));
    await _cargarEmpleados();
  }

  Future<void> _deleteEmployee() async {
    if (_empresa == null || _empleado == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("¿Eliminar Legajo?"),
        content: Text("Se borrará a ${_empleado!.nombre} de forma permanente."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancelar")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Eliminar", style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) {
      await SanidadEmpleadoService.deleteEmployee(_empresa!.cuit, _empleado!.cuil);
      await _cargarEmpleados();
      _crearNuevoEmpleado();
      _goToStep(_WizardStep.selectEmployee);
    }
  }

  // === EXPORTACIONES ===
  Future<void> _exportarLsd() async {
    if (_resultado == null || _empresa == null) return;
    try {
      final txt = await sanidadToLsdTxt(
        liquidacion: _resultado!,
        cuitEmpresa: _empresa!.cuit,
        razonSocial: _empresa!.razonSocial,
        domicilio: _empresa!.domicilio ?? '',
      );
      final nombreArchivo = 'lsd_sanidad_${_resultado!.input.cuil}_${DateFormat('yyyyMM').format(_periodoSeleccionado)}.txt';
      await saveFile(fileName: nombreArchivo, bytes: latin1.encode(txt), mimeType: 'text/plain');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('LSD generado: $nombreArchivo'), backgroundColor: Colors.green));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al exportar LSD: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _generarRecibo() async {
     if (_resultado == null || _empresa == null) return;
    try {
      final path = await _pdfService.generarReciboPdf(
        liquidacion: _resultado!,
        empresaData: {
          'cuit': _empresa!.cuit,
          'razonSocial': _empresa!.razonSocial,
          'domicilio': _empresa!.domicilio ?? '',
        },
        empleadoData: {
          'nombre': _resultado!.input.nombre,
          'cuil': _resultado!.input.cuil,
          'categoriaId': _resultado!.input.categoria.name,
          'sueldoBasico': _resultado!.sueldoBasico,
          'periodo': _resultado!.periodo,
          'fechaPago': _resultado!.fechaPago,
          'fechaIngreso': _resultado!.input.fechaIngreso.toIso8601String(),
          'codigoRnos': _resultado!.input.codigoRnos,
        },
      );
      if (path != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Recibo generado: $path'), backgroundColor: Colors.green));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al generar PDF: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _exportarLsdMasivo() async {
     // Implementación pendiente o delegada a servicio
  }

  Future<void> _generarPackARCA() async {
     // Implementación pendiente o delegada a servicio
  }

  void _handleAbrirMaestro() {
    // Implementar navegación a editor de paritarias
  }

  void _abrirEscanerRecibo() {
    Navigator.push(context, MaterialPageRoute(builder: (ctx) => const SanidadReceiptScanScreen())).then((res) {
      if (res is OcrConfirmResult) {
        _goToStep(_WizardStep.fillData);
        _prefillFromOcr(res);
      }
    });
  }

  void _prefillFromOcr(OcrConfirmResult res) {
    // Lógica para llenar campos desde OCR
  }
}