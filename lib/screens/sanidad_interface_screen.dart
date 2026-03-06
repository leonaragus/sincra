// --- Pantalla de Liquidación de Sanidad (CCT 122/75 y otros) - ARCA 2026 ---
// Arquitectura rediseñada a un "Asistente Guiado" para mejorar el flujo de trabajo.
// v3.1 - Implementación de Exportación Masiva y validaciones de neto.

import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/cct_model.dart';
import '../models/sanidad_empleado_model.dart';
import '../models/sanidad_empresa_model.dart';
import '../models/sanidad_liquidacion_model.dart';
import '../models/ocr_confirm_result.dart';
import '../models/teacher_types.dart'; // Para Jurisdiccion

import '../services/sanidad_engine.dart';
import '../services/sanidad_company_service.dart';
import '../services/sanidad_empleado_service.dart';
import '../services/lsd_mapping_service.dart';
import '../services/sanidad_lsd_export.dart';
import '../services/contabilidad_service.dart';
import '../services/sanidad_pdf_recibo.dart';
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

enum _WizardStep { welcome, selectCompany, manageCompanies, selectEmployee, fillData }

class SanidadInterfaceScreen extends StatefulWidget {
  final SanidadEmpresa? initialEmpresa;
  final OcrConfirmResult? initialOcrResult;

  const SanidadInterfaceScreen({super.key, this.initialEmpresa, this.initialOcrResult});

  @override
  State<SanidadInterfaceScreen> createState() => _SanidadInterfaceScreenState();
}

