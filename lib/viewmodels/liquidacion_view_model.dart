
import 'package:flutter/material.dart';

import '../models/cct_completo.dart';
import '../services/convenios_service.dart';
import '../services/lsd_service.dart';
import '../services/pdf_service.dart';
import '../services/sanidad_omni_engine.dart';
import '../utils/image_bytes_reader.dart';

class LiquidacionViewModel extends ChangeNotifier {
  final PdfService _pdfService = PdfService();
  final LsdService _lsdService = LsdService();

  List<Map<String, dynamic>> _empresas = [];
  List<Map<String, dynamic>> get empresas => _empresas;

  List<Map<String, dynamic>> _empleados = [];
  List<Map<String, dynamic>> get empleados => _empleados;

  Map<String, String>? _empresaSeleccionada;
  Map<String, String>? get empresaSeleccionada => _empresaSeleccionada;

  Map<String, dynamic>? _empleadoSeleccionado;
  Map<String, dynamic>? get empleadoSeleccionado => _empleadoSeleccionado;

  CCTCompleto? _convenioEmpleado;

  dynamic _liquidacion;
  dynamic get liquidacion => _liquidacion;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  String? _successMessage;
  String? get successMessage => _successMessage;

  String sueldoBasico = '0.0';
  String periodo = '';
  String fechaPago = '';
  int diasInasistencia = 0;

  LiquidacionViewModel() {
    _init();
  }

  void _init() async {
    _setLoading(true);
    await _cargarEmpresas();
    periodo = _obtenerPeriodoActual();
    fechaPago = _obtenerFechaPagoSugerida();
    _setLoading(false);
  }

  Future<void> _cargarEmpresas() async {
    _empresas = [
      {
        'cuit': '30-12345678-9',
        'razonSocial': 'Mi Sanatorio S.A.',
        'domicilio': 'Calle Falsa 123, Ciudad'
      }
    ];
    notifyListeners();
  }

  Future<void> onEmpresaSeleccionada(Map<String, dynamic> empresa) async {
    _setLoading(true);
    _empresaSeleccionada = Map<String, String>.from(empresa);
    _empleadoSeleccionado = null;
    _liquidacion = null;

    _empleados = [
      {
        'nombre': 'Juan Perez',
        'cuil': '20-12345678-5',
        'convenioId': 'CCT 122/75',
        'categoriaId': 'enfermero',
        'fechaIngreso': '2018-01-01',
        'codigoRnos': '126205'
      }
    ];
    _setLoading(false);
  }

  Future<void> onEmpleadoSeleccionado(Map<String, dynamic> empleado) async {
    _setLoading(true);
    _empleadoSeleccionado = empleado;
    _liquidacion = null;

    final convenioId = empleado['convenioId']?.toString();
    if (convenioId != null) {
      _convenioEmpleado = await ConveniosService.getConvenioById(convenioId);
    }

    if (_convenioEmpleado != null && _convenioEmpleado!.categorias.isNotEmpty) {
      final categoriaEmpleado = _convenioEmpleado!.categorias.firstWhere(
          (c) => c.id == empleado['categoriaId'],
          orElse: () => CategoriaCCT(id: '', nombre: '', salarioBase: 0, descripcion: ''));
      if (categoriaEmpleado.salarioBase > 0) {
        sueldoBasico = categoriaEmpleado.salarioBase.toStringAsFixed(2);
      }
    }
    _setLoading(false);
  }

  Future<void> calcularLiquidacion() async {
    if (_empleadoSeleccionado == null || _convenioEmpleado == null) {
      _setError('Seleccione un empleado con un convenio válido.');
      return;
    }
    
    _setLoading(true);
    _clearMessages();

    try {
      final convenioId = _convenioEmpleado!.id;

      if (convenioId.contains('122/75') || convenioId.contains('108/75')) {
        final input = _crearInputSanidad();
        _liquidacion = SanidadOmniEngine.liquidar(input, periodo: periodo, fechaPago: fechaPago);
      } else {
        _setError('El convenio $convenioId aún no está soportado para el cálculo.');
        _liquidacion = null;
      }
    } catch (e) {
      _setError('Error al calcular la liquidación: ${e.toString()}');
      _liquidacion = null;
    }
    _setLoading(false);
  }
  
  // --- MÉTODOS DE EXPORTACIÓN ---

