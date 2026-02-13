// Sanidad Interface - Liquidación FATSA CCT 122/75 y 108/75
// Estructura Omni: listado Instituciones (estilo Empresa), Datos Empleado, Simulador Neto, Export LSD
// Sistema FEDERAL con 24 jurisdicciones - Escalas dinámicas editables
// ARCA 2026: Exportación masiva, Pack ZIP, Modos SAC/Vacaciones/Final

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/image_bytes_reader.dart';
import '../utils/file_saver.dart';
import '../models/teacher_types.dart';
import '../models/empresa.dart';
import '../models/empleado.dart';
import '../data/rnos_docentes_data.dart';
import '../services/sanidad_omni_engine.dart';
import '../services/sanidad_lsd_export.dart';
import '../services/lsd_mapping_service.dart';
import '../services/instituciones_service.dart';
import '../services/costo_empleador_service.dart';
import '../services/sanidad_paritarias_service.dart';
import '../services/liquidacion_historial_service.dart';
import '../services/contabilidad_service.dart';
import '../services/contabilidad_config_service.dart';
import '../services/excel_export_service.dart';
import '../utils/validaciones_arca.dart';
import '../utils/pdf_recibo.dart';
import '../theme/app_colors.dart';
import '../utils/app_help.dart';
import 'institucion_form_screen.dart';
import 'lista_legajos_sanidad_screen.dart';
import 'sanidad_receipt_scan_screen.dart';
import '../utils/sanidad_stress_seed.dart';

class SanidadInterfaceScreen extends StatefulWidget {
  const SanidadInterfaceScreen({super.key});

  @override
  State<SanidadInterfaceScreen> createState() => _SanidadInterfaceScreenState();
}

class _SanidadInterfaceScreenState extends State<SanidadInterfaceScreen> {
  // === CONTROLADORES BÁSICOS ===
  final _nombreController = TextEditingController();
  final _cuilController = TextEditingController();
  final _puestoController = TextEditingController();
  final _codigoRnosController = TextEditingController();
  final _cuitEmpresaController = TextEditingController(text: '30-12345678-9');
  final _razonSocialController = TextEditingController(text: 'Hospital / Clínica Ejemplo');
  final _domicilioController = TextEditingController(text: 'Av. Ejemplo 123');
  final _cantidadFamiliaresController = TextEditingController(text: '0');
  final _horasNocturnasController = TextEditingController(text: '0');
  final _artPctController = TextEditingController(text: '3.5');
  final _artCuotaFijaController = TextEditingController(text: '800');
  
  // === CONTROLADORES CAMPOS ARCA 2026 ===
  final _cbuController = TextEditingController();
  final _localidadController = TextEditingController();
  final _codigoPostalController = TextEditingController();
  final _domicilioEmpleadoController = TextEditingController();
  final _codigoActividadController = TextEditingController(text: '049'); // Default Salud
  final _codigoPuestoController = TextEditingController(text: '0000');
  
  // === CONTROLADORES HORAS EXTRAS ===
  final _horasExtras50Controller = TextEditingController(text: '0');
  final _horasExtras100Controller = TextEditingController(text: '0');
  
  // === CONTROLADORES ADELANTOS/DESCUENTOS ===
  final _adelantosController = TextEditingController(text: '0');
  final _embargosController = TextEditingController(text: '0');
  final _prestamosController = TextEditingController(text: '0');
  
  // === CONTROLADORES LIQUIDACIÓN FINAL ===
  final _mejorRemuneracionController = TextEditingController();
  final _diasSACController = TextEditingController(text: '180');
  final _diasVacacionesController = TextEditingController(text: '14');

  // === ESTADOS BÁSICOS ===
  CategoriaSanidad _categoria = CategoriaSanidad.profesional;
  NivelTituloSanidad _nivelTitulo = NivelTituloSanidad.sinTitulo;
  bool _tareaCriticaRiesgo = false;
  bool _cuotaSindicalAtsa = false;
  bool _manejoEfectivoCaja = false;
  DateTime _fechaIngreso = DateTime.now().subtract(const Duration(days: 365 * 5));
  Jurisdiccion _jurisdiccion = Jurisdiccion.buenosAires;
  
  // === PERÍODO Y FECHA PAGO ===
  DateTime _periodoSeleccionado = DateTime.now();
  DateTime _fechaPago = DateTime.now();
  
  // === MODO DE LIQUIDACIÓN ===
  ModoLiquidacionSanidad _modoLiquidacion = ModoLiquidacionSanidad.mensual;
  
  // === LIQUIDACIÓN FINAL ===
  DateTime? _fechaEgreso;
  String _motivoEgreso = 'renuncia';
  bool _incluyePreaviso = false;
  bool _incluyeIntegracionMes = false;
  
  // === MODALIDAD/SITUACIÓN ARCA ===
  String _modalidadContratacion = '008'; // Tiempo indeterminado
  String _situacionRevista = '01';       // Activo

  bool get _esZonaPatagonica =>
      [Jurisdiccion.rioNegro, Jurisdiccion.neuquen, Jurisdiccion.chubut, Jurisdiccion.santaCruz, Jurisdiccion.tierraDelFuego].contains(_jurisdiccion);

  /// Valida CUIL con algoritmo Módulo 11
  bool _validarCuil(String cuil) {
    final digitsOnly = cuil.replaceAll(RegExp(r'[^\d]'), '');
    if (digitsOnly.length != 11) return false;
    
    final coeficientes = [5, 4, 3, 2, 7, 6, 5, 4, 3, 2];
    int suma = 0;
    for (int i = 0; i < 10; i++) {
      suma += int.parse(digitsOnly[i]) * coeficientes[i];
    }
    
    final resto = suma % 11;
    int digitoEsperado;
    if (resto == 0) {
      digitoEsperado = 0;
    } else if (resto == 1) {
      digitoEsperado = 9;
    } else {
      digitoEsperado = 11 - resto;
    }
    
    return int.parse(digitsOnly[10]) == digitoEsperado;
  }

  LiquidacionSanidadResult? _resultado;
  bool _calculando = false;
  bool _exportandoMasivo = false;

  List<Map<String, dynamic>> _instituciones = [];
  String? _institucionSeleccionadaCuit;
  List<Map<String, dynamic>> _legajosSanidad = [];
  String? _legajoSeleccionadoCuil;
  
  // === LOGO Y FIRMA DIGITAL (ARCA 2026) ===
  String? _logoPath;
  String? _firmaPath;

  // Estados para Panel de Escalas/Paritarias
  List<ParitariaSanidad> _paritariasMaestras = [];
  bool _maestroLoading = false;
  bool _savingMaestro = false;
  DateTime? _ultimaSincronizacion;
  String _modoSincronizacion = '';

