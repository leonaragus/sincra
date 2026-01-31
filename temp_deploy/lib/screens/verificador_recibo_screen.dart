import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:syncra_arg/services/ocr_service.dart';
import 'package:syncra_arg/services/verificacion_recibo_service.dart';
import 'teacher_receipt_scan_screen.dart';
import 'package:syncra_arg/models/recibo_escaneado.dart';
import 'package:syncra_arg/services/hybrid_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncra_arg/services/parametros_legales_service.dart';
import 'package:syncra_arg/utils/app_help.dart';
import 'package:syncra_arg/theme/app_colors.dart';

class VerificadorReciboScreen extends StatefulWidget {
  const VerificadorReciboScreen({super.key});

  @override
  State<VerificadorReciboScreen> createState() =>
      _VerificadorReciboScreenState();
}

class _VerificadorReciboScreenState extends State<VerificadorReciboScreen> {
  final OcrService _ocrService = OcrService();
  final VerificacionReciboService _verificacionService = VerificacionReciboService();

  bool _estaProcesando = false;
  String? _rutaImagen;
  String _textoOcr = '';
  ResultadoVerificacion? _resultado;
  ReciboEscaneado? _recibo;
  double _ipcBase = 8.0;
  final double _ipcConservador = 6.0;
  final double _ipcOptimista = 10.0;
  double _ajusteMensual = 0.0;
  final TextEditingController _ipcController = TextEditingController(text: '8.0');
  final TextEditingController _ajusteController = TextEditingController(text: '0.0');
  DateTime? _fechaDocentes;
  DateTime? _fechaSanidad;
  double? _smvm;
  DateTime? _fechaIngreso;
  String _motivoCese = 'Renuncia'; // 'Renuncia' o 'Despido'
  
  // Nuevas variables para funcionalidad mejorada
  bool _mostrarDatosLeidos = true;
  String _convenioSeleccionado = 'Docente Federal';
  final List<String> _conveniosDisponibles = ['Docente Federal', 'Sanidad', 'Comercio', 'Gastronomía', 'Construcción'];
  
  // Variables para análisis de pago
  bool _mostrarBannerAcademia = true;

  
  /// Controlador para el menú hamburguesa
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void dispose() {
    _ocrService.dispose();
    _ipcController.dispose();
    _ajusteController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _cargarDatosAutomaticos();
  }

  Future<void> _cargarDatosAutomaticos() async {
    try {
      final docentes = await HybridStore.getMaestroParitarias();
      final sanidad = await HybridStore.getMaestroParitariasSanidad();
      double? indiceDocente;
      if (docentes.isNotEmpty) {
        final v = docentes.firstWhere(
          (e) => e.containsKey('valor_indice'),
          orElse: () => const {},
        )['valor_indice'];
        if (v is num) indiceDocente = v.toDouble();
      }
      final prefs = await SharedPreferences.getInstance();
      final fDoc = prefs.getString('ultima_sincronizacion_paritarias');
      final fSan = prefs.getString('ultima_sincronizacion_paritarias_sanidad');
      final params = await ParametrosLegalesService.cargarParametros();
      final smvm = params.smvm;
      if (mounted) {
        setState(() {
          if (indiceDocente != null && indiceDocente > 0) {
            _ipcBase = indiceDocente;
            _ipcController.text = _ipcBase.toStringAsFixed(1);
          }
          if (sanidad.isNotEmpty) {
            _ajusteMensual = 0.0;
            _ajusteController.text = _ajusteMensual.toStringAsFixed(1);
          }
          _fechaDocentes = fDoc != null ? DateTime.tryParse(fDoc) : null;
          _fechaSanidad = fSan != null ? DateTime.tryParse(fSan) : null;
          _smvm = smvm > 0 ? smvm : null;
        });
      }
    } catch (_) {}
  }



  // Helper method to extract basic salary from conceptos
  double? _obtenerSueldoBasico(ReciboEscaneado recibo) {
    final sueldoBasicoConcepto = recibo.conceptos.firstWhere(
      (concepto) => concepto.descripcion.toLowerCase().contains('sueldo') && 
                   concepto.descripcion.toLowerCase().contains('basico'),
      orElse: () => ConceptoRecibo(descripcion: '', remunerativo: null),
    );
    return sueldoBasicoConcepto.remunerativo;
  }

