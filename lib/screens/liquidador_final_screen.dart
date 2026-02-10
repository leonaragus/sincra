import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'dart:io';
import 'dart:ui';
import 'package:url_launcher/url_launcher.dart';
import '../utils/image_bytes_reader.dart';

import '../models/liquidacion.dart';
import '../models/empresa.dart';
import '../models/empleado.dart';
import '../models/cct_completo.dart';
import '../data/cct_argentina_completo.dart';
import '../theme/app_colors.dart';
import '../utils/pdf_recibo.dart';
import '../utils/validadores.dart';
import '../services/lsd_engine.dart';
import '../services/lsd_mapping_service.dart';
import '../services/excel_export_service.dart';
import '../models/parametros_legales.dart';
import '../services/parametros_legales_service.dart';
import '../services/antiguedad_service.dart';
import '../services/vacaciones_service.dart';
import '../services/hybrid_store.dart';
import 'empresa_screen.dart';
import 'empleado_screen.dart';

class LiquidadorFinalScreen extends StatefulWidget {
  const LiquidadorFinalScreen({super.key});

  @override
  State<LiquidadorFinalScreen> createState() => _LiquidadorFinalScreenState();
}

class _LiquidadorFinalScreenState extends State<LiquidadorFinalScreen> {
  // Listas de datos
  List<Map<String, String>> _empresas = [];
  List<Map<String, dynamic>> _empleados = [];
  
  // Selecciones
  String? _empresaSeleccionada;
  String? _empleadoSeleccionado;
  
  // Datos del empleado (solo lectura)
  Map<String, dynamic>? _datosEmpleado;
  double? _sueldoBasicoCategoria;
  
  // Controllers
  final _sueldoBasicoController = TextEditingController();
  final _periodoController = TextEditingController();
  final _fechaPagoController = TextEditingController();
  // Controllers para horas extras (cantidad de horas)
  final _cantidadHorasExtras50Controller = TextEditingController();
  final _cantidadHorasExtras100Controller = TextEditingController();
  // Montos calculados de horas extras (para mostrar en tiempo real)
  double _montoCalculadoHorasExtras50 = 0.0;
  double _montoCalculadoHorasExtras100 = 0.0;
  final _premiosController = TextEditingController();
  final _impuestoGananciasController = TextEditingController();
  final _diasInasistenciaController = TextEditingController();
  // Novedades específicas de CCT (ej. Camioneros)
  final _kilometrosRecorridosController = TextEditingController();
  final _diasViaticosComidaController = TextEditingController();
  final _diasPernocteController = TextEditingController();
  
  // Vacaciones
  final _diasVacacionesController = TextEditingController();
  final _montoVacacionesController = TextEditingController();
  final _fechaInicioVacacionesController = TextEditingController();
  final _fechaFinVacacionesController = TextEditingController();
  bool _vacacionesActivas = false;
  bool _vacacionesGozadas = true;
  String? _mensajeCalculoVacaciones;
  
  // Conceptos no remunerativos
  final List<Map<String, dynamic>> _conceptosNoRemunerativos = [];
  
  // Deducciones adicionales
  final List<Map<String, dynamic>> _deduccionesAdicionales = [];
  
  // === LOGO Y FIRMA DIGITAL (ARCA 2026) ===
  String? _logoPath;
  String? _firmaPath;
  
  // Flags
  bool _afiliadoSindical = false;
  bool _calcularGananciasAutomatico = true;
  bool _presentismoActivo = true; // Por defecto activado
  int _diasInasistencia = 0;
  double _porcentajePresentismo = 8.33; // Por defecto 8.33%
  String? _pdfConvenioUrl; // URL del PDF del convenio seleccionado

  // Liquidación
  Liquidacion? _liquidacion;
  
  // Cachear Future de parámetros legales para evitar recrearlo en cada build
  late final Future<ParametrosLegales> _parametrosLegalesFuture;
  
  @override
  void initState() {
    super.initState();
    _parametrosLegalesFuture = ParametrosLegalesService.cargarParametros();
    _cargarEmpresas();
    // Fecha de pago se deja vacía para que el usuario la complete
    _periodoController.text = _obtenerPeriodoActual();
  }
  
  @override
  void dispose() {
    _sueldoBasicoController.dispose();
    _periodoController.dispose();
    _fechaPagoController.dispose();
    _cantidadHorasExtras50Controller.dispose();
    _cantidadHorasExtras100Controller.dispose();
    _premiosController.dispose();
    _impuestoGananciasController.dispose();
    _diasInasistenciaController.dispose();
     _kilometrosRecorridosController.dispose();
     _diasViaticosComidaController.dispose();
     _diasPernocteController.dispose();
    _diasVacacionesController.dispose();
    _montoVacacionesController.dispose();
    _fechaInicioVacacionesController.dispose();
    _fechaFinVacacionesController.dispose();
    super.dispose();
  }
  
  String _obtenerPeriodoActual() {
    final meses = [
      'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
    ];
    final now = DateTime.now();
    return '${meses[now.month - 1]} ${now.year}';
  }
  
  Future<void> _cargarEmpresas() async {
    final list = await HybridStore.getEmpresas();
    if (mounted) setState(() => _empresas = list);
  }
  