  @override
  void initState() {
    super.initState();
    _cargarInstituciones();
    _cargarParitarias();
    _nombreController.addListener(_recalcular);
    _cuilController.addListener(_recalcular);
    _cantidadFamiliaresController.addListener(_recalcular);
    _horasNocturnasController.addListener(_recalcular);
    _recalcular();
    
    // Mostrar cartel inicial para ajustar paritarias provinciales
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _mostrarCartelInicialParitarias();
    });
  }
  
  Future<void> _mostrarCartelInicialParitarias() async {
    // Verificar si ya se mostró el cartel anteriormente
    final prefs = await SharedPreferences.getInstance();
    final yaVisto = prefs.getBool('sanidad_cartel_paritarias_visto') ?? false;
    
    if (yaVisto || !mounted) return;
    
    // Mostrar diálogo informativo
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.backgroundLight,
        title: Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.orange.shade400, size: 28),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Importante: Ajustar Escalas Salariales',
                style: TextStyle(color: AppColors.textPrimary, fontSize: 16),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Los cálculos de liquidación se basan en escalas salariales FATSA por provincia.',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade900.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '⚠️ Valores por defecto pueden no reflejar su realidad',
                    style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '• Ajuste los básicos según su provincia\n'
                    '• Diferencie entre público y privado si es necesario\n'
                    '• Los cambios son LOCALES (no afectan a otros usuarios)',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green.shade900.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.verified_user, color: Colors.green.shade400, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'El formato LSD ARCA 2026 es inalterable y siempre será aceptado',
                      style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await prefs.setBool('sanidad_cartel_paritarias_visto', true);
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Más tarde'),
          ),
          FilledButton.icon(
            onPressed: () async {
              await prefs.setBool('sanidad_cartel_paritarias_visto', true);
              if (mounted) {
                Navigator.pop(context);
                _mostrarModalMaestroSanidad();
              }
            },
            icon: const Icon(Icons.edit),
            label: const Text('Ajustar ahora'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.pastelMint,
              foregroundColor: Colors.black87,
            ),
          ),
        ],
      ),
    );
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
        // Cargar en cache del motor
        await SanidadOmniEngine.loadParitariasCache();
      }
    } catch (e) {
      if (mounted) setState(() => _maestroLoading = false);
      print('Error cargando paritarias: $e');
    }
  }

  Future<void> _handleAbrirMaestro() async {
    setState(() => _maestroLoading = true);
    
    try {
      final res = await SanidadParitariasService.sincronizarParitarias();
      if (mounted) {
        setState(() {
          final list = res['data'] as List?;
          if (list != null) {
            _paritariasMaestras = list.map((e) => ParitariaSanidad.fromMap(e as Map<String, dynamic>)).toList();
          }
          _maestroLoading = false;
        });
        // Mostrar el modal solo después de cargar los datos
        _mostrarModalMaestroSanidad();
      }
    } catch (e) {
      if (mounted) setState(() => _maestroLoading = false);
      print('Error cargando maestro sanidad: $e');
      // Mostrar modal incluso con error, pero con mensaje de error
      _mostrarModalMaestroSanidad();
    }
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

  void _mostrarAyuda() {
    final helpContent = AppHelp.getHelpContent('sanidad_interface');
    AppHelp.showHelpDialog(
      context,
      helpContent['title']!,
      helpContent['content']!,
    );
  }

  void _mostrarModalMaestroSanidad() {
    showDialog(
      context: context,
      barrierDismissible: !_savingMaestro,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              backgroundColor: AppColors.background,
              title: Row(
                children: [
                  const Icon(Icons.settings, color: Colors.teal),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('Ajustes Locales (Paritarias Sanidad)', 
                      style: TextStyle(color: Colors.white, fontSize: 16)),
                  ),
                  IconButton(
                    icon: Icon(_maestroLoading ? Icons.hourglass_empty : Icons.refresh, color: Colors.white70, size: 20),
                    onPressed: _maestroLoading ? null : () async {
                      setModalState(() => _maestroLoading = true);
                      await _cargarParitarias();
                      setModalState(() => _maestroLoading = false);
                    },
                    tooltip: 'Sincronizar',
                  ),
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
                        Text('Cargando escalas...', style: TextStyle(color: Colors.white70)),
                      ],
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.teal.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline, size: 16, color: Colors.teal),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Personalizá los valores para tus liquidaciones. Cambios LOCALES, no afectan a otros usuarios.',
                                  style: TextStyle(color: Colors.teal.shade200, fontSize: 11),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_ultimaSincronizacion != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              'Última sync: ${DateFormat('dd/MM/yyyy HH:mm').format(_ultimaSincronizacion!)} ($_modoSincronizacion)',
                              style: const TextStyle(color: Colors.white38, fontSize: 10),
                            ),
                          ),
                        const SizedBox(height: 12),
                        Flexible(
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: _paritariasMaestras.length,
                            itemBuilder: (context, index) {
                              final p = _paritariasMaestras[index];
                              final esPatagonica = SanidadParitariasService.jurisdiccionesPatagonicas.contains(p.jurisdiccion);
                              
                              return Card(
                                color: esPatagonica ? Colors.cyan.withValues(alpha: 0.15) : AppColors.glassFill,
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ExpansionTile(
                                  leading: CircleAvatar(
                                    backgroundColor: esPatagonica ? Colors.cyan.shade800 : Colors.teal.shade800,
                                    radius: 16,
                                    child: Text(p.nombreMostrar.substring(0, 2).toUpperCase(), 
                                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                                  ),
                                  title: Text(p.nombreMostrar, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                                  subtitle: Text(
                                    'Prof: \$${p.basicoProfesional.toStringAsFixed(0)}${esPatagonica ? " (Patagónica +${p.zonaPatagonicaPct.toInt()}%)" : ""}',
                                    style: TextStyle(color: esPatagonica ? Colors.cyan.shade200 : Colors.white54, fontSize: 11),
                                  ),
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('BÁSICOS POR CATEGORÍA', style: TextStyle(color: Colors.tealAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                                          const SizedBox(height: 8),
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 8,
                                            children: [
                                              _buildMiniTextField('Profesional', p.basicoProfesional, (v) {
                                                p.basicoProfesional = double.tryParse(v) ?? p.basicoProfesional;
                                              }),
                                              _buildMiniTextField('Técnico', p.basicoTecnico, (v) {
                                                p.basicoTecnico = double.tryParse(v) ?? p.basicoTecnico;
                                              }),
                                              _buildMiniTextField('Servicios', p.basicoServicios, (v) {
                                                p.basicoServicios = double.tryParse(v) ?? p.basicoServicios;
                                              }),
                                              _buildMiniTextField('Administrativo', p.basicoAdministrativo, (v) {
                                                p.basicoAdministrativo = double.tryParse(v) ?? p.basicoAdministrativo;
                                              }),
                                              _buildMiniTextField('Maestranza', p.basicoMaestranza, (v) {
                                                p.basicoMaestranza = double.tryParse(v) ?? p.basicoMaestranza;
                                              }),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          const Text('PORCENTAJES ADICIONALES', style: TextStyle(color: Colors.blueAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                                          const SizedBox(height: 8),
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 8,
                                            children: [
                                              _buildMiniTextField('Antig %/año', p.antiguedadPctPorAno, (v) {
                                                p.antiguedadPctPorAno = double.tryParse(v) ?? p.antiguedadPctPorAno;
                                              }, width: 70),
                                              _buildMiniTextField('Tít Aux %', p.tituloAuxiliarPct, (v) {
                                                p.tituloAuxiliarPct = double.tryParse(v) ?? p.tituloAuxiliarPct;
                                              }, width: 70),
                                              _buildMiniTextField('Tít Téc %', p.tituloTecnicoPct, (v) {
                                                p.tituloTecnicoPct = double.tryParse(v) ?? p.tituloTecnicoPct;
                                              }, width: 70),
                                              _buildMiniTextField('Tít Univ %', p.tituloUniversitarioPct, (v) {
                                                p.tituloUniversitarioPct = double.tryParse(v) ?? p.tituloUniversitarioPct;
                                              }, width: 70),
                                              _buildMiniTextField('Tarea Crít %', p.tareaCriticaRiesgoPct, (v) {
                                                p.tareaCriticaRiesgoPct = double.tryParse(v) ?? p.tareaCriticaRiesgoPct;
                                              }, width: 80),
                                              _buildMiniTextField('Zona Patag %', p.zonaPatagonicaPct, (v) {
                                                p.zonaPatagonicaPct = double.tryParse(v) ?? p.zonaPatagonicaPct;
                                              }, width: 80),
                                              _buildMiniTextField('Nocturnas %', p.nocturnasPct, (v) {
                                                p.nocturnasPct = double.tryParse(v) ?? p.nocturnasPct;
                                              }, width: 80),
                                              _buildMiniTextField('Fallo Caja \$', p.montoFalloCaja, (v) {
                                                p.montoFalloCaja = double.tryParse(v) ?? p.montoFalloCaja;
                                              }, width: 90),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          const Text('APORTES Y DESCUENTOS', style: TextStyle(color: Colors.orangeAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                                          const SizedBox(height: 8),
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 8,
                                            children: [
                                              _buildMiniTextField('Jubilación %', p.jubilacionPct, (v) {
                                                p.jubilacionPct = double.tryParse(v) ?? p.jubilacionPct;
                                              }, width: 80),
                                              _buildMiniTextField('Ley 19032 %', p.ley19032Pct, (v) {
                                                p.ley19032Pct = double.tryParse(v) ?? p.ley19032Pct;
                                              }, width: 80),
                                              _buildMiniTextField('O. Social %', p.obraSocialPct, (v) {
                                                p.obraSocialPct = double.tryParse(v) ?? p.obraSocialPct;
                                              }, width: 80),
                                              _buildMiniTextField('ATSA %', p.cuotaSindicalAtsaPct, (v) {
                                                p.cuotaSindicalAtsaPct = double.tryParse(v) ?? p.cuotaSindicalAtsaPct;
                                              }, width: 70),
                                              _buildMiniTextField('Sepelio %', p.seguroSepelioPct, (v) {
                                                p.seguroSepelioPct = double.tryParse(v) ?? p.seguroSepelioPct;
                                              }, width: 70),
                                              _buildMiniTextField('FATSA %', p.aporteSolidarioFatsaPct, (v) {
                                                p.aporteSolidarioFatsaPct = double.tryParse(v) ?? p.aporteSolidarioFatsaPct;
                                              }, width: 70),
                                              _buildMiniTextField('Tope Prev \$', p.topeBasePrevisional, (v) {
                                                p.topeBasePrevisional = double.tryParse(v) ?? p.topeBasePrevisional;
                                              }, width: 100),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              TextButton.icon(
                                                onPressed: _savingMaestro ? null : () async {
                                                  setModalState(() => _savingMaestro = true);
                                                  try {
                                                    await SanidadParitariasService.resetearJurisdiccion(p.jurisdiccion);
                                                    await _cargarParitarias();
                                                    if (mounted) {
                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                        SnackBar(content: Text('${p.nombreMostrar} reseteado a valores por defecto')));
                                                    }
                                                  } finally {
                                                    setModalState(() => _savingMaestro = false);
                                                  }
                                                },
                                                icon: const Icon(Icons.refresh, size: 16),
                                                label: const Text('Resetear', style: TextStyle(fontSize: 11)),
                                              ),
                                              FilledButton.icon(
                                                onPressed: _savingMaestro ? null : () async {
                                                  setModalState(() => _savingMaestro = true);
                                                  try {
                                                    await SanidadParitariasService.actualizarParitariaProvincial(
                                                      p.jurisdiccion, 
                                                      p.toMap(),
                                                    );
                                                    // Recargar cache del motor
                                                    await SanidadOmniEngine.loadParitariasCache();
                                                    
                                                    if (mounted) {
                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                        SnackBar(content: Text('Guardado: ${p.nombreMostrar}')));
                                                    }
                                                  } catch (e) {
                                                    if (mounted) {
                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                        SnackBar(content: Text('Error: $e')));
                                                    }
                                                  } finally {
                                                    setModalState(() => _savingMaestro = false);
                                                  }
                                                },
                                                icon: _savingMaestro 
                                                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                                  : const Icon(Icons.save, size: 16),
                                                label: const Text('Guardar', style: TextStyle(fontSize: 11)),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
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

  Widget _buildMiniTextField(String label, double value, void Function(String) onChanged, {double width = 90}) {
    return SizedBox(
      width: width,
      child: TextField(
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontSize: 9),
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          isDense: true,
        ),
        style: const TextStyle(color: Colors.white, fontSize: 12),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        controller: TextEditingController(text: value.toStringAsFixed(value == value.roundToDouble() ? 0 : 1)),
        onChanged: onChanged,
      ),
    );
  }

  /// Selector de período, fecha de pago y modo de liquidación
  Widget _buildSelectorPeriodoYModo() {
    return Card(
      color: AppColors.glassFillStrong,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.calendar_month, color: Colors.tealAccent, size: 20),
                const SizedBox(width: 8),
                const Text('Período y Tipo de Liquidación', 
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              ],
            ),
            const SizedBox(height: 16),
            
            // Fila 1: Período y Fecha de Pago
            Row(
              children: [
                Expanded(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Período', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    subtitle: Text(
                      DateFormat('MMMM yyyy', 'es_AR').format(_periodoSeleccionado),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit_calendar, color: Colors.tealAccent),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _periodoSeleccionado,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                          initialDatePickerMode: DatePickerMode.year,
                        );
                        if (picked != null) {
                          setState(() => _periodoSeleccionado = DateTime(picked.year, picked.month, 1));
                          _recalcular();
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Fecha de Pago', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    subtitle: Text(
                      DateFormat('dd/MM/yyyy').format(_fechaPago),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.today, color: Colors.tealAccent),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _fechaPago,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) {
                          setState(() => _fechaPago = picked);
                          _recalcular();
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
            
            const Divider(color: AppColors.glassBorder),
            
            // Fila 2: Modo de Liquidación
            const Text('Tipo de Liquidación', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildModoChip(ModoLiquidacionSanidad.mensual, 'Mensual', Icons.calendar_today),
                _buildModoChip(ModoLiquidacionSanidad.sac, 'SAC (Aguinaldo)', Icons.card_giftcard),
                _buildModoChip(ModoLiquidacionSanidad.vacaciones, 'Vacaciones', Icons.beach_access),
                _buildModoChip(ModoLiquidacionSanidad.liquidacionFinal, 'Liquidación Final', Icons.exit_to_app),
              ],
            ),
            
            // Campos adicionales según modo
            if (_modoLiquidacion == ModoLiquidacionSanidad.sac) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _diasSACController,
                decoration: const InputDecoration(
                  labelText: 'Días trabajados en el semestre',
                  helperText: '180 = SAC completo, menos = proporcional',
                  prefixIcon: Icon(Icons.calendar_view_day),
                ),
                keyboardType: TextInputType.number,
                onChanged: (_) => _recalcular(),
              ),
            ],
            
            if (_modoLiquidacion == ModoLiquidacionSanidad.vacaciones) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _diasVacacionesController,
                decoration: const InputDecoration(
                  labelText: 'Días de vacaciones',
                  helperText: 'Según antigüedad: <5 años=14, <10=21, <20=28, +20=35',
                  prefixIcon: Icon(Icons.beach_access),
                ),
                keyboardType: TextInputType.number,
                onChanged: (_) => _recalcular(),
              ),
            ],
            
            if (_modoLiquidacion == ModoLiquidacionSanidad.liquidacionFinal) ...[
              const SizedBox(height: 16),
              _buildCamposLiquidacionFinal(),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildModoChip(ModoLiquidacionSanidad modo, String label, IconData icon) {
    final seleccionado = _modoLiquidacion == modo;
    return FilterChip(
      selected: seleccionado,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: seleccionado ? Colors.white : AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(label),
        ],
      ),
      selectedColor: Colors.teal,
      backgroundColor: AppColors.glassFill,
      labelStyle: TextStyle(
        color: seleccionado ? Colors.white : AppColors.textPrimary,
        fontSize: 12,
      ),
      onSelected: (v) {
        setState(() => _modoLiquidacion = modo);
        _recalcular();
      },
    );
  }
  
  Widget _buildCamposLiquidacionFinal() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Fecha de Egreso', style: TextStyle(fontSize: 12)),
                subtitle: Text(
                  _fechaEgreso != null ? DateFormat('dd/MM/yyyy').format(_fechaEgreso!) : 'Sin definir',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.calendar_today),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _fechaEgreso ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) {
                      setState(() => _fechaEgreso = picked);
                      _recalcular();
                    }
                  },
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _motivoEgreso,
                decoration: const InputDecoration(
                  labelText: 'Motivo de Egreso',
                  isDense: true,
                ),
                items: const [
                  DropdownMenuItem(value: 'renuncia', child: Text('Renuncia')),
                  DropdownMenuItem(value: 'despidoSinCausa', child: Text('Despido Sin Causa')),
                  DropdownMenuItem(value: 'despidoConCausa', child: Text('Despido Con Causa')),
                  DropdownMenuItem(value: 'mutuoAcuerdo', child: Text('Mutuo Acuerdo')),
                  DropdownMenuItem(value: 'jubilacion', child: Text('Jubilación')),
                  DropdownMenuItem(value: 'finContrato', child: Text('Fin de Contrato')),
                ],
                onChanged: (v) {
                  if (v != null) {
                    setState(() => _motivoEgreso = v);
                    _recalcular();
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_motivoEgreso == 'despidoSinCausa') ...[
          SwitchListTile(
            title: const Text('Incluir Preaviso'),
            subtitle: Text('${_resultado?.input.diasPreaviso() ?? 30} días según antigüedad'),
            value: _incluyePreaviso,
            onChanged: (v) {
              setState(() => _incluyePreaviso = v);
              _recalcular();
            },
          ),
          SwitchListTile(
            title: const Text('Incluir Integración Mes'),
            subtitle: const Text('Días restantes del mes de despido'),
            value: _incluyeIntegracionMes,
            onChanged: (v) {
              setState(() => _incluyeIntegracionMes = v);
              _recalcular();
            },
          ),
        ],
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _mejorRemuneracionController,
                decoration: const InputDecoration(
                  labelText: 'Mejor Remuneración (opcional)',
                  helperText: 'Para cálculo de SAC e Indemnización. Si vacío, usa bruto actual.',
                  prefixIcon: Icon(Icons.attach_money),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => _recalcular(),
              ),
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: 'Cargar automáticamente mejor remuneración últimos 6 meses',
              child: ElevatedButton.icon(
                onPressed: _cargarMejorRemuneracionAutomatica,
                icon: const Icon(Icons.auto_awesome, size: 16),
                label: const Text('Auto', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _diasSACController,
                decoration: const InputDecoration(
                  labelText: 'Días SAC proporcional',
                  prefixIcon: Icon(Icons.card_giftcard),
                ),
                keyboardType: TextInputType.number,
                onChanged: (_) => _recalcular(),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextField(
                controller: _diasVacacionesController,
                decoration: const InputDecoration(
                  labelText: 'Días Vacaciones no gozadas',
                  prefixIcon: Icon(Icons.beach_access),
                ),
                keyboardType: TextInputType.number,
                onChanged: (_) => _recalcular(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBannerSincronizacion() {
    // MODIFICADO: Siempre mostrar banner
    final bool hasInfo = _ultimaSincronizacion != null;
    final bool success = _modoSincronizacion == 'online' || _modoSincronizacion == 'default';
    final bool isOffline = _modoSincronizacion == 'offline';
    final String fechaStr = _ultimaSincronizacion != null 
        ? DateFormat('dd/MM/yyyy HH:mm').format(_ultimaSincronizacion!) 
        : 'Desconocida';

    Color bgColor;
    Color borderColor;
    IconData icon;
    String mensajeBanner;

    if (_maestroLoading) {
      bgColor = Colors.blue.withValues(alpha: 0.1);
      borderColor = Colors.blue.withValues(alpha: 0.3);
      icon = Icons.sync;
      mensajeBanner = 'Sincronizando paritarias Sanidad...';
    } else if (!hasInfo) {
      bgColor = Colors.grey.withValues(alpha: 0.1);
      borderColor = Colors.grey.withValues(alpha: 0.3);
      icon = Icons.help_outline;
      mensajeBanner = 'Estado de paritarias desconocido';
    } else if (success) {
      bgColor = Colors.teal.withValues(alpha: 0.1);
      borderColor = Colors.teal.withValues(alpha: 0.3);
      icon = Icons.check_circle_outline;
      mensajeBanner = 'Paritarias Sanidad actualizadas al $fechaStr';
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
          if (_maestroLoading)
            const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.teal))
          else
            Icon(icon, size: 16, color: borderColor.withOpacity(1.0)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              mensajeBanner,
              style: TextStyle(
                fontSize: 12, 
                color: borderColor.withOpacity(1.0),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
           if (!_maestroLoading)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.refresh, size: 14),
                  onPressed: _cargarParitarias,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  visualDensity: VisualDensity.compact,
                  color: Colors.teal,
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


  void _recalcular() {
    if (_nombreController.text.trim().isEmpty || _cuilController.text.trim().isEmpty) {
      setState(() => _resultado = null);
      return;
    }
    setState(() => _calculando = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      
      // Validaciones previas al cálculo
      double embargosInput = double.tryParse(_embargosController.text) ?? 0;
      
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
        // Campos ARCA 2026
        cbu: _cbuController.text.trim().isEmpty ? null : _cbuController.text.trim(),
        localidad: _localidadController.text.trim().isEmpty ? null : _localidadController.text.trim(),
        codigoPostal: _codigoPostalController.text.trim().isEmpty ? null : _codigoPostalController.text.trim(),
        domicilioEmpleado: _domicilioEmpleadoController.text.trim().isEmpty ? null : _domicilioEmpleadoController.text.trim(),
        codigoModalidad: _modalidadContratacion,
        codigoSituacion: _situacionRevista,
        // Horas extras
        horasExtras50: double.tryParse(_horasExtras50Controller.text) ?? 0,
        horasExtras100: double.tryParse(_horasExtras100Controller.text) ?? 0,
        // Adelantos y descuentos
        adelantos: double.tryParse(_adelantosController.text) ?? 0,
        embargos: embargosInput,
        prestamos: double.tryParse(_prestamosController.text) ?? 0,
        // Liquidación final
        fechaEgreso: _modoLiquidacion == ModoLiquidacionSanidad.liquidacionFinal ? _fechaEgreso : null,
        motivoEgreso: _modoLiquidacion == ModoLiquidacionSanidad.liquidacionFinal ? _motivoEgreso : null,
        mejorRemuneracion: _mejorRemuneracionController.text.isNotEmpty 
            ? double.tryParse(_mejorRemuneracionController.text) : null,
        diasSACProporcional: _modoLiquidacion == ModoLiquidacionSanidad.sac || _modoLiquidacion == ModoLiquidacionSanidad.liquidacionFinal
            ? int.tryParse(_diasSACController.text) : null,
        diasVacacionesNoGozadas: _modoLiquidacion == ModoLiquidacionSanidad.vacaciones || _modoLiquidacion == ModoLiquidacionSanidad.liquidacionFinal
            ? int.tryParse(_diasVacacionesController.text) : null,
        incluyePreaviso: _incluyePreaviso,
        incluyeIntegracionMes: _incluyeIntegracionMes,
      );
      final r = SanidadOmniEngine.liquidar(
        i,
        periodo: DateFormat('MMMM yyyy', 'es_AR').format(_periodoSeleccionado),
        fechaPago: DateFormat('dd/MM/yyyy').format(_fechaPago),
        esZonaPatagonica: _esZonaPatagonica,
        jurisdiccion: _jurisdiccion.name,
        modo: _modoLiquidacion,
      );
      
      // VALIDACIÓN CRÍTICA: Límite legal de embargos (20% del neto)
      bool advertenciaEmbargoLegal = false;
      double embargosAjustados = embargosInput;
      if (embargosInput > 0) {
        final limiteEmbargoLegal = r.netoACobrar * 0.20;
        if (embargosInput > limiteEmbargoLegal) {
          advertenciaEmbargoLegal = true;
          embargosAjustados = limiteEmbargoLegal;
        }
      }
      
      // VALIDACIÓN CRÍTICA: Neto positivo
      bool advertencianetoNegativo = false;
      if (r.netoACobrar < 0) {
        advertencianetoNegativo = true;
      }
      
      if (!mounted) return;
      
      // GUARDAR EN HISTORIAL
      _guardarEnHistorial(r).then((_) {
        // Detectar saltos inusuales
        _verificarSaltosInusuales(r);
      });
      
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
                '⚠️ LÍMITE LEGAL: El embargo ingresado (\$${embargosInput.toStringAsFixed(2)}) '
                'excede el 20% del neto (\$${embargosAjustados.toStringAsFixed(2)}). '
                'Se recomienda ajustar el monto.',
              ),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 6),
              action: SnackBarAction(
                label: 'Ajustar',
                textColor: Colors.white,
                onPressed: () {
                  setState(() {
                    _embargosController.text = embargosAjustados.toStringAsFixed(2);
                  });
                  _recalcular();
                },
              ),
            ),
          );
        });
      }
      
      if (advertencianetoNegativo) {
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
    final catDesc = SanidadNomenclador2026.itemPorCategoria(_categoria)?.descripcion ?? _categoria.name;
    final categoriaStr = _tareaCriticaRiesgo ? '$catDesc - Tarea Crítica/Riesgo' : catDesc;
    final empresa = Empresa(
      razonSocial: _razonSocialController.text.trim(),
      cuit: _cuitEmpresaController.text.trim(),
      domicilio: _domicilioController.text.trim(),
      convenioId: 'sanidad_fatsa_2026',
      convenioNombre: 'Sanidad FATSA CCT 122/75 y 108/75',
      convenioPersonalizado: false,
      categorias: [],
      parametros: [],
    );
    final empleado = Empleado(
      nombre: _nombreController.text.trim(),
      categoria: categoriaStr,
      sueldoBasico: r.sueldoBasico,
      periodo: r.periodo,
      fechaPago: r.fechaPago,
      fechaIngreso: DateFormat('yyyy-MM-dd').format(_fechaIngreso),
      lugarPago: _domicilioController.text.trim().isNotEmpty ? _domicilioController.text.trim() : null,
    );
    
    // USAR LA LÓGICA UNIFICADA DE CONCEPTOS (misma que Pack ARCA)
    final conceptos = _buildConceptosParaPDF(r);

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
        totalNoRemunerativo: 0,
        sueldoNeto: r.netoACobrar,
        baseImponibleTopeada: r.baseImponibleTopeada != r.totalBrutoRemunerativo ? r.baseImponibleTopeada : null,
        logoBytes: logoBytes,
        firmaBytes: firmaBytes,
        incluirBloqueFirmaLey25506: true,
      );
      final cuilLimpio = _cuilController.text.replaceAll(RegExp(r'[^\d]'), '');
      final nombreArchivo = 'recibo_sanidad_${cuilLimpio}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final filePath = await saveFile(fileName: nombreArchivo, bytes: pdfBytes, mimeType: 'application/pdf');
      if (!mounted) return;
      
      // Determinar si estamos en web
      final esWeb = filePath == 'descargado';
      
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.check_circle, color: AppColors.pastelMint),
              const SizedBox(width: 12),
              const Text('Recibo generado'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Sueldo neto: \$${r.netoACobrar.toStringAsFixed(2)}'),
              const SizedBox(height: 12),
              Text(
                esWeb 
                  ? 'El PDF se descargó automáticamente.\nRevisa tu carpeta de Descargas.'
                  : 'Archivo: $nombreArchivo',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
            ],
          ),
          actions: [
            if (!esWeb && filePath != null)
              FilledButton(onPressed: () { Navigator.pop(ctx); openFile(filePath); }, child: const Text('Abrir PDF')),
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar')),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al generar PDF: $e')));
    }
  }

  Future<void> _exportarLsd() async {
    final r = _resultado;
    if (r == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Complete los datos y calcule la liquidación')),
      );
      return;
    }
    final cuit = _cuitEmpresaController.text.replaceAll(RegExp(r'[^\d]'), '');
    if (cuit.length != 11) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('CUIT empresa debe tener 11 dígitos')),
      );
      return;
    }
    try {
      final txt = await sanidadOmniToLsdTxt(
        liquidacion: r,
        cuitEmpresa: cuit,
        razonSocial: _razonSocialController.text,
        domicilio: _domicilioController.text,
      );
      final name = 'LSD_Sanidad_${r.input.nombre.replaceAll(RegExp(r'[^\w]'), '_')}_${DateFormat('yyyyMMdd').format(DateTime.now())}.txt';
      final filePath = await saveTextFile(fileName: name, content: txt, mimeType: 'text/plain');
      if (!mounted) return;
      
      final esWeb = filePath == 'descargado';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(esWeb ? 'LSD descargado: $name (ver carpeta Descargas)' : 'Exportado: $name'),
          duration: const Duration(seconds: 4),
        ),
      );
      if (!esWeb && filePath != null) openFile(filePath);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _exportarAsiento() async {
    if (_resultado == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Debe liquidar primero')));
        return;
    }

    final perfil = await ContabilidadConfigService.cargarPerfil();
    
    // Generar asiento preliminar
    final asiento = ContabilidadService.generarAsientoSanidad(
      liquidaciones: [_resultado!], 
      perfil: perfil
    );

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Exportación Contable (Asiento)'),
        content: SizedBox(
          width: 500,
          height: 400,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Resumen del Asiento a Generar:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Expanded(
                child: ListView.builder(
                  itemCount: asiento.items.length,
                  itemBuilder: (c, i) {
                    final item = asiento.items[i];
                    return ListTile(
                      dense: true,
                      title: Text('${item.cuentaCodigo} - ${item.cuentaNombre}'),
                      subtitle: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Debe: \$${item.debe.toStringAsFixed(2)}'),
                          Text('Haber: \$${item.haber.toStringAsFixed(2)}'),
                        ],
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
              final name = 'Asiento_Sanidad_${DateTime.now().millisecondsSinceEpoch}.csv';
              final filePath = await saveTextFile(fileName: name, content: csv, mimeType: 'text/csv');
              
              if (mounted) {
                Navigator.pop(ctx);
                final esWeb = filePath == 'descargado';
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(esWeb ? 'CSV descargado: $name' : 'Exportado a: $filePath')),
                );
                if (!esWeb && filePath != null) openFile(filePath);
              }
            },
            icon: const Icon(Icons.save),
            label: const Text('Guardar CSV (Holistor/Tango)'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportarLibroSueldosExcel() async {
    // Si hay un cálculo individual, exportamos ese. Si no, y hay legajos, sugerimos masivo.
    List<LiquidacionSanidadResult> listaParaExportar = [];
    
    if (_resultado != null) {
      listaParaExportar.add(_resultado!);
    } else if (_legajosSanidad.isNotEmpty) {
      final confirm = await showDialog<bool>(
        context: context, 
        builder: (c) => AlertDialog(
          title: const Text('Generar Libro de Sueldos'),
          content: Text('No hay liquidación actual. ¿Desea calcular y exportar los ${_legajosSanidad.length} legajos de la lista?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Calcular y Exportar')),
          ],
        )
      );
      
      if (confirm != true) return;
      
      setState(() => _exportandoMasivo = true);
      // Reutilizar lógica de masivo
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

    // Convertir a formato mapa para el servicio Excel
    final datosExcel = listaParaExportar.map((liq) {
      return {
        'cuil': liq.input.cuil,
        'nombre': liq.input.nombre,
        'categoria': liq.input.categoria.name,
        'basico': liq.sueldoBasico,
        'antiguedad': liq.adicionalAntiguedad,
        'conceptosRemunerativos': liq.totalBrutoRemunerativo - liq.sueldoBasico - liq.adicionalAntiguedad,
        'totalBruto': liq.totalBrutoRemunerativo,
        'totalAportes': liq.totalDescuentos, // Usamos total descuentos como "aportes" para simplificar visualización
        'descuentos': 0.0, // Ya incluido en totalAportes para este formato simple
        'conceptosNoRemunerativos': liq.totalNoRemunerativo,
        'neto': liq.netoACobrar,
        'totalContribuciones': 0.0, // No calculado aún en este motor
      };
    }).toList();

    try {
      final path = await ExcelExportService.generarLibroSueldos(
        mes: _periodoSeleccionado.month, 
        anio: _periodoSeleccionado.year, 
        liquidaciones: datosExcel,
        empresaNombre: _razonSocialController.text,
      );
      
      if (!mounted) return;
      
      final esWeb = path == 'web_download' || path == 'descargado';
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(esWeb ? 'Libro de Sueldos descargado' : 'Libro de Sueldos generado: $path')),
      );
      if (!esWeb) openFile(path);
      
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error Excel: $e')));
    }
  }

  void _mostrarInstructivoArca() {
    final codigosUsados = <String>{};
    
    // Si hay un resultado calculado (individual)
    if (_resultado != null) {
      if (_resultado!.sueldoBasico > 0) codigosUsados.add(SanidadLsdCodigos.sueldoBasico);
      if (_resultado!.adicionalAntiguedad > 0) codigosUsados.add(SanidadLsdCodigos.antiguedad);
      if (_resultado!.nocturnidad > 0) codigosUsados.add(SanidadLsdCodigos.nocturnidad);
      if (_resultado!.falloCaja > 0) codigosUsados.add(SanidadLsdCodigos.falloCaja);
      if (_resultado!.adicionalTareaCriticaRiesgo > 0) codigosUsados.add(SanidadLsdCodigos.tareaCritica);
      
      for (final c in _resultado!.conceptosPropios) {
        final cod = c['codigo']?.toString() ?? '';
        if (cod.isNotEmpty) {
            codigosUsados.add(cod.length > 10 ? cod.substring(0, 10) : cod);
        }
      }
    } 
    
    // Si hay legajos para masivo, agregar códigos comunes si la lista está vacía
    if (codigosUsados.isEmpty && _legajosSanidad.isNotEmpty) {
       codigosUsados.addAll([
         SanidadLsdCodigos.sueldoBasico,
         SanidadLsdCodigos.antiguedad,
         SanidadLsdCodigos.jubilacion,
         SanidadLsdCodigos.obraSocial,
         SanidadLsdCodigos.ley19032,
         SanidadLsdCodigos.cuotaSindical,
       ]);
    }
    
    // Fallback default
    if (codigosUsados.isEmpty) {
       codigosUsados.addAll([
         SanidadLsdCodigos.sueldoBasico,
         SanidadLsdCodigos.antiguedad,
         SanidadLsdCodigos.jubilacion,
         SanidadLsdCodigos.obraSocial,
         SanidadLsdCodigos.ley19032
       ]);
    }

    final instructivo = LsdMappingService.generarInstructivo(codigosUsados.toList());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
            children: [
                Icon(Icons.info_outline, color: Colors.teal),
                SizedBox(width: 8),
                Text('Instructivo Asociación AFIP'),
            ],
        ),
        content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                        Text('Antes de subir el archivo a AFIP, debe asociar los conceptos por única vez:', style: TextStyle(fontWeight: FontWeight.bold)),
                        SizedBox(height: 10),
                        Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                                color: Colors.teal.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.teal.withValues(alpha: 0.2)),
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

  Future<void> _cargarInstituciones() async {
    final list = await InstitucionesService.getInstituciones();
    if (mounted) setState(() => _instituciones = list);
  }

  /// Carga datos de prueba de estrés para verificar recibos y LSD
  Future<void> _cargarDatosStressTest() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.backgroundLight,
        title: const Row(
          children: [
            Icon(Icons.bug_report, color: AppColors.pastelOrange),
            SizedBox(width: 12),
            Text('STRESS TEST', style: TextStyle(color: AppColors.textPrimary)),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Esto creará datos de prueba de alta complejidad:',
              style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Text('• 1 Hospital en Neuquén (zona patagónica)', style: TextStyle(color: AppColors.textSecondary)),
            Text('• 5 empleados con casos extremos:', style: TextStyle(color: AppColors.textSecondary)),
            Padding(
              padding: EdgeInsets.only(left: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('- Médico UTI: todos los adicionales', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  Text('- Enfermera: liquidación final despido', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  Text('- Camillero: SAC proporcional (4 meses)', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  Text('- Admin: embargos al límite legal', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  Text('- Mucama: 160 hs nocturnas', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                ],
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Útil para verificar:\n• Generación de recibos PDF\n• Exportación LSD ARCA 2026\n• Cálculos complejos',
              style: TextStyle(color: AppColors.pastelBlue, fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.download),
            label: const Text('Cargar Datos'),
          ),
        ],
      ),
    );

    if (confirmar != true || !mounted) return;

    // Mostrar loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AlertDialog(
        backgroundColor: AppColors.backgroundLight,
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text('Creando datos de prueba...', style: TextStyle(color: AppColors.textPrimary)),
          ],
        ),
      ),
    );

    try {
      final resultado = await SanidadStressSeed.cargarDatosDePrueba();
      if (!mounted) return;
      Navigator.pop(context); // Cerrar loading

      await _cargarInstituciones();

      // Mostrar resumen
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.backgroundLight,
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: AppColors.pastelMint),
              SizedBox(width: 12),
              Text('Datos creados', style: TextStyle(color: AppColors.textPrimary)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Institución: ${resultado['institucion']}',
                style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text('Empleados creados:', style: TextStyle(color: AppColors.textSecondary)),
              ...((resultado['empleados'] as List<String>).map((e) => Padding(
                padding: const EdgeInsets.only(left: 16, top: 4),
                child: Text('• $e', style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
              ))),
              const SizedBox(height: 16),
              const Text(
                'Selecciona la institución "STRESS TEST" para probar.',
                style: TextStyle(color: AppColors.pastelBlue, fontStyle: FontStyle.italic),
              ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Cerrar loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.pastelPink),
      );
    }
  }

  Future<void> _cargarLegajosSanidad() async {
    final cuit = _institucionSeleccionadaCuit;
    if (cuit == null || cuit.isEmpty) {
      setState(() => _legajosSanidad = []);
      return;
    }
    final list = await InstitucionesService.getLegajosSanidad(cuit);
    if (mounted) setState(() => _legajosSanidad = list);
  }

  Future<void> _eliminarInstitucionPorCuit(String cuit) async {
    final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      title: const Text('Eliminar institución'),
      content: const Text('¿Eliminar esta institución? Los legajos asociados no se borran.'),
      actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')), TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Eliminar'))],
    ));
    if (ok != true || !mounted) return;
    await InstitucionesService.removeInstitucion(cuit);
    await _cargarInstituciones();
    if (!mounted) return;
    if (cuit == _institucionSeleccionadaCuit) {
      setState(() {
        _institucionSeleccionadaCuit = null;
        _cuitEmpresaController.clear();
        _razonSocialController.clear();
        _domicilioController.clear();
        _jurisdiccion = Jurisdiccion.buenosAires;
        _artPctController.text = '3.5';
        _artCuotaFijaController.text = '800';
        _legajosSanidad = [];
        _legajoSeleccionadoCuil = null;
      });
    }
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Institución eliminada')));
  }

  void _prefillFromInstitucion(Map<String, dynamic> i) {
    _cuitEmpresaController.text = i['cuit']?.toString() ?? '';
    _razonSocialController.text = i['razonSocial']?.toString() ?? '';
    _domicilioController.text = i['domicilio']?.toString() ?? '';
    final j = i['jurisdiccion']?.toString();
    _jurisdiccion = Jurisdiccion.values.cast<Jurisdiccion?>().firstWhere(
        (e) => e?.name == j, orElse: () => Jurisdiccion.buenosAires) ?? Jurisdiccion.buenosAires;
    _artPctController.text = (i['artPct'] is num) ? (i['artPct'] as num).toString() : (i['artPct']?.toString() ?? '3.5');
    _artCuotaFijaController.text = (i['artCuotaFija'] is num) ? (i['artCuotaFija'] as num).toString() : (i['artCuotaFija']?.toString() ?? '800');
    // Logo y firma ARCA 2026
    final logo = i['logoPath']?.toString();
    _logoPath = (logo == null || logo.isEmpty || logo == 'No disponible') ? null : logo;
    final firma = i['firmaPath']?.toString();
    _firmaPath = (firma == null || firma.isEmpty || firma == 'No disponible') ? null : firma;
  }

  void _prefillFromLegajoSanidad(Map<String, dynamic> l) {
    _nombreController.text = l['nombre']?.toString() ?? '';
    _cuilController.text = l['cuil']?.toString() ?? '';
    _puestoController.text = l['puesto']?.toString() ?? ''; // Cargar puesto
    final fi = l['fechaIngreso']?.toString();
    if (fi != null && fi.isNotEmpty) {
      final d = DateTime.tryParse(fi);
      if (d != null) _fechaIngreso = d;
    }
    final cat = l['categoria']?.toString();
    _categoria = CategoriaSanidad.values.cast<CategoriaSanidad?>().firstWhere(
        (e) => e?.name == cat, orElse: () => CategoriaSanidad.profesional) ?? CategoriaSanidad.profesional;
    final nt = l['nivelTitulo']?.toString();
    _nivelTitulo = NivelTituloSanidad.values.cast<NivelTituloSanidad?>().firstWhere(
        (e) => e?.name == nt, orElse: () => NivelTituloSanidad.sinTitulo) ?? NivelTituloSanidad.sinTitulo;
    _tareaCriticaRiesgo = l['tareaCriticaRiesgo'] == true;
    _cuotaSindicalAtsa = l['cuotaSindicalAtsa'] == true;
    _manejoEfectivoCaja = l['manejoEfectivoCaja'] == true;
    _horasNocturnasController.text = (l['horasNocturnas'] is int ? l['horasNocturnas'] as int : int.tryParse(l['horasNocturnas']?.toString() ?? '') ?? 0).toString();
    _codigoRnosController.text = l['codigoRnos']?.toString() ?? '';
    _cantidadFamiliaresController.text = (l['cantidadFamiliares'] is int ? l['cantidadFamiliares'] as int : int.tryParse(l['cantidadFamiliares']?.toString() ?? '') ?? 0).toString();
  }

  Future<void> _guardarLegajoSanidad() async {
    final cuit = _institucionSeleccionadaCuit;
    if (cuit == null || cuit.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Seleccione una institución')));
      return;
    }
    final cuilEmp = _cuilController.text.replaceAll(RegExp(r'[^\d]'), '');
    if (cuilEmp.length != 11) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('CUIL debe tener 11 dígitos')));
      return;
    }
    await InstitucionesService.saveLegajoSanidad(cuit, {
      'nombre': _nombreController.text.trim(),
      'cuil': _cuilController.text.trim(),
      'puesto': _puestoController.text.trim().isEmpty ? null : _puestoController.text.trim(), // Guardar puesto
      'fechaIngreso': DateFormat('yyyy-MM-dd').format(_fechaIngreso),
      'categoria': _categoria.name,
      'nivelTitulo': _nivelTitulo.name,
      'tareaCriticaRiesgo': _tareaCriticaRiesgo,
      'cuotaSindicalAtsa': _cuotaSindicalAtsa,
      'horasNocturnas': int.tryParse(_horasNocturnasController.text) ?? 0,
      'manejoEfectivoCaja': _manejoEfectivoCaja,
      'codigoRnos': _codigoRnosController.text.trim().isEmpty ? null : _codigoRnosController.text.trim(),
      'cantidadFamiliares': int.tryParse(_cantidadFamiliaresController.text) ?? 0,
      'codigoActividad': _codigoActividadController.text.trim(),
      'codigoPuesto': _codigoPuestoController.text.trim(),
    });
    await _cargarLegajosSanidad();
    if (!mounted) return;
    setState(() => _legajoSeleccionadoCuil = cuilEmp);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Legajo guardado')));
  }

  Future<void> _eliminarLegajoSanidad() async {
    final cuit = _institucionSeleccionadaCuit;
    final cuilEmp = _legajoSeleccionadoCuil ?? _cuilController.text.replaceAll(RegExp(r'[^\d]'), '');
    if (cuit == null || cuilEmp.isEmpty) return;
    final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      title: const Text('Eliminar legajo'),
      content: const Text('¿Eliminar este empleado de la lista de legajos?'),
      actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')), TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Eliminar'))],
    ));
    if (ok != true || !mounted) return;
    await InstitucionesService.removeLegajoSanidad(cuit, cuilEmp);
    await _cargarLegajosSanidad();
    if (!mounted) return;
    setState(() {
      _legajoSeleccionadoCuil = null;
      _nombreController.clear();
      _cuilController.clear();
      _codigoRnosController.clear();
      _cantidadFamiliaresController.text = '0';
      _horasNocturnasController.text = '0';
      _manejoEfectivoCaja = false;
      _fechaIngreso = DateTime.now().subtract(const Duration(days: 365 * 5));
      _categoria = CategoriaSanidad.profesional;
      _nivelTitulo = NivelTituloSanidad.sinTitulo;
      _tareaCriticaRiesgo = false;
      _cuotaSindicalAtsa = false;
    });
    _recalcular();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Legajo eliminado')));
  }

  /// Abre el escáner de recibos (OCR + QR) para cargar datos automáticamente
  Future<void> _abrirEscanerRecibo() async {
    final resultado = await Navigator.push(
      context,
      MaterialPageRoute(builder: (c) => const SanidadReceiptScanScreen()),
    );
    
    if (resultado == null || !mounted) return;
    
    // Resultado viene del OcrReviewScreen: Map con datos extraídos
    if (resultado is Map<String, dynamic>) {
      setState(() {
        if (resultado['cuil'] != null) {
          _cuilController.text = resultado['cuil'].toString();
        }
        if (resultado['nombre'] != null) {
          _nombreController.text = resultado['nombre'].toString();
        }
        if (resultado['categoria'] != null) {
          final catName = resultado['categoria'].toString();
          _categoria = CategoriaSanidad.values.cast<CategoriaSanidad?>().firstWhere(
            (e) => e?.name == catName,
            orElse: () => CategoriaSanidad.profesional,
          ) ?? CategoriaSanidad.profesional;
        }
        if (resultado['nivelTitulo'] != null) {
          final nivelName = resultado['nivelTitulo'].toString();
          _nivelTitulo = NivelTituloSanidad.values.cast<NivelTituloSanidad?>().firstWhere(
            (e) => e?.name == nivelName,
            orElse: () => NivelTituloSanidad.sinTitulo,
          ) ?? NivelTituloSanidad.sinTitulo;
        }
        if (resultado['horasNocturnas'] != null) {
          _horasNocturnasController.text = resultado['horasNocturnas'].toString();
        }
        // Note: sueldoBasico y antiguedadPct del OCR son informativos,
        // el sistema los recalcula según la categoría y fecha de ingreso
      });
      _recalcular();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Datos cargados desde recibo escaneado'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.glassFillStrong, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.glassBorder)), child: const Icon(Icons.arrow_back, color: AppColors.textPrimary)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Liquidación Sanidad 2026', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
        actions: [
          // Botón STRESS TEST - bien visible
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
                ),
                child: const Icon(Icons.bug_report, color: Colors.orange, size: 20),
              ),
              tooltip: 'Cargar datos de PRUEBA',
              onPressed: _cargarDatosStressTest,
            ),
          ),
          // Botón Ajustes Locales (Paritarias)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.teal.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.teal.withValues(alpha: 0.5)),
                ),
                child: const Icon(Icons.settings, color: Colors.tealAccent, size: 20),
              ),
              tooltip: 'Ajustes Locales (Paritarias)',
              onPressed: _handleAbrirMaestro,
            ),
          ),
          // Botón de Ayuda
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
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
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildBannerSincronizacion(),
          _buildInstitucionesSection(),
          if (_institucionSeleccionadaCuit != null) ...[
            const SizedBox(height: 24),
            _buildSelectorPeriodoYModo(),
            const SizedBox(height: 24),
            _buildDatosEmpleado(),
            const SizedBox(height: 24),
            _buildSimuladorNeto(),
            if (_resultado != null) ...[
              const SizedBox(height: 24),
              _buildDetalleLiquidacion(_resultado!),
              const SizedBox(height: 24),
              _buildPanelCostoEmpleador(),
            ],
          ],
        ],
      ),
      persistentFooterButtons: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Fila 0: Instructivo ARCA (Ayuda previa a exportación)
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: _mostrarInstructivoArca,
                  icon: const Icon(Icons.info_outline, size: 18, color: Colors.teal),
                  label: const Text('Instructivo ARCA: Asociación de Conceptos (Leer antes de subir)'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.teal,
                    padding: EdgeInsets.zero,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              // Fila 1: Exportar individual
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
              // Fila 1b: Exportar Asiento y Libro Sueldos
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _resultado != null ? _exportarAsiento : null,
                      icon: const Icon(Icons.account_balance_wallet, size: 20),
                      label: const Text('Asiento CSV'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _exportarLibroSueldosExcel(), // Habilitar siempre para masivo
                      icon: const Icon(Icons.table_view, size: 20),
                      label: const Text('Libro Excel'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Fila 2: Exportación masiva
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _legajosSanidad.isNotEmpty ? _exportarLsdMasivo : null,
                      icon: _exportandoMasivo 
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.file_copy, size: 18),
                      label: Text('LSD Todos (${_legajosSanidad.length})'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.teal,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _legajosSanidad.isNotEmpty ? _generarPackARCA : null,
                      icon: _exportandoMasivo 
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.folder_zip, size: 18),
                      label: const Text('Pack ARCA ZIP'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.teal,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInstitucionesSection() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: AppColors.glassFillStrong, borderRadius: BorderRadius.circular(24), border: Border.all(color: AppColors.glassBorder, width: 1)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Instituciones', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Cartel de pruebas y botón para cargar datos de prueba de estrés
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.pastelOrange.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.pastelOrange, width: 1),
                        ),
                        child: const Text(
                          'Realiza pruebas',
                          style: TextStyle(
                            color: AppColors.pastelOrange,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.bug_report, color: AppColors.pastelOrange),
                        tooltip: 'Cargar datos de prueba (STRESS TEST)',
                        onPressed: _cargarDatosStressTest,
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline, color: AppColors.textPrimary),
                        onPressed: () async {
                          final r = await Navigator.push(context, MaterialPageRoute(builder: (c) => const InstitucionFormScreen()));
                          if (r == true && mounted) await _cargarInstituciones();
                        },
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_instituciones.isEmpty)
                const Padding(padding: EdgeInsets.all(16), child: Text('No hay instituciones. Toca + para crear una.', style: TextStyle(color: AppColors.textSecondary)))
              else
                ..._instituciones.map((e) {
                  final cuit = (e['cuit']?.toString() ?? '').replaceAll(RegExp(r'[^\d]'), '');
                  final razon = e['razonSocial']?.toString() ?? cuit;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(color: AppColors.glassFill, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.glassBorder, width: 1)),
                    child: ListTile(
                      leading: const CircleAvatar(backgroundColor: AppColors.glassFillStrong, child: Icon(Icons.local_hospital, color: AppColors.textSecondary)),
                      title: Text(razon, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
                      subtitle: Text('CUIT: ${e['cuit'] ?? ''}', style: const TextStyle(color: AppColors.textSecondary)),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        TextButton.icon(
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => ListaLegajosSanidadScreen(cuit: cuit, razonSocial: razon))),
                          icon: const Icon(Icons.people, color: AppColors.pastelBlue, size: 18),
                          label: const Text('Ver legajos', style: TextStyle(fontSize: 12, color: AppColors.pastelBlue)),
                          style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8), minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                        ),
                        TextButton.icon(
                          onPressed: () async {
                            final r = await Navigator.push(context, MaterialPageRoute(builder: (c) => InstitucionFormScreen(institucion: e)));
                            if (r == true && mounted) {
                              await _cargarInstituciones();
                              if (_institucionSeleccionadaCuit == cuit) {
                                final L = _instituciones.where((x) => (x['cuit']?.toString() ?? '').replaceAll(RegExp(r'[^\d]'), '') == cuit).toList();
                                if (L.isNotEmpty) _prefillFromInstitucion(L.first);
                                setState(() {});
                              }
                            }
                          },
                          icon: const Icon(Icons.edit, color: AppColors.textPrimary, size: 18),
                          label: const Text('Editar', style: TextStyle(fontSize: 12, color: AppColors.textPrimary)),
                          style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8), minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                        ),
                        IconButton(icon: const Icon(Icons.delete, color: AppColors.textSecondary, size: 20), tooltip: 'Eliminar', onPressed: () => _eliminarInstitucionPorCuit(cuit)),
                      ]),
                      onTap: () {
                        _prefillFromInstitucion(e);
                        setState(() { _institucionSeleccionadaCuit = cuit; _legajoSeleccionadoCuil = null; });
                        _cargarLegajosSanidad().then((_) { if (mounted) setState(() {}); });
                      },
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }

  /// Dropdown de empleado (legajo sanidad) para seleccionar y prefill — mismo patrón que Teacher.
  Widget _buildDropdownEmpleado() {
    final itemValues = <String?>[null];
    final items = <DropdownMenuItem<String?>>[
      const DropdownMenuItem<String?>(value: null, child: Text('+ Nuevo empleado')),
      ..._legajosSanidad.asMap().entries.map((entry) {
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
      key: ValueKey('empleado_${valorValido ? _legajoSeleccionadoCuil : "null"}'),
      initialValue: valorValido ? _legajoSeleccionadoCuil : null,
      decoration: const InputDecoration(labelText: 'Empleado (legajo)', prefixIcon: Icon(Icons.person)),
      items: items,
      onChanged: (value) {
        if (value == null) {
          setState(() {
            _legajoSeleccionadoCuil = null;
            _nombreController.clear();
            _cuilController.clear();
            _codigoRnosController.clear();
            _cantidadFamiliaresController.text = '0';
            _horasNocturnasController.text = '0';
            _manejoEfectivoCaja = false;
            _fechaIngreso = DateTime.now().subtract(const Duration(days: 365 * 5));
            _categoria = CategoriaSanidad.profesional;
            _nivelTitulo = NivelTituloSanidad.sinTitulo;
            _tareaCriticaRiesgo = false;
            _cuotaSindicalAtsa = false;
          });
          _recalcular();
        } else {
          Map<String, dynamic>? legajo;
          if (value.startsWith('legajo_')) {
            final idx = int.tryParse(value.replaceFirst('legajo_', ''));
            if (idx != null && idx >= 0 && idx < _legajosSanidad.length) legajo = _legajosSanidad[idx];
          } else {
            final list = _legajosSanidad.where((e) => (e['cuil']?.toString() ?? '').replaceAll(RegExp(r'[^\d]'), '') == value).toList();
            if (list.isNotEmpty) legajo = list.first;
          }
          if (legajo != null) {
            try { _prefillFromLegajoSanidad(legajo); } catch (_) { /* datos inesperados */ }
          }
          setState(() => _legajoSeleccionadoCuil = value);
          _recalcular();
        }
      },
    );
  }

  Widget _buildDatosEmpleado() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Datos del Empleado', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            if (_institucionSeleccionadaCuit != null) ...[
              _buildDropdownEmpleado(),
              const SizedBox(height: 8),
              Row(
                children: [
                  FilledButton.icon(
                    onPressed: _guardarLegajoSanidad,
                    icon: const Icon(Icons.save, size: 18),
                    label: const Text('Guardar legajo'),
                  ),
                  if (_legajoSeleccionadoCuil != null) ...[
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: _eliminarLegajoSanidad,
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('Eliminar legajo'),
                    ),
                  ],
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _abrirEscanerRecibo,
                    icon: const Icon(Icons.qr_code_scanner, size: 18),
                    label: const Text('Escanear recibo'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.pastelMint,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _nombreController,
              decoration: const InputDecoration(labelText: 'Nombre', prefixIcon: Icon(Icons.person_outline)),
              onChanged: (_) => _recalcular(),
            ),
            TextField(
              controller: _cuilController,
              decoration: InputDecoration(
                labelText: 'CUIL',
                prefixIcon: const Icon(Icons.badge_outlined),
                suffixIcon: _cuilController.text.isNotEmpty 
                    ? Icon(
                        _validarCuil(_cuilController.text) ? Icons.check_circle : Icons.error,
                        color: _validarCuil(_cuilController.text) ? Colors.green : Colors.red,
                        size: 20,
                      )
                    : null,
                errorText: _cuilController.text.isNotEmpty && !_validarCuil(_cuilController.text) 
                    ? 'CUIL inválido (verificar dígito)' 
                    : null,
              ),
              keyboardType: TextInputType.number,
              maxLength: 11,
              onChanged: (_) {
                setState(() {}); // Para actualizar el icono
                _recalcular();
              },
            ),
            TextField(
              controller: _puestoController,
              decoration: const InputDecoration(
                labelText: 'Puesto / Cargo (ej: Enfermero, Camillero...)',
                prefixIcon: Icon(Icons.work_outline),
                helperText: 'Aparece en el recibo de sueldo',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<CategoriaSanidad>(
              initialValue: _categoria,
              decoration: const InputDecoration(labelText: 'Categoría', prefixIcon: Icon(Icons.work_outline)),
              items: SanidadNomenclador2026.items.map((e) {
                return DropdownMenuItem(
                  value: e.categoria,
                  child: Text('${e.descripcion} (\$${e.basico.toStringAsFixed(0)})'),
                );
              }).toList(),
              onChanged: (v) {
                if (v != null) {
                  setState(() => _categoria = v);
                  _recalcular();
                }
              },
            ),
            DropdownButtonFormField<NivelTituloSanidad>(
              initialValue: _nivelTitulo,
              decoration: const InputDecoration(
                labelText: 'Nivel de Título',
                prefixIcon: Icon(Icons.school_outlined),
                helperText: 'Universitario 10%, Técnico 7%, Auxiliar 5%',
              ),
              items: const [
                DropdownMenuItem(value: NivelTituloSanidad.sinTitulo, child: Text('Sin título (0%)')),
                DropdownMenuItem(value: NivelTituloSanidad.auxiliar, child: Text('Auxiliar (5%)')),
                DropdownMenuItem(value: NivelTituloSanidad.tecnico, child: Text('Técnico (7%)')),
                DropdownMenuItem(value: NivelTituloSanidad.universitario, child: Text('Universitario (10%)')),
              ],
              onChanged: (v) {
                if (v != null) {
                  setState(() => _nivelTitulo = v);
                  _recalcular();
                }
              },
            ),
            SwitchListTile(
              title: const Text('Tarea Crítica / Riesgo'),
              subtitle: const Text('10% sobre básico'),
              value: _tareaCriticaRiesgo,
              onChanged: (v) {
                setState(() => _tareaCriticaRiesgo = v);
                _recalcular();
              },
            ),
            SwitchListTile(
              title: const Text('Cuota Sindical ATSA'),
              subtitle: const Text('2% opcional'),
              value: _cuotaSindicalAtsa,
              onChanged: (v) {
                setState(() => _cuotaSindicalAtsa = v);
                _recalcular();
              },
            ),
            TextField(
              controller: _horasNocturnasController,
              decoration: const InputDecoration(
                labelText: 'Horas Nocturnas',
                prefixIcon: Icon(Icons.nightlight_round),
                helperText: '((Sueldo Básico/200)*0.15)*horas. Franja 22 a 6 hs.',
              ),
              keyboardType: TextInputType.number,
              onChanged: (_) => _recalcular(),
            ),
            if (_categoria == CategoriaSanidad.administrativo)
              SwitchListTile(
                title: const Text('Manejo de Efectivo / Cobranzas'),
                subtitle: Text('Fallo de Caja (\$${montoFalloCaja2026.toStringAsFixed(0)})'),
                value: _manejoEfectivoCaja,
                onChanged: (v) {
                  setState(() => _manejoEfectivoCaja = v);
                  _recalcular();
                },
              ),
            ListTile(
              title: const Text('Fecha de ingreso'),
              subtitle: Text(DateFormat('dd/MM/yyyy').format(_fechaIngreso)),
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _fechaIngreso,
                  firstDate: DateTime(1950),
                  lastDate: DateTime.now(),
                );
                if (d != null) {
                  setState(() => _fechaIngreso = d);
                  _recalcular();
                }
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _codigoRnosController,
                    decoration: const InputDecoration(
                      labelText: 'Código RNOS (Obra Social)',
                      prefixIcon: Icon(Icons.medical_services_outlined),
                    ),
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
            const SizedBox(height: 12),
            TextField(
              controller: _cantidadFamiliaresController,
              decoration: const InputDecoration(labelText: 'Cantidad de familiares a cargo'),
              keyboardType: TextInputType.number,
              onChanged: (_) => _recalcular(),
            ),
            
            // === SECCIÓN HORAS EXTRAS ===
            const SizedBox(height: 16),
            ExpansionTile(
              title: Row(
                children: [
                  const Icon(Icons.access_time, size: 20, color: Colors.orange),
                  const SizedBox(width: 8),
                  const Text('Horas Extras', style: TextStyle(fontWeight: FontWeight.bold)),
                  if (_resultado != null && _resultado!.totalHorasExtras > 0)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Chip(
                        label: Text('\$${_resultado!.totalHorasExtras.toStringAsFixed(0)}', style: const TextStyle(fontSize: 11)),
                        backgroundColor: Colors.orange.withValues(alpha: 0.2),
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                ],
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _horasExtras50Controller,
                          decoration: const InputDecoration(
                            labelText: 'Horas 50%',
                            helperText: 'Días hábiles',
                            prefixIcon: Icon(Icons.schedule),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (_) => _recalcular(),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: _horasExtras100Controller,
                          decoration: const InputDecoration(
                            labelText: 'Horas 100%',
                            helperText: 'Feriados/Nocturnos',
                            prefixIcon: Icon(Icons.nights_stay),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (_) => _recalcular(),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            // === SECCIÓN ADELANTOS Y DESCUENTOS ===
            ExpansionTile(
              title: Row(
                children: [
                  const Icon(Icons.money_off, size: 20, color: Colors.red),
                  const SizedBox(width: 8),
                  const Text('Adelantos y Descuentos', style: TextStyle(fontWeight: FontWeight.bold)),
                  if (_resultado != null && _resultado!.totalDescuentosAdicionales > 0)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Chip(
                        label: Text('-\$${_resultado!.totalDescuentosAdicionales.toStringAsFixed(0)}', style: const TextStyle(fontSize: 11, color: Colors.red)),
                        backgroundColor: Colors.red.withValues(alpha: 0.1),
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                ],
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _adelantosController,
                              decoration: const InputDecoration(
                                labelText: 'Adelantos',
                                prefixIcon: Icon(Icons.payments),
                                prefixText: '\$ ',
                              ),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              onChanged: (_) => _recalcular(),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextField(
                              controller: _embargosController,
                              decoration: const InputDecoration(
                                labelText: 'Embargos',
                                prefixIcon: Icon(Icons.gavel),
                                prefixText: '\$ ',
                              ),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              onChanged: (_) => _recalcular(),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _prestamosController,
                        decoration: const InputDecoration(
                          labelText: 'Préstamos / Cuotas',
                          prefixIcon: Icon(Icons.account_balance),
                          prefixText: '\$ ',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (_) => _recalcular(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            // === SECCIÓN DATOS ARCA (CBU, Domicilio, Modalidad) ===
            ExpansionTile(
              title: Row(
                children: [
                  const Icon(Icons.verified, size: 20, color: Colors.teal),
                  const SizedBox(width: 8),
                  const Text('Datos ARCA / LSD', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Datos bancarios', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _cbuController,
                        decoration: InputDecoration(
                          labelText: 'CBU',
                          helperText: '22 dígitos',
                          prefixIcon: const Icon(Icons.account_balance_wallet),
                          suffixIcon: _cbuController.text.isNotEmpty
                              ? (ValidacionesARCA.validarCBU(_cbuController.text)
                                  ? const Icon(Icons.check_circle, color: Colors.green)
                                  : const Icon(Icons.error, color: Colors.red))
                              : null,
                          errorText: _cbuController.text.isNotEmpty && 
                                     !ValidacionesARCA.validarCBU(_cbuController.text)
                              ? 'CBU inválido (debe ser 22 dígitos)'
                              : null,
                        ),
                        keyboardType: TextInputType.number,
                        maxLength: 22,
                        onChanged: (_) => setState(() {}), // Para actualizar el icono
                      ),
                      const SizedBox(height: 12),
                      const Text('Domicilio del empleado', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _domicilioEmpleadoController,
                        decoration: const InputDecoration(
                          labelText: 'Domicilio',
                          prefixIcon: Icon(Icons.home),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: _localidadController,
                              decoration: const InputDecoration(
                                labelText: 'Localidad',
                                prefixIcon: Icon(Icons.location_city),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextField(
                              controller: _codigoPostalController,
                              decoration: const InputDecoration(
                                labelText: 'CP',
                                prefixIcon: Icon(Icons.pin_drop),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text('Modalidad de contratación AFIP', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _modalidadContratacion,
                              decoration: const InputDecoration(
                                labelText: 'Modalidad',
                                isDense: true,
                              ),
                              items: const [
                                DropdownMenuItem(value: '008', child: Text('Tiempo Indeterminado')),
                                DropdownMenuItem(value: '003', child: Text('Plazo Fijo')),
                                DropdownMenuItem(value: '004', child: Text('Eventual')),
                                DropdownMenuItem(value: '005', child: Text('Temporada')),
                                DropdownMenuItem(value: '010', child: Text('Aprendizaje')),
                                DropdownMenuItem(value: '011', child: Text('Pasantía')),
                              ],
                              onChanged: (v) {
                                if (v != null) setState(() => _modalidadContratacion = v);
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _situacionRevista,
                              decoration: const InputDecoration(
                                labelText: 'Situación',
                                isDense: true,
                              ),
                              items: const [
                                DropdownMenuItem(value: '01', child: Text('Activo')),
                                DropdownMenuItem(value: '02', child: Text('Licencia Enfermedad')),
                                DropdownMenuItem(value: '03', child: Text('Licencia Maternidad')),
                                DropdownMenuItem(value: '04', child: Text('Licencia Sin Goce')),
                                DropdownMenuItem(value: '05', child: Text('Suspendido')),
                                DropdownMenuItem(value: '06', child: Text('Baja')),
                                DropdownMenuItem(value: '07', child: Text('Vacaciones')),
                                DropdownMenuItem(value: '08', child: Text('Accidente Trabajo')),
                              ],
                              onChanged: (v) {
                                if (v != null) setState(() => _situacionRevista = v);
                              },
                            ),
                          ),
                        ],
                      ),
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
            
            // Leyenda informativa sobre origen de datos
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, size: 18, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Origen de los datos',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Los cálculos se basan en las escalas salariales FATSA CCT 122/75 para ${_getJurisdiccionNombre()}. '
                    'Puede editar estos valores en "Ajustes Locales (Paritarias Sanidad)" para adaptarlos a su institución (público/privado) o acuerdos específicos.',
                    style: TextStyle(fontSize: 12, color: Colors.blue.shade800),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () {
                      _mostrarModalMaestroSanidad();
                    },
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('Editar escalas salariales', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
            
            if (_esZonaPatagonica) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade700),
                ),
                child: Row(
                  children: [
                    Icon(Icons.map, size: 18, color: Colors.amber.shade800),
                    const SizedBox(width: 8),
                    Text('Zona Patagónica Detectada: +20% aplicado', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.amber.shade900)),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 8),
            if (_calculando)
              const CircularProgressIndicator()
            else if (_resultado != null)
              Text(
                'Neto a cobrar: \$${_resultado!.netoACobrar.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              )
            else
              const Text('Complete nombre y CUIL para simular.'),
          ],
        ),
      ),
    );
  }
  
  String _getJurisdiccionNombre() {
    final jurisdiccionesMap = {
      Jurisdiccion.buenosAires: 'Buenos Aires',
      Jurisdiccion.caba: 'CABA',
      Jurisdiccion.catamarca: 'Catamarca',
      Jurisdiccion.chaco: 'Chaco',
      Jurisdiccion.chubut: 'Chubut',
      Jurisdiccion.cordoba: 'Córdoba',
      Jurisdiccion.corrientes: 'Corrientes',
      Jurisdiccion.entreRios: 'Entre Ríos',
      Jurisdiccion.formosa: 'Formosa',
      Jurisdiccion.jujuy: 'Jujuy',
      Jurisdiccion.laPampa: 'La Pampa',
      Jurisdiccion.laRioja: 'La Rioja',
      Jurisdiccion.mendoza: 'Mendoza',
      Jurisdiccion.misiones: 'Misiones',
      Jurisdiccion.neuquen: 'Neuquén',
      Jurisdiccion.rioNegro: 'Río Negro',
      Jurisdiccion.salta: 'Salta',
      Jurisdiccion.sanJuan: 'San Juan',
      Jurisdiccion.sanLuis: 'San Luis',
      Jurisdiccion.santaCruz: 'Santa Cruz',
      Jurisdiccion.santaFe: 'Santa Fe',
      Jurisdiccion.santiagoDelEstero: 'Santiago del Estero',
      Jurisdiccion.tierraDelFuego: 'Tierra del Fuego',
      Jurisdiccion.tucuman: 'Tucumán',
    };
    return jurisdiccionesMap[_jurisdiccion] ?? _jurisdiccion.name;
  }

  Widget _buildDetalleLiquidacion(LiquidacionSanidadResult r) {
    return ExpansionTile(
      title: Row(
        children: [
          const Text('Detalle liquidación'),
          const SizedBox(width: 8),
          if (r.modo != ModoLiquidacionSanidad.mensual)
            Chip(
              label: Text(
                r.modo == ModoLiquidacionSanidad.sac ? 'SAC' 
                  : r.modo == ModoLiquidacionSanidad.vacaciones ? 'Vacaciones' 
                  : 'Liq. Final',
                style: const TextStyle(fontSize: 10, color: Colors.white),
              ),
              backgroundColor: r.modo == ModoLiquidacionSanidad.liquidacionFinal ? Colors.red : Colors.teal,
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
      initiallyExpanded: true,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('HABERES REMUNERATIVOS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 8),
              _row('Sueldo básico', r.sueldoBasico),
              if (r.adicionalAntiguedad > 0) _row('Antigüedad', r.adicionalAntiguedad),
              if (r.adicionalTitulo > 0) _row('Adicional Título', r.adicionalTitulo),
              if (r.adicionalTareaCriticaRiesgo > 0) _row('Tarea Crítica/Riesgo', r.adicionalTareaCriticaRiesgo),
              if (r.adicionalZonaPatagonica > 0) _row('Plus Zona Desfavorable (Patagonia 20%)', r.adicionalZonaPatagonica),
              if (r.nocturnidad > 0) _row('Horas Nocturnas', r.nocturnidad),
              if (r.falloCaja > 0) _row('Fallo de Caja', r.falloCaja),
              // Horas extras
              if (r.horasExtras50Monto > 0) _row('Horas Extras 50%', r.horasExtras50Monto),
              if (r.horasExtras100Monto > 0) _row('Horas Extras 100%', r.horasExtras100Monto),
              // SAC
              if (r.sac > 0) _row('SAC (${r.diasSACCalculados >= 180 ? "Completo" : "${r.diasSACCalculados} días"})', r.sac),
              // Vacaciones
              if (r.vacaciones > 0) _row('Vacaciones (${r.diasVacacionesCalculados} días)', r.vacaciones),
              if (r.plusVacacional > 0) _row('Plus Vacacional', r.plusVacacional),
              if (r.vacacionesNoGozadas > 0) _row('Vacaciones No Gozadas', r.vacacionesNoGozadas),
              if (r.sacSobreVacaciones > 0) _row('SAC sobre Vacaciones', r.sacSobreVacaciones),
              if (r.sacSobrePreaviso > 0) _row('SAC sobre Preaviso', r.sacSobrePreaviso),
              const Divider(),
              _row('Total bruto remunerativo', r.totalBrutoRemunerativo, bold: true),
              
              // No remunerativos (indemnización)
              if (r.totalNoRemunerativo > 0) ...[
                const SizedBox(height: 12),
                const Text('NO REMUNERATIVOS (INDEMNIZACIÓN)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.orange)),
                const SizedBox(height: 8),
                if (r.indemnizacionArt245 > 0) _row('Indemnización Art. 245 LCT', r.indemnizacionArt245),
                if (r.preaviso > 0) _row('Preaviso', r.preaviso),
                if (r.integracionMes > 0) _row('Integración Mes Despido', r.integracionMes),
                const Divider(),
                _row('Total no remunerativo', r.totalNoRemunerativo, bold: true),
              ],
              
              const SizedBox(height: 12),
              const Text('DESCUENTOS LEGALES', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.red)),
              const SizedBox(height: 8),
              _row('Jubilación (11%)', -r.aporteJubilacion),
              _row('Ley 19.032 (3%)', -r.aporteLey19032),
              _row('Obra Social (3%)', -r.aporteObraSocial),
              if (r.cuotaSindicalAtsa > 0) _row('Cuota Sindical ATSA (2%)', -r.cuotaSindicalAtsa),
              _row('Seguro de Sepelio (1%)', -r.seguroSepelio),
              _row('Aporte Solidario FATSA (1%)', -r.aporteSolidarioFatsa),
              
              // Otros descuentos
              if (r.adelantos > 0 || r.embargos > 0 || r.prestamos > 0 || r.otrosDescuentos > 0) ...[
                const SizedBox(height: 8),
                const Text('OTROS DESCUENTOS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.red)),
                if (r.adelantos > 0) _row('Adelantos', -r.adelantos),
                if (r.embargos > 0) _row('Embargos', -r.embargos),
                if (r.prestamos > 0) _row('Préstamos', -r.prestamos),
                if (r.otrosDescuentos > 0) _row('Otros', -r.otrosDescuentos),
              ],
              
              const Divider(),
              _row('Total descuentos', -r.totalDescuentos, bold: true),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade300, width: 2),
                ),
                child: _row('NETO A COBRAR', r.netoACobrar, bold: true),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _row(String label, double value, {bool bold = false}) {
    return Padding(
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

  Widget _buildPanelCostoEmpleador() {
    if (_resultado == null) return const SizedBox.shrink();
    final artPct = double.tryParse(_artPctController.text.replaceAll(',', '.')) ?? 3.5;
    final artCuotaFija = double.tryParse(_artCuotaFijaController.text.replaceAll(',', '.')) ?? 800;
    final costo = calcularCostoPatronal(_resultado!.totalBrutoRemunerativo, artPct: artPct, artCuotaFija: artCuotaFija);
    return ExpansionTile(
      initiallyExpanded: false,
      title: Row(
        children: [
          const Expanded(child: Text('Análisis de Costo Empleador (Solo para la Empresa)')),
          Tooltip(
            message: 'El Costo Laboral Real incluye la reserva mensual obligatoria para el pago de Aguinaldo y Vacaciones, incluyendo sus respectivas cargas sociales patronales. Este es el gasto real de mantener el puesto de trabajo mes a mes.',
            child: Icon(Icons.info_outline, size: 20, color: Colors.grey.shade600),
          ),
        ],
      ),
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _row('Sueldo Bruto', costo.sueldoBruto),
              _row('Contribuciones Patronales (30% total)', costo.contribucionesPatronalesTotal),
              _row('ART y Seguros', costo.artYSeguros),
              _row('Provisión SAC y Vacaciones', costo.provisionSACYVacaciones),
              _row('Cargas Sociales s/ Provisiones', costo.cargasSocialesSobreProvisiones),
              const Divider(),
              _row('TOTAL COSTO LABORAL REAL', costo.totalCostoLaboralReal, bold: true),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _exportarInformeCostos,
                icon: const Icon(Icons.download, size: 18),
                label: const Text('Exportar Informe de Costos'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _exportarInformeCostos() async {
    final r = _resultado;
    if (r == null) return;
    final artPct = double.tryParse(_artPctController.text.replaceAll(',', '.')) ?? 3.5;
    final artCuotaFija = double.tryParse(_artCuotaFijaController.text.replaceAll(',', '.')) ?? 800;
    final costo = calcularCostoPatronal(r.totalBrutoRemunerativo, artPct: artPct, artCuotaFija: artCuotaFija);
    final txt = generarInformeCostosTxt(
      empleado: _nombreController.text.trim(),
      cuil: _cuilController.text.trim(),
      institucion: _razonSocialController.text.trim(),
      periodo: r.periodo,
      costo: costo,
      convenio: 'Sanidad FATSA CCT 122/75 y 108/75',
    );
    try {
      final nom = _nombreController.text.trim().replaceAll(RegExp(r'[^\w\s]'), '').replaceAll(RegExp(r'\s+'), '_');
      final name = 'Informe_Costos_Sanidad_${nom.isEmpty ? "empleado" : nom}_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.txt';
      final filePath = await saveTextFile(fileName: name, content: txt, mimeType: 'text/plain');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Exportado: $name')));
      if (filePath != null) openFile(filePath);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al exportar: $e')));
    }
  }

  /// Liquida todos los empleados de la institución seleccionada
  Future<List<LiquidacionSanidadResult>> _liquidarTodos() async {
    final liquidaciones = <LiquidacionSanidadResult>[];
    
    for (final legajo in _legajosSanidad) {
      try {
        final input = SanidadEmpleadoInput(
          nombre: legajo['nombre']?.toString() ?? '',
          cuil: legajo['cuil']?.toString() ?? '',
          fechaIngreso: DateTime.tryParse(legajo['fechaIngreso']?.toString() ?? '') ?? DateTime.now(),
          categoria: CategoriaSanidad.values.firstWhere(
            (e) => e.name == legajo['categoria'], 
            orElse: () => CategoriaSanidad.profesional,
          ),
          nivelTitulo: NivelTituloSanidad.values.firstWhere(
            (e) => e.name == legajo['nivelTitulo'], 
            orElse: () => NivelTituloSanidad.sinTitulo,
          ),
          tareaCriticaRiesgo: legajo['tareaCriticaRiesgo'] == true,
          aplicarCuotaSindicalAtsa: legajo['cuotaSindicalAtsa'] == true,
          codigoRnos: legajo['codigoRnos']?.toString(),
          cantidadFamiliares: (legajo['cantidadFamiliares'] as num?)?.toInt() ?? 0,
          horasNocturnas: (legajo['horasNocturnas'] as num?)?.toInt() ?? 0,
          manejoEfectivoCaja: legajo['manejoEfectivoCaja'] == true,
          cbu: legajo['cbu']?.toString(),
          localidad: legajo['localidad']?.toString(),
          codigoPostal: legajo['codigoPostal']?.toString(),
          codigoModalidad: legajo['codigoModalidad']?.toString() ?? '008',
          codigoSituacion: legajo['codigoSituacion']?.toString() ?? '01',
        );
        
        final liq = SanidadOmniEngine.liquidar(
          input,
          periodo: DateFormat('MMMM yyyy', 'es_AR').format(_periodoSeleccionado),
          fechaPago: DateFormat('dd/MM/yyyy').format(_fechaPago),
          esZonaPatagonica: _esZonaPatagonica,
          jurisdiccion: _jurisdiccion.name,
          modo: _modoLiquidacion,
        );
        
        liquidaciones.add(liq);
      } catch (e) {
        print('Error liquidando ${legajo['nombre']}: $e');
      }
    }
    
    return liquidaciones;
  }

  /// Exporta LSD masivo de todos los empleados
  Future<void> _exportarLsdMasivo() async {
    if (_legajosSanidad.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay empleados para exportar')),
      );
      return;
    }
    
    setState(() => _exportandoMasivo = true);
    
    try {
      final liquidaciones = await _liquidarTodos();
      
      if (liquidaciones.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se pudo liquidar ningún empleado')),
          );
        }
        return;
      }
      
      final cuit = _cuitEmpresaController.text.replaceAll(RegExp(r'[^\d]'), '');
      final txt = await sanidadLsdMasivo(
        liquidaciones: liquidaciones,
        cuitEmpresa: cuit,
        razonSocial: _razonSocialController.text.trim(),
        domicilio: _domicilioController.text.trim(),
      );
      
      final periodoLimpio = DateFormat('yyyy_MM').format(_periodoSeleccionado);
      final name = 'LSD_Sanidad_Masivo_${periodoLimpio}_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.txt';
      final filePath = await saveTextFile(fileName: name, content: txt, mimeType: 'text/plain');
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('LSD exportado: ${liquidaciones.length} empleados')),
      );
      if (filePath != null) openFile(filePath);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _exportandoMasivo = false);
    }
  }

  /// Genera Pack ARCA completo: LSD + Recibos en ZIP
  Future<void> _generarPackARCA() async {
    if (_legajosSanidad.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay empleados para exportar')),
      );
      return;
    }
    
    setState(() => _exportandoMasivo = true);
    
    try {
      final liquidaciones = await _liquidarTodos();
      
      if (liquidaciones.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se pudo liquidar ningún empleado')),
          );
        }
        return;
      }
      
      final cuit = _cuitEmpresaController.text.replaceAll(RegExp(r'[^\d]'), '');
      
      // Cargar bytes de logo y firma para el pack masivo (multiplataforma)
      final logoBytesPack = await readImageBytes(_logoPath);
      final firmaBytesPack = await readImageBytes(_firmaPath);
      
      final zipPath = await generarPackARCASanidad(
        liquidaciones: liquidaciones,
        cuitEmpresa: cuit,
        razonSocial: _razonSocialController.text.trim(),
        domicilio: _domicilioController.text.trim(),
        generadorReciboPDF: (liq) async {
          // Generar PDF del recibo
          final catDesc = SanidadNomenclador2026.itemPorCategoria(liq.input.categoria)?.descripcion ?? liq.input.categoria.name;
          final empresa = Empresa(
            razonSocial: _razonSocialController.text.trim(),
            cuit: _cuitEmpresaController.text.trim(),
            domicilio: _domicilioController.text.trim(),
            convenioId: 'sanidad_fatsa_2026',
            convenioNombre: 'Sanidad FATSA CCT 122/75 y 108/75',
            convenioPersonalizado: false,
            categorias: [],
            parametros: [],
          );
          final empleado = Empleado(
            nombre: liq.input.nombre,
            categoria: catDesc,
            sueldoBasico: liq.sueldoBasico,
            periodo: liq.periodo,
            fechaPago: liq.fechaPago,
            fechaIngreso: DateFormat('yyyy-MM-dd').format(liq.input.fechaIngreso),
          );
          final conceptos = _buildConceptosParaPDF(liq);
          
          return await PdfRecibo.generarCompleto(
            empresa: empresa,
            empleado: empleado,
            conceptos: conceptos,
            sueldoBruto: liq.totalBrutoRemunerativo,
            totalDeducciones: liq.totalDescuentos,
            totalNoRemunerativo: liq.totalNoRemunerativo,
            sueldoNeto: liq.netoACobrar,
            logoBytes: logoBytesPack,
            firmaBytes: firmaBytesPack,
            incluirBloqueFirmaLey25506: true,
          );
        },
      );
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Pack ARCA generado: ${liquidaciones.length} empleados')),
      );
      if (zipPath.isNotEmpty) openFile(zipPath);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _exportandoMasivo = false);
    }
  }

  /// Construye lista de conceptos para PDF
  List<ConceptoParaPDF> _buildConceptosParaPDF(LiquidacionSanidadResult r) {
    return <ConceptoParaPDF>[
      ConceptoParaPDF(descripcion: 'Sueldo básico', remunerativo: r.sueldoBasico, noRemunerativo: 0, descuento: 0),
      if (r.adicionalAntiguedad > 0) ConceptoParaPDF(descripcion: 'Antigüedad', remunerativo: r.adicionalAntiguedad, noRemunerativo: 0, descuento: 0),
      if (r.adicionalTitulo > 0) ConceptoParaPDF(descripcion: 'Ad. Título', remunerativo: r.adicionalTitulo, noRemunerativo: 0, descuento: 0),
      if (r.adicionalTareaCriticaRiesgo > 0) ConceptoParaPDF(descripcion: 'Tarea Crítica/Riesgo', remunerativo: r.adicionalTareaCriticaRiesgo, noRemunerativo: 0, descuento: 0),
      if (r.adicionalZonaPatagonica > 0) ConceptoParaPDF(descripcion: 'Plus Zona Patagónica', remunerativo: r.adicionalZonaPatagonica, noRemunerativo: 0, descuento: 0),
      if (r.nocturnidad > 0) ConceptoParaPDF(descripcion: 'Horas Nocturnas', remunerativo: r.nocturnidad, noRemunerativo: 0, descuento: 0),
      if (r.falloCaja > 0) ConceptoParaPDF(descripcion: 'Fallo de Caja', remunerativo: r.falloCaja, noRemunerativo: 0, descuento: 0),
      if (r.horasExtras50Monto > 0) ConceptoParaPDF(descripcion: 'Horas Extras 50%', remunerativo: r.horasExtras50Monto, noRemunerativo: 0, descuento: 0),
      if (r.horasExtras100Monto > 0) ConceptoParaPDF(descripcion: 'Horas Extras 100%', remunerativo: r.horasExtras100Monto, noRemunerativo: 0, descuento: 0),
      if (r.sac > 0) ConceptoParaPDF(descripcion: 'SAC (Aguinaldo)', remunerativo: r.sac, noRemunerativo: 0, descuento: 0),
      if (r.vacaciones > 0) ConceptoParaPDF(descripcion: 'Vacaciones', remunerativo: r.vacaciones, noRemunerativo: 0, descuento: 0),
      if (r.plusVacacional > 0) ConceptoParaPDF(descripcion: 'Plus Vacacional', remunerativo: r.plusVacacional, noRemunerativo: 0, descuento: 0),
      if (r.vacacionesNoGozadas > 0) ConceptoParaPDF(descripcion: 'Vacaciones No Gozadas', remunerativo: r.vacacionesNoGozadas, noRemunerativo: 0, descuento: 0),
      if (r.indemnizacionArt245 > 0) ConceptoParaPDF(descripcion: 'Indemnización Art. 245', remunerativo: 0, noRemunerativo: r.indemnizacionArt245, descuento: 0),
      if (r.preaviso > 0) ConceptoParaPDF(descripcion: 'Preaviso', remunerativo: 0, noRemunerativo: r.preaviso, descuento: 0),
      if (r.integracionMes > 0) ConceptoParaPDF(descripcion: 'Integración Mes', remunerativo: 0, noRemunerativo: r.integracionMes, descuento: 0),
      ConceptoParaPDF(descripcion: 'Jubilación (11%)', remunerativo: 0, noRemunerativo: 0, descuento: r.aporteJubilacion),
      ConceptoParaPDF(descripcion: 'Ley 19.032 (3%)', remunerativo: 0, noRemunerativo: 0, descuento: r.aporteLey19032),
      ConceptoParaPDF(descripcion: 'Obra Social (3%)', remunerativo: 0, noRemunerativo: 0, descuento: r.aporteObraSocial),
      if (r.cuotaSindicalAtsa > 0) ConceptoParaPDF(descripcion: 'Cuota Sindical ATSA (2%)', remunerativo: 0, noRemunerativo: 0, descuento: r.cuotaSindicalAtsa),
      ConceptoParaPDF(descripcion: 'Seguro de Sepelio (1%)', remunerativo: 0, noRemunerativo: 0, descuento: r.seguroSepelio),
      ConceptoParaPDF(descripcion: 'Aporte Solidario FATSA (1%)', remunerativo: 0, noRemunerativo: 0, descuento: r.aporteSolidarioFatsa),
      if (r.adelantos > 0) ConceptoParaPDF(descripcion: 'Adelantos', remunerativo: 0, noRemunerativo: 0, descuento: r.adelantos),
      if (r.embargos > 0) ConceptoParaPDF(descripcion: 'Embargos', remunerativo: 0, noRemunerativo: 0, descuento: r.embargos),
      if (r.prestamos > 0) ConceptoParaPDF(descripcion: 'Préstamos', remunerativo: 0, noRemunerativo: 0, descuento: r.prestamos),
    ];
  }
  
  /// Guarda la liquidación en el historial
  Future<void> _guardarEnHistorial(LiquidacionSanidadResult r) async {
    try {
      final cuil = r.input.cuil.replaceAll(RegExp(r'[^\d]'), '');
      if (cuil.length != 11) return;
      
      // Crear detalle de conceptos para auditoría
      final detalleConceptos = <String, double>{
        'sueldoBasico': r.sueldoBasico,
        if (r.adicionalAntiguedad > 0) 'antiguedad': r.adicionalAntiguedad,
        if (r.adicionalTitulo > 0) 'titulo': r.adicionalTitulo,
        if (r.adicionalTareaCriticaRiesgo > 0) 'tareaCritica': r.adicionalTareaCriticaRiesgo,
        if (r.adicionalZonaPatagonica > 0) 'zonaPatagonica': r.adicionalZonaPatagonica,
        if (r.nocturnidad > 0) 'nocturnidad': r.nocturnidad,
        if (r.falloCaja > 0) 'falloCaja': r.falloCaja,
        if (r.horasExtras50Monto > 0) 'horasExtras50': r.horasExtras50Monto,
        if (r.horasExtras100Monto > 0) 'horasExtras100': r.horasExtras100Monto,
      };
      
      final registro = RegistroLiquidacion(
        empleadoCuil: cuil,
        empleadoNombre: r.input.nombre,
        modulo: 'sanidad',
        fecha: DateTime.now(),
        periodo: r.periodo,
        totalBrutoRemunerativo: r.totalBrutoRemunerativo,
        totalNoRemunerativo: r.totalNoRemunerativo,
        totalDescuentos: r.totalDescuentos,
        netoACobrar: r.netoACobrar,
        detalleConceptos: detalleConceptos,
        tipoLiquidacion: _modoLiquidacion == ModoLiquidacionSanidad.mensual ? 'mensual' :
                         _modoLiquidacion == ModoLiquidacionSanidad.sac ? 'sac' :
                         _modoLiquidacion == ModoLiquidacionSanidad.vacaciones ? 'vacaciones' : 'liquidacion_final',
      );
      
      await LiquidacionHistorialService.guardarLiquidacion(registro);
    } catch (e) {
      print('Error guardando historial: $e');
    }
  }
  
  /// Verifica saltos inusuales entre liquidaciones
  Future<void> _verificarSaltosInusuales(LiquidacionSanidadResult r) async {
    try {
      final cuil = r.input.cuil.replaceAll(RegExp(r'[^\d]'), '');
      if (cuil.length != 11) return;
      
      final tipoLiq = _modoLiquidacion == ModoLiquidacionSanidad.mensual ? 'mensual' :
                      _modoLiquidacion == ModoLiquidacionSanidad.sac ? 'sac' :
                      _modoLiquidacion == ModoLiquidacionSanidad.vacaciones ? 'vacaciones' : 'liquidacion_final';
      
      final salto = await LiquidacionHistorialService.detectarSaltoInusual(
        cuil,
        r.netoACobrar,
        tipoLiq,
      );
      
      if (salto != null && mounted) {
        final variacionPct = salto['variacionPct'] as double;
        final esAumento = salto['esAumento'] as bool;
        final netoAnterior = salto['netoAnterior'] as double;
        
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Row(
                children: [
                  Icon(esAumento ? Icons.trending_up : Icons.trending_down,
                       color: esAumento ? Colors.green : Colors.orange),
                  const SizedBox(width: 8),
                  const Text('Variación Inusual Detectada'),
                ],
              ),
              content: Text(
                'Se detectó una variación de ${variacionPct.toStringAsFixed(1)}% '
                '${esAumento ? 'superior' : 'inferior'} respecto a la liquidación anterior.\n\n'
                'Neto anterior: \$${netoAnterior.toStringAsFixed(2)}\n'
                'Neto actual: \$${r.netoACobrar.toStringAsFixed(2)}\n\n'
                '💡 Verifique que los datos ingresados sean correctos.',
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
    } catch (e) {
      print('Error verificando saltos inusuales: $e');
    }
  }
  
  /// Carga automáticamente la mejor remuneración de los últimos 6 meses
  Future<void> _cargarMejorRemuneracionAutomatica() async {
    try {
      final cuil = _cuilController.text.replaceAll(RegExp(r'[^\d]'), '');
      if (cuil.length != 11) return;
      
      final mejorRemu = await LiquidacionHistorialService.calcularMejorRemuneracion(cuil, meses: 6);
      
      if (mejorRemu != null && mejorRemu > 0) {
        setState(() {
          _mejorRemuneracionController.text = mejorRemu.toStringAsFixed(2);
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✓ Mejor remuneración cargada automáticamente: \$${mejorRemu.toStringAsFixed(2)}'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
        
        _recalcular();
      }
    } catch (e) {
      print('Error cargando mejor remuneración: $e');
    }
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _cuilController.dispose();
    _puestoController.dispose();
    _codigoRnosController.dispose();
    _cuitEmpresaController.dispose();
    _razonSocialController.dispose();
    _domicilioController.dispose();
    _cantidadFamiliaresController.dispose();
    _horasNocturnasController.dispose();
    _artPctController.dispose();
    _artCuotaFijaController.dispose();
    // Nuevos controladores ARCA 2026
    _cbuController.dispose();
    _localidadController.dispose();
    _codigoPostalController.dispose();
    _domicilioEmpleadoController.dispose();
    _codigoActividadController.dispose();
    _codigoPuestoController.dispose();
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
}
