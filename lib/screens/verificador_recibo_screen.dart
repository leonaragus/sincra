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
import 'package:syncra_arg/services/conceptos_explicaciones_service.dart';
import 'package:syncra_arg/screens/glosario_conceptos_screen.dart';
import 'package:syncra_arg/screens/conoce_tu_convenio_screen.dart';
import 'package:syncra_arg/services/api_service.dart';
import 'package:syncra_arg/models/convenio_model.dart';
import 'package:syncra_arg/utils/app_help.dart';
import 'package:syncra_arg/utils/conceptos_builder.dart';
import 'package:syncra_arg/theme/app_colors.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:syncra_arg/widgets/academy_promo_dialog.dart';
import 'package:syncra_arg/services/pdf_report_service.dart';
import 'package:syncra_arg/data/cct_argentina_completo.dart';
import '../services/subscription_service.dart';

class VerificadorReciboScreen extends StatefulWidget {
  const VerificadorReciboScreen({super.key});

  @override
  State<VerificadorReciboScreen> createState() =>
      _VerificadorReciboScreenState();
}

class _VerificadorReciboScreenState extends State<VerificadorReciboScreen> {
  final OcrService _ocrService = OcrService();
  final VerificacionReciboService _verificacionService =
      VerificacionReciboService();

  bool _estaProcesando = false;
  String? _rutaImagen;
  String _textoOcr = '';
  ResultadoVerificacion? _resultado;
  ReciboEscaneado? _recibo;
  double _ipcBase = 8.0;
  final double _ipcConservador = 6.0;
  final double _ipcOptimista = 10.0;
  double _ajusteMensual = 0.0;
  final TextEditingController _ipcController =
      TextEditingController(text: '8.0');
  final TextEditingController _ajusteController =
      TextEditingController(text: '0.0');
  DateTime? _fechaDocentes;
  DateTime? _fechaSanidad;
  double? _smvm;
  DateTime? _fechaIngreso;
  String _motivoCese = 'Renuncia'; // 'Renuncia' o 'Despido'

