import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'dart:io';
import 'dart:ui';

import 'package:elevar_liquidacion/models/liquidacion.dart';
import 'package:elevar_liquidacion/models/empresa.dart';
import 'package:elevar_liquidacion/models/empleado.dart';
import 'package:elevar_liquidacion/models/cct_completo.dart';
import 'package:elevar_liquidacion/data/cct_argentina_completo.dart';
import 'package:elevar_liquidacion/theme/app_colors.dart';
import 'package:elevar_liquidacion/utils/pdf_recibo.dart';
import 'package:elevar_liquidacion/services/lsd_engine.dart';
import 'package:elevar_liquidacion/screens/empresa_screen.dart';
import 'package:elevar_liquidacion/screens/empleado_screen.dart';

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
  final _horasExtras50Controller = TextEditingController();
  final _horasExtras100Controller = TextEditingController();
  final _premiosController = TextEditingController();
  final _impuestoGananciasController = TextEditingController();
  final _diasInasistenciaController = TextEditingController();
  
  // Conceptos no remunerativos
  final List<Map<String, dynamic>> _conceptosNoRemunerativos = [];
  
  // Deducciones adicionales
  final List<Map<String, dynamic>> _deduccionesAdicionales = [];
  
  // Flags
  bool _afiliadoSindical = false;
  bool _calcularGananciasAutomatico = true;
  bool _presentismoActivo = true; // Por defecto activado
  int _diasInasistencia = 0;
  double _porcentajePresentismo = 8.33; // Por defecto 8.33%
  
  // CUIT limpio para LSD (se limpia al cargar empleado, se usa en LSD, luego se vacía)
  String? _cuitEmpresaLimpioParaLSD;
  String? _cuilEmpleadoLimpioParaLSD;
  
  // Liquidación
  Liquidacion? _liquidacion;
  
  @override
  void initState() {
    super.initState();
    _cargarEmpresas();
    // Fecha de pago se deja vacía para que el usuario la complete
    _periodoController.text = _obtenerPeriodoActual();
  }
  
  @override
  void dispose() {
    _sueldoBasicoController.dispose();
    _periodoController.dispose();
    _fechaPagoController.dispose();
    _horasExtras50Controller.dispose();
    _horasExtras100Controller.dispose();
    _premiosController.dispose();
    _impuestoGananciasController.dispose();
    _diasInasistenciaController.dispose();
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
    final prefs = await SharedPreferences.getInstance();
    final List<String> empresasData = prefs.getStringList('empresas') ?? [];
    
    setState(() {
      _empresas = empresasData.map((empresaStr) {
        final partes = empresaStr.split('|');
        // Limpiar espacios en blanco del CUIT al cargar
        final cuit = partes.length > 1 ? partes[1].trim() : '';
        return {
          'razonSocial': partes[0],
          'cuit': cuit,
          'domicilio': partes.length > 2 ? partes[2] : '',
        };
      }).toList();
    });
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
    });
    
    if (razonSocial != null) {
      _cargarEmpleados(razonSocial);
    }
  }
  
  void _onEmpleadoSeleccionado(String? cuil) {
    setState(() {
      _empleadoSeleccionado = cuil;
      _datosEmpleado = null;
      _sueldoBasicoCategoria = null;
      _sueldoBasicoController.clear();
      // Limpiar campos de horas extras
      _horasExtras50Controller.clear();
      _horasExtras100Controller.clear();
      // Limpiar CUIT/CUIL para LSD
      _cuitEmpresaLimpioParaLSD = null;
      _cuilEmpleadoLimpioParaLSD = null;
    });
    
    if (cuil == null) return;
    
    final empleado = _empleados.firstWhere(
      (e) => e['cuil']?.toString().replaceAll('-', '') == cuil.replaceAll('-', ''),
      orElse: () => {},
    );
    
    if (empleado.isEmpty) return;
    
    // Limpiar CUIL del empleado para LSD (quitar guiones y espacios, dejar solo números)
    final cuilLimpio = cuil.replaceAll(RegExp(r'[^\d]'), '').trim();
    if (cuilLimpio.length == 11) {
      _cuilEmpleadoLimpioParaLSD = cuilLimpio;
    }
    
    // Limpiar CUIT de la empresa para LSD
    if (_empresaSeleccionada != null) {
      final empresaData = _empresas.firstWhere(
        (e) => e['razonSocial'] == _empresaSeleccionada,
        orElse: () => {},
      );
      if (empresaData.isNotEmpty && empresaData['cuit'] != null) {
        final cuitEmpresa = empresaData['cuit'].toString().trim();
        final cuitLimpio = cuitEmpresa.replaceAll(RegExp(r'[^\d]'), '').trim();
        if (cuitLimpio.length == 11) {
          _cuitEmpresaLimpioParaLSD = cuitLimpio;
        }
      }
    }
    
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
        orElse: () => const CCTCompleto(
          id: '',
          numeroCCT: '',
          nombre: '',
          descripcion: '',
          categorias: [],
          descuentos: [],
          zonas: [],
          adicionalPresentismo: 8.33, // Valor por defecto
        ),
      );
      
      if (convenio.id.isNotEmpty) {
        setState(() {
          _porcentajePresentismo = convenio.adicionalPresentismo;
        });
      }
    } catch (e) {
      // Si no se encuentra, usar valor por defecto
      setState(() {
        _porcentajePresentismo = 8.33;
      });
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
  
  Future<String> _generarArchivoLSD({
    required Empresa empresa,
    required Empleado empleado,
    required Liquidacion liquidacion,
    required double sueldoBasico,
    required Directory directory,
    required DateTime fechaGeneracion,
  }) async {
    // Usar las variables de CUIT/CUIL limpias preparadas al cargar el empleado
    if (_cuilEmpleadoLimpioParaLSD == null || _cuilEmpleadoLimpioParaLSD!.isEmpty) {
      throw ArgumentError('El CUIL del empleado no está disponible. Por favor, seleccione el empleado nuevamente.');
    }
    
    if (_cuitEmpresaLimpioParaLSD == null || _cuitEmpresaLimpioParaLSD!.isEmpty) {
      throw ArgumentError('El CUIT de la empresa no está disponible. Por favor, seleccione la empresa y el empleado nuevamente.');
    }
    
    // Usar las variables limpias
    final cuilLimpio = _cuilEmpleadoLimpioParaLSD!;
    final cuitEmpresaLimpio = _cuitEmpresaLimpioParaLSD!;
    
    final nombreArchivo = 'lsd_${cuitEmpresaLimpio}_${fechaGeneracion.millisecondsSinceEpoch}.txt';
    final file = File('${directory.path}/$nombreArchivo');
    
    final registros = <Uint8List>[];
    
    // Registro 1: Cabecera
    final registro1 = LSDGenerator.generateRegistro1(
      cuitEmpresa: cuitEmpresaLimpio,
      periodo: _periodoController.text,
      fechaPago: _fechaPagoController.text,
      razonSocial: empresa.razonSocial,
      domicilio: empresa.domicilio,
    );
    registros.add(registro1);
    
    // Registro 3: Conceptos
    final sueldoBruto = liquidacion.calcularSueldoBruto(sueldoBasico);
    
    // Sueldo básico
    final sueldoBasicoProporcional = liquidacion.obtenerSueldoBasicoProporcional(sueldoBasico);
    if (sueldoBasicoProporcional > 0) {
      registros.add(LSDGenerator.generateRegistro2Conceptos(
        cuilEmpleado: cuilLimpio,
        codigoConcepto: '001', // Código AFIP para Sueldo Básico
        importe: sueldoBasicoProporcional,
        descripcionConcepto: 'Sueldo Básico',
      ));
    }
    
    // Presentismo (remunerativo) - solo si está activo y no hay inasistencias
    if (liquidacion.presentismoActivo && liquidacion.diasInasistencia == 0) {
      final presentismo = sueldoBasicoProporcional * (liquidacion.porcentajePresentismo / 100);
      if (presentismo > 0) {
        registros.add(LSDGenerator.generateRegistro2Conceptos(
          cuilEmpleado: cuilLimpio,
          codigoConcepto: '002', // Código AFIP para Presentismo
          importe: presentismo,
          descripcionConcepto: 'Presentismo',
        ));
      }
    }
    
    // Horas extras 50% (no remunerativo) - usar monto calculado
    // ignore: deprecated_member_use_from_same_package
    if (liquidacion.horasExtras50 > 0) {
      registros.add(LSDGenerator.generateRegistro2Conceptos(
        cuilEmpleado: cuilLimpio,
        codigoConcepto: '002',
        // ignore: deprecated_member_use_from_same_package
        importe: liquidacion.horasExtras50,
        descripcionConcepto: 'Horas Extras 50%',
      ));
    }
    
    // Horas extras 100% (no remunerativo) - usar monto calculado
    // ignore: deprecated_member_use_from_same_package
    if (liquidacion.horasExtras100 > 0) {
      registros.add(LSDGenerator.generateRegistro2Conceptos(
        cuilEmpleado: cuilLimpio,
        codigoConcepto: '003',
        // ignore: deprecated_member_use_from_same_package
        importe: liquidacion.horasExtras100,
        descripcionConcepto: 'Horas Extras 100%',
      ));
    }
    
    // Premios (no remunerativo)
    final premios = double.tryParse(_premiosController.text) ?? 0.0;
    if (premios > 0) {
      registros.add(LSDGenerator.generateRegistro2Conceptos(
        cuilEmpleado: cuilLimpio,
        codigoConcepto: '004',
        importe: premios,
        descripcionConcepto: 'Premios',
      ));
    }
    
    // Conceptos no remunerativos
    final totalNoRemunerativo = liquidacion.calcularTotalNoRemunerativo();
    if (totalNoRemunerativo > 0) {
      registros.add(LSDGenerator.generateRegistro2Conceptos(
        cuilEmpleado: cuilLimpio,
        codigoConcepto: '005',
        importe: totalNoRemunerativo,
        descripcionConcepto: 'Conceptos No Remunerativos',
      ));
    }
    
    // Deducciones
    final aportes = liquidacion.calcularAportes(sueldoBruto);
    if ((aportes['jubilacion'] ?? 0.0) > 0) {
      registros.add(LSDGenerator.generateRegistro2Conceptos(
        cuilEmpleado: cuilLimpio,
        codigoConcepto: '101',
        importe: -(aportes['jubilacion'] ?? 0.0),
        descripcionConcepto: 'Jubilación (SIPA)',
      ));
    }
    if ((aportes['ley19032'] ?? 0.0) > 0) {
      registros.add(LSDGenerator.generateRegistro2Conceptos(
        cuilEmpleado: cuilLimpio,
        codigoConcepto: '102',
        importe: -(aportes['ley19032'] ?? 0.0),
        descripcionConcepto: 'Ley 19.032 (PAMI)',
      ));
    }
    if ((aportes['obraSocial'] ?? 0.0) > 0) {
      registros.add(LSDGenerator.generateRegistro2Conceptos(
        cuilEmpleado: cuilLimpio,
        codigoConcepto: '103',
        importe: -(aportes['obraSocial'] ?? 0.0),
        descripcionConcepto: 'Obra Social',
      ));
    }
    if (liquidacion.afiliadoSindical && (aportes['cuotaSindical'] ?? 0.0) > 0) {
      registros.add(LSDGenerator.generateRegistro2Conceptos(
        cuilEmpleado: cuilLimpio,
        codigoConcepto: '104',
        importe: -(aportes['cuotaSindical'] ?? 0.0),
        descripcionConcepto: 'Cuota Sindical',
      ));
    }
    
    final ganancias = liquidacion.obtenerGanancias(sueldoBruto);
    if (ganancias > 0) {
      registros.add(LSDGenerator.generateRegistro2Conceptos(
        cuilEmpleado: cuilLimpio,
        codigoConcepto: '105',
        importe: -ganancias,
        descripcionConcepto: 'Retención Ganancias 4ta Cat.',
      ));
    }
    
    // Deducciones adicionales
    for (final deduccion in _deduccionesAdicionales) {
      registros.add(LSDGenerator.generateRegistro2Conceptos(
        cuilEmpleado: cuilLimpio,
        codigoConcepto: '199',
        importe: -(deduccion['monto'] as double),
        descripcionConcepto: deduccion['nombre'] as String,
      ));
    }
    
    // Escribir archivo
    final sink = file.openWrite();
    for (final registro in registros) {
      sink.add(registro);
      sink.writeln(); // Agregar salto de línea después de cada registro
    }
    await sink.close();
    
    // Vaciar las variables de CUIT/CUIL después de usarlas
    setState(() {
      _cuitEmpresaLimpioParaLSD = null;
      _cuilEmpleadoLimpioParaLSD = null;
    });
    
    return file.path;
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
    
    // ========== CÁLCULO DE HORAS EXTRAS - REINICIO COMPLETO ==========
    // Paso 1: Leer cantidad de horas de los controladores
    final cantidadHoras50 = double.tryParse(_horasExtras50Controller.text) ?? 0.0;
    final cantidadHoras100 = double.tryParse(_horasExtras100Controller.text) ?? 0.0;
    
    // Paso 2: Obtener convenio para saber qué divisor usar
    final convenioId = _datosEmpleado?['convenioId']?.toString();
    CCTCompleto? convenio;
    if (convenioId != null && convenioId.isNotEmpty && convenioId != 'fuera_convenio') {
      try {
        convenio = cctArgentinaCompleto.firstWhere(
          (c) => c.id == convenioId,
          orElse: () => const CCTCompleto(
            id: '', numeroCCT: '', nombre: '', descripcion: '',
            categorias: [], descuentos: [], zonas: [],
          ),
        );
      } catch (e) {
        // Si no se encuentra, convenio queda null
      }
    }
    
    // Paso 3: Calcular valor de hora normal según convenio
    double valorHoraNormal = 0.0;
    if (sueldoBasico > 0) {
      if (convenio != null && convenio.horasMensualesDivisor != null) {
        if (convenio.esDivisorDias) {
          // Camioneros: (Sueldo / días) / 8 horas
          valorHoraNormal = (sueldoBasico / convenio.horasMensualesDivisor!) / 8.0;
        } else {
          // Otros: Sueldo / horas mensuales
          valorHoraNormal = sueldoBasico / convenio.horasMensualesDivisor!;
        }
      } else {
        // Fuera de convenio: 200 horas estándar
        valorHoraNormal = sueldoBasico / 200.0;
      }
    }
    
    // Paso 4: Calcular montos de horas extras
    final montoHorasExtras50 = cantidadHoras50 > 0 
        ? (valorHoraNormal * 1.5) * cantidadHoras50 
        : 0.0;
    final montoHorasExtras100 = cantidadHoras100 > 0 
        ? (valorHoraNormal * 2.0) * cantidadHoras100 
        : 0.0;
    
    // Paso 5: Asignar a la liquidación (esto es lo que se muestra en el recibo)
    // NOTA: horasExtras50 y horasExtras100 fueron deprecados, ahora se usa cantidadHorasExtras50/100
    liquidacion.cantidadHorasExtras50 = cantidadHoras50.toInt();
    liquidacion.cantidadHorasExtras100 = cantidadHoras100.toInt();
    
    // También agregar a conceptos adicionales para compatibilidad
    if (montoHorasExtras50 > 0) {
      liquidacion.conceptosNoRemunerativosAdicionales['Horas Extras 50%'] = montoHorasExtras50;
    }
    if (montoHorasExtras100 > 0) {
      liquidacion.conceptosNoRemunerativosAdicionales['Horas Extras 100%'] = montoHorasExtras100;
    }
    
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
    
    setState(() {
      _liquidacion = liquidacion;
    });
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
    
    // Crear modelo de empresa - limpiar CUIT antes de crear el objeto
    final cuitEmpresa = (empresaData['cuit'] ?? '').toString().trim();
    if (cuitEmpresa.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El CUIT de la empresa no puede estar vacío. Por favor, verifique los datos de la empresa.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    final empresa = Empresa(
      razonSocial: empresaData['razonSocial'] ?? '',
      cuit: cuitEmpresa, // CUIT con formato (puede tener guiones, se limpiará al generar LSD)
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
    final sueldoBruto = _liquidacion!.calcularSueldoBruto(sueldoBasico);
    final totalDeducciones = _liquidacion!.calcularTotalDeducciones(sueldoBruto);
    final totalNoRemunerativo = _liquidacion!.calcularTotalNoRemunerativo();
    final sueldoNeto = _liquidacion!.calcularSueldoNeto(sueldoBasico);
    
    try {
      // Generar PDF
      final pdfBytes = await PdfRecibo.generarCompleto(
        empresa: empresa,
        empleado: empleado,
        conceptos: conceptosPDF,
        sueldoBruto: sueldoBruto,
        totalDeducciones: totalDeducciones,
        totalNoRemunerativo: totalNoRemunerativo,
        sueldoNeto: sueldoNeto,
      );
      
      // Guardar PDF
      final directory = await getApplicationDocumentsDirectory();
      final cuilLimpio = _empleadoSeleccionado!.replaceAll('-', '').replaceAll(' ', '');
      final fechaGeneracion = DateTime.now();
      final nombreArchivo = 'recibo_${cuilLimpio}_${fechaGeneracion.millisecondsSinceEpoch}.pdf';
      final file = File('${directory.path}/$nombreArchivo');
      await file.writeAsBytes(pdfBytes);
      
      // Guardar información del recibo
      final prefs = await SharedPreferences.getInstance();
      final recibosJson = prefs.getString('recibos_$cuilLimpio');
      List<dynamic> recibos = [];
      
      if (recibosJson != null && recibosJson.isNotEmpty) {
        try {
          recibos = jsonDecode(recibosJson);
        } catch (e) {
          recibos = [];
        }
      }
      
      recibos.add({
        'fechaGeneracion': fechaGeneracion.toIso8601String(),
        'periodo': _periodoController.text,
        'fechaPago': _fechaPagoController.text,
        'ruta': file.path,
        'sueldoNeto': sueldoNeto,
      });
      
      await prefs.setString('recibos_$cuilLimpio', jsonEncode(recibos));
      
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
        // Mostrar error del LSD en la UI
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al generar archivo LSD: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
        // También mostrar en diálogo para mejor visibilidad
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: AppColors.backgroundLight,
            title: const Text(
              'Error al Generar Archivo LSD',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
            content: Text(
              'Error: $e\n\nPor favor, verifique:\n- Que el CUIT de la empresa tenga 11 dígitos\n- Que el CUIL del empleado tenga 11 dígitos\n- Que todos los datos estén completos',
              style: const TextStyle(color: AppColors.textPrimary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cerrar'),
              ),
            ],
          ),
        );
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
      // Mostrar error detallado en diálogo
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.backgroundLight,
          title: const Text(
            'Error al Generar PDF',
            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Error: $e\n\nPor favor, verifique que todos los datos estén completos.',
            style: const TextStyle(color: AppColors.textPrimary),
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
          content: Text('Error al generar PDF: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
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
              _buildDatoSoloLectura('Convenio', _datosEmpleado!['convenioNombre']?.toString() ?? 'Fuera de Convenio'),
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
            ],
          ),
        ),
      ),
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
              // Horas Extras 50% (número de horas)
              _buildTextField(
                controller: _horasExtras50Controller,
                label: 'Horas Extras 50% (Número de horas)',
                hint: '0',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 16),
              // Horas Extras 100% (número de horas)
              _buildTextField(
                controller: _horasExtras100Controller,
                label: 'Horas Extras 100% (Número de horas)',
                hint: '0',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
  
  Widget _buildBotonGenerarPDF() {
    return Row(
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
    
    // Crear modelo de empresa - limpiar CUIT antes de crear el objeto
    final cuitEmpresa = (empresaData['cuit'] ?? '').toString().trim();
    if (cuitEmpresa.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El CUIT de la empresa no puede estar vacío. Por favor, verifique los datos de la empresa.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    final empresa = Empresa(
      razonSocial: empresaData['razonSocial'] ?? '',
      cuit: cuitEmpresa, // CUIT con formato (puede tener guiones, se limpiará al generar LSD)
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
      final errorMsg = e.toString();
      // Mostrar error detallado en diálogo
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.backgroundLight,
          title: const Text(
            '❌ Error al Generar Archivo LSD',
            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 18),
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Error detallado:',
                  style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 8),
                Text(
                  errorMsg,
                  style: const TextStyle(color: Colors.red, fontSize: 14),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Por favor, verifique:',
                  style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 8),
                const Text(
                  '• CUIT de la empresa debe tener 11 dígitos\n'
                  '• CUIL del empleado debe tener 11 dígitos\n'
                  '• Todos los datos deben estar completos',
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
                ),
              ],
            ),
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
        const SnackBar(
          content: Text('Error al generar archivo LSD. Ver detalles en el diálogo.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 5),
        ),
      );
    }
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