class _SanidadInterfaceScreenState extends State<SanidadInterfaceScreen> {
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
        backgroundColor: AppColors.backgroundDark.withOpacity(0.5),
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
                    Text(title, style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: isPrimary ? AppColors.textPrimary : AppColors.textPrimary.withOpacity(0.9))),
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
        _listaEmpresas = companies;
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
                        ValidacionesARCA.validarCuil(_cuilController.text) ? Icons.check_circle : Icons.error,
                        color: ValidacionesARCA.validarCuil(_cuilController.text) ? Colors.green : Colors.red,
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
                  ),)
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
                  ),)
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
                  ),)
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
          Text('\$${value.toStringAsFixed(2)}', style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal, color: isDiscount ? AppColors.accentRed : AppColors.textPrimary)),
        ],
      ),
    );
  }

  Widget _buildSelectorPeriodoYModo() {
      return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Período y Tipo de Liquidación', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Período'),
                    subtitle: Text(DateFormat('MMMM yyyy', 'es_AR').format(_periodoSeleccionado), style: const TextStyle(fontWeight: FontWeight.bold)),
                    trailing: const Icon(Icons.edit_calendar), 
                    onTap: () async {
                      final picked = await showDatePicker(context: context, initialDate: _periodoSeleccionado, firstDate: DateTime(2020), lastDate: DateTime(2030), initialDatePickerMode: DatePickerMode.year);
                      if (picked != null) {
                        setState(() => _periodoSeleccionado = DateTime(picked.year, picked.month, 1));
                        _recalcular();
                      }
                    },
                  ),
                ),
                Expanded(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Fecha de Pago'),
                    subtitle: Text(DateFormat('dd/MM/yyyy').format(_fechaPago), style: const TextStyle(fontWeight: FontWeight.bold)),
                     trailing: const Icon(Icons.today),
                    onTap: () async {
                      final picked = await showDatePicker(context: context, initialDate: _fechaPago, firstDate: DateTime(2020), lastDate: DateTime(2030));
                      if (picked != null) {
                        setState(() => _fechaPago = picked);
                        _recalcular();
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<ModoLiquidacionSanidad>(
              value: _modoLiquidacion,
              decoration: const InputDecoration(labelText: 'Tipo de Liquidación'),
              items: ModoLiquidacionSanidad.values.map((e) => DropdownMenuItem(value: e, child: Text(e.name))).toList(),
              onChanged: (v) {
                if (v != null) {
                  setState(() => _modoLiquidacion = v);
                  _recalcular();
                }
              },
            ),
             if (_modoLiquidacion == ModoLiquidacionSanidad.liquidacionFinal) _buildCamposLiquidacionFinal(),
          ],
        ),
      ),
    );
  }

  Widget _buildCamposLiquidacionFinal() {
     return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Opciones de Liquidación Final", style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.accentRed)),
          ListTile(
              title: const Text('Fecha de Egreso'),
              subtitle: Text(_fechaEgreso != null ? DateFormat('dd/MM/yyyy').format(_fechaEgreso!) : 'Sin definir'),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final picked = await showDatePicker(context: context, initialDate: _fechaEgreso ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2030));
                if (picked != null) {
                  setState(() => _fechaEgreso = picked);
                  _recalcular();
                }
              },
            ),
            DropdownButtonFormField<String>(
              value: _motivoEgreso,
              decoration: const InputDecoration(labelText: 'Motivo de Egreso'),
              items: const [
                  DropdownMenuItem(value: 'renuncia', child: Text('Renuncia')),
                  DropdownMenuItem(value: 'despidoSinCausa', child: Text('Despido Sin Causa')),
                  DropdownMenuItem(value: 'despidoConCausa', child: Text('Despido Con Causa')),
              ],
               onChanged: (v) {
                  if (v != null) {
                    setState(() => _motivoEgreso = v);
                    _recalcular();
                  }
                },
            ),
            if (_motivoEgreso == 'despidoSinCausa') ...[
              SwitchListTile(title: const Text('Incluir Preaviso'), value: _incluyePreaviso, onChanged: (v) => setState(() { _incluyePreaviso = v; _recalcular();})),
              SwitchListTile(title: const Text('Incluir Integración Mes'), value: _incluyeIntegracionMes, onChanged: (v) => setState(() { _incluyeIntegracionMes = v; _recalcular();})),
            ],
            TextField(controller: _mejorRemuneracionController, decoration: const InputDecoration(labelText: 'Mejor Remuneración (para Indemnización)'), keyboardType: const TextInputType.numberWithOptions(decimal: true)),
        ],
      ),
    );
  }

  // === LÓGICA DE EMPRESAS Y EMPLEADOS ===

  void _editCompany(SanidadEmpresa emp) {
    setState(() {
      _editingCompany = emp;
      _razonSocialController.text = emp.razonSocial;
      _cuitController.text = emp.cuit;
      _domicilioController.text = emp.domicilio ?? '';
    });
  }

  void _clearCompanyForm() {
    setState(() {
      _editingCompany = null;
      _razonSocialController.clear();
      _cuitController.clear();
      _domicilioController.clear();
    });
  }

  Future<void> _saveCompany() async {
    final cuit = _cuitController.text.replaceAll(RegExp(r'[\D]'), '');
    if (cuit.length != 11 || _razonSocialController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('CUIT (11 dígitos) y Razón Social son obligatorios.'), backgroundColor: Colors.red));
      return;
    }
    setState(() => _isSaving = true);
    
    final empresa = SanidadEmpresa(
      cuit: cuit,
      razonSocial: _razonSocialController.text,
      domicilio: _domicilioController.text,
      cctId: 'sanidad-122-75',
      actividad: 'Servicios de Salud',
      jurisdiccion: _editingCompany?.jurisdiccion ?? Jurisdiccion.buenosAires
    );

    try {
      await SanidadCompanyService.saveCompany(empresa);
      _clearCompanyForm();
      await _cargarEmpresas();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Empresa guardada con éxito.'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al guardar: $e'), backgroundColor: Colors.red));
    }
    if (mounted) setState(() => _isSaving = false);
  }

  Future<void> _deleteCompany(String cuit) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Confirmar Eliminación'),
        content: const Text('¿Está seguro que desea eliminar esta empresa y todos sus empleados asociados? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(child: const Text('Cancelar'), onPressed: () => Navigator.pop(c, false)),
          FilledButton(child: const Text('Eliminar'), onPressed: () => Navigator.pop(c, true), style: FilledButton.styleFrom(backgroundColor: Colors.red)),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await SanidadCompanyService.removeCompany(cuit);
      await _cargarEmpresas();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Empresa eliminada.'), backgroundColor: Colors.orange));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al eliminar: $e'), backgroundColor: Colors.red));
    }
  }
  
  Future<void> _cargarEmpleados() async {
    if (_empresa == null) return;
    final empleados = await SanidadEmpleadoService.getEmpleados(_empresa!.cuit);
    if(mounted) {
      setState(() {
        _listaEmpleados = empleados;
      });
    }
  }

  void _seleccionarEmpleado(SanidadEmpleado empleado) {
    _prefillFromEmpleado(empleado);
    _goToStep(_WizardStep.fillData);
  }

  void _crearNuevoEmpleado() {
    _clearEmployeeForm();
    _goToStep(_WizardStep.fillData);
  }

  void _prefillFromEmpleado(SanidadEmpleado emp) {
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
      _localidadController.text = emp.localidad ?? '';
      _codigoPostalController.text = emp.codigoPostal ?? '';
      _domicilioEmpleadoController.text = emp.domicilio ?? '';
      _modalidadContratacion = emp.codigoModalidad ?? '008';
      _situacionRevista = emp.codigoSituacion ?? '01';
    });
  }

  void _clearEmployeeForm() {
    setState(() {
      _empleado = null;
      _nombreController.clear();
      _cuilController.clear();
      _puestoController.clear();
      _codigoRnosController.clear();
      _cbuController.clear();
      _localidadController.clear();
      _codigoPostalController.clear();
      _domicilioEmpleadoController.clear();
      _cantidadFamiliaresController.text = '0';
      _horasNocturnasController.text = '0';
      _adelantosController.text = '0';
      _embargosController.text = '0';
      _prestamosController.text = '0';
      _horasExtras50Controller.text = '0';
      _horasExtras100Controller.text = '0';
      _mejorRemuneracionController.clear();
      _diasSACController.text = '180';
      _diasVacacionesController.text = '14';
      _fechaIngreso = DateTime.now().subtract(const Duration(days: 365 * 5));
      _categoria = CategoriaSanidad.profesional;
      _nivelTitulo = NivelTituloSanidad.sinTitulo;
      _tareaCriticaRiesgo = false;
      _cuotaSindicalAtsa = false;
      _manejoEfectivoCaja = false;
      _modalidadContratacion = '008';
      _situacionRevista = '01';
      _fechaEgreso = null;
      _motivoEgreso = 'renuncia';
      _incluyePreaviso = false;
      _incluyeIntegracionMes = false;
    });
  }

  Future<void> _saveEmployee() async {
    if (_empresa == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No hay una empresa seleccionada.'), backgroundColor: Colors.orange));
      return;
    }
    final cuil = _cuilController.text.replaceAll(RegExp(r'[\D]'), '');
    if (!ValidacionesARCA.validarCuil(cuil) || _nombreController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('CUIL válido y Nombre son obligatorios.'), backgroundColor: Colors.red));
      return;
    }

    final empleado = SanidadEmpleado(
      cuit: cuil,
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
    );

    await SanidadEmpleadoService.saveEmpleado(_empresa!.cuit, empleado);
    setState(() => _empleado = empleado);
    await _cargarEmpleados(); // Recargar la lista
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Legajo guardado con éxito.'), backgroundColor: Colors.green));
  }

  Future<void> _deleteEmployee() async {
    if (_empresa == null || _empleado == null) return;

     final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Confirmar Eliminación'),
        content: const Text('¿Está seguro que desea eliminar este legajo?'),
        actions: [
          TextButton(child: const Text('Cancelar'), onPressed: () => Navigator.pop(c, false)),
          FilledButton(child: const Text('Eliminar'), onPressed: () => Navigator.pop(c, true), style: FilledButton.styleFrom(backgroundColor: Colors.red)),
        ],
      ),
    );
    if (confirm != true) return;

    await SanidadEmpleadoService.removeEmpleado(_empresa!.cuit, _empleado!.cuit);
    _clearEmployeeForm();
    await _cargarEmpleados(); // Recargar la lista
    _goToStep(_WizardStep.selectEmployee);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Legajo eliminado.'), backgroundColor: Colors.orange));
  }

  void _prefillFromOcr(OcrConfirmResult ocrResult) {
      // Implementar la lógica para precargar el formulario desde el resultado del OCR
  }

  // === LÓGICA DE CÁLCULO Y EXPORTACIÓN ===
  void _recalcular() {
    if (!mounted || _nombreController.text.trim().isEmpty || !ValidacionesARCA.validarCuil(_cuilController.text)) {
      setState(() => _resultado = null);
      return;
    }
    setState(() => _calculando = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      
      final i = SanidadEmpleadoInput(
        nombre: _nombreController.text.trim(),
        cuil: _cuilController.text.trim(),
        fechaIngreso: _fechaIngreso,
        categoria: _categoria,
        nivelTitulo: _nivelTitulo,
        tareaCriticaRiesgo: _tareaCriticaRiesgo,
        aplicarCuotaSindicalAtsa: _cuotaSindicalAtsa,
        codigoRnos: _codigoRnosController.text.trim().isEmpty ? null : _codigoRnosController.text.trim(),
        cantidadFamiliares: int.tryParse(_cantidadFamiliaresController.text) ?? 0,
        horasNocturnas: int.tryParse(_horasNocturnasController.text) ?? 0,
        manejoEfectivoCaja: _manejoEfectivoCaja,
        cbu: _cbuController.text.trim(),
        localidad: _localidadController.text.trim(),
        codigoPostal: _codigoPostalController.text.trim(),
        domicilioEmpleado: _domicilioEmpleadoController.text.trim(),
        codigoModalidad: _modalidadContratacion,
        codigoSituacion: _situacionRevista,
        horasExtras50: double.tryParse(_horasExtras50Controller.text) ?? 0,
        horasExtras100: double.tryParse(_horasExtras100Controller.text) ?? 0,
        adelantos: double.tryParse(_adelantosController.text) ?? 0,
        embargos: double.tryParse(_embargosController.text) ?? 0,
        prestamos: double.tryParse(_prestamosController.text) ?? 0,
        fechaEgreso: _modoLiquidacion == ModoLiquidacionSanidad.liquidacionFinal ? _fechaEgreso : null,
        motivoEgreso: _modoLiquidacion == ModoLiquidacionSanidad.liquidacionFinal ? _motivoEgreso : null,
        mejorRemuneracion: _mejorRemuneracionController.text.isNotEmpty ? double.tryParse(_mejorRemuneracionController.text) : null,
        diasSACProporcional: int.tryParse(_diasSACController.text),
        diasVacacionesNoGozadas: int.tryParse(_diasVacacionesController.text),
        incluyePreaviso: _incluyePreaviso,
        incluyeIntegracionMes: _incluyeIntegracionMes,
      );
      final r = SanidadOmniEngine.liquidar(i, periodo: DateFormat('MMMM yyyy', 'es_AR').format(_periodoSeleccionado), fechaPago: DateFormat('dd/MM/yyyy').format(_fechaPago), esZonaPatagonica: _esZonaPatagonica, jurisdiccion: _jurisdiccion.name, modo: _modoLiquidacion);
      
      if (!mounted) return;
      setState(() {
        _resultado = r;
        _calculando = false;
      });

      if (r != null && r.netoACobrar < 0) {
        // Usar un post frame callback para asegurar que el build está completo
        WidgetsBinding.instance.addPostFrameCallback((_) {
            if(mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Atención: El neto a cobrar es negativo.'),
                    backgroundColor: Colors.orange,
                ));
            }
        });
      }
      
      // TODO: Migrar validaciones de topes de embargos según legislación.
    });
  }

  Future<void> _generarRecibo() async {
     if (_resultado == null || _empresa == null) return;
    try {
      final bytes = await SanidadPdfRecibo.generarRecibo(_resultado!, _empresa!);
      final nombreArchivo = 'recibo_sanidad_${_empleado?.cuit ?? 'empleado'}.pdf';
      await saveFile(fileName: nombreArchivo, bytes: bytes, mimeType: 'application/pdf');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Recibo generado: $nombreArchivo'), backgroundColor: Colors.green));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al generar PDF: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _exportarLsd() async {
    if (_resultado == null || _empresa == null) return;
    try {
      final txt = await sanidadOmniToLsdTxt(liquidacion: _resultado!, cuitEmpresa: _empresa!.cuit, razonSocial: _empresa!.razonSocial, domicilio: _empresa!.domicilio ?? '');
      final name = 'LSD_Sanidad_${_resultado!.input.nombre.replaceAll(RegExp(r'[^\w]'), '_')}.txt';
      await saveTextFile(fileName: name, content: txt, mimeType: 'text/plain');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('LSD Exportado: $name'), backgroundColor: Colors.green));
    } catch (e) {
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al exportar LSD: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _exportarLsdMasivo() async {
    if (_empresa == null || _listaEmpleados.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No hay empresa o empleados para exportar.'), backgroundColor: Colors.orange));
      return;
    }

    setState(() => _exportandoMasivo = true);

    try {
      final lsdCompleto = StringBuffer();
      int empleadosProcesados = 0;
      
      // La exportación masiva se hace sobre el MODO y PERIODO seleccionado en la UI
      // pero sin novedades individuales (extras, adelantos, etc. van en cero)
      // ya que no hay UI para cargarlas masivamente.
      if (_modoLiquidacion != ModoLiquidacionSanidad.mensual && _modoLiquidacion != ModoLiquidacionSanidad.sac) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('La exportación masiva solo está disponible para liquidación Mensual o SAC.'), backgroundColor: Colors.orange));
          return;
      }

      for (final empleado in _listaEmpleados) {
        final input = SanidadEmpleadoInput(
          nombre: empleado.nombre,
          cuil: empleado.cuil,
          fechaIngreso: empleado.fechaIngreso,
          categoria: empleado.categoria,
          nivelTitulo: empleado.nivelTitulo,
          tareaCriticaRiesgo: empleado.tareaCriticaRiesgo,
          aplicarCuotaSindicalAtsa: empleado.cuotaSindicalAtsa,
          codigoRnos: empleado.codigoRnos,
          cantidadFamiliares: empleado.cantidadFamiliares,
          horasNocturnas: empleado.horasNocturnas,
          manejoEfectivoCaja: empleado.manejoEfectivoCaja,
          cbu: empleado.cbu,
          localidad: empleado.localidad,
          codigoPostal: empleado.codigoPostal,
          domicilioEmpleado: empleado.domicilio,
          codigoModalidad: empleado.codigoModalidad,
          codigoSituacion: empleado.codigoSituacion,
          horasExtras50: 0, horasExtras100: 0, adelantos: 0, embargos: 0, prestamos: 0,
        );

        final resultado = SanidadOmniEngine.liquidar(
          input,
          periodo: DateFormat('MMMM yyyy', 'es_AR').format(_periodoSeleccionado),
          fechaPago: DateFormat('dd/MM/yyyy').format(_fechaPago),
          esZonaPatagonica: _esZonaPatagonica,
          jurisdiccion: _jurisdiccion.name,
          modo: _modoLiquidacion,
        );

        if (resultado != null) {
          final txt = await sanidadOmniToLsdTxt(
            liquidacion: resultado,
            cuitEmpresa: _empresa!.cuit,
            razonSocial: _empresa!.razonSocial,
            domicilio: _empresa!.domicilio ?? '',
          );
          // Aseguramos que cada registro termine con un salto de línea
          lsdCompleto.writeln(txt.trim());
          empleadosProcesados++;
        }
      }

      if (lsdCompleto.isEmpty) {
        throw Exception('No se pudo generar la liquidación para ningún empleado.');
      }
      
      final nombreArchivo = 'LSD_Masivo_Sanidad_${_empresa!.cuit}_${DateFormat('yyyyMM').format(_periodoSeleccionado)}.txt';
      await saveTextFile(fileName: nombreArchivo, content: lsdCompleto.toString(), mimeType: 'text/plain');
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('LSD Masivo para $empleadosProcesados empleados exportado: $nombreArchivo'), backgroundColor: Colors.green));

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error en exportación masiva: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) {
        setState(() => _exportandoMasivo = false);
      }
    }
  }

  Future<void> _generarPackARCA() async {
     setState(() => _exportandoMasivo = true);
     try {
        ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Esta función para generar el ZIP aún no está implementada. Se exportará el LSD Masivo en su lugar.'),
          backgroundColor: Colors.blueAccent,
        ),
      );
      // Como fallback, mientras no haya ZIP, llamamos a la exportación masiva de LSD.
      await _exportarLsdMasivo();

      // TODO: Implementar la generación de múltiples PDFs y su compresión en un archivo ZIP.
      // Esto requerirá una librería para manejar archivos ZIP, como `archive`.
      // 1. Iterar sobre _listaEmpleados.
      // 2. Para cada uno, generar el resultado de liquidación.
      // 3. Generar el PDF del recibo usando SanidadPdfRecibo.generarRecibo.
      // 4. Añadir cada PDF a un archivo ZIP en memoria.
      // 5. Generar el LSD masivo como en `_exportarLsdMasivo` y añadirlo al ZIP.
      // 6. Guardar el archivo ZIP resultante.

     } finally {
        if (mounted) {
            setState(() => _exportandoMasivo = false);
        }
     }
  }

  // === Stubs y funciones migradas ===
  Future<void> _abrirEscanerRecibo() async { 
     final OcrConfirmResult? result = await Navigator.push(context, MaterialPageRoute(builder: (c) => const SanidadReceiptScanScreen()));
     if (result != null) {
       _clearEmployeeForm();
       _prefillFromOcr(result);
       _goToStep(_WizardStep.fillData);
     }
  }
  
  Future<void> _cargarParitarias() async {
    setState(() => _maestroLoading = true);
    try {
      final res = await SanidadParitariasService.sincronizarParitarias();
      if (mounted) {
        setState(() {
          final list = res['data'] as List?;
          if (list != null) {
            _paritariasMaestras = list.map((e) => ParitariaSanidad.fromMap(e as Map<String, dynamic>)).toList();
          }
          _ultimaSincronizacion = res['fecha'] as DateTime?;
          _modoSincronizacion = res['modo']?.toString() ?? '';
          _maestroLoading = false;
        });
        await SanidadOmniEngine.loadParitariasCache();
      }
    } catch (e) {
      if (mounted) setState(() => _maestroLoading = false);
    }
  }
  
  Future<void> _handleAbrirMaestro() async {
    setState(() => _maestroLoading = true);
    try {
      await _cargarParitarias();
      if (mounted) _mostrarModalMaestroSanidad();
    } finally {
      if (mounted) setState(() => _maestroLoading = false);
    }
  }

  void _mostrarModalMaestroSanidad() {
    // Lógica original para mostrar el diálogo de edición de paritarias
  }

  Widget _buildBannerSincronizacion() {
    // Lógica original del banner de sincronización
    return const SizedBox.shrink(); 
  }
}