  Future<void> exportarReciboPDF() async {
    await _ejecutarAccionExportacion((liq) async {
      return await _pdfService.generarReciboPdf(
        liquidacion: liq,
        empresaData: _empresaSeleccionada!,
        empleadoData: _empleadoSeleccionado!,
      );
    }, 'Recibo PDF');
  }

  Future<void> exportarLsdTxt() async {
    await _ejecutarAccionExportacion((liq) async {
      return await _lsdService.generarLsdTxt(
        liquidaciones: [liq],
        convenioId: _empleadoSeleccionado!['convenioId'],
        empresaData: _empresaSeleccionada!,
      );
    }, 'Archivo LSD (.txt)');
  }

  Future<void> exportarPackARCA() async {
    await _ejecutarAccionExportacion((liq) async {
      return await _lsdService.generarPackARCA(
        liquidaciones: [liq],
        convenioId: _empleadoSeleccionado!['convenioId'],
        empresaData: _empresaSeleccionada!,
        generadorReciboPDF: (dynamic innerLiq) async {
          final path = await _pdfService.generarReciboPdf(
            liquidacion: innerLiq,
            empresaData: _empresaSeleccionada!,
            empleadoData: _empleadoSeleccionado!,
          );
          if (path == null) throw Exception('No se pudo generar el PDF para el ZIP.');
          final bytes = await readBytesFromFile(path);
          if (bytes == null) throw Exception('No se pudieron leer los bytes del archivo PDF.');
          return bytes;
        },
      );
    }, 'Pack ARCA (.zip)');
  }

  /// Método genérico para manejar la lógica común de exportación.
  Future<void> _ejecutarAccionExportacion(Future<String?> Function(dynamic) accion, String nombreArtefacto) async {
    if (_liquidacion == null || _empleadoSeleccionado == null || _empresaSeleccionada == null) {
      _setError('Calcule una liquidación antes de exportar.');
      return;
    }
    
    _setLoading(true);
    _clearMessages();

    try {
      final path = await accion(_liquidacion);
      _setSuccess('¡Éxito! $nombreArtefacto guardado en: $path');
    } catch (e) {
      _setError('Error al generar $nombreArtefacto: ${e.toString()}');
    }

    _setLoading(false);
  }

  SanidadEmpleadoInput _crearInputSanidad() {
    return SanidadEmpleadoInput(
        cuil: _empleadoSeleccionado!['cuil'],
        nombre: _empleadoSeleccionado!['nombre'],
        fechaIngreso: DateTime.parse(_empleadoSeleccionado!['fechaIngreso']),
        categoria: CategoriaSanidad.values.firstWhere(
          (e) => e.name == _empleadoSeleccionado!['categoriaId'],
          orElse: () => CategoriaSanidad.servicios,
        ),
        nivelTitulo: NivelTituloSanidad.sinTitulo,
        tareaCriticaRiesgo: false,
        aplicarCuotaSindicalAtsa: true,
        horasNocturnas: 0,
        manejoEfectivoCaja: false,
        horasExtras50: 0,
        horasExtras100: 0,
        adelantos: 0,
        embargos: 0,
        prestamos: 0,
        otrosDescuentos: 0,
        conceptosPropios: [],
        codigoRnos: _empleadoSeleccionado!['codigoRnos'],
        cantidadFamiliares: 0,
        codigoCondicion: '01',
        codigoActividad: '049',
        codigoPuesto: 'PUESTO1',
    );
  }
  
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? error) {
    _errorMessage = error;
    notifyListeners();
  }

  void _setSuccess(String? message) {
    _successMessage = message;
    notifyListeners();
  }

  void _clearMessages() {
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }

  String _obtenerPeriodoActual() {
    final meses = ['Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'];
    final now = DateTime.now();
    return '${meses[now.month - 1]} ${now.year}';
  }

  String _obtenerFechaPagoSugerida() {
    final now = DateTime.now();
    final primerDiaMesSiguiente = DateTime(now.year, now.month + 1, 1);
    int diasHabiles = 0;
    int diasCorridos = 0;
    DateTime fechaPago = primerDiaMesSiguiente;
    while (diasHabiles < 4) {
      fechaPago = primerDiaMesSiguiente.add(Duration(days: diasCorridos));
      if (fechaPago.weekday != DateTime.saturday && fechaPago.weekday != DateTime.sunday) {
        diasHabiles++;
      }
      diasCorridos++;
    }
    return '${fechaPago.year}-${fechaPago.month.toString().padLeft(2, '0')}-${fechaPago.day.toString().padLeft(2, '0')}';
  }
}