  Future<void> _cargarEmpleados(String razonSocial) async {
    final prefs = await SharedPreferences.getInstance();
    final empleadosJson = prefs.getString('empleados_$razonSocial');
    
    if (empleadosJson != null && empleadosJson.isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(empleadosJson);
        setState(() {
          _empleados = List<Map<String, dynamic>>.from(
            decoded.map((e) => Map<String, dynamic>.from(e)),
          );
        });
      } catch (e) {
        setState(() {
          _empleados = [];
        });
      }
    } else {
      setState(() {
        _empleados = [];
      });
    }
  }
  
  void _onEmpresaSeleccionada(String? razonSocial) {
    setState(() {
      _empresaSeleccionada = razonSocial;
      _empleadoSeleccionado = null;
      _datosEmpleado = null;
      _sueldoBasicoCategoria = null;
      _sueldoBasicoController.clear();
      _empleados = [];
      _logoPath = null;
      _firmaPath = null;
    });
    
    if (razonSocial != null) {
      _cargarEmpleados(razonSocial);
      // Cargar logo y firma de la empresa
      final emp = _empresas.firstWhere((e) => e['razonSocial'] == razonSocial, orElse: () => {});
      final logo = emp['logoPath']?.toString();
      _logoPath = (logo == null || logo.isEmpty || logo == 'No disponible') ? null : logo;
      final firma = emp['firmaPath']?.toString();
      _firmaPath = (firma == null || firma.isEmpty || firma == 'No disponible') ? null : firma;
    }
  }
  
  void _onEmpleadoSeleccionado(String? cuil) {
    setState(() {
      _empleadoSeleccionado = cuil;
      _datosEmpleado = null;
      _sueldoBasicoCategoria = null;
      _sueldoBasicoController.clear();
    });
    
    if (cuil == null) return;
    
    final empleado = _empleados.firstWhere(
      (e) => e['cuil']?.toString().replaceAll('-', '') == cuil.replaceAll('-', ''),
      orElse: () => {},
    );
    
    if (empleado.isEmpty) return;
    
    setState(() {
      _datosEmpleado = empleado;
      
      // Cargar sueldo básico de la categoría si existe
      final categoriaId = empleado['categoriaId']?.toString();
      if (categoriaId != null && categoriaId.isNotEmpty) {
        _cargarSueldoBasicoCategoria(categoriaId);
      }
      
      // Cargar porcentaje de presentismo del convenio
      final convenioId = empleado['convenioId']?.toString();
      if (convenioId != null && convenioId.isNotEmpty && convenioId != 'fuera_convenio') {
        _cargarPorcentajePresentismo(convenioId);
      } else {
        // Si no tiene convenio, usar el valor por defecto
        _porcentajePresentismo = 8.33;
      }
      
      // Calcular vacaciones automáticamente si tiene fecha de ingreso
      if (empleado['fechaIngreso'] != null && empleado['fechaIngreso'].toString().isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _vacacionesActivas) {
            _calcularVacacionesAutomaticas();
          }
        });
      }
      
      // Si no hay sueldo básico de categoría, dejar el campo vacío para ingreso manual
      if (_sueldoBasicoCategoria == null) {
        _sueldoBasicoController.text = '0';
      } else {
        _sueldoBasicoController.text = _sueldoBasicoCategoria!.toStringAsFixed(2);
      }
    });
  }
  
  void _cargarSueldoBasicoCategoria(String categoriaId) {
    try {
      // Buscar en todos los convenios
      for (final convenio in cctArgentinaCompleto) {
        final categoria = convenio.categorias.firstWhere(
          (c) => c.id == categoriaId,
          orElse: () => const CategoriaCCT(
            id: '',
            nombre: '',
            salarioBase: 0,
            descripcion: '',
          ),
        );
        
        if (categoria.id.isNotEmpty && categoria.salarioBase > 0) {
          setState(() {
            _sueldoBasicoCategoria = categoria.salarioBase;
          });
          return;
        }
      }
    } catch (e) {
      // Si no se encuentra, dejar null
    }
  }
  
  void _cargarPorcentajePresentismo(String convenioId) {
    try {
      // Buscar el convenio en la lista completa
      final convenio = cctArgentinaCompleto.firstWhere(
        (c) => c.id == convenioId,
        orElse: () => CCTCompleto(
          id: '',
          numeroCCT: '',
          nombre: '',
          descripcion: '',
          categorias: [],
          descuentos: [],
          zonas: [],
          adicionalPresentismo: 8.33, // Valor por defecto
          fechaVigencia: DateTime.now(),
          activo: true,
          pdfUrl: null,
        ),
      );
      
      if (convenio.id.isNotEmpty) {
        setState(() {
          _porcentajePresentismo = convenio.adicionalPresentismo;
          _pdfConvenioUrl = convenio.pdfUrl;
        });
      }
    } catch (e) {
      // Si no se encuentra, usar valor por defecto
      setState(() {
        _porcentajePresentismo = 8.33;
        _pdfConvenioUrl = null;
      });
    }
  }

  Future<void> _descargarPdfConvenio() async {
    if (_pdfConvenioUrl != null && _pdfConvenioUrl!.isNotEmpty) {
      final uri = Uri.parse(_pdfConvenioUrl!);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No se pudo abrir el enlace PDF'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PDF no disponible para este convenio'),
            backgroundColor: AppColors.info,
          ),
        );
      }
    }
  }
  
  void _agregarConceptoNoRemunerativo() {
    showDialog(
      context: context,
      builder: (context) => _DialogConcepto(
        titulo: 'Agregar Concepto No Remunerativo',
        onGuardar: (nombre, monto) {
          setState(() {
            _conceptosNoRemunerativos.add({
              'nombre': nombre,
              'monto': monto,
            });
          });
        },
      ),
    );
  }
  
  void _editarConceptoNoRemunerativo(int index) {
    final concepto = _conceptosNoRemunerativos[index];
    showDialog(
      context: context,
      builder: (context) => _DialogConcepto(
        titulo: 'Editar Concepto No Remunerativo',
        nombreInicial: concepto['nombre'] as String,
        montoInicial: concepto['monto'] as double,
        onGuardar: (nombre, monto) {
          setState(() {
            _conceptosNoRemunerativos[index] = {
              'nombre': nombre,
              'monto': monto,
            };
          });
        },
      ),
    );
  }
  
  /// Limpia y valida CUIT/CUIL para formato AFIP (exactamente 11 dígitos)
  /// Elimina todos los caracteres no numéricos y valida la longitud
  String _limpiarYValidarCUITCUIL(String cuitCuil, String tipo) {
    if (cuitCuil.isEmpty || cuitCuil.trim().isEmpty) {
      throw ArgumentError('El $tipo no puede estar vacío');
    }
    
    // Eliminar TODOS los caracteres no numéricos (guiones, espacios, puntos, etc.)
    final limpio = cuitCuil.replaceAll(RegExp(r'[^\d]'), '').trim();
    
    // Validar que tenga exactamente 11 dígitos
    if (limpio.length != 11) {
      throw ArgumentError(
        'El $tipo debe tener exactamente 11 dígitos. '
        'Se encontraron ${limpio.length} dígitos en: "$cuitCuil" (limpio: "$limpio"). '
        'Por favor, verifique que el $tipo tenga el formato correcto (ej: 20-12345678-9 o 20123456789).'
      );
    }
    
    // Validar que solo contenga dígitos
    if (!RegExp(r'^\d{11}$').hasMatch(limpio)) {
      throw ArgumentError('El $tipo contiene caracteres inválidos después de la limpieza');
    }
    
    return limpio;
  }
  
  Future<String> _generarArchivoLSD({
    required Empresa empresa,
    required Empleado empleado,
    required Liquidacion liquidacion,
    required double sueldoBasico,
    required Directory directory,
    required DateTime fechaGeneracion,
  }) async {
    // ========== VALIDACIÓN Y LIMPIEZA DE CUIT/CUIL ==========
    // Obtener CUIT de la empresa desde los datos guardados
    final empresaData = _empresas.firstWhere(
      (e) => e['razonSocial'] == empresa.razonSocial,
      orElse: () => {},
    );
    
    if (empresaData.isEmpty || empresaData['cuit'] == null) {
      throw ArgumentError('No se encontró el CUIT de la empresa. Por favor, verifique los datos de la empresa.');
    }
    
    final cuitEmpresaRaw = empresaData['cuit'].toString().trim();
    final cuitEmpresaLimpio = _limpiarYValidarCUITCUIL(cuitEmpresaRaw, 'CUIT de la empresa');
    
    // Obtener CUIL del empleado desde los datos del empleado
    if (_datosEmpleado == null || _datosEmpleado!['cuil'] == null) {
      throw ArgumentError('No se encontró el CUIL del empleado. Por favor, seleccione el empleado nuevamente.');
    }
    
    final cuilEmpleadoRaw = _datosEmpleado!['cuil'].toString().trim();
    final cuilEmpleadoLimpio = _limpiarYValidarCUITCUIL(cuilEmpleadoRaw, 'CUIL del empleado');
    
    // Validar que la fecha de pago esté completa
    if (_fechaPagoController.text.isEmpty || _fechaPagoController.text.trim().isEmpty) {
      throw ArgumentError('La fecha de pago es obligatoria. Por favor, complete el campo de fecha de pago.');
    }
    
    // ========== GENERACIÓN DEL ARCHIVO ==========
    final nombreArchivo = 'lsd_${cuitEmpresaLimpio}_${fechaGeneracion.millisecondsSinceEpoch}.txt';
    
    final registros = <Uint8List>[];
    
    // Registro 1: Cabecera
    final registro1 = LSDGenerator.generateRegistro1(
      cuitEmpresa: cuitEmpresaLimpio, // Usar el CUIT limpio y validado
      periodo: _periodoController.text,
      fechaPago: _fechaPagoController.text,
      razonSocial: empresa.razonSocial,
      domicilio: empresa.domicilio,
    );
    registros.add(registro1);
    
    // Calcular sueldo bruto (total de conceptos remunerativos)
    final sueldoBruto = liquidacion.calcularSueldoBruto(sueldoBasico);
    
    // Cargar parámetros legales vigentes
    final parametrosLegales = await ParametrosLegalesService.cargarParametros();
    
    // Validar si el sueldo bruto está por debajo del SMVM
    if (parametrosLegales.sueldoPorDebajoSMVM(sueldoBruto)) {
      // Mostrar advertencia pero no bloquear la generación
      // La advertencia se mostrará en la UI
      // throw ArgumentError(
      //   'Atención: El sueldo bruto está por debajo del Mínimo Vital y Móvil vigente (\$${parametrosLegales.smvm.toStringAsFixed(2)})'
      // );
    }
    
    // Validar base imponible según topes legales vigentes
    // NOTA: El sueldo bruto puede exceder el tope máximo, pero se aplicará el tope para cálculos
    final baseMinima = parametrosLegales.baseImponibleMinima;
    final baseTopeada = liquidacion.obtenerBaseImponibleTopeada(sueldoBruto);
    
    // Solo validar que la base topeada esté dentro de los límites
    if (baseTopeada < baseMinima) {
      throw ArgumentError(
        'La base imponible ajustada (\$${baseTopeada.toStringAsFixed(2)}) está por debajo del mínimo permitido. '
        'Mínimo: \$${baseMinima.toStringAsFixed(2)}'
      );
    }
    
    final aportes = liquidacion.calcularAportes(sueldoBruto);
    
    // ===== REGISTRO 02: Conceptos Individuales =====
    // Lista para almacenar conceptos y calcular total remunerativo automáticamente
    final conceptosParaRegistro02 = <Map<String, dynamic>>[];
    
    // Sueldo básico (remunerativo)
    final sueldoBasicoProporcional = liquidacion.obtenerSueldoBasicoProporcional(sueldoBasico);
    if (sueldoBasicoProporcional > 0) {
      final codigoInterno = LSDGenerator.obtenerCodigoInternoConcepto('Sueldo Básico');
      final registro02 = LSDGenerator.generateRegistro2Conceptos(
        cuilEmpleado: cuilEmpleadoLimpio,
        codigoConcepto: codigoInterno,
        importe: sueldoBasicoProporcional,
        descripcionConcepto: 'Sueldo Básico',
        tipo: 'H',
      );
      registros.add(registro02);
      conceptosParaRegistro02.add({
        'importe': sueldoBasicoProporcional,
        'tipo': 'H',
      });
    }
    
    // Presentismo (remunerativo) - solo si está activo y no hay inasistencias
    if (liquidacion.presentismoActivo && liquidacion.diasInasistencia == 0) {
      final presentismo = sueldoBasicoProporcional * (liquidacion.porcentajePresentismo / 100);
      if (presentismo > 0) {
        final codigoInterno = LSDGenerator.obtenerCodigoInternoConcepto('Presentismo');
        final registro02 = LSDGenerator.generateRegistro2Conceptos(
          cuilEmpleado: cuilEmpleadoLimpio,
          codigoConcepto: codigoInterno,
          importe: presentismo,
          descripcionConcepto: 'Presentismo',
          tipo: 'H',
        );
        registros.add(registro02);
        conceptosParaRegistro02.add({
          'importe': presentismo,
          'tipo': 'H',
        });
      }
    }
    
    // Vacaciones (REMUNERATIVO) - Código AFIP 015000
    if (liquidacion.vacacionesActivas && liquidacion.diasVacaciones > 0) {
      if (liquidacion.montoVacaciones > 0) {
        final codigoInterno = LSDGenerator.obtenerCodigoInternoConcepto('Vacaciones');
        final registro02 = LSDGenerator.generateRegistro2Conceptos(
          cuilEmpleado: cuilEmpleadoLimpio,
          codigoConcepto: codigoInterno,
          importe: liquidacion.montoVacaciones,
          descripcionConcepto: 'Vacaciones (${liquidacion.diasVacaciones} días)',
          cantidad: liquidacion.diasVacaciones,
          tipo: 'H',
        );
        registros.add(registro02);
        conceptosParaRegistro02.add({
          'importe': liquidacion.montoVacaciones,
          'tipo': 'H',
        });
      }
      
      // Plus Vacacional (REMUNERATIVO) - También se registra con código de vacaciones
      if (liquidacion.plusVacacional > 0) {
        final codigoInterno = LSDGenerator.obtenerCodigoInternoConcepto('Plus Vacacional');
        final registro02 = LSDGenerator.generateRegistro2Conceptos(
          cuilEmpleado: cuilEmpleadoLimpio,
          codigoConcepto: codigoInterno,
          importe: liquidacion.plusVacacional,
          descripcionConcepto: 'Plus Vacacional',
          tipo: 'H',
        );
        registros.add(registro02);
        conceptosParaRegistro02.add({
          'importe': liquidacion.plusVacacional,
          'tipo': 'H',
        });
      }
    }
    
    // Conceptos remunerativos adicionales
    liquidacion.conceptosRemunerativos.forEach((nombre, valor) {
      if (valor > 0) {
        final codigoInterno = LSDGenerator.obtenerCodigoInternoConcepto(nombre);
        final registro02 = LSDGenerator.generateRegistro2Conceptos(
          cuilEmpleado: cuilEmpleadoLimpio,
          codigoConcepto: codigoInterno,
          importe: valor,
          descripcionConcepto: nombre,
          tipo: 'H',
        );
        registros.add(registro02);
        conceptosParaRegistro02.add({
          'importe': valor,
          'tipo': 'H',
        });
      }
    });

    // Kilómetros Recorridos (REMUNERATIVO) - CCT Camioneros
    if (liquidacion.kilometrosRecorridos > 0 && liquidacion.montoKilometros > 0) {
      final codigoInterno = LSDGenerator.obtenerCodigoInternoConcepto('Kilometros Recorridos');
      final registro02 = LSDGenerator.generateRegistro2Conceptos(
        cuilEmpleado: cuilEmpleadoLimpio,
        codigoConcepto: codigoInterno,
        importe: liquidacion.montoKilometros,
        descripcionConcepto:
            'Kilometros Recorridos (${liquidacion.kilometrosRecorridos} km)',
        cantidad: liquidacion.kilometrosRecorridos,
        tipo: 'H',
      );
      registros.add(registro02);
      conceptosParaRegistro02.add({
        'importe': liquidacion.montoKilometros,
        'tipo': 'H',
      });
    }
    
    // Horas extras 50% (REMUNERATIVO)
    final montoHorasExtras50 = liquidacion.calcularMontoHorasExtras50(sueldoBasico);
    if (montoHorasExtras50 > 0) {
      final codigoInterno = LSDGenerator.obtenerCodigoInternoConcepto('Horas Extras');
      registros.add(LSDGenerator.generateRegistro2Conceptos(
        cuilEmpleado: cuilEmpleadoLimpio,
        codigoConcepto: codigoInterno,
        importe: montoHorasExtras50,
        cantidad: liquidacion.cantidadHorasExtras50,
        descripcionConcepto: 'Horas Extras 50% (${liquidacion.cantidadHorasExtras50} horas)',
        tipo: 'H', // REMUNERATIVO
      ));
    }
    
    // Horas extras 100% (REMUNERATIVO)
    final montoHorasExtras100 = liquidacion.calcularMontoHorasExtras100(sueldoBasico);
    if (montoHorasExtras100 > 0) {
      final codigoInterno = LSDGenerator.obtenerCodigoInternoConcepto('Horas Extras');
      registros.add(LSDGenerator.generateRegistro2Conceptos(
        cuilEmpleado: cuilEmpleadoLimpio,
        codigoConcepto: codigoInterno,
        importe: montoHorasExtras100,
        cantidad: liquidacion.cantidadHorasExtras100,
        descripcionConcepto: 'Horas Extras 100% (${liquidacion.cantidadHorasExtras100} horas)',
        tipo: 'H', // REMUNERATIVO
      ));
    }
    
    // Premios (NO REMUNERATIVO - pero se registra como concepto)
    final premios = double.tryParse(_premiosController.text) ?? 0.0;
    if (premios > 0) {
      final codigoInterno = LSDGenerator.obtenerCodigoInternoConcepto('Premios');
      registros.add(LSDGenerator.generateRegistro2Conceptos(
        cuilEmpleado: cuilEmpleadoLimpio,
        codigoConcepto: codigoInterno,
        importe: premios,
        descripcionConcepto: 'Premios',
        tipo: 'H', // Aunque es no remunerativo, se registra como concepto
      ));
    }

    // Viáticos / Comida (NO REMUNERATIVO - se registra, pero no integra bases)
    if (liquidacion.diasViaticosComida > 0 && liquidacion.montoViaticosComida > 0) {
      final codigoInterno = LSDGenerator.obtenerCodigoInternoConcepto('Viaticos / Comida');
      registros.add(LSDGenerator.generateRegistro2Conceptos(
        cuilEmpleado: cuilEmpleadoLimpio,
        codigoConcepto: codigoInterno,
        importe: liquidacion.montoViaticosComida,
        descripcionConcepto:
            'Viaticos / Comida (${liquidacion.diasViaticosComida} dias)',
        cantidad: liquidacion.diasViaticosComida,
        tipo: 'H',
      ));
    }

    // Pernocte (NO REMUNERATIVO - se registra, pero no integra bases)
    if (liquidacion.diasPernocte > 0 && liquidacion.montoPernocte > 0) {
      final codigoInterno = LSDGenerator.obtenerCodigoInternoConcepto('Pernocte');
      registros.add(LSDGenerator.generateRegistro2Conceptos(
        cuilEmpleado: cuilEmpleadoLimpio,
        codigoConcepto: codigoInterno,
        importe: liquidacion.montoPernocte,
        descripcionConcepto: 'Pernocte (${liquidacion.diasPernocte} dias)',
        cantidad: liquidacion.diasPernocte,
        tipo: 'H',
      ));
    }
    
    // Conceptos no remunerativos adicionales
    for (final concepto in _conceptosNoRemunerativos) {
      final monto = concepto['monto'] as double;
      if (monto > 0) {
        final nombreConcepto = concepto['nombre'] as String;
        final codigoInterno = LSDGenerator.obtenerCodigoInternoConcepto(nombreConcepto);
        registros.add(LSDGenerator.generateRegistro2Conceptos(
          cuilEmpleado: cuilEmpleadoLimpio,
          codigoConcepto: codigoInterno,
          importe: monto,
          descripcionConcepto: nombreConcepto,
          tipo: 'H',
        ));
      }
    }
    
    // Deducciones - Usar códigos internos del catálogo
    // IMPORTANTE: Los importes deben ser POSITIVOS, las deducciones se identifican por código
    
    // Jubilación
    if ((aportes['jubilacion'] ?? 0.0) > 0) {
      final codigoInterno = LSDGenerator.obtenerCodigoInternoConcepto('Jubilación (SIPA)');
      registros.add(LSDGenerator.generateRegistro2Conceptos(
        cuilEmpleado: cuilEmpleadoLimpio,
        codigoConcepto: codigoInterno,
        importe: aportes['jubilacion'] ?? 0.0,
        descripcionConcepto: 'Jubilación (SIPA)',
        tipo: 'D',
      ));
    }
    
    // Ley 19.032 (PAMI)
    if ((aportes['ley19032'] ?? 0.0) > 0) {
      final codigoInterno = LSDGenerator.obtenerCodigoInternoConcepto('Ley 19.032 (PAMI)');
      registros.add(LSDGenerator.generateRegistro2Conceptos(
        cuilEmpleado: cuilEmpleadoLimpio,
        codigoConcepto: codigoInterno,
        importe: aportes['ley19032'] ?? 0.0,
        descripcionConcepto: 'Ley 19.032 (PAMI)',
        tipo: 'D',
      ));
    }
    
    // Obra Social
    if ((aportes['obraSocial'] ?? 0.0) > 0) {
      final codigoInterno = LSDGenerator.obtenerCodigoInternoConcepto('Obra Social');
      registros.add(LSDGenerator.generateRegistro2Conceptos(
        cuilEmpleado: cuilEmpleadoLimpio,
        codigoConcepto: codigoInterno,
        importe: aportes['obraSocial'] ?? 0.0,
        descripcionConcepto: 'Obra Social',
        tipo: 'D',
      ));
    }
    
    // Cuota Sindical
    if (liquidacion.afiliadoSindical && (aportes['cuotaSindical'] ?? 0.0) > 0) {
      final codigoInterno = LSDGenerator.obtenerCodigoInternoConcepto('Cuota Sindical');
      registros.add(LSDGenerator.generateRegistro2Conceptos(
        cuilEmpleado: cuilEmpleadoLimpio,
        codigoConcepto: codigoInterno,
        importe: aportes['cuotaSindical'] ?? 0.0,
        descripcionConcepto: 'Cuota Sindical',
        tipo: 'D',
      ));
    }
    
    // Retención Ganancias
    final ganancias = liquidacion.obtenerGanancias(sueldoBruto);
    if (ganancias > 0) {
      final codigoInterno = LSDGenerator.obtenerCodigoInternoConcepto('Retención Ganancias');
      registros.add(LSDGenerator.generateRegistro2Conceptos(
        cuilEmpleado: cuilEmpleadoLimpio,
        codigoConcepto: codigoInterno,
        importe: ganancias,
        descripcionConcepto: 'Retención Ganancias 4ta Cat.',
        tipo: 'D',
      ));
    }
    
    // Deducciones adicionales
    for (final deduccion in _deduccionesAdicionales) {
      final monto = deduccion['monto'] as double;
      if (monto > 0) {
        final nombreDeduccion = deduccion['nombre'] as String;
        final codigoInterno = LSDGenerator.obtenerCodigoInternoConcepto(nombreDeduccion);
        registros.add(LSDGenerator.generateRegistro2Conceptos(
          cuilEmpleado: cuilEmpleadoLimpio,
          codigoConcepto: codigoInterno,
          importe: monto,
          descripcionConcepto: nombreDeduccion,
          tipo: 'D',
        ));
      }
    }
    
    // ===== REGISTRO 03: Bases Imponibles F.931 =====
    // Motor de cálculos automáticos: Sumar todos los conceptos remunerativos (tipo 'H')
    final totalRemunerativoCalculado = LSDGenerator.calcularTotalRemunerativoAutomatico(conceptosParaRegistro02);
    
    // Aplicar topes legales vigentes (carga dinámicamente desde ParametrosLegales)
    final baseImponibleAjustada = await LSDGenerator.aplicarTopesLegales(totalRemunerativoCalculado);
    
    final registro3 = await LSDGenerator.generateRegistro3Bases(
      cuilEmpleado: cuilEmpleadoLimpio,
      baseImponibleJubilacion: baseImponibleAjustada,
      baseImponibleObraSocial: baseImponibleAjustada,
      baseImponibleLey19032: baseImponibleAjustada,
      totalRemunerativo: totalRemunerativoCalculado,
    );
    registros.add(registro3);
    
    // ========== ESCRITURA DEL ARCHIVO CON VALIDACIÓN FINAL ==========
    // Construir contenido como String para validación
    final buffer = StringBuffer();
    for (final registro in registros) {
      buffer.write(String.fromCharCodes(registro));
      buffer.writeln(); // Agregar salto de línea después de cada registro
    }
    
    final contenido = buffer.toString();
    
    // VALIDACIÓN FINAL: Usar guardarArchivoTXT que valida:
    // - Todas las líneas tienen 150 caracteres
    // - Todos los CUILs pasan Módulo 11
    // - Codificación Windows-1252 (ANSI)
    try {
      final nombreArchivoSinExtension = '${directory.path}/$nombreArchivo'.replaceAll('.txt', '');
      final rutaArchivo = await LSDGenerator.guardarArchivoTXT(
        contenido: contenido,
        nombreArchivo: nombreArchivoSinExtension,
      );
      
      return rutaArchivo;
    } catch (e) {
      // Si la validación falla, el error ya fue lanzado por guardarArchivoTXT
      // con mensaje detallado que bloquea la descarga
      rethrow;
    }
  }
  
  void _eliminarConceptoNoRemunerativo(int index) {
    setState(() {
      _conceptosNoRemunerativos.removeAt(index);
    });
  }
  
  void _agregarDeduccionAdicional() {
    showDialog(
      context: context,
      builder: (context) => _DialogConcepto(
        titulo: 'Agregar Deducción',
        onGuardar: (nombre, monto) {
          setState(() {
            _deduccionesAdicionales.add({
              'nombre': nombre,
              'monto': monto,
            });
          });
        },
      ),
    );
  }
  
  void _editarDeduccionAdicional(int index) {
    final deduccion = _deduccionesAdicionales[index];
    showDialog(
      context: context,
      builder: (context) => _DialogConcepto(
        titulo: 'Editar Deducción',
        nombreInicial: deduccion['nombre'] as String,
        montoInicial: deduccion['monto'] as double,
        onGuardar: (nombre, monto) {
          setState(() {
            _deduccionesAdicionales[index] = {
              'nombre': nombre,
              'monto': monto,
            };
          });
        },
      ),
    );
  }
  
  void _eliminarDeduccionAdicional(int index) {
    setState(() {
      _deduccionesAdicionales.removeAt(index);
    });
  }
  
  void _calcularVacacionesAutomaticas() {
    if (_datosEmpleado == null || _datosEmpleado!['fechaIngreso'] == null) {
      return;
    }
    
    final fechaIngreso = _datosEmpleado!['fechaIngreso'].toString();
    if (fechaIngreso.isEmpty) return;
    
    // Obtener convenio si existe
    CCTCompleto? convenio;
    final convenioId = _datosEmpleado!['convenioId']?.toString();
    if (convenioId != null && convenioId.isNotEmpty && convenioId != 'fuera_convenio') {
      try {
        convenio = cctArgentinaCompleto.firstWhere((c) => c.id == convenioId);
      } catch (e) {
        // Si no se encuentra, usar null
      }
    }
    
    // Calcular días de vacaciones
    final resultado = VacacionesService.calcularDiasVacaciones(
      fechaIngreso: fechaIngreso,
      periodoLiquidacion: _periodoController.text,
      convenio: convenio,
    );
    
    final dias = resultado['dias'] as int? ?? 0;
    final nombreConvenio = convenio?.nombre;
    
    // Generar mensaje de cálculo
    _mensajeCalculoVacaciones = VacacionesService.obtenerMensajeCalculo(
      resultado,
      nombreConvenio: nombreConvenio,
    );
    
    setState(() {
      _diasVacacionesController.text = dias.toString();
      _actualizarMontoVacaciones();
    });
  }
  
  void _actualizarMontoVacaciones() {
    final sueldoBasico = double.tryParse(_sueldoBasicoController.text) ?? 0.0;
    final dias = int.tryParse(_diasVacacionesController.text) ?? 0;
    
    if (sueldoBasico > 0 && dias > 0) {
      // Calcular monto de vacaciones (divisor 25)
      final montoVacaciones = VacacionesService.calcularMontoVacaciones(sueldoBasico, dias);
      
      setState(() {
        _montoVacacionesController.text = montoVacaciones.toStringAsFixed(2);
      });
    } else {
      setState(() {
        _montoVacacionesController.text = '0.00';
      });
    }
  }
  
  void _calcularLiquidacion() {
    if (_empresaSeleccionada == null || _empleadoSeleccionado == null) {
      return;
    }
    
    final sueldoBasico = double.tryParse(_sueldoBasicoController.text) ?? 0.0;
    if (sueldoBasico <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El sueldo básico debe ser mayor a 0'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    // Validar fecha de ingreso vs mes de liquidación
    if (_datosEmpleado != null && _datosEmpleado!['fechaIngreso'] != null) {
      final fechaIngreso = _datosEmpleado!['fechaIngreso'].toString();
      if (fechaIngreso.isNotEmpty) {
        final aniosAntiguedad = AntiguedadService.calcularAniosAntiguedad(
          fechaIngreso,
          _periodoController.text,
        );
        
        if (aniosAntiguedad < 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error: Fecha de ingreso inválida. La fecha de ingreso no puede ser posterior al mes de liquidación.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 5),
            ),
          );
          return;
        }
      }
    }
    
    final liquidacion = Liquidacion(
      empresaId: _empresaSeleccionada!,
      empleadoId: _empleadoSeleccionado!,
      periodo: _periodoController.text,
      fechaPago: _fechaPagoController.text,
    );
    
    liquidacion.afiliadoSindical = _afiliadoSindical;
    liquidacion.calcularGananciasAutomatico = _calcularGananciasAutomatico;
    liquidacion.presentismoActivo = _presentismoActivo;
    liquidacion.diasInasistencia = _diasInasistencia;
    liquidacion.porcentajePresentismo = _porcentajePresentismo;
    
    if (!_calcularGananciasAutomatico) {
      liquidacion.impuestoGanancias = double.tryParse(_impuestoGananciasController.text) ?? 0.0;
    }

    // Novedades específicas de convenio (ej. Camioneros)
    // El usuario informa solo cantidades, la app calcula los montos automáticamente
    liquidacion.kilometrosRecorridos =
        int.tryParse(_kilometrosRecorridosController.text) ?? 0;
    liquidacion.diasViaticosComida =
        int.tryParse(_diasViaticosComidaController.text) ?? 0;
    liquidacion.diasPernocte =
        int.tryParse(_diasPernocteController.text) ?? 0;
    
    // Calcular antigüedad automáticamente si el empleado tiene fecha de ingreso
    if (_datosEmpleado != null && _datosEmpleado!['fechaIngreso'] != null) {
      final fechaIngreso = _datosEmpleado!['fechaIngreso'].toString();
      if (fechaIngreso.isNotEmpty) {
        final aniosAntiguedad = AntiguedadService.calcularAniosAntiguedad(
          fechaIngreso,
          _periodoController.text,
        );
        
        if (aniosAntiguedad >= 1) {
          // Obtener porcentaje de antigüedad anual del convenio
          double porcentajeAntiguedadAnual = 1.0; // Por defecto 1%
          
          final convenioId = _datosEmpleado!['convenioId']?.toString();
          if (convenioId != null && convenioId.isNotEmpty && convenioId != 'fuera_convenio') {
            try {
              final convenio = cctArgentinaCompleto.firstWhere(
                (c) => c.id == convenioId,
              );
              porcentajeAntiguedadAnual = convenio.porcentajeAntiguedadAnual;
            } catch (e) {
              // Si no se encuentra el convenio, usar valor por defecto
            }
          }
          
          // Calcular monto de antigüedad
          final montoAntiguedad = AntiguedadService.calcularMontoAntiguedad(
            sueldoBasico,
            porcentajeAntiguedadAnual,
            aniosAntiguedad,
          );
          
          if (montoAntiguedad > 0) {
            // Agregar antigüedad como concepto remunerativo
            liquidacion.conceptosRemunerativos['Antigüedad'] = montoAntiguedad;
          }
        }
      }
    }
    
    // Agregar horas extras (ahora son REMUNERATIVAS, se ingresan por cantidad)
    final cantidadHorasExtras50 = int.tryParse(_cantidadHorasExtras50Controller.text) ?? 0;
    liquidacion.cantidadHorasExtras50 = cantidadHorasExtras50;
    
    final cantidadHorasExtras100 = int.tryParse(_cantidadHorasExtras100Controller.text) ?? 0;
    liquidacion.cantidadHorasExtras100 = cantidadHorasExtras100;
    
    // Establecer divisor de horas mensuales según convenio
    // Por defecto: 173 horas para Petroleros Jerárquicos (CCT 637/11)
    // Nota: Este valor puede ser configurado por convenio en futuras versiones
    liquidacion.horasMensualesDivisor = 173.0;
    
    // Agregar conceptos no remunerativos (premios y otros)
    
    final premios = double.tryParse(_premiosController.text) ?? 0.0;
    if (premios > 0) {
      liquidacion.conceptosNoRemunerativosAdicionales['Premios'] = premios;
    }
    
    // Agregar conceptos no remunerativos adicionales
    for (final concepto in _conceptosNoRemunerativos) {
      liquidacion.conceptosNoRemunerativosAdicionales[concepto['nombre'] as String] = 
          concepto['monto'] as double;
    }
    
    // Agregar deducciones adicionales
    for (final deduccion in _deduccionesAdicionales) {
      liquidacion.deduccionesAdicionales[deduccion['nombre'] as String] = 
          deduccion['monto'] as double;
    }
    
    // Agregar vacaciones si están activas
    if (_vacacionesActivas) {
      final diasVacaciones = int.tryParse(_diasVacacionesController.text) ?? 0;
      if (diasVacaciones > 0) {
        // Validar máximo legal
        if (!VacacionesService.validarDiasVacaciones(diasVacaciones)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('El valor excede el máximo legal establecido para 2026 (35 días)'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
        
        final montoVacaciones = double.tryParse(_montoVacacionesController.text) ?? 
            VacacionesService.calcularMontoVacaciones(sueldoBasico, diasVacaciones);
        final plusVacacional = VacacionesService.calcularPlusVacacional(sueldoBasico, diasVacaciones);
        
        liquidacion.vacacionesActivas = true;
        liquidacion.diasVacaciones = diasVacaciones;
        liquidacion.montoVacaciones = montoVacaciones;
        liquidacion.plusVacacional = plusVacacional;
        liquidacion.vacacionesGozadas = _vacacionesGozadas;
        liquidacion.fechaInicioVacaciones = _fechaInicioVacacionesController.text.isNotEmpty 
            ? _fechaInicioVacacionesController.text 
            : null;
        liquidacion.fechaFinVacaciones = _fechaFinVacacionesController.text.isNotEmpty 
            ? _fechaFinVacacionesController.text 
            : null;
        liquidacion.ajusteManualVacaciones = _diasVacacionesController.text.isNotEmpty;
      }
    }
    
    setState(() {
      _liquidacion = liquidacion;
    });
    
    // Mostrar resumen de topes legales y años de antigüedad
    _mostrarResumenLiquidacion();
  }
  
  void _mostrarResumenLiquidacion() async {
    if (_datosEmpleado == null || _liquidacion == null) return;
    
    // Calcular años de antigüedad
    int aniosAntiguedad = 0;
    if (_datosEmpleado!['fechaIngreso'] != null) {
      final fechaIngreso = _datosEmpleado!['fechaIngreso'].toString();
      if (fechaIngreso.isNotEmpty) {
        aniosAntiguedad = AntiguedadService.calcularAniosAntiguedad(
          fechaIngreso,
          _periodoController.text,
        );
      }
    }
    
    // Obtener mes y año del período
    final periodo = _periodoController.text;
    final ahora = DateTime.now();
    final mesAnio = periodo.isNotEmpty ? periodo : '${_obtenerMesActual()} ${ahora.year}';
    
    String mensajeResumen = 'Se han aplicado topes legales de $mesAnio';
    
    if (aniosAntiguedad >= 1) {
      mensajeResumen += ' y calculado $aniosAntiguedad ${aniosAntiguedad == 1 ? 'año' : 'años'} de antigüedad automáticamente';
    }
    
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensajeResumen),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 4),
      ),
    );
  }
  
  String _obtenerMesActual() {
    final meses = [
      'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
    ];
    final now = DateTime.now();
    return meses[now.month - 1];
  }
  
  /// Recalcula la liquidación si ya existe, actualizando solo los valores de novedades
  /// Esto permite que el neto se actualice en tiempo real cuando el usuario cambia las cantidades
  void _recalcularLiquidacionSiExiste() {
    if (_liquidacion == null) return;
    
    // Los montos se calculan automáticamente mediante los getters
    // Solo necesitamos actualizar el estado para que la UI se refresque
    // Los valores ya están actualizados en _liquidacion gracias a los onChanged
  }
  
  Future<void> _generarPDF() async {
    if (_liquidacion == null || _datosEmpleado == null || _empresaSeleccionada == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Complete todos los datos antes de generar el PDF'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    final sueldoBasico = double.tryParse(_sueldoBasicoController.text) ?? 0.0;
    if (sueldoBasico <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El sueldo básico debe ser mayor a 0'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    // Obtener datos de la empresa
    final empresaData = _empresas.firstWhere(
      (e) => e['razonSocial'] == _empresaSeleccionada,
      orElse: () => {},
    );
    
    if (empresaData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se encontraron datos de la empresa'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    // Crear modelo de empresa
    final empresa = Empresa(
      razonSocial: empresaData['razonSocial'] ?? '',
      cuit: empresaData['cuit'] ?? '',
      domicilio: empresaData['domicilio'] ?? '',
      convenioId: '',
      convenioNombre: _datosEmpleado!['convenioNombre']?.toString() ?? '',
      convenioPersonalizado: false,
      categorias: [],
      parametros: [],
    );
    
    // Crear modelo de empleado para PDF
    final empleado = Empleado(
      nombre: _datosEmpleado!['nombre']?.toString() ?? '',
      categoria: _datosEmpleado!['categoriaNombre']?.toString() ?? '',
      sueldoBasico: sueldoBasico,
      periodo: _periodoController.text,
      fechaPago: _fechaPagoController.text,
      fechaIngreso: _datosEmpleado!['fechaIngreso']?.toString(),
      lugarPago: empresaData['domicilio'],
    );
    
    // Obtener conceptos para PDF
    final conceptos = _liquidacion!.obtenerConceptosParaTabla(sueldoBasico);
    final conceptosPDF = conceptos.map((c) => ConceptoParaPDF(
      descripcion: c.concepto,
      remunerativo: c.remunerativo,
      noRemunerativo: c.noRemunerativo,
      descuento: c.deducciones,
    )).toList();
    
    // Calcular totales
    // ========== CÁLCULO ÚNICO COMPARTIDO (PDF y TXT) ==========
    final sueldoBruto = _liquidacion!.calcularSueldoBruto(sueldoBasico);
    final baseImponibleTopeada = _liquidacion!.obtenerBaseImponibleTopeada(sueldoBruto);
    final totalDeducciones = _liquidacion!.calcularTotalDeducciones(sueldoBruto);
    final totalNoRemunerativo = _liquidacion!.calcularTotalNoRemunerativo();
    final sueldoNeto = _liquidacion!.calcularSueldoNeto(sueldoBasico);
    
    try {
      // Cargar bytes de logo y firma (multiplataforma)
      final logoBytes = await readImageBytes(_logoPath);
      final firmaBytes = await readImageBytes(_firmaPath);
      
      // Generar PDF con base topeada y campos obligatorios
      final pdfBytes = await PdfRecibo.generarCompleto(
        empresa: empresa,
        empleado: empleado,
        conceptos: conceptosPDF,
        sueldoBruto: sueldoBruto, // Bruto real sin topes
        totalDeducciones: totalDeducciones,
        totalNoRemunerativo: totalNoRemunerativo,
        sueldoNeto: sueldoNeto, // Neto calculado una sola vez
        baseImponibleTopeada: baseImponibleTopeada, // Base de cálculo de aportes
        bancoAcreditacion: 'Banco Nación Argentina', // Valor por defecto
        fechaUltimoDepositoAportes: '31/12/2025', // Diciembre 2025
        sueldoBasico: sueldoBasico, // Para desglose de horas extras
        cantidadHorasExtras50: _liquidacion!.cantidadHorasExtras50,
        cantidadHorasExtras100: _liquidacion!.cantidadHorasExtras100,
        logoBytes: logoBytes,
        firmaBytes: firmaBytes,
        incluirBloqueFirmaLey25506: true,
      );
      
      // Guardar PDF
      final directory = await getApplicationDocumentsDirectory();
      final cuilEmpleadoLimpio = _empleadoSeleccionado!.replaceAll('-', '').replaceAll(' ', '');
      final fechaGeneracion = DateTime.now();
      final nombreArchivo = 'recibo_${cuilEmpleadoLimpio}_${fechaGeneracion.millisecondsSinceEpoch}.pdf';
      final file = File('${directory.path}/$nombreArchivo');
      await file.writeAsBytes(pdfBytes);
      
      // Guardar información del recibo
      final prefs = await SharedPreferences.getInstance();
      final recibosJson = prefs.getString('recibos_$cuilEmpleadoLimpio');
      List<dynamic> recibos = [];
      
      if (recibosJson != null && recibosJson.isNotEmpty) {
        try {
          recibos = jsonDecode(recibosJson);
        } catch (e) {
          recibos = [];
        }
      }
      
      // Preparar datos de vacaciones para persistencia
      Map<String, dynamic>? datosVacaciones;
      if (_liquidacion!.vacacionesActivas && _liquidacion!.diasVacaciones > 0) {
        datosVacaciones = {
          'diasVacaciones': _liquidacion!.diasVacaciones,
          'montoVacaciones': _liquidacion!.montoVacaciones,
          'plusVacacional': _liquidacion!.plusVacacional,
          'vacacionesGozadas': _liquidacion!.vacacionesGozadas,
          'fechaInicioVacaciones': _liquidacion!.fechaInicioVacaciones,
          'fechaFinVacaciones': _liquidacion!.fechaFinVacaciones,
          'ajusteManualVacaciones': _liquidacion!.ajusteManualVacaciones,
        };
      }
      
      recibos.add({
        'fechaGeneracion': fechaGeneracion.toIso8601String(),
        'periodo': _periodoController.text,
        'fechaPago': _fechaPagoController.text,
        'ruta': file.path,
        'sueldoNeto': sueldoNeto,
        if (datosVacaciones != null) 'vacaciones': datosVacaciones,
      });
      
      await prefs.setString('recibos_$cuilEmpleadoLimpio', jsonEncode(recibos));
      
      // Generar archivo LSD para AFIP
      String? lsdFilePath;
      try {
        lsdFilePath = await _generarArchivoLSD(
          empresa: empresa,
          empleado: empleado,
          liquidacion: _liquidacion!,
          sueldoBasico: sueldoBasico,
          directory: directory,
          fechaGeneracion: fechaGeneracion,
        );
      } catch (e) {
        // Si falla la generación del LSD, continuar de todas formas
        // El error se registra silenciosamente para no interrumpir el flujo
        // pero no se muestra al usuario ya que el PDF ya se generó correctamente
      }
      
      // Mostrar diálogo de éxito
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.backgroundLight,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Recibo Generado',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'El recibo se ha generado correctamente.\n\nSueldo Neto: \$${sueldoNeto.toStringAsFixed(2)}${lsdFilePath != null ? '\n\nArchivo LSD generado para AFIP.' : ''}',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
            if (lsdFilePath != null)
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  OpenFile.open(lsdFilePath!);
                },
                child: const Text('Abrir LSD'),
              ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                OpenFile.open(file.path);
              },
              child: const Text('Abrir PDF'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al generar PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light.copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: AppColors.background,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            color: AppColors.background,
          ),
          child: SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildSeleccionEmpresa(),
                        const SizedBox(height: 24),
                        if (_empresaSeleccionada != null) _buildSeleccionEmpleado(),
                        if (_datosEmpleado != null) ...[
                          const SizedBox(height: 24),
                          _buildDatosEmpleado(),
                        ],
                        if (_datosEmpleado != null) ...[
                          const SizedBox(height: 24),
                          _buildDatosLiquidacion(),
                          const SizedBox(height: 24),
                          _buildNovedadesConvenio(),
                          const SizedBox(height: 24),
                          _buildConceptosNoRemunerativos(),
                          const SizedBox(height: 24),
                          _buildConfiguracionDeducciones(),
                          const SizedBox(height: 24),
                          _buildDeduccionesAdicionales(),
                          const SizedBox(height: 24),
                          _buildBotonesAccion(),
                        ],
                        if (_liquidacion != null) ...[
                          const SizedBox(height: 24),
                          _buildTablaLiquidacion(),
                          const SizedBox(height: 24),
                          _buildTotales(),
                          const SizedBox(height: 24),
                          _buildBotonesDescargaARCA(),
                          const SizedBox(height: 24),
                          _buildBotonGenerarPDF(),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
          const Expanded(
            child: Text(
              'Liquidador Final',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 48), // Balancear el botón de atrás
        ],
      ),
    );
  }
  
  Widget _buildSeleccionEmpresa() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.glassFillStrong,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.glassBorder, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Empresa',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              if (_empresas.isEmpty)
                Column(
                  children: [
                    const Text(
                      'No hay empresas creadas',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const EmpresaScreen(),
                          ),
                        );
                        if (result == true) {
                          _cargarEmpresas();
                        }
                      },
                      child: const Text('Crear Empresa'),
                    ),
                  ],
                )
              else
                DropdownButtonFormField<String>(
                  initialValue: _empresaSeleccionada,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppColors.glassFill,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.glassBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.glassBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.pastelBlue, width: 2),
                    ),
                  ),
                  dropdownColor: AppColors.backgroundLight,
                  style: const TextStyle(color: AppColors.textPrimary),
                  items: _empresas.map((empresa) {
                    return DropdownMenuItem<String>(
                      value: empresa['razonSocial'],
                      child: Text(empresa['razonSocial'] ?? ''),
                    );
                  }).toList(),
                  onChanged: _onEmpresaSeleccionada,
                ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildSeleccionEmpleado() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.glassFillStrong,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.glassBorder, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Empleado',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              if (_empleados.isEmpty)
                Column(
                  children: [
                    const Text(
                      'No hay empleados para esta empresa',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () async {
                        // Crear empresa temporal para navegar
                        final empresaData = _empresas.firstWhere(
                          (e) => e['razonSocial'] == _empresaSeleccionada,
                        );
                        final empresa = Empresa(
                          razonSocial: empresaData['razonSocial'] ?? '',
                          cuit: empresaData['cuit'] ?? '',
                          domicilio: empresaData['domicilio'] ?? '',
                          convenioId: '',
                          convenioNombre: '',
                          convenioPersonalizado: false,
                          categorias: [],
                          parametros: [],
                        );
                        
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => EmpleadoScreen(empresa: empresa),
                          ),
                        );
                        if (result == true) {
                          _cargarEmpleados(_empresaSeleccionada!);
                        }
                      },
                      child: const Text('Crear Empleado'),
                    ),
                  ],
                )
              else
                DropdownButtonFormField<String>(
                  initialValue: _empleadoSeleccionado,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppColors.glassFill,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.glassBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.glassBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.pastelBlue, width: 2),
                    ),
                  ),
                  dropdownColor: AppColors.backgroundLight,
                  style: const TextStyle(color: AppColors.textPrimary),
                  menuMaxHeight: 300,
                  items: _empleados.map((empleado) {
                    final nombre = empleado['nombre']?.toString() ?? '';
                    final cuil = empleado['cuil']?.toString() ?? '';
                    final cuilFormateado = _formatearCUIL(cuil);
                    return DropdownMenuItem<String>(
                      value: cuil.replaceAll('-', '').replaceAll(' ', ''),
                      child: Text('$nombre - $cuilFormateado'),
                    );
                  }).toList(),
                  onChanged: _onEmpleadoSeleccionado,
                ),
            ],
          ),
        ),
      ),
    );
  }
  
  String _formatearCUIL(String cuil) {
    final digitsOnly = cuil.replaceAll(RegExp(r'[^\d]'), '');
    if (digitsOnly.length != 11) return cuil;
    return '${digitsOnly.substring(0, 2)}-${digitsOnly.substring(2, 10)}-${digitsOnly.substring(10)}';
  }
  
  Widget _buildDatosEmpleado() {
    if (_datosEmpleado == null) return const SizedBox.shrink();
    
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.glassFillStrong,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.glassBorder, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Datos del Empleado',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              _buildDatoSoloLectura('Nombre', _datosEmpleado!['nombre']?.toString() ?? ''),
              _buildDatoSoloLectura('CUIL', _formatearCUIL(_datosEmpleado!['cuil']?.toString() ?? '')),
              _buildDatoSoloLectura('Cargo', _datosEmpleado!['cargo']?.toString() ?? ''),
              if (_datosEmpleado!['fechaIngreso'] != null)
                _buildDatoSoloLectura('Fecha de Ingreso', _datosEmpleado!['fechaIngreso']?.toString() ?? ''),
              // Convenio con botón de descarga si está disponible
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 120,
                    child: Text(
                      'Convenio:',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _datosEmpleado!['convenioNombre']?.toString() ?? 'Fuera de Convenio',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        if (_pdfConvenioUrl != null && _pdfConvenioUrl!.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.picture_as_pdf, color: AppColors.accentBlue),
                            tooltip: 'Descargar Convenio PDF',
                            onPressed: _descargarPdfConvenio,
                            constraints: const BoxConstraints(),
                            padding: EdgeInsets.zero,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_datosEmpleado!['categoriaNombre'] != null && _datosEmpleado!['categoriaNombre'].toString().isNotEmpty)
                _buildDatoSoloLectura('Categoría', _datosEmpleado!['categoriaNombre']?.toString() ?? ''),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildDatoSoloLectura(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildDatosLiquidacion() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.glassFillStrong,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.glassBorder, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Datos de Liquidación',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _sueldoBasicoController,
                label: 'Sueldo Básico',
                hint: '0.00',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _periodoController,
                label: 'Período',
                hint: 'Enero 2026',
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _fechaPagoController,
                label: 'Fecha de Pago',
                hint: 'DD/MM/YYYY',
              ),
              const SizedBox(height: 24),
              // Sección de Presentismo
              const Divider(color: AppColors.glassBorder),
              const SizedBox(height: 16),
              const Text(
                'Presentismo',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              CheckboxListTile(
                title: Text(
                  'Aplicar Presentismo (${_porcentajePresentismo.toStringAsFixed(2)}%)',
                  style: const TextStyle(color: AppColors.textPrimary),
                ),
                subtitle: _presentismoActivo && _diasInasistencia == 0
                    ? Text(
                        'Se calculará: ${(_porcentajePresentismo).toStringAsFixed(2)}% sobre sueldo básico',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      )
                    : _diasInasistencia > 0
                        ? const Text(
                            'No se aplica por tener inasistencias injustificadas',
                            style: TextStyle(
                              color: Colors.orange,
                              fontSize: 12,
                            ),
                          )
                        : const Text(
                            'Desactivado',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12,
                            ),
                          ),
                value: _presentismoActivo,
                onChanged: (value) {
                  setState(() {
                    _presentismoActivo = value ?? true;
                  });
                },
                activeColor: AppColors.pastelBlue,
              ),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _diasInasistenciaController,
                label: 'Días de Inasistencia Injustificada',
                hint: '0',
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  setState(() {
                    _diasInasistencia = int.tryParse(value) ?? 0;
                  });
                },
              ),
              const SizedBox(height: 24),
              // Sección de Vacaciones
              const Divider(color: AppColors.glassBorder),
              const SizedBox(height: 16),
              const Text(
                'Vacaciones (LCT 20.744)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              CheckboxListTile(
                title: const Text(
                  'Aplicar Vacaciones',
                  style: TextStyle(color: AppColors.textPrimary),
                ),
                value: _vacacionesActivas,
                onChanged: (value) {
                  setState(() {
                    _vacacionesActivas = value ?? false;
                    if (_vacacionesActivas) {
                      _calcularVacacionesAutomaticas();
                    } else {
                      _diasVacacionesController.clear();
                      _montoVacacionesController.clear();
                      _mensajeCalculoVacaciones = null;
                    }
                  });
                },
                activeColor: AppColors.pastelBlue,
              ),
              if (_vacacionesActivas) ...[
                const SizedBox(height: 12),
                // Mensaje de cálculo sugerido
                if (_mensajeCalculoVacaciones != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.glassFill,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.pastelBlue.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: AppColors.pastelBlue, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _mensajeCalculoVacaciones!,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                _buildTextField(
                  controller: _diasVacacionesController,
                  label: 'Días de Vacaciones',
                  hint: '14',
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    final dias = int.tryParse(value) ?? 0;
                    if (dias > 35) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('El valor excede el máximo legal establecido para 2026 (35 días)'),
                          backgroundColor: Colors.orange,
                          duration: Duration(seconds: 3),
                        ),
                      );
                    }
                    _actualizarMontoVacaciones();
                  },
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  controller: _montoVacacionesController,
                  label: 'Monto Vacaciones (divisor 25)',
                  hint: '0.00',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (value) {
                    // Permitir ajuste manual
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        controller: _fechaInicioVacacionesController,
                        label: 'Fecha Inicio',
                        hint: 'DD/MM/YYYY',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTextField(
                        controller: _fechaFinVacacionesController,
                        label: 'Fecha Fin',
                        hint: 'DD/MM/YYYY',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile<bool>(
                        title: const Text(
                          'Gozadas',
                          style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
                        ),
                        value: true,
                        // ignore: deprecated_member_use
                        groupValue: _vacacionesGozadas,
                        // ignore: deprecated_member_use
                        onChanged: (value) {
                          setState(() {
                            _vacacionesGozadas = value ?? true;
                          });
                        },
                        activeColor: AppColors.pastelBlue,
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<bool>(
                        title: const Text(
                          'No Gozadas',
                          style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
                        ),
                        value: false,
                        // ignore: deprecated_member_use
                        groupValue: _vacacionesGozadas,
                        // ignore: deprecated_member_use
                        onChanged: (value) {
                          setState(() {
                            _vacacionesGozadas = value ?? false;
                          });
                        },
                        activeColor: AppColors.pastelBlue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: _calcularVacacionesAutomaticas,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Recalcular Automáticamente'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.glassFill,
                    foregroundColor: AppColors.textPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
  
  /// Widget para campo de horas extras con cálculo automático en tiempo real
  Widget _buildHorasExtrasField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required int porcentaje,
    required double montoCalculado,
    required double sueldoBasico,
    required void Function(double) onCalculoChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: controller,
          keyboardType: TextInputType.number,
          onChanged: (value) {
            final cantidad = int.tryParse(value) ?? 0;
            const horasMensuales = 173.0; // Por defecto para Petroleros Jerárquicos
            if (sueldoBasico > 0 && cantidad > 0) {
              final valorHoraNormal = sueldoBasico / horasMensuales;
              final recargo = porcentaje == 50 ? 1.5 : 2.0;
              final monto = valorHoraNormal * recargo * cantidad;
              onCalculoChanged(monto);
            } else {
              onCalculoChanged(0.0);
            }
            // Recalcular liquidación si existe
            if (_liquidacion != null) {
              setState(() {
                if (porcentaje == 50) {
                  _liquidacion!.cantidadHorasExtras50 = cantidad;
                } else {
                  _liquidacion!.cantidadHorasExtras100 = cantidad;
                }
                _recalcularLiquidacionSiExiste();
              });
            }
          },
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            labelText: '$label (cantidad de horas)',
            hintText: hint,
            filled: true,
            fillColor: AppColors.glassFill,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.glassBorder),
            ),
          ),
        ),
        if (montoCalculado > 0) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.pastelBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.pastelBlue.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.calculate, size: 16, color: AppColors.pastelBlue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Monto calculado: \$${montoCalculado.toStringAsFixed(2)} '
                    '(Valor hora: \$${(sueldoBasico / 173.0).toStringAsFixed(2)} × $porcentaje% × ${int.tryParse(controller.text) ?? 0} horas)',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType? keyboardType,
    void Function(String)? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      onChanged: onChanged,
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: AppColors.glassFill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.glassBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.glassBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.pastelBlue, width: 2),
        ),
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        hintStyle: const TextStyle(color: AppColors.textMuted),
      ),
    );
  }
  
  Widget _buildConfiguracionDeducciones() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.glassFillStrong,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.glassBorder, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Configuración de Deducciones',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              CheckboxListTile(
                title: const Text(
                  'Afiliado Sindical',
                  style: TextStyle(color: AppColors.textPrimary),
                ),
                value: _afiliadoSindical,
                onChanged: (value) {
                  setState(() {
                    _afiliadoSindical = value ?? false;
                  });
                },
                activeColor: AppColors.pastelBlue,
              ),
              const SizedBox(height: 16),
              CheckboxListTile(
                title: const Text(
                  'Calcular Ganancias Automáticamente',
                  style: TextStyle(color: AppColors.textPrimary),
                ),
                value: _calcularGananciasAutomatico,
                onChanged: (value) {
                  setState(() {
                    _calcularGananciasAutomatico = value ?? true;
                  });
                },
                activeColor: AppColors.pastelBlue,
              ),
              if (!_calcularGananciasAutomatico) ...[
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _impuestoGananciasController,
                  label: 'Impuesto a las Ganancias (Manual)',
                  hint: '0.00',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildConceptosNoRemunerativos() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.glassFillStrong,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.glassBorder, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Conceptos No Remunerativos',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle, color: AppColors.pastelBlue),
                    onPressed: _agregarConceptoNoRemunerativo,
                    tooltip: 'Agregar concepto',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Horas Extras 50% - Ahora se ingresa por CANTIDAD
              _buildHorasExtrasField(
                controller: _cantidadHorasExtras50Controller,
                label: 'Horas Extras 50%',
                hint: '0',
                porcentaje: 50,
                montoCalculado: _montoCalculadoHorasExtras50,
                sueldoBasico: double.tryParse(_sueldoBasicoController.text) ?? 0.0,
                onCalculoChanged: (monto) {
                  setState(() {
                    _montoCalculadoHorasExtras50 = monto;
                  });
                },
              ),
              const SizedBox(height: 16),
              // Horas Extras 100% - Ahora se ingresa por CANTIDAD
              _buildHorasExtrasField(
                controller: _cantidadHorasExtras100Controller,
                label: 'Horas Extras 100%',
                hint: '0',
                porcentaje: 100,
                montoCalculado: _montoCalculadoHorasExtras100,
                sueldoBasico: double.tryParse(_sueldoBasicoController.text) ?? 0.0,
                onCalculoChanged: (monto) {
                  setState(() {
                    _montoCalculadoHorasExtras100 = monto;
                  });
                },
              ),
              const SizedBox(height: 16),
              // Premios
              _buildTextField(
                controller: _premiosController,
                label: 'Premios',
                hint: '0.00',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              if (_conceptosNoRemunerativos.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Divider(color: AppColors.glassBorder),
                const SizedBox(height: 16),
                const Text(
                  'Otros Conceptos No Remunerativos',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                ..._conceptosNoRemunerativos.asMap().entries.map((entry) {
                  final index = entry.key;
                  final concepto = entry.value;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.glassFill,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.glassBorder),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                concepto['nombre'] as String,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '\$${(concepto['monto'] as double).toStringAsFixed(2)}',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit, color: AppColors.pastelBlue, size: 20),
                          onPressed: () => _editarConceptoNoRemunerativo(index),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                          onPressed: () => _eliminarConceptoNoRemunerativo(index),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Sección de Novedades específicas del Convenio (ej. Camioneros)
  /// El usuario ingresa solo cantidades y la app calcula los montos
  Widget _buildNovedadesConvenio() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.glassFillStrong,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.glassBorder, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Novedades del Convenio',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Complete solo las cantidades. Los montos se calculan automáticamente '
                'según valores vigentes Enero 2026.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              // Kilómetros Recorridos (REMUNERATIVO)
              _buildTextField(
                controller: _kilometrosRecorridosController,
                label: 'Kilometros Recorridos (cantidad de km)',
                hint: '0',
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  final cantidad = int.tryParse(value) ?? 0;
                  if (_liquidacion != null) {
                    setState(() {
                      _liquidacion!.kilometrosRecorridos = cantidad;
                      // Recalcular liquidación para actualizar neto en tiempo real
                      _recalcularLiquidacionSiExiste();
                    });
                  }
                },
              ),
              const SizedBox(height: 6),
              Builder(
                builder: (context) {
                  final cantidad = int.tryParse(_kilometrosRecorridosController.text) ?? 0;
                  final monto = cantidad * Liquidacion.valorKilometroEnero2026;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Valor unitario Enero 2026: \$150,00 (remunerativo, AFIP 011000).',
                        style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                      ),
                      if (cantidad > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Monto calculado: \$${monto.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.pastelBlue,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              // Viáticos / Comida (NO REMUNERATIVO)
              _buildTextField(
                controller: _diasViaticosComidaController,
                label: 'Viaticos / Comida (dias)',
                hint: '0',
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  final cantidad = int.tryParse(value) ?? 0;
                  if (_liquidacion != null) {
                    setState(() {
                      _liquidacion!.diasViaticosComida = cantidad;
                      // Recalcular liquidación para actualizar neto en tiempo real
                      _recalcularLiquidacionSiExiste();
                    });
                  }
                },
              ),
              const SizedBox(height: 6),
              Builder(
                builder: (context) {
                  final cantidad = int.tryParse(_diasViaticosComidaController.text) ?? 0;
                  final monto = cantidad * Liquidacion.valorViaticoComidaEnero2026;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Valor unitario Enero 2026: \$2.500,00 (no remunerativo, AFIP 112000).',
                        style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                      ),
                      if (cantidad > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Monto calculado: \$${monto.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.pastelBlue,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              // Pernocte (NO REMUNERATIVO)
              _buildTextField(
                controller: _diasPernocteController,
                label: 'Pernocte (dias)',
                hint: '0',
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  final cantidad = int.tryParse(value) ?? 0;
                  if (_liquidacion != null) {
                    setState(() {
                      _liquidacion!.diasPernocte = cantidad;
                      // Recalcular liquidación para actualizar neto en tiempo real
                      _recalcularLiquidacionSiExiste();
                    });
                  }
                },
              ),
              const SizedBox(height: 6),
              Builder(
                builder: (context) {
                  final cantidad = int.tryParse(_diasPernocteController.text) ?? 0;
                  final monto = cantidad * Liquidacion.valorPernocteEnero2026;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Valor unitario Enero 2026: \$3.800,00 (no remunerativo, AFIP 112000).',
                        style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                      ),
                      if (cantidad > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Monto calculado: \$${monto.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.pastelBlue,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildDeduccionesAdicionales() {
    // Calcular deducciones legales para mostrarlas
    double sueldoBruto = 0.0;
    if (_liquidacion != null) {
      final sueldoBasico = double.tryParse(_sueldoBasicoController.text) ?? 0.0;
      sueldoBruto = _liquidacion!.calcularSueldoBruto(sueldoBasico);
    }
    final aportes = _liquidacion?.calcularAportes(sueldoBruto) ?? {};
    final ganancias = _liquidacion != null && sueldoBruto > 0 
        ? _liquidacion!.obtenerGanancias(sueldoBruto) 
        : 0.0;
    
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.glassFillStrong,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.glassBorder, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Deducciones',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle, color: AppColors.pastelOrange),
                    onPressed: _agregarDeduccionAdicional,
                    tooltip: 'Agregar deducción adicional',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Deducciones legales (no editables)
              const Text(
                'Deducciones Legales (No Editables)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              _buildDeduccionLegal(
                'Jubilación (SIPA)',
                '11%',
                sueldoBruto > 0 ? (aportes['jubilacion'] ?? 0.0) : 0.0,
                sueldoBruto: sueldoBruto,
              ),
              _buildDeduccionLegal(
                'Ley 19.032 (PAMI)',
                '3%',
                sueldoBruto > 0 ? (aportes['ley19032'] ?? 0.0) : 0.0,
                sueldoBruto: sueldoBruto,
              ),
              _buildDeduccionLegal(
                'Obra Social',
                '3%',
                sueldoBruto > 0 ? (aportes['obraSocial'] ?? 0.0) : 0.0,
                sueldoBruto: sueldoBruto,
              ),
              if (_afiliadoSindical && sueldoBruto > 0)
                _buildDeduccionLegal(
                  'Cuota Sindical',
                  '2.5%',
                  aportes['cuotaSindical'] ?? 0.0,
                  sueldoBruto: sueldoBruto,
                ),
              if (ganancias > 0)
                _buildDeduccionLegal(
                  'Retención Ganancias 4ta Cat.',
                  'Calculado',
                  ganancias,
                  sueldoBruto: sueldoBruto,
                ),
              // Deducciones adicionales editables
              if (_deduccionesAdicionales.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Divider(color: AppColors.glassBorder),
                const SizedBox(height: 16),
                const Text(
                  'Deducciones Adicionales',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                ..._deduccionesAdicionales.asMap().entries.map((entry) {
                  final index = entry.key;
                  final deduccion = entry.value;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.glassFill,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.glassBorder),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                deduccion['nombre'] as String,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '\$${(deduccion['monto'] as double).toStringAsFixed(2)}',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit, color: AppColors.pastelOrange, size: 20),
                          onPressed: () => _editarDeduccionAdicional(index),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                          onPressed: () => _eliminarDeduccionAdicional(index),
                        ),
                      ],
                    ),
                  );
                }),
              ] else if (sueldoBruto == 0) ...[
                const SizedBox(height: 8),
                const Text(
                  'Calcule la liquidación para ver las deducciones legales',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildDeduccionLegal(String nombre, String porcentaje, double monto, {double sueldoBruto = 0.0}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.glassFill.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.glassBorder.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock, color: AppColors.textMuted, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      nombre,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '($porcentaje)',
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                Text(
                  sueldoBruto > 0 ? '\$${monto.toStringAsFixed(2)}' : 'Se calculará automáticamente',
                  style: TextStyle(
                    color: sueldoBruto > 0 ? AppColors.textSecondary : AppColors.textMuted,
                    fontSize: 12,
                    fontStyle: sueldoBruto == 0 ? FontStyle.italic : FontStyle.normal,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildBotonesAccion() {
    return ElevatedButton(
      onPressed: _calcularLiquidacion,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.pastelBlue,
        foregroundColor: AppColors.background,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: const Text(
        'Calcular Liquidación',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
  
  Widget _buildTablaLiquidacion() {
    if (_liquidacion == null) return const SizedBox.shrink();
    
    final sueldoBasico = double.tryParse(_sueldoBasicoController.text) ?? 0.0;
    final conceptos = _liquidacion!.obtenerConceptosParaTabla(sueldoBasico);
    
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.glassFillStrong,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.glassBorder, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Detalle de Liquidación',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(AppColors.glassFill),
                  dataRowColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return AppColors.glassFillStrong;
                    }
                    return Colors.transparent;
                  }),
                  columns: const [
                    DataColumn(
                      label: Text(
                        'Concepto',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Remunerativo',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      numeric: true,
                    ),
                    DataColumn(
                      label: Text(
                        'No Remunerativo',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      numeric: true,
                    ),
                    DataColumn(
                      label: Text(
                        'Deducciones',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      numeric: true,
                    ),
                  ],
                  rows: conceptos.map((concepto) {
                    return DataRow(
                      cells: [
                        DataCell(Text(
                          concepto.concepto,
                          style: const TextStyle(color: AppColors.textPrimary),
                        )),
                        DataCell(Text(
                          concepto.remunerativo > 0
                              ? '\$${concepto.remunerativo.toStringAsFixed(2)}'
                              : '',
                          style: const TextStyle(color: AppColors.textPrimary),
                        )),
                        DataCell(Text(
                          concepto.noRemunerativo > 0
                              ? '\$${concepto.noRemunerativo.toStringAsFixed(2)}'
                              : '',
                          style: const TextStyle(color: AppColors.textPrimary),
                        )),
                        DataCell(Text(
                          concepto.deducciones > 0
                              ? '\$${concepto.deducciones.toStringAsFixed(2)}'
                              : '',
                          style: const TextStyle(color: AppColors.textPrimary),
                        )),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildTotales() {
    if (_liquidacion == null) return const SizedBox.shrink();
    
    final sueldoBasico = double.tryParse(_sueldoBasicoController.text) ?? 0.0;
    final sueldoBruto = _liquidacion!.calcularSueldoBruto(sueldoBasico);
    final totalDeducciones = _liquidacion!.calcularTotalDeducciones(sueldoBruto);
    final totalNoRemunerativo = _liquidacion!.calcularTotalNoRemunerativo();
    final sueldoNeto = _liquidacion!.calcularSueldoNeto(sueldoBasico);
    
    return FutureBuilder<ParametrosLegales>(
      future: _parametrosLegalesFuture,
      builder: (context, snapshot) {
        final parametrosLegales = snapshot.data;
        final mostrarAdvertenciaSMVM = parametrosLegales != null && 
            parametrosLegales.sueldoPorDebajoSMVM(sueldoBruto);
        
        return ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.glassFillStrong,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.glassBorder, width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (mostrarAdvertenciaSMVM)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange, width: 1),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Atención: El sueldo bruto está por debajo del Mínimo Vital y Móvil vigente (\$${parametrosLegales.smvm.toStringAsFixed(2)})',
                              style: const TextStyle(
                                color: Colors.orange,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  _buildTotalItem('Sueldo Bruto', sueldoBruto),
                  _buildTotalItem('Total No Remunerativo', totalNoRemunerativo),
                  _buildTotalItem('Total Deducciones', totalDeducciones),
                  const Divider(color: AppColors.glassBorder),
                  _buildTotalItem(
                    'SUELDO NETO A COBRAR',
                    sueldoNeto,
                    isDestacado: true,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildTotalItem(String label, double valor, {bool isDestacado = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isDestacado ? AppColors.textPrimary : AppColors.textSecondary,
              fontSize: isDestacado ? 18 : 14,
              fontWeight: isDestacado ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            '\$${valor.toStringAsFixed(2)}',
            style: TextStyle(
              color: isDestacado ? AppColors.pastelBlue : AppColors.textPrimary,
              fontSize: isDestacado ? 18 : 14,
              fontWeight: isDestacado ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
  
  void _mostrarInstructivoArca() {
    final l = _liquidacion;
    final codigosUsados = <String>[];
    
    if (l != null) {
      codigosUsados.add(GeneralesLsdCodigos.sueldoBasico);
      
      if (l.cantidadHorasExtras50 > 0) codigosUsados.add(GeneralesLsdCodigos.horasExtras50);
      if (l.cantidadHorasExtras100 > 0) codigosUsados.add(GeneralesLsdCodigos.horasExtras100);
      if (l.kilometrosRecorridos > 0) codigosUsados.add(GeneralesLsdCodigos.kilometros);
      if (l.diasViaticosComida > 0) codigosUsados.add(GeneralesLsdCodigos.viaticos);
      if (l.diasPernocte > 0) codigosUsados.add(GeneralesLsdCodigos.pernocte);
      
      // Premios
      if (l.premios > 0) codigosUsados.add(GeneralesLsdCodigos.premios);
      
      // Vacaciones
      if (l.vacacionesActivas || l.montoVacaciones > 0) {
        codigosUsados.add(GeneralesLsdCodigos.vacaciones);
        if (l.plusVacacional > 0) codigosUsados.add(GeneralesLsdCodigos.plusVacacional);
      }
      
      // Aportes
      codigosUsados.add(GeneralesLsdCodigos.jubilacion);
      codigosUsados.add(GeneralesLsdCodigos.obraSocial);
      codigosUsados.add(GeneralesLsdCodigos.ley19032);
      
      if (l.afiliadoSindical) codigosUsados.add(GeneralesLsdCodigos.sindicato);
      if (l.impuestoGanancias > 0) codigosUsados.add(GeneralesLsdCodigos.ganancias);
      
      // Conceptos adicionales propios
      for (final c in l.conceptosRemunerativos.keys) {
         codigosUsados.add(c); 
      }
       for (final c in l.conceptosNoRemunerativosAdicionales.keys) {
         codigosUsados.add(c);
      }
      for (final c in l.deduccionesAdicionales.keys) {
         codigosUsados.add(c);
      }

    } else {
      // Default basic codes
      codigosUsados.addAll([
        GeneralesLsdCodigos.sueldoBasico,
        GeneralesLsdCodigos.jubilacion,
        GeneralesLsdCodigos.obraSocial,
        GeneralesLsdCodigos.ley19032
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

  Widget _buildBotonesDescargaARCA() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.glassFillStrong,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.glassBorder, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Descargas ARCA',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              
              // Botón Instructivo
              TextButton.icon(
                 onPressed: _mostrarInstructivoArca,
                 icon: const Icon(Icons.info_outline, size: 18, color: Colors.blue),
                 label: const Text('Ver Instructivo de Asociación (Leer antes de subir)'),
                 style: TextButton.styleFrom(
                   foregroundColor: Colors.blue,
                   alignment: Alignment.centerLeft,
                   padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
                 ),
               ),
               const SizedBox(height: 8),

              // Botón 1: Descargar Catálogo de Conceptos
              Tooltip(
                message: 'Subir este archivo primero en el portal de ARCA para dar de alta sus códigos',
                child: ElevatedButton.icon(
                  onPressed: _descargarCatalogoConceptos,
                  icon: const Icon(Icons.download, size: 20),
                  label: const Text(
                    '1. Descargar Catálogo de Conceptos',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.pastelMint,
                    foregroundColor: AppColors.background,
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Botón 2: Descargar Liquidación (LSD)
              ElevatedButton.icon(
                onPressed: _descargarLiquidacionLSD,
                icon: const Icon(Icons.download, size: 20),
                label: const Text(
                  '2. Descargar Liquidación (LSD)',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.pastelBlue,
                  foregroundColor: AppColors.background,
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _generarExcel() async {
    if (_liquidacion == null || _datosEmpleado == null || _empresaSeleccionada == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Complete todos los datos y calcule la liquidación antes de exportar'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final sueldoBasico = double.tryParse(_sueldoBasicoController.text) ?? 0.0;
      final bruto = _liquidacion!.calcularSueldoBruto(sueldoBasico);
      final aportes = _liquidacion!.calcularAportes(bruto);
      final totalAportes = aportes.values.fold(0.0, (sum, val) => sum + val);
      final totalDescuentos = _liquidacion!.calcularTotalDescuentos(bruto);
      final neto = _liquidacion!.calcularSueldoNeto(bruto);
      
      // Intentar obtener antigüedad si existe en conceptos remunerativos
      double antiguedad = 0.0;
      _liquidacion!.conceptosRemunerativos.forEach((key, value) {
        if (key.toLowerCase().contains('antigüedad') || key.toLowerCase().contains('antiguedad')) {
          antiguedad += value;
        }
      });
      
      // Calcular otros remunerativos (todo lo que no es básico ni antigüedad)
      double otrosRem = bruto - sueldoBasico - antiguedad;
      if (otrosRem < 0) otrosRem = 0; 

      // Calcular no remunerativos
      double noRem = _liquidacion!.conceptosNoRemunerativos;
      _liquidacion!.conceptosNoRemunerativosAdicionales.forEach((_, val) => noRem += val);
      noRem += _liquidacion!.montoViaticosComida;
      noRem += _liquidacion!.montoPernocte;

      final liqMap = {
        'cuil': _datosEmpleado!['cuil'],
        'nombre': _datosEmpleado!['nombre'],
        'categoria': _datosEmpleado!['categoriaNombre'] ?? '',
        'basico': sueldoBasico,
        'antiguedad': antiguedad,
        'conceptosRemunerativos': otrosRem,
        'totalBruto': bruto,
        'totalAportes': totalAportes,
        'descuentos': totalDescuentos, 
        'conceptosNoRemunerativos': noRem,
        'neto': neto,
        'totalContribuciones': bruto * 0.24, // Estimado patronal 24%
      };
      
      // Parsear periodo
      int mes = DateTime.now().month;
      int anio = DateTime.now().year;
      final periodoText = _periodoController.text;
      final partes = periodoText.split(' ');
      if (partes.length >= 2) {
        anio = int.tryParse(partes[1]) ?? anio;
        final meses = [
          'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
          'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
        ];
        final mesIndex = meses.indexOf(partes[0]);
        if (mesIndex >= 0) mes = mesIndex + 1;
      }

      final path = await ExcelExportService.generarLibroSueldos(
        mes: mes,
        anio: anio,
        liquidaciones: [liqMap],
        empresaNombre: _empresaSeleccionada,
      );
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Excel generado correctamente'),
          backgroundColor: Colors.green,
          action: SnackBarAction(
            label: 'ABRIR',
            textColor: Colors.white,
            onPressed: () => OpenFile.open(path),
          ),
        ),
      );
      
      OpenFile.open(path);

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al generar Excel: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Widget _buildBotonGenerarPDF() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: _generarPDF,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.pastelOrange,
                  foregroundColor: AppColors.background,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Generar Recibo PDF',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _generarExcel,
                icon: const Icon(Icons.table_chart),
                label: const Text('Exportar Excel'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _generarLSD,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.pastelBlue,
                  foregroundColor: AppColors.background,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Generar LSD AFIP',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
  
  Future<void> _generarLSD() async {
    if (_liquidacion == null || _datosEmpleado == null || _empresaSeleccionada == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Complete todos los datos y calcule la liquidación antes de generar el LSD'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    final sueldoBasico = double.tryParse(_sueldoBasicoController.text) ?? 0.0;
    if (sueldoBasico <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El sueldo básico debe ser mayor a 0'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    // Obtener datos de la empresa
    final empresaData = _empresas.firstWhere(
      (e) => e['razonSocial'] == _empresaSeleccionada,
      orElse: () => {},
    );
    
    if (empresaData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se encontraron datos de la empresa'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    // Crear modelo de empresa
    final empresa = Empresa(
      razonSocial: empresaData['razonSocial'] ?? '',
      cuit: empresaData['cuit'] ?? '',
      domicilio: empresaData['domicilio'] ?? '',
      convenioId: '',
      convenioNombre: _datosEmpleado!['convenioNombre']?.toString() ?? '',
      convenioPersonalizado: false,
      categorias: [],
      parametros: [],
    );
    
    // Crear modelo de empleado para LSD
    final empleado = Empleado(
      nombre: _datosEmpleado!['nombre']?.toString() ?? '',
      categoria: _datosEmpleado!['categoriaNombre']?.toString() ?? '',
      sueldoBasico: sueldoBasico,
      periodo: _periodoController.text,
      fechaPago: _fechaPagoController.text,
      fechaIngreso: _datosEmpleado!['fechaIngreso']?.toString(),
      lugarPago: empresaData['domicilio'],
    );
    
    try {
      final directory = await getApplicationDocumentsDirectory();
      final fechaGeneracion = DateTime.now();
      final lsdFilePath = await _generarArchivoLSD(
        empresa: empresa,
        empleado: empleado,
        liquidacion: _liquidacion!,
        sueldoBasico: sueldoBasico,
        directory: directory,
        fechaGeneracion: fechaGeneracion,
      );
      
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.backgroundLight,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Archivo LSD Generado',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: const Text(
            'El archivo LSD para AFIP se ha generado correctamente.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                OpenFile.open(lsdFilePath);
              },
              child: const Text('Abrir Archivo'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      
      // Mostrar error detallado en un diálogo
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.backgroundLight,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Error al Generar Archivo LSD',
            style: TextStyle(
              color: Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'No se pudo generar el archivo LSD para AFIP.',
                style: TextStyle(color: AppColors.textPrimary),
              ),
              const SizedBox(height: 12),
              Text(
                'Error: ${e.toString()}',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Por favor, verifique:',
                style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              const Text(
                '• CUIT de la empresa debe tener 11 dígitos\n'
                '• CUIL del empleado debe tener 11 dígitos\n'
                '• Fecha de pago debe estar completa\n'
                '• Todos los datos deben estar correctos',
                style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al generar archivo LSD: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  /// Descarga el catálogo de conceptos para ARCA
  Future<void> _descargarCatalogoConceptos() async {
    try {
      // Generar el contenido del archivo de conceptos
      final contenido = LSDGenerator.generarArchivoConceptosTXT();
      
      // Guardar el archivo
      final directory = await getApplicationDocumentsDirectory();
      final fechaGeneracion = DateTime.now();
      final fechaStr = '${fechaGeneracion.year}${fechaGeneracion.month.toString().padLeft(2, '0')}${fechaGeneracion.day.toString().padLeft(2, '0')}_${fechaGeneracion.hour.toString().padLeft(2, '0')}${fechaGeneracion.minute.toString().padLeft(2, '0')}';
      final filePath = '${directory.path}/conceptos_importacion_arca_$fechaStr.txt';
      final file = File(filePath);
      
      // Codificar en Latin-1 (ANSI)
      final bytes = latin1.encode(contenido);
      await file.writeAsBytes(bytes);
      
      if (!mounted) return;
      
      // Mostrar diálogo de éxito
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.backgroundLight,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Catálogo de Conceptos Generado',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: const Text(
            'El archivo de catálogo de conceptos se ha generado correctamente.\n\n'
            'Recuerde: Suba este archivo primero en el portal de ARCA para dar de alta sus códigos.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                OpenFile.open(filePath);
              },
              child: const Text('Abrir Archivo'),
            ),
          ],
        ),
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Catálogo de conceptos generado exitosamente'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al generar catálogo: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  /// Descarga la liquidación en formato LSD para ARCA con validación previa
  Future<void> _descargarLiquidacionLSD() async {
    if (_liquidacion == null || _datosEmpleado == null || _empresaSeleccionada == null) {
      _mostrarErrorValidacion('Complete todos los datos y calcule la liquidación antes de descargar el LSD');
      return;
    }
    
    final sueldoBasico = double.tryParse(_sueldoBasicoController.text) ?? 0.0;
    if (sueldoBasico <= 0) {
      _mostrarErrorValidacion('El sueldo básico debe ser mayor a 0');
      return;
    }
    
    // Obtener datos de la empresa
    final empresaData = _empresas.firstWhere(
      (e) => e['razonSocial'] == _empresaSeleccionada,
      orElse: () => {},
    );
    
    if (empresaData.isEmpty) {
      _mostrarErrorValidacion('No se encontraron datos de la empresa');
      return;
    }
    
    // Validar CUIL del empleado con algoritmo de Módulo 11
    final cuilEmpleadoRaw = _datosEmpleado!['cuil']?.toString() ?? '';
    if (cuilEmpleadoRaw.isEmpty) {
      _mostrarErrorValidacion('CUIL del empleado no puede estar vacío.');
      return;
    }
    
    final cuilEmpleado = cuilEmpleadoRaw.replaceAll(RegExp(r'[^\d]'), '');
    if (cuilEmpleado.length != 11) {
      _mostrarErrorValidacion('CUIL del empleado debe tener 11 dígitos numéricos.');
      return;
    }
    
    // Validación matemática con algoritmo de Módulo 11
    if (!validarCUITCUIL(cuilEmpleadoRaw)) {
      _mostrarErrorValidacion('CUIL del empleado inválido: Verifique los dígitos. El número no cumple con el algoritmo de validación de ARCA/AFIP.');
      return;
    }
    
    // Validar CUIT de la empresa con algoritmo de Módulo 11
    final cuitEmpresaRaw = empresaData['cuit']?.toString() ?? '';
    if (cuitEmpresaRaw.isEmpty) {
      _mostrarErrorValidacion('CUIT de la empresa no puede estar vacío.');
      return;
    }
    
    final cuitEmpresa = cuitEmpresaRaw.replaceAll(RegExp(r'[^\d]'), '');
    if (cuitEmpresa.length != 11) {
      _mostrarErrorValidacion('CUIT de la empresa debe tener 11 dígitos numéricos.');
      return;
    }
    
    // Validación matemática con algoritmo de Módulo 11
    if (!validarCUITCUIL(cuitEmpresaRaw)) {
      _mostrarErrorValidacion('CUIT de la empresa inválido: Verifique los dígitos. El número no cumple con el algoritmo de validación de ARCA/AFIP.');
      return;
    }
    
    // Crear modelo de empresa
    final empresa = Empresa(
      razonSocial: empresaData['razonSocial'] ?? '',
      cuit: empresaData['cuit'] ?? '',
      domicilio: empresaData['domicilio'] ?? '',
      convenioId: '',
      convenioNombre: _datosEmpleado!['convenioNombre']?.toString() ?? '',
      convenioPersonalizado: false,
      categorias: [],
      parametros: [],
    );
    
    // Crear modelo de empleado para LSD
    final empleado = Empleado(
      nombre: _datosEmpleado!['nombre']?.toString() ?? '',
      categoria: _datosEmpleado!['categoriaNombre']?.toString() ?? '',
      sueldoBasico: sueldoBasico,
      periodo: _periodoController.text,
      fechaPago: _fechaPagoController.text,
      fechaIngreso: _datosEmpleado!['fechaIngreso']?.toString(),
      lugarPago: empresaData['domicilio'],
    );
    
    try {
      // Generar contenido del archivo primero para validarlo
      final directory = await getApplicationDocumentsDirectory();
      final fechaGeneracion = DateTime.now();
      final lsdFilePath = await _generarArchivoLSD(
        empresa: empresa,
        empleado: empleado,
        liquidacion: _liquidacion!,
        sueldoBasico: sueldoBasico,
        directory: directory,
        fechaGeneracion: fechaGeneracion,
      );
      
      // Leer el archivo generado para validarlo
      final archivoGenerado = await File(lsdFilePath).readAsString();
      final validacion = LSDGenerator.validarArchivoLSD(archivoGenerado);
      
      if (!mounted) return;
      
      // Si hay errores, mostrar modal de error
      final esValido = validacion['valido'] as bool;
      if (!esValido) {
        final erroresList = validacion['errores'] as List<dynamic>;
        final erroresString = erroresList.map((e) => e.toString()).toList();
        _mostrarErrorValidacionDetallado(erroresString);
        // Eliminar archivo inválido
        try {
          await File(lsdFilePath).delete();
        } catch (_) {
          // Ignorar errores al eliminar
        }
        return;
      }
      
      // Si todo está OK, mostrar diálogo de éxito con check
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.backgroundLight,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 28),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Archivo Validado con Éxito',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: const Text(
            'El archivo LSD para ARCA se ha generado y validado correctamente.\n\n'
            '✓ Todas las líneas tienen 150 caracteres\n'
            '✓ Todos los CUILs son válidos\n'
            '✓ Todos los conceptos tienen código asignado\n\n'
            'Puede subirlo al portal de ARCA para procesar la liquidación.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                OpenFile.open(lsdFilePath);
              },
              child: const Text('Abrir Archivo'),
            ),
          ],
        ),
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Archivo LSD generado y validado exitosamente'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      
      _mostrarErrorValidacion('Error al generar archivo LSD: ${e.toString()}');
    }
  }
  
  /// Muestra un modal de error de validación detallado
  void _mostrarErrorValidacionDetallado(List<String> errores) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.backgroundLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Row(
          children: [
            Icon(Icons.error, color: Colors.red, size: 28),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Error de Validación',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'El archivo no puede ser descargado. Corrija los siguientes errores:',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ...errores.map((error) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.circle, size: 8, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        error,
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              )),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }
  
  /// Muestra un error de validación simple
  void _mostrarErrorValidacion(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
      ),
    );
  }
}

class _DialogConcepto extends StatefulWidget {
  final String titulo;
  final String? nombreInicial;
  final double? montoInicial;
  final Function(String nombre, double monto) onGuardar;
  
  const _DialogConcepto({
    required this.titulo,
    this.nombreInicial,
    this.montoInicial,
    required this.onGuardar,
  });
  
  @override
  State<_DialogConcepto> createState() => _DialogConceptoState();
}

class _DialogConceptoState extends State<_DialogConcepto> {
  final _nombreController = TextEditingController();
  final _montoController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  @override
  void initState() {
    super.initState();
    if (widget.nombreInicial != null) {
      _nombreController.text = widget.nombreInicial!;
    }
    if (widget.montoInicial != null) {
      _montoController.text = widget.montoInicial!.toStringAsFixed(2);
    }
  }
  
  @override
  void dispose() {
    _nombreController.dispose();
    _montoController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.backgroundLight,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: Text(
        widget.titulo,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nombreController,
              decoration: InputDecoration(
                labelText: 'Nombre del Concepto',
                filled: true,
                fillColor: AppColors.glassFill,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.glassBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.glassBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.pastelBlue, width: 2),
                ),
                labelStyle: const TextStyle(color: AppColors.textSecondary),
              ),
              style: const TextStyle(color: AppColors.textPrimary),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'El nombre es obligatorio';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _montoController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Monto',
                filled: true,
                fillColor: AppColors.glassFill,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.glassBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.glassBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.pastelBlue, width: 2),
                ),
                labelStyle: const TextStyle(color: AppColors.textSecondary),
              ),
              style: const TextStyle(color: AppColors.textPrimary),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'El monto es obligatorio';
                }
                final monto = double.tryParse(value);
                if (monto == null || monto < 0) {
                  return 'Ingrese un monto válido';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final nombre = _nombreController.text.trim();
              final monto = double.parse(_montoController.text);
              widget.onGuardar(nombre, monto);
              Navigator.pop(context);
            }
          },
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