  // Función para analizar pago según convenio
  Map<String, dynamic> _analizarPagoConvenio() {
    final r = _recibo;
    if (r == null) return {'detalles': [], 'items_revisar': [], 'alertas_graves': []};
    
    final sueldoBasico = _obtenerSueldoBasico(r);

    final detalles = <String>[];
    final itemsRevisar = <String>[];
    final alertasGraves = <String>[];

    // Análisis general para todos los convenios
    detalles.add('Se analizaron ${r.conceptos.length} conceptos de tu recibo');
    detalles.add('Sueldo básico: ${sueldoBasico?.toStringAsFixed(2) ?? "N/A"}');
    detalles.add('Total neto: ${r.sueldoNeto.toStringAsFixed(2)}');

    // Análisis específico por convenio con valores de referencia 2026
    switch (_convenioSeleccionado) {
      case 'Docente Federal':
        detalles.add('Convenio: Docente Federal (Nacional)');
        detalles.add('Categoría: Maestro de Grado - Jornada Completa');
        detalles.add('Referencia 2026: 650.000 - 850.000');
        
        if (sueldoBasico != null && sueldoBasico < 600000) {
          alertasGraves.add('⚠️ SUELDO CRÍTICAMENTE BAJO: Tu básico está muy por debajo del piso docente');
          alertasGraves.add('Urgente: Contactá a tu delegado gremial inmediatamente');
        } else if (sueldoBasico != null && sueldoBasico < 650000) {
          itemsRevisar.add('Sueldo básico bajo para docente federal (debería ser > 650.000)');
        }
        break;
      
      case 'Sanidad':
        detalles.add('Convenio: Sanidad (UPCN/Sindicato)');
        detalles.add('Categoría: Enfermero Profesional');
        detalles.add('Referencia 2026: 580.000 - 720.000');
        
        if (sueldoBasico != null && sueldoBasico < 550000) {
          alertasGraves.add('⚠️ SUELDO BAJO: Tu básico está por debajo del convenio de sanidad');
          itemsRevisar.add('Revisá con recursos humanos tu categorización');
        }
        break;
      
      case 'Comercio':
        detalles.add('Convenio: Comercio (FAECYS)');
        detalles.add('Categoría: Dependiente - 8hs');
        detalles.add('Referencia 2026: 520.000 - 620.000');
        
        if (sueldoBasico != null && sueldoBasico < 500000) {
          itemsRevisar.add('Sueldo básico bajo para convenio de comercio (mínimo 520.000)');
        }
        break;
      
      default:
        detalles.add('Convenio: $_convenioSeleccionado');
        detalles.add('Verificá con tu sindicato los valores de referencia');
    }

    // Verificación de aportes básicos (porcentajes aproximados)
    final aporteJubilacion = r.conceptos.firstWhere((concepto) =>
        concepto.descripcion.toLowerCase().contains('jubilacion') ||
        concepto.descripcion.toLowerCase().contains('aporte j'),
        orElse: () => ConceptoRecibo(descripcion: '', remunerativo: 0));
    
    final aporteObraSocial = r.conceptos.firstWhere((concepto) =>
        concepto.descripcion.toLowerCase().contains('obra social') ||
        concepto.descripcion.toLowerCase().contains('os') ||
        concepto.descripcion.toLowerCase().contains('pami'),
        orElse: () => ConceptoRecibo(descripcion: '', remunerativo: 0));

    // Verificación de porcentajes
    if (sueldoBasico != null && sueldoBasico > 0) {
      final porcentajeJubilacion = ((aporteJubilacion.remunerativo ?? 0) / sueldoBasico) * 100;
      if (porcentajeJubilacion < 10 || porcentajeJubilacion > 12) {
        itemsRevisar.add('Aporte jubilatorio irregular: ${porcentajeJubilacion.toStringAsFixed(1)}% (debería ser 11%)');
      }
      
      final porcentajeObraSocial = ((aporteObraSocial.remunerativo ?? 0) / sueldoBasico) * 100;
      if (porcentajeObraSocial < 2.5 || porcentajeObraSocial > 3.5) {
        itemsRevisar.add('Aporte obra social irregular: ${porcentajeObraSocial.toStringAsFixed(1)}% (debería ser 3%)');
      }
    }

    // Verificación de conceptos obligatorios
    final conceptosObligatorios = ['presentismo', 'antiguedad', 'asignacion'];
    final faltantes = conceptosObligatorios.where((concepto) =>
        !r.conceptos.any((conceptoRecibo) => conceptoRecibo.descripcion.toLowerCase().contains(concepto)));
    
    if (faltantes.isNotEmpty) {
      alertasGraves.add('❌ CONCEPTOS FALTANTES: No se detectaron: ${faltantes.join(', ').toUpperCase()}');
      alertasGraves.add('Estos conceptos son obligatorios por ley en todo recibo de sueldo');
    }

    return {
      'detalles': detalles,
      'items_revisar': itemsRevisar,
      'alertas_graves': alertasGraves,
    };
  }