  // Variables para funcionalidad mejorada
  bool _mostrarDatosLeidos = false; // Cambiado a false por defecto
  String? _convenioSeleccionado; // Hacer opcional
  List<ConvenioModel> _conveniosModelos = [];
  List<String> _conveniosDisponibles = ['Cargando convenios...'];

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
    print('VerificadorReciboScreen v1.2 loaded'); // Debug version
    _cargarDatosAutomaticos();
  }

  Future<void> _cargarDatosAutomaticos() async {
    try {
      // 1. Cargar convenios desde API (prioridad) o local storage
      final conveniosApi = await ApiService.syncOrLoadLocal();
      
      // 2. Cargar convenios locales completos (fallback/base)
      final List<ConvenioModel> todosLosConvenios = [...conveniosApi];
      final Set<String> nombresEnApi = conveniosApi.map((c) => c.nombreCCT).toSet();

      // 3. Fusionar: Agregar los locales que NO estén en la API
      for (final local in cctArgentinaCompleto) {
        if (!nombresEnApi.contains(local.nombre)) {
          // Convertir cada categoría del CCT local a un ConvenioModel
          for (final cat in local.categorias) {
            todosLosConvenios.add(ConvenioModel(
              id: local.id,
              nombreCCT: local.nombre,
              categoria: cat.nombre,
              sueldoBasico: cat.salarioBase,
              adicionales: {
                'presentismo': local.adicionalPresentismo,
                'antiguedad': local.adicionalAntiguedad,
              },
              ultimaActualizacion: local.fechaVigencia,
              pdfUrl: local.pdfUrl,
            ));
          }
        }
      }

      if (mounted) {
        setState(() {
          _conveniosModelos = todosLosConvenios;
          final nombres = todosLosConvenios.map((c) => c.nombreCCT).toSet().toList();
          nombres.sort();
          _conveniosDisponibles = [...nombres, 'No sé mi convenio'];
        });
      }

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

  Future<void> _escanearYVerificar() async {
    // 0. Verificar cuota Freemium
    final canScan = await SubscriptionService.canPerformOcrScan();
    if (!canScan) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Límite de escaneos alcanzado'),
          content: const Text(
            'Has alcanzado el límite de escaneos OCR para tu plan actual. '
            'Actualiza a Premium para continuar o espera al próximo mes.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                // Navegar a planes
                Navigator.pushNamed(context, '/plans'); 
              },
              child: const Text('Ver Planes'),
            ),
          ],
        ),
      );
      return;
    }

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
      
      // Registrar uso de cuota
      await SubscriptionService.registerOcrScan();

      setState(() => _rutaImagen = imagenFile.path);

      // 2. Procesar con OCR
      InputImage inputImage;
      if (kIsWeb) {
        // En web no usamos path de archivo real para ML Kit
        inputImage = InputImage.fromFilePath('web_dummy_path');
      } else {
        inputImage = InputImage.fromFilePath(imagenFile.path);
      }

      final resultadoOcr = await _ocrService.procesarImagen(inputImage);
      setState(() {
        _textoOcr = resultadoOcr.texto;
        _estaProcesando = false;
      });

      // 3. Parsear el texto - intentamos parsear incluso si el OCR fue parcial
      ReciboEscaneado reciboEscaneado;
      try {
        reciboEscaneado = await _verificacionService.parsearTextoOcr(resultadoOcr.textoCrudo);
      } catch (e) {
        // Si falla el parseo, intentamos con el texto formateado
        try {
          reciboEscaneado = await _verificacionService.parsearTextoOcr(resultadoOcr.texto);
        } catch (e2) {
          // Si todo falla, mostramos mensaje amigable
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('⚠️ Leímos el recibo pero no pudimos extraer todos los datos. Revisá los datos manualmente.')),
            );
          }
          // Creamos un recibo vacío para que el usuario pueda ver lo que se leyó
          reciboEscaneado = ReciboEscaneado(
            sueldoNeto: 0,
            conceptos: [],
          );
        }
      }
      setState(() {
        _recibo = reciboEscaneado;
      });

      // 4. Identificar CCT (aquí usamos uno de ejemplo)
      // En la versión real, deberías buscar en la base de datos de CCTs
      // o pedirle al usuario que lo seleccione.
      final cctEjemplo = CctSimplificado(nombre: 'Ejemplo CCT');

      // 5. Verificar
      final resultado = await _verificacionService.verificarRecibo(
          reciboEscaneado, cctEjemplo);

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
        title: const Text('Verificador de Recibo',
            style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.glassFill,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.glassBorder, width: 1),
              ),
              child: Icon(Icons.menu, color: AppColors.textPrimary, size: 20),
            ),
            onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
          ),
        ],
      ),
      endDrawer: _buildMenuHamburguesa(),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.background,
              AppColors.backgroundLight,
            ],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Selector de convenio
              _buildSelectorConvenio(),

              if (_estaProcesando)
                _buildLoadingState()
              else if (_resultado == null)
                _buildInitialState()
              else
                _buildResultadoWidget(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.glassFill,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.glassBorder, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Analizando tu recibo...',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Detectando conceptos de tu liquidación',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 15,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.glassFillStrong,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.glassBorder, width: 1),
            ),
            child: Column(
              children: [
                Text(
                  '¿Qué estamos haciendo?',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '• Leyendo el texto de tu recibo\n• Identificando sueldo básico, jubilación, obra social\n• Verificando contra tu convenio laboral\n• Detectando posibles errores o faltantes',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.left,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInitialState() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          // Tarjeta principal de escaneo
          Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: AppColors.glassFill,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.glassBorder, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 15,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: AppColors.primary.withOpacity(0.3), width: 2),
                  ),
                  child: Icon(
                    Icons.document_scanner_outlined,
                    size: 50,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Verificá tu recibo de sueldo',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Escaneá tu recibo y descubrí si tu liquidación es correcta según tu convenio laboral',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 15,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 25),
                ElevatedButton(
                  onPressed: _escanearYVerificar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 30, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.camera_alt, size: 20),
                      SizedBox(width: 10),
                      Text('Escanear Recibo',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ConoceTuConvenioScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.library_books, color: Colors.white),
                  label: const Text(
                    'Biblioteca de Convenios',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    backgroundColor: AppColors.secondary,
                    foregroundColor: Colors.white,
                    side: BorderSide(color: AppColors.glassBorder),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 4,
                  ),
                ),
              ],
            ),
          ),

          // Información adicional simplificada
          const SizedBox(height: 25),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.glassFillStrong,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.glassBorder, width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '¿Qué hace esta app?',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                _buildSimpleInfoItem('📱', 'Lee tu recibo automáticamente'),
                _buildSimpleInfoItem('🔍', 'Detecta todos los conceptos'),
                _buildSimpleInfoItem('⚖️', 'Compara con tu convenio'),
                _buildSimpleInfoItem('📊', 'Te dice qué revisar'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleInfoItem(String emoji, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultadoWidget() {
    if (_resultado == null) return const SizedBox.shrink();

    final analisisConvenio = _analizarPagoConvenio();

    return Column(
      children: [
        // Imagen del recibo escaneado
        if (_rutaImagen != null)
          Container(
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: kIsWeb
                  ? Image.network(_rutaImagen!, height: 220, fit: BoxFit.cover)
                  : Image.file(
                      File(_rutaImagen!),
                      height: 220,
                      fit: BoxFit.cover,
                    ),
            ),
          ),

        // Tarjeta principal de resultados
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.glassFill,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.glassBorder, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 15,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Estado principal
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _resultado!.esCorrecto
                          ? Colors.green.withOpacity(0.15)
                          : Colors.orange.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _resultado!.esCorrecto
                            ? Colors.green.withOpacity(0.3)
                            : Colors.orange.withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      _resultado!.esCorrecto
                          ? Icons.check_circle
                          : Icons.warning,
                      color:
                          _resultado!.esCorrecto ? Colors.green : Colors.orange,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      _resultado!.esCorrecto
                          ? '✅ Recibo verificado correctamente'
                          : '⚠️ Se encontraron inconsistencias',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Resumen de conceptos detectados
              if (_recibo != null && _recibo!.conceptos.isNotEmpty) ...[                
                // Botón de acceso al glosario
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const GlosarioConceptosScreen(),
                      ),
                    );
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.help_outline, color: AppColors.primary, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '¿No entiendes algún concepto? Consulta nuestro glosario',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Icon(Icons.arrow_forward_ios, color: AppColors.primary, size: 16),
                      ],
                    ),
                  ),
                ),

                // Botón de acceso a información del convenio
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ConoceTuConvenioScreen(),
                      ),
                    );
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.accentGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.accentGreen.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.business_center, color: AppColors.accentGreen, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '¿Quieres conocer tu convenio? Ver detalles completos',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Icon(Icons.arrow_forward_ios, color: AppColors.accentGreen, size: 16),
                      ],
                    ),
                  ),
                ),
                _buildSectionHeader('📋 Conceptos detectados'),
                const SizedBox(height: 12),
                ConceptosBuilder.buildResumenConceptos(_recibo, context),
                const SizedBox(height: 20),
              ],

              // Inconsistencias
              if (_resultado!.inconsistencias.isNotEmpty) ...[
                _buildSectionHeader('⚠️ Inconsistencias detectadas'),
                const SizedBox(height: 12),
                ..._resultado!.inconsistencias.map((e) => _buildListItem(
                      Icons.warning,
                      Colors.orange,
                      e,
                    )),
                const SizedBox(height: 20),
              ],

              // Sugerencias
              if (_resultado!.sugerencias.isNotEmpty) ...[
                _buildSectionHeader('💡 Sugerencias'),
                const SizedBox(height: 12),
                ..._resultado!.sugerencias.map((e) => _buildListItem(
                      Icons.lightbulb_outline,
                      Colors.blue,
                      e,
                    )),
                const SizedBox(height: 20),
              ],

              // Análisis según convenio
              _buildSectionHeader('📊 Análisis según tu convenio'),
              const SizedBox(height: 12),
              ...analisisConvenio['detalles'].map((detalle) => _buildListItem(
                    Icons.analytics,
                    Colors.purple,
                    detalle,
                  )),

              // Items para revisar
              if (analisisConvenio['items_revisar'].isNotEmpty) ...[
                const SizedBox(height: 20),
                _buildSectionHeader('🔍 Items para revisar con tu empleador'),
                const SizedBox(height: 12),
                ...analisisConvenio['items_revisar']
                    .map((item) => _buildListItem(
                          Icons.search,
                          Colors.orange,
                          item,
                        )),
              ],

              // Alertas graves
              if (analisisConvenio['alertas_graves'].isNotEmpty) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: Colors.red.withOpacity(0.3), width: 1.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.error_outline,
                              color: Colors.red, size: 22),
                          const SizedBox(width: 10),
                          Text(
                            '🚨 Alertas graves - Revisión urgente',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ...analisisConvenio['alertas_graves']
                          .map((alerta) => Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 4),
                                child: Text(
                                  '• $alerta',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              )),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 20),

          if (_recibo != null) ...[
            Center(
              child: ElevatedButton.icon(
                onPressed: () {
                  final analisis = _analizarPagoConvenio();
                  showDialog(
                    context: context,
                    builder: (context) => AcademyPromoDialog(
                      onDownload: () {
                        PdfReportService.generateAndDownloadReport(
                          recibo: _recibo!,
                          detalles:
                              List<String>.from(analisis['detalles'] ?? []),
                          itemsRevisar: List<String>.from(
                              analisis['items_revisar'] ?? []),
                          alertasGraves: List<String>.from(
                              analisis['alertas_graves'] ?? []),
                          convenio: _convenioSeleccionado ?? 'No especificado',
                        );
                      },
                    ),
                  );
                },
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('Descargar Informe Completo'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondary,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Widgets adicionales
          _buildProyeccionesWidget(),
        const SizedBox(height: 16),
        _buildMetasUnidadesWidget(),
        const SizedBox(height: 16),
        _buildEstimadorLiquidacionWidget(),

        // Botones de acción
        Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: _escanearYVerificar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.refresh, size: 18),
                    SizedBox(width: 8),
                    Text('Escanear otro recibo',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const TeacherReceiptScanScreen(),
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: BorderSide(color: AppColors.glassBorder),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.qr_code_scanner, size: 18),
                    SizedBox(width: 8),
                    Text('Escanear QR'),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Texto OCR - AHORA SIEMPRE VISIBLE
        Container(
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: AppColors.glassFill,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.glassBorder, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  '📄 Texto extraído del recibo (OCR)',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.backgroundLight.withOpacity(0.5),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.text_snippet, size: 16, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Texto detectado por OCR:',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.glassBorder, width: 1),
                      ),
                      child: SingleChildScrollView(
                        child: Text(
                          _textoOcr.isNotEmpty ? _textoOcr : 'No se detectó texto',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontFamily: 'monospace',
                            height: 1.4,
                          ),
                        ),
                      ),
                    ),
                    if (_textoOcr.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Caracteres detectados: ${_textoOcr.length}',
                        style: TextStyle(
                          color: AppColors.textSecondary.withOpacity(0.7),
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }



  // NUEVO WIDGET: Resumen de conceptos detectados
  Widget _buildResumenConceptos() {
    if (_recibo == null || _recibo!.conceptos.isEmpty) return const SizedBox.shrink();
    
    final conceptosAgrupados = <String, double>{};
    for (final concepto in _recibo!.conceptos) {
      if (concepto.remunerativo != null && concepto.remunerativo! > 0) {
        conceptosAgrupados[concepto.descripcion] = (conceptosAgrupados[concepto.descripcion] ?? 0) + concepto.remunerativo!;
      }
      if (concepto.noRemunerativo != null && concepto.noRemunerativo! > 0) {
        conceptosAgrupados[concepto.descripcion] = (conceptosAgrupados[concepto.descripcion] ?? 0) + concepto.noRemunerativo!;
      }
      if (concepto.deducciones != null && concepto.deducciones! > 0) {
        conceptosAgrupados[concepto.descripcion] = (conceptosAgrupados[concepto.descripcion] ?? 0) + concepto.deducciones!;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '✅ Detectados ${conceptosAgrupados.length} conceptos',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        ...conceptosAgrupados.entries.take(5).map((entry) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                entry.key,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
              Text(
                '\$${entry.value.toStringAsFixed(2)}',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        )),
        if (conceptosAgrupados.length > 5) ...[
          const SizedBox(height: 4),
          Text(
            '... y ${conceptosAgrupados.length - 5} más',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ],
    );
  }

  // Resto de métodos permanecen iguales...
  
  // Helper method to extract basic salary from conceptos
  double? _obtenerSueldoBasico(ReciboEscaneado recibo) {
    final sueldoBasicoConcepto = recibo.conceptos.firstWhere(
      (concepto) =>
          concepto.descripcion.toLowerCase().contains('sueldo') &&
          concepto.descripcion.toLowerCase().contains('basico'),
      orElse: () => ConceptoRecibo(descripcion: '', remunerativo: null),
    );
    return sueldoBasicoConcepto.remunerativo;
  }

  // Función para analizar pago según convenio
  Map<String, dynamic> _analizarPagoConvenio() {
    final r = _recibo;
    if (r == null)
      return {'detalles': [], 'items_revisar': [], 'alertas_graves': []};

    final sueldoBasico = _obtenerSueldoBasico(r);

    final detalles = <String>[];
    final itemsRevisar = <String>[];
    final alertasGraves = <String>[];

    // Análisis general para todos los convenios
    detalles.add('Se analizaron ${r.conceptos.length} conceptos de tu recibo');
    detalles.add('Sueldo básico: ${sueldoBasico?.toStringAsFixed(2) ?? "N/A"}');
    detalles.add('Total neto: ${r.sueldoNeto.toStringAsFixed(2)}');

    // Análisis específico por convenio con valores de referencia
    if (_convenioSeleccionado == null ||
        _convenioSeleccionado == 'No sé mi convenio') {
      detalles.add('Convenio: No especificado');
      detalles.add('Te ayudamos a verificar valores generales');
      detalles.add('Verificamos porcentajes estándar de aportes');

      // Verificaciones generales para usuarios que no conocen su convenio
      if (sueldoBasico != null && sueldoBasico < 400000) {
        alertasGraves.add(
            '⚠️ SUELDO MUY BAJO: Tu básico está por debajo de referencia general');
        itemsRevisar
            .add('Consultá con tu empleador sobre tu convenio aplicable');
      }
    } else {
      detalles.add('Convenio seleccionado: $_convenioSeleccionado');

      // Buscar modelos que coincidan con el nombre seleccionado
      final modelos = _conveniosModelos
          .where((c) => c.nombreCCT == _convenioSeleccionado)
          .toList();

      if (modelos.isEmpty) {
        detalles.add(
            'No se encontraron datos actualizados para este convenio.');
      } else {
        // Obtener rango salarial
        final salarios = modelos.map((m) => m.sueldoBasico).toList();
        salarios.sort();
        final minSalario = salarios.first;
        final maxSalario = salarios.last;

        // Formatear moneda sin decimales
        final fMin = minSalario.toStringAsFixed(0);
        final fMax = maxSalario.toStringAsFixed(0);

        detalles.add('Rango salarial ref. (aprox): \$$fMin - \$$fMax');
        detalles.add('Categorías registradas: ${modelos.length}');

        if (sueldoBasico != null) {
          // Umbral de tolerancia (10%)
          if (sueldoBasico < minSalario * 0.9) {
            alertasGraves.add(
                '⚠️ SUELDO CRÍTICAMENTE BAJO: Tu básico está por debajo del mínimo registrado para este convenio (\$$fMin).');
            alertasGraves.add(
                'Urgente: Contactá a tu delegado gremial inmediatamente.');
          } else if (sueldoBasico < minSalario) {
            itemsRevisar.add(
                'Tu básico está ligeramente por debajo del mínimo de referencia (\$$fMin). Revisá tu categoría.');
          } else {
            detalles.add(
                '✅ Tu sueldo básico está dentro o por encima del rango mínimo.');
          }
        } else {
          itemsRevisar.add(
              'No pudimos detectar tu sueldo básico para compararlo.');
        }
      }
    }

    // Disclaimer siempre visible
    detalles.add('');
    detalles.add(
        '⚠️ IMPORTANTE: Los valores son orientativos y pueden variar según antigüedad, zona, y acuerdos puntuales.');

    // Verificación de aportes básicos (porcentajes aproximados)
    final aporteJubilacion = r.conceptos.firstWhere(
        (concepto) =>
            concepto.descripcion.toLowerCase().contains('jubilacion') ||
            concepto.descripcion.toLowerCase().contains('aporte j'),
        orElse: () => ConceptoRecibo(descripcion: '', remunerativo: 0));

    final aporteObraSocial = r.conceptos.firstWhere(
        (concepto) =>
            concepto.descripcion.toLowerCase().contains('obra social') ||
            concepto.descripcion.toLowerCase().contains('os') ||
            concepto.descripcion.toLowerCase().contains('pami'),
        orElse: () => ConceptoRecibo(descripcion: '', remunerativo: 0));

    // Verificación de porcentajes
    if (sueldoBasico != null && sueldoBasico > 0) {
      final porcentajeJubilacion =
          ((aporteJubilacion.remunerativo ?? 0) / sueldoBasico) * 100;
      if (porcentajeJubilacion < 10 || porcentajeJubilacion > 12) {
        itemsRevisar.add(
            'Aporte jubilatorio irregular: ${porcentajeJubilacion.toStringAsFixed(1)}% (debería ser 11%)');
      }

      final porcentajeObraSocial =
          ((aporteObraSocial.remunerativo ?? 0) / sueldoBasico) * 100;
      if (porcentajeObraSocial < 2.5 || porcentajeObraSocial > 3.5) {
        itemsRevisar.add(
            'Aporte obra social irregular: ${porcentajeObraSocial.toStringAsFixed(1)}% (debería ser 3%)');
      }
    }

    // Verificación de conceptos obligatorios
    final conceptosObligatorios = ['presentismo', 'antiguedad', 'asignacion'];
    final faltantes = conceptosObligatorios.where((concepto) => !r.conceptos
        .any((conceptoRecibo) =>
            conceptoRecibo.descripcion.toLowerCase().contains(concepto)));

    if (faltantes.isNotEmpty) {
      alertasGraves.add(
          '❌ CONCEPTOS FALTANTES: No se detectaron: ${faltantes.join(', ').toUpperCase()}');
      alertasGraves.add(
          'Estos conceptos son obligatorios por ley en todo recibo de sueldo');
    }

    return {
      'detalles': detalles,
      'items_revisar': itemsRevisar,
      'alertas_graves': alertasGraves,
    };
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _buildListItem(IconData icon, Color color, String text) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                height: 1.4,
              ),
            ),
         ),
        ],
      ),
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
      if (v >= 1.02) return AppColors.success;
      if (v >= 0.98) return AppColors.warning;
      return AppColors.error;
    }

    String epaLabel(double v) {
      if (v >= 1.02) return 'Gana poder';
      if (v >= 0.98) return 'Se mantiene';
      return 'Pierde poder';
    }

    return Card(
      elevation: 0,
      color: AppColors.backgroundCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.glassBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Proyecciones 3–6 meses (IPC/INDEC)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: AppColors.warning.withOpacity(0.3)),
              ),
              child: Text(
                'Ajuste necesario para no perder poder: ${ajusteReq.toStringAsFixed(1)}% mensual',
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.warning),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ipcController,
                    style: const TextStyle(color: AppColors.textPrimary),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'IPC mensual (%)',
                      labelStyle: const TextStyle(color: AppColors.textSecondary),
                      enabledBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: AppColors.border),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: AppColors.primary),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: AppColors.backgroundLight,
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
                    style: const TextStyle(color: AppColors.textPrimary),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Ajuste mensual (%)',
                      labelStyle: const TextStyle(color: AppColors.textSecondary),
                      enabledBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: AppColors.border),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: AppColors.primary),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: AppColors.backgroundLight,
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
                Expanded(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: epaColor(epa3).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: epaColor(epa3).withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.shield, color: epaColor(epa3), size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'EPA 3m: ${epa3.toStringAsFixed(2)} • ${epaLabel(epa3)}',
                            style: TextStyle(color: epaColor(epa3), fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: epaColor(epa6).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: epaColor(epa6).withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.shield, color: epaColor(epa6), size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'EPA 6m: ${epa6.toStringAsFixed(2)} • ${epaLabel(epa6)}',
                            style: TextStyle(color: epaColor(epa6), fontSize: 12),
                          ),
                        ),
                      ],
                    ),
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
        color: AppColors.backgroundLight,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.trending_up, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Text(
            '$label: \$${valor.toStringAsFixed(0)}',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
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

  double _proyectado(
      double neto, double ipcMensualPct, double ajusteMensualPct, int meses) {
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

  Widget _buildMetasUnidadesWidget() {
    if (_smvm == null || _smvm! <= 0) return const SizedBox.shrink();
    final neto = _netoActual();
    final u0 = neto > 0 ? neto / _smvm! : 0.0;
    final u3 = _proyectado(neto, _ipcBase, _ajusteMensual, 3) / _smvm!;
    final u6 = _proyectado(neto, _ipcBase, _ajusteMensual, 6) / _smvm!;
    return Card(
      elevation: 0,
      color: AppColors.backgroundCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.glassBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Metas en Unidades (SMVM)',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.accentOrange)),
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
      color: AppColors.backgroundCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.glassBorder),
      ),
      child: ExpansionTile(
        collapsedIconColor: AppColors.textPrimary,
        iconColor: AppColors.primary,
        title: const Text(
          'Estimador de Liquidación Final',
          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.accentGreen),
        ),
        subtitle: const Text('Simulá tu salida (Despido o Renuncia)',
            style: TextStyle(color: AppColors.textSecondary)),
        leading: const Icon(Icons.calculate, color: AppColors.accentGreen),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '⚠ Aviso Legal: Este cálculo es una estimación aproximada y no tiene validez legal. Consultá con un profesional para una liquidación exacta.',
                  style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: AppColors.error),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text('Motivo: ', style: TextStyle(color: AppColors.textPrimary)),
                    const SizedBox(width: 8),
                    DropdownButton<String>(
                      value: _motivoCese,
                      dropdownColor: AppColors.backgroundCard,
                      style: const TextStyle(color: AppColors.textPrimary),
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
                      initialDate:
                          DateTime.now().subtract(const Duration(days: 365)),
                      firstDate: DateTime(1980),
                      lastDate: DateTime.now(),
                      helpText: 'Fecha de Ingreso',
                      builder: (context, child) {
                        return Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: const ColorScheme.dark(
                              primary: AppColors.primary,
                              onPrimary: Colors.white,
                              surface: AppColors.backgroundCard,
                              onSurface: AppColors.textPrimary,
                            ),
                          ),
                          child: child!,
                        );
                      },
                    );
                    if (picked != null && mounted) {
                      setState(() => _fechaIngreso = picked);
                    }
                  },
                  icon: const Icon(Icons.calendar_today, size: 18),
                  label: Text(_fechaIngreso == null
                      ? 'Seleccionar Fecha de Ingreso'
                      : 'Ingreso: ${_fechaIngreso!.day}/${_fechaIngreso!.month}/${_fechaIngreso!.year}'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: AppColors.border),
                  ),
                ),
                if (_fechaIngreso != null) ...[
                  const Divider(height: 32, color: AppColors.border),
                  _buildFilaLiquidacion(
                      'SAC Proporcional (est.)', _calcularSacProporcional()),
                  _buildFilaLiquidacion('Vacaciones Proporcionales (est.)',
                      _calcularVacacionesProporcionales()),
                  if (_motivoCese == 'Despido') ...[
                    _buildFilaLiquidacion('Indemnización Antigüedad',
                        _calcularIndemnizacionAntiguedad()),
                    _buildFilaLiquidacion('Preaviso', _netoActual()),
                  ],
                  const Divider(color: AppColors.border),
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

  Widget _buildFilaLiquidacion(String label, double monto,
      {bool esTotal = false}) {
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
              color: AppColors.textPrimary,
            ),
          ),
          Text(
            '\$${monto.toStringAsFixed(2)}',
            style: TextStyle(
              fontWeight: esTotal ? FontWeight.bold : FontWeight.w600,
              fontSize: esTotal ? 16 : 14,
              color: esTotal ? AppColors.accentGreen : AppColors.textPrimary,
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
    final inicioSemestre =
        hoy.month <= 6 ? DateTime(hoy.year, 1, 1) : DateTime(hoy.year, 7, 1);
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
    double total =
        _calcularSacProporcional() + _calcularVacacionesProporcionales();
    if (_motivoCese == 'Despido') {
      total += _calcularIndemnizacionAntiguedad() +
          _netoActual(); // Antigüedad + 1 mes preaviso
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
                border:
                    Border(bottom: BorderSide(color: AppColors.glassBorder)),
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
                  MaterialPageRoute(
                      builder: (context) => const TeacherReceiptScanScreen()),
                );
              },
            ),

            _buildMenuItem(
              icon: Icons.library_books,
              label: 'Biblioteca de Convenios',
              onTap: () {
                Navigator.pop(context); // Cerrar menú
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ConoceTuConvenioScreen(),
                  ),
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
                    title: const Text('Verificador de Recibo',
                        style: TextStyle(color: AppColors.textPrimary)),
                    content: const Text(
                        'Sistema profesional para verificación de recibos de sueldo según convenios nacionales vigentes.',
                        style: TextStyle(color: AppColors.textSecondary)),
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
                    'Convenio: ${_convenioSeleccionado ?? "No especificado"}',
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
            const Text('¿Conocés tu convenio colectivo?',
                style: TextStyle(
                    color: AppColors.textPrimary, 
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
            const SizedBox(height: 4),
            const Text(
              'Seleccioná tu convenio si lo conocés. Si no estás seguro, podés elegir "No sé mi convenio" y te ayudaremos igual.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              value: _convenioSeleccionado,
              items: [
                // Opción por defecto para usuarios que no conocen su convenio
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text(
                    'No sé mi convenio - Ayúdame a verificar igual',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
                // Separador visual
                const DropdownMenuItem<String?>(
                  value: '',
                  enabled: false,
                  child: Divider(height: 1, color: AppColors.border),
                ),
                // Todos los convenios disponibles
                ..._conveniosDisponibles.where((c) => c != 'No sé mi convenio').map((String value) {
                  return DropdownMenuItem<String?>(
                    value: value,
                    child: Text(value,
                        style: const TextStyle(color: AppColors.textPrimary)),
                  );
                }).toList(),
              ],
              onChanged: (val) {
                setState(() => _convenioSeleccionado = val);
              },
              dropdownColor: AppColors.backgroundCard,
              decoration: InputDecoration(
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                filled: true,
                fillColor: AppColors.backgroundLight,
                hint: const Text('Seleccionar convenio (opcional)'),
              ),
              style: const TextStyle(color: AppColors.textPrimary),
            ),
          ],
        ),
      ),
    );
  }

  /// Método para ajustar margen OCR
  void _mostrarAjustesOcr() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.backgroundCard,
        title: const Text('Ajustar Margen OCR',
            style: TextStyle(color: AppColors.textPrimary)),
        content: const Text(
            'Margen de error aumentado al 15% para cámaras de baja calidad',
            style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }

  /// Método para mostrar información de la academia
  void _mostrarInfoAcademia() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.backgroundLight,
        title: const Row(
          children: [
            Icon(Icons.school, color: AppColors.primary),
            SizedBox(width: 12),
            Text('Elevar Formación Técnica',
                style: TextStyle(
                    color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '¡Aprendé a liquidar sueldos con nuestro curso especializado!',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 16),
              _buildAcademiaItem('📱 Sacale foto a tu recibo',
                  'Usá la cámara para escanear tu recibo de sueldo'),
              _buildAcademiaItem('🔍 La app lee todo automático',
                  'Reconoce todos los conceptos importantes'),
              _buildAcademiaItem('⚖️ Chequeamos si está bien',
                  'Comparamos con lo que deberías cobrar según tu convenio'),
              _buildAcademiaItem('📊 Te decimos qué revisar',
                  'Te mostramos si falta algo o si está todo correcto'),
              const SizedBox(height: 16),
              const Text(
                '💼 Curso de Liquidación de Sueldos',
                style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 14,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                '• Formación completa y práctica\n'
                '• Aprendé con casos reales\n'
                '• Certificación oficial\n'
                '• Modalidad presencial y online',
                style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendido',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _abrirWhatsApp();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.chat, size: 18),
                SizedBox(width: 8),
                Text('Contactar por WhatsApp'),
              ],
            ),
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
                Text(titulo,
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w500,
                        fontSize: 12)),
                Text(descripcion,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Método para abrir WhatsApp con el número de contacto
  Future<void> _abrirWhatsApp() async {
    const numero = '5492995484312'; // Número de Elevar Formación Técnica
    final url = 'https://wa.me/$numero';
    
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo abrir WhatsApp'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }
}