  // Función para mostrar información de la academia
  void _mostrarInfoAcademia() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.backgroundLight,
        title: const Row(
          children: [
            Icon(Icons.school, color: AppColors.primary),
            SizedBox(width: 12),
            Text('¿Cómo funciona esta app?', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Con esta app podés entender tu recibo de sueldo y ver si te pagaron bien.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 16),
              _buildAcademiaItem('📱 Sacale foto a tu recibo', 'Usá la cámara para escanear tu recibo de sueldo'),
              _buildAcademiaItem('🔍 La app lee todo automático', 'Reconoce solo los números y conceptos importantes'),
              _buildAcademiaItem('⚖️ Chequeamos si está bien', 'Comparamos con lo que deberías cobrar según tu convenio'),
              _buildAcademiaItem('📊 Te decimos qué revisar', 'Te mostramos si falta algo o si está todo correcto'),
              const SizedBox(height: 16),
              const Text(
                '¡Tocá cualquier cosa que no entiendas en tu recibo y te explicamos qué es!',
                style: TextStyle(color: AppColors.primary, fontSize: 12, fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendido', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  // Widget auxiliar para items de la academia
  Widget _buildAcademiaItem(String titulo, String descripcion) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.glassFillStrong,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle, size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w500, fontSize: 12)),
                Text(descripcion, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _escanearYVerificar() async {
    setState(() {
      _estaProcesando = true;
      _rutaImagen = null;
      _textoOcr = '';
      _resultado = null;
      _recibo = null;
    });

    try {
      // 1. Obtener imagen
      final imagenFile = await _ocrService.obtenerImagen();
      if (imagenFile == null) {
        setState(() => _estaProcesando = false);
        return;
      }
      setState(() => _rutaImagen = imagenFile.path);

      // 2. Procesar con OCR
      InputImage inputImage;
      if (kIsWeb) {
        // En web no usamos path de archivo real para ML Kit
        inputImage = InputImage.fromFilePath('web_dummy_path'); 
      } else {
        inputImage = InputImage.fromFilePath(imagenFile.path);
      }
      
      final texto = await _ocrService.procesarImagen(inputImage);
      setState(() => _textoOcr = texto);

      // 3. Parsear el texto
      final reciboEscaneado = await _verificacionService.parsearTextoOcr(texto);
      setState(() {
        _recibo = reciboEscaneado;
      });

      // 4. Identificar CCT (aquí usamos uno de ejemplo)
      // En la versión real, deberías buscar en la base de datos de CCTs
      // o pedirle al usuario que lo seleccione.
      final cctEjemplo = CctSimplificado(nombre: 'Ejemplo CCT');

      // 5. Verificar
      final resultado = await _verificacionService.verificarRecibo(reciboEscaneado, cctEjemplo);

      setState(() {
        _resultado = resultado;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _estaProcesando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Verificador de Recibo', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.glassFillStrong,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: const Icon(Icons.menu, color: AppColors.textPrimary, size: 22),
            ),
            onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
          ),
        ],
      ),
      endDrawer: _buildMenuHamburguesa(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Sección de datos leídos (ahora arriba del todo)
            if (_mostrarDatosLeidos && _textoOcr.isNotEmpty)
              _buildDatosLeidosWidget(),
            
            _buildDatosActualizadosWidget(),
            
            // Selector de convenio
            _buildSelectorConvenio(),
            
            // Banner interactivo de la academia
            if (_mostrarBannerAcademia && _resultado == null)
              _buildBannerAcademia(),
            
            if (_estaProcesando)
              Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  children: [
                    CircularProgressIndicator(color: AppColors.primary),
                    const SizedBox(height: 16),
                    Text('Procesando recibo...', style: TextStyle(color: AppColors.textPrimary)),
                  ],
                ),
              )
            else ...[
              if (_resultado == null)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        const Icon(Icons.document_scanner_outlined, size: 80, color: Colors.grey),
                        const SizedBox(height: 16),
                        const Text(
                          'Escaneá tu recibo de sueldo y descubrí si tu liquidación es correcta.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _escanearYVerificar,
                          icon: const Icon(Icons.camera_alt),
                          label: const Text('Escanear Recibo de Sueldo'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: _buildResultadoWidget(),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResultadoWidget() {
    if (_resultado == null) return const SizedBox.shrink();
    
    final analisisConvenio = _analizarPagoConvenio();

    return Column(
      children: [
        if (_rutaImagen != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: kIsWeb
                ? Image.network(_rutaImagen!, height: 200, fit: BoxFit.cover)
                : Image.file(
                    File(_rutaImagen!),
                    height: 200,
                    fit: BoxFit.cover,
                  ),
          ),
        const SizedBox(height: 24),
        Card(
          color: _resultado!.esCorrecto ? Colors.green.shade50 : Colors.red.shade50,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      _resultado!.esCorrecto ? Icons.check_circle : Icons.error,
                      color: _resultado!.esCorrecto ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _resultado!.esCorrecto
                            ? 'Tu recibo parece correcto'
                            : 'Se encontraron inconsistencias',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                if (_resultado!.inconsistencias.isNotEmpty) ...[
                  const Divider(),
                  const Text('Inconsistencias:', style: TextStyle(fontWeight: FontWeight.bold)),
                  ..._resultado!.inconsistencias.map((e) => ListTile(
                        leading: const Icon(Icons.warning, color: Colors.orange, size: 16),
                        title: Text(e, style: const TextStyle(fontSize: 14)),
                        dense: true,
                      )),
                ],
                if (_resultado!.sugerencias.isNotEmpty) ...[
                  const Divider(),
                  const Text('Sugerencias:', style: TextStyle(fontWeight: FontWeight.bold)),
                  ..._resultado!.sugerencias.map((e) => ListTile(
                        leading: const Icon(Icons.info, color: Colors.blue, size: 16),
                        title: Text(e, style: const TextStyle(fontSize: 14)),
                        dense: true,
                      )),
                ],
                
                // Análisis según convenio
                const Divider(),
                const Text('Análisis según tu convenio:', style: TextStyle(fontWeight: FontWeight.bold)),
                ...analisisConvenio['detalles'].map((detalle) => ListTile(
                      leading: const Icon(Icons.analytics, color: Colors.purple, size: 16),
                      title: Text(detalle, style: const TextStyle(fontSize: 14)),
                      dense: true,
                    )),
                
                if (analisisConvenio['items_revisar'].isNotEmpty) ...[
                  const Divider(),
                  const Text('Items para revisar:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                  ...analisisConvenio['items_revisar'].map((item) => ListTile(
                        leading: const Icon(Icons.warning, color: Colors.orange, size: 16),
                        title: Text(item, style: const TextStyle(fontSize: 14, color: Colors.orange)),
                        dense: true,
                      )),
                ],

                // Alertas graves (errores críticos)
                if (analisisConvenio['alertas_graves'].isNotEmpty) ...[                  
                  const Divider(),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.error_outline, color: Colors.red, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'ALERTAS GRAVES - REVISIÓN URGENTE',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...analisisConvenio['alertas_graves'].map((alerta) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Text(
                                '• $alerta',
                                style: const TextStyle(color: Colors.red, fontSize: 14),
                              ),
                            )),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildProyeccionesWidget(),
        const SizedBox(height: 12),
        _buildMetasUnidadesWidget(),
        const SizedBox(height: 12),
        _buildEstimadorLiquidacionWidget(),
        const SizedBox(height: 16),
        _buildBannerAcademia(),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              onPressed: _escanearYVerificar,
              icon: const Icon(Icons.refresh),
              label: const Text('Escanear Otro Recibo'),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const TeacherReceiptScanScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Escanear QR'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ExpansionTile(
          title: const Text('Texto extraído del recibo (OCR)'),
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              color: Colors.grey.shade200,
              width: double.infinity,
              child: Text(_textoOcr),
            ),
          ],
        )
      ],
    );
  }

  Widget _buildProyeccionesWidget() {
    final netoActual = _netoActual();
    final base3 = _proyectado(netoActual, _ipcBase, _ajusteMensual, 3);
    final base6 = _proyectado(netoActual, _ipcBase, _ajusteMensual, 6);
    final cons3 = _proyectado(netoActual, _ipcConservador, _ajusteMensual, 3);
    final cons6 = _proyectado(netoActual, _ipcConservador, _ajusteMensual, 6);
    final opt3 = _proyectado(netoActual, _ipcOptimista, _ajusteMensual, 3);
    final opt6 = _proyectado(netoActual, _ipcOptimista, _ajusteMensual, 6);
    final epa3 = _epa(_ipcBase, _ajusteMensual, 3);
    final epa6 = _epa(_ipcBase, _ajusteMensual, 6);
    final ajusteReq = _ipcBase;

    Color epaColor(double v) {
      if (v >= 1.02) return Colors.green;
      if (v >= 0.98) return Colors.orange;
      return Colors.red;
    }

    String epaLabel(double v) {
      if (v >= 1.02) return 'Gana poder';
      if (v >= 0.98) return 'Se mantiene';
      return 'Pierde poder';
    }

    return Card(
      elevation: 0,
      color: Colors.blueGrey.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Proyecciones 3–6 meses (IPC/INDEC)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: (0.1 * 255).round().toDouble()),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withValues(alpha: (0.3 * 255).round().toDouble())),
              ),
              child: Text(
                'Ajuste necesario para no perder poder: ${ajusteReq.toStringAsFixed(1)}% mensual',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.orange[900]),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ipcController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'IPC mensual (%)',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) {
                      final x = double.tryParse(v.replaceAll(',', '.'));
                      if (x != null && mounted) {
                        setState(() => _ipcBase = x);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _ajusteController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Ajuste mensual (%)',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) {
                      final x = double.tryParse(v.replaceAll(',', '.'));
                      if (x != null && mounted) {
                        setState(() => _ajusteMensual = x);
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _proyeccionChip('Base 3m', base3),
                _proyeccionChip('Base 6m', base6),
                _proyeccionChip('Conservador 3m', cons3),
                _proyeccionChip('Conservador 6m', cons6),
                _proyeccionChip('Optimista 3m', opt3),
                _proyeccionChip('Optimista 6m', opt6),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: epaColor(epa3).withValues(alpha: (0.15 * 255).round().toDouble()),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.shield, color: epaColor(epa3)),
                      const SizedBox(width: 8),
                      Text('EPA 3m: ${epa3.toStringAsFixed(2)} • ${epaLabel(epa3)}'),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: epaColor(epa6).withValues(alpha: (0.15 * 255).round().toDouble()),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.shield, color: epaColor(epa6)),
                      const SizedBox(width: 8),
                      Text('EPA 6m: ${epa6.toStringAsFixed(2)} • ${epaLabel(epa6)}'),
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

  Widget _proyeccionChip(String label, double valor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.blueGrey.shade100),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.trending_up, size: 16, color: Colors.blueGrey),
          const SizedBox(width: 6),
          Text('$label: \$${valor.toStringAsFixed(0)}'),
        ],
      ),
    );
  }

  double _netoActual() {
    final r = _recibo;
    if (r == null) return 0.0;
    if (r.sueldoNeto > 0) return r.sueldoNeto;
    return (r.totalRemunerativo + r.totalNoRemunerativo) - r.totalDeducciones;
  }

  double _proyectado(double neto, double ipcMensualPct, double ajusteMensualPct, int meses) {
    if (neto <= 0) return 0.0;
    final crecimiento = pow(1 + (ajusteMensualPct / 100), meses);
    return neto * crecimiento;
  }

  double _epa(double ipcMensualPct, double ajusteMensualPct, int meses) {
    final a = pow(1 + (ajusteMensualPct / 100), meses);
    final i = pow(1 + (ipcMensualPct / 100), meses);
    final ratio = (a / i);
    return ratio;
  }

  Widget _buildDatosActualizadosWidget() {
    String doc = _fechaDocentes != null ? '${_fechaDocentes!.day.toString().padLeft(2, '0')}/${_fechaDocentes!.month.toString().padLeft(2, '0')}/${_fechaDocentes!.year}' : 'sin fecha';
    String san = _fechaSanidad != null ? '${_fechaSanidad!.day.toString().padLeft(2, '0')}/${_fechaSanidad!.month.toString().padLeft(2, '0')}/${_fechaSanidad!.year}' : 'sin fecha';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.update, color: Colors.grey),
          const SizedBox(width: 8),
          Text('Datos actualizados • Docentes: $doc • Sanidad: $san • Fuente: INDEC/Paritarias'),
        ],
      ),
    );
  }

  Widget _buildMetasUnidadesWidget() {
    if (_smvm == null || _smvm! <= 0) return const SizedBox.shrink();
    final neto = _netoActual();
    final u0 = neto > 0 ? neto / _smvm! : 0.0;
    final u3 = _proyectado(neto, _ipcBase, _ajusteMensual, 3) / _smvm!;
    final u6 = _proyectado(neto, _ipcBase, _ajusteMensual, 6) / _smvm!;
    return Card(
      elevation: 0,
      color: Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Metas en Unidades (SMVM)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _proyeccionChip('Hoy', u0),
                _proyeccionChip('3m', u3),
                _proyeccionChip('6m', u6),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEstimadorLiquidacionWidget() {
    return Card(
      elevation: 0,
      color: Colors.teal.shade50,
      child: ExpansionTile(
        title: const Text(
          'Estimador de Liquidación Final',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal),
        ),
        subtitle: const Text('Simulá tu salida (Despido o Renuncia)'),
        leading: const Icon(Icons.calculate, color: Colors.teal),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '⚠ Aviso Legal: Este cálculo es una estimación aproximada y no tiene validez legal. Consultá con un profesional para una liquidación exacta.',
                  style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.red),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text('Motivo: '),
                    const SizedBox(width: 8),
                    DropdownButton<String>(
                      value: _motivoCese,
                      items: ['Renuncia', 'Despido'].map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _motivoCese = val);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    final scaffoldContext = context;
                    final picked = await showDatePicker(
                      context: scaffoldContext,
                      initialDate: DateTime.now().subtract(const Duration(days: 365)),
                      firstDate: DateTime(1980),
                      lastDate: DateTime.now(),
                      helpText: 'Fecha de Ingreso',
                    );
                    if (picked != null && mounted) {
                      setState(() => _fechaIngreso = picked);
                    }
                  },
                  icon: const Icon(Icons.calendar_today, size: 18),
                  label: Text(_fechaIngreso == null
                      ? 'Seleccionar Fecha de Ingreso'
                      : 'Ingreso: ${_fechaIngreso!.day}/${_fechaIngreso!.month}/${_fechaIngreso!.year}'),
                ),
                if (_fechaIngreso != null) ...[
                  const Divider(height: 32),
                  _buildFilaLiquidacion('SAC Proporcional (est.)', _calcularSacProporcional()),
                  _buildFilaLiquidacion('Vacaciones Proporcionales (est.)', _calcularVacacionesProporcionales()),
                  if (_motivoCese == 'Despido') ...[
                    _buildFilaLiquidacion('Indemnización Antigüedad', _calcularIndemnizacionAntiguedad()),
                    _buildFilaLiquidacion('Preaviso', _netoActual()),
                  ],
                  const Divider(),
                  _buildFilaLiquidacion(
                    'Total Estimado',
                    _calcularTotalLiquidacion(),
                    esTotal: true,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilaLiquidacion(String label, double monto, {bool esTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: esTotal ? FontWeight.bold : FontWeight.normal,
              fontSize: esTotal ? 16 : 14,
            ),
          ),
          Text(
            '\$${monto.toStringAsFixed(2)}',
            style: TextStyle(
              fontWeight: esTotal ? FontWeight.bold : FontWeight.w600,
              fontSize: esTotal ? 16 : 14,
              color: esTotal ? Colors.teal.shade700 : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  double _calcularSacProporcional() {
    // Estimación simple: medio sueldo por semestre
    // Calculamos días desde el último semestre (enero o julio)
    final hoy = DateTime.now();
    final inicioSemestre = hoy.month <= 6 ? DateTime(hoy.year, 1, 1) : DateTime(hoy.year, 7, 1);
    final dias = hoy.difference(inicioSemestre).inDays;
    return (_netoActual() / 2) * (dias / 182.5);
  }

  double _calcularVacacionesProporcionales() {
    // Estimación simple: 14 días por año trabajado
    if (_fechaIngreso == null) return 0.0;
    final hoy = DateTime.now();
    final diasAnio = hoy.difference(DateTime(hoy.year, 1, 1)).inDays;
    // Asumimos 14 días base (ley 20.744)
    return (_netoActual() / 25) * 14 * (diasAnio / 365);
  }

  double _calcularIndemnizacionAntiguedad() {
    if (_fechaIngreso == null) return 0.0;
    final hoy = DateTime.now();
    final anios = (hoy.difference(_fechaIngreso!).inDays / 365).ceil();
    return _netoActual() * anios;
  }

  double _calcularTotalLiquidacion() {
    double total = _calcularSacProporcional() + _calcularVacacionesProporcionales();
    if (_motivoCese == 'Despido') {
      total += _calcularIndemnizacionAntiguedad() + _netoActual(); // Antigüedad + 1 mes preaviso
    }
    return total;
  }



  void _mostrarManualUsuario() {
    final helpContent = AppHelp.getHelpContent('verificador_recibo');
    AppHelp.showHelpDialog(
      context,
      helpContent['title']!,
      helpContent['content']!,
    );
  }

  /// Construye el menú hamburguesa lateral con todas las opciones
  Widget _buildMenuHamburguesa() {
    return Drawer(
      backgroundColor: AppColors.backgroundLight,
      surfaceTintColor: AppColors.backgroundLight,
      width: 300,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Encabezado del menú
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.glassFillStrong,
                border: Border(bottom: BorderSide(color: AppColors.glassBorder)),
              ),
              child: const Text(
                'Verificador de Recibo',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ),

            // Sección de Navegación Principal
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                'NAVEGACIÓN',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                  letterSpacing: 1.2,
                ),
              ),
            ),

            // Botones principales
            _buildMenuItem(
              icon: Icons.camera_alt,
              label: 'Escanear Recibo',
              onTap: () {
                Navigator.pop(context); // Cerrar menú
                _escanearYVerificar();
              },
            ),

            _buildMenuItem(
              icon: Icons.qr_code_scanner,
              label: 'Escanear QR',
              onTap: () {
                Navigator.pop(context); // Cerrar menú
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const TeacherReceiptScanScreen()),
                );
              },
            ),

            _buildMenuItem(
              icon: Icons.tune,
              label: 'Ajustar Margen OCR',
              onTap: () {
                Navigator.pop(context); // Cerrar menú
                _mostrarAjustesOcr();
              },
            ),

            const Divider(height: 24, color: AppColors.glassBorder),

            // Sección de Ayuda
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Text(
                'AYUDA',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                  letterSpacing: 1.2,
                ),
              ),
            ),

            _buildMenuItem(
              icon: Icons.help,
              label: 'Manual de Usuario',
              onTap: () {
                Navigator.pop(context); // Cerrar menú
                _mostrarManualUsuario();
              },
            ),

            _buildMenuItem(
              icon: Icons.school,
              label: 'Academia - ¿Cómo funciona?',
              onTap: () {
                Navigator.pop(context); // Cerrar menú
                _mostrarInfoAcademia();
              },
            ),

            _buildMenuItem(
              icon: Icons.info,
              label: 'Acerca del Sistema',
              onTap: () {
                Navigator.pop(context); // Cerrar menú
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: AppColors.backgroundCard,
                    title: const Text('Verificador de Recibo', style: TextStyle(color: AppColors.textPrimary)),
                    content: const Text('Sistema profesional para verificación de recibos de sueldo según convenios nacionales vigentes.', style: TextStyle(color: AppColors.textSecondary)),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cerrar'),
                      ),
                    ],
                  ),
                );
              },
            ),

            // Espaciador final
            const Spacer(),

            // Footer con información
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.glassFillStrong,
                border: Border(top: BorderSide(color: AppColors.glassBorder)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Convenio: $_convenioSeleccionado',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'OCR Mejorado',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Widget auxiliar para items del menú
  Widget _buildMenuItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.glassFillStrong,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Icon(icon, size: 20, color: AppColors.textPrimary),
      ),
      title: Text(
        label,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
        ),
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }

  /// Widget para mostrar datos leídos (ahora arriba del todo)
  Widget _buildDatosLeidosWidget() {
    return Card(
      color: AppColors.backgroundCard,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Datos Leídos del Recibo', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: Icon(_mostrarDatosLeidos ? Icons.visibility_off : Icons.visibility, size: 20, color: AppColors.textSecondary),
                  onPressed: () => setState(() => _mostrarDatosLeidos = !_mostrarDatosLeidos),
                ),
              ],
            ),
            if (_mostrarDatosLeidos) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.backgroundLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.glassBorder),
                ),
                child: Text(
                  _textoOcr,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _agregarDatosManuales,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Agregar Datos Manualmente'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Selector de convenio para análisis específico
  Widget _buildSelectorConvenio() {
    return Card(
      color: AppColors.backgroundCard,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Seleccionar Convenio', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _convenioSeleccionado,
              items: _conveniosDisponibles.map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value, style: const TextStyle(color: AppColors.textPrimary)),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _convenioSeleccionado = val);
              },
              dropdownColor: AppColors.backgroundCard,
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                filled: true,
                fillColor: AppColors.backgroundLight,
              ),
              style: const TextStyle(color: AppColors.textPrimary),
            ),
          ],
        ),
      ),
    );
  }

  /// Método para agregar datos manualmente
  void _agregarDatosManuales() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.backgroundCard,
        title: const Text('Agregar Datos Manualmente', style: TextStyle(color: AppColors.textPrimary)),
        content: const Text('Funcionalidad en desarrollo - Próximamente', style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  /// Método para ajustar margen OCR
  void _mostrarAjustesOcr() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.backgroundCard,
        title: const Text('Ajustar Margen OCR', style: TextStyle(color: AppColors.textPrimary)),
        content: const Text('Margen de error aumentado al 15% para cámaras de baja calidad', style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }



  Widget _buildBannerAcademia() {
    return GestureDetector(
      onTap: () {
        setState(() => _mostrarBannerAcademia = false);
        _mostrarInfoAcademia();
      },
      child: Card(
        elevation: 4,
        shadowColor: AppColors.primary.withValues(alpha: (0.3 * 255).round().toDouble()),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            gradient: LinearGradient(
              colors: [AppColors.primary.withValues(alpha: (0.1 * 255).round().toDouble()), AppColors.backgroundLight],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: AppColors.primary.withValues(alpha: (0.3 * 255).round().toDouble())),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  children: [
                    // Logo de la academia
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: (0.2 * 255).round().toDouble()),
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(color: AppColors.primary.withValues(alpha: (0.5 * 255).round().toDouble())),
                      ),
                      child: Icon(Icons.school, color: AppColors.primary, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Academia Elevar',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            '¿No entendés algo de tu recibo?',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, size: 18, color: AppColors.textSecondary),
                      onPressed: () => setState(() => _mostrarBannerAcademia = false),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Tocá cualquier número o palabra de tu recibo que no entiendas y te explicamos qué es.',
                  style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() => _mostrarBannerAcademia = false);
                    _mostrarInfoAcademia();
                  },
                  icon: const Icon(Icons.lightbulb_outline, size: 18),
                  label: const Text('Aprender cómo funciona'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
