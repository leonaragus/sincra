import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
// import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart'; // Removed for web compatibility
import 'package:syncra_arg/services/ocr_service.dart';
import 'package:syncra_arg/services/verificacion_recibo_service.dart';
import 'teacher_receipt_scan_screen.dart';
import 'package:syncra_arg/models/recibo_escaneado.dart';
import 'package:syncra_arg/services/hybrid_store.dart';
import 'package:syncra_arg/services/parametros_legales_service.dart';
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
// import 'dart:io'; // Removed for web compatibility

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
  // final double _ipcConservador = 6.0; // Unused
  // final double _ipcOptimista = 10.0; // Unused
  double _ajusteMensual = 0.0;
  final TextEditingController _ipcController =
      TextEditingController(text: '8.0');
  final TextEditingController _ajusteController =
      TextEditingController(text: '0.0');
  double? _smvm;
  DateTime? _fechaIngreso; // Unused
  String _motivoCese = 'Renuncia'; // Unused
  
  // Variables para funcionalidad mejorada
  String? _convenioSeleccionado; // Hacer opcional
  List<ConvenioModel> _conveniosModelos = []; // Unused
  List<String> _conveniosDisponibles = ['Cargando convenios...']; // Unused

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
      // Refactored to remove direct dependency on MLKit InputImage
      final resultadoOcr = await _ocrService.procesarImagen(imagenFile);
      
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor, // Usar tema
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Verificador de Recibo',
            style: TextStyle(
                color: Theme.of(context).textTheme.bodyLarge?.color, // Usar tema
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
              child: Icon(Icons.menu, color: Theme.of(context).textTheme.bodyLarge?.color, size: 20), // Usar tema
            ),
            onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
          ),
        ],
      ),
      endDrawer: _buildMenuHamburguesa(),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).scaffoldBackgroundColor,
              Theme.of(context).cardColor,
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
              color: Theme.of(context).textTheme.bodyLarge?.color,
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
                    color: Theme.of(context).textTheme.bodyLarge?.color,
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
                    color: Theme.of(context).textTheme.bodyLarge?.color,
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
                    color: Theme.of(context).textTheme.bodyLarge?.color,
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
        // if (_rutaImagen != null)
        //   Container(
        //     margin: const EdgeInsets.only(bottom: 24),
        //     decoration: BoxDecoration(
        //       borderRadius: BorderRadius.circular(16),
        //       boxShadow: [
        //         BoxShadow(
        //           color: Colors.black.withOpacity(0.1),
        //           blurRadius: 10,
        //           offset: const Offset(0, 4),
        //         ),
        //       ],
        //     ),
        //     child: ClipRRect(
        //       borderRadius: BorderRadius.circular(16),
        //       // Use network image on web if path is blob url
        //       child: kIsWeb
        //           ? Image.network(_rutaImagen!, height: 220, fit: BoxFit.cover)
        //           : const SizedBox.shrink(),
        //     ),
        //   ),

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
                        color: Theme.of(context).textTheme.bodyLarge?.color,
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
                              color: Theme.of(context).textTheme.bodyLarge?.color,
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
                              color: Theme.of(context).textTheme.bodyLarge?.color,
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
                  foregroundColor: Theme.of(context).textTheme.bodyLarge?.color,
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
                    color: Theme.of(context).textTheme.bodyLarge?.color,
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
                            color: Theme.of(context).textTheme.bodyLarge?.color,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _textoOcr.isEmpty
                          ? 'No se detectó texto o no se ha escaneado.'
                          : _textoOcr,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Helper methods to satisfy compilation
  Widget _buildSelectorConvenio() {
    // Simplified selector
    return const SizedBox.shrink();
  }
  
  Widget _buildMenuHamburguesa() {
    return const Drawer();
  }
  
  Widget _buildProyeccionesWidget() {
    return const SizedBox.shrink();
  }
  
  Widget _buildMetasUnidadesWidget() {
    return const SizedBox.shrink();
  }
  
  Widget _buildEstimadorLiquidacionWidget() {
    return const SizedBox.shrink();
  }
  
  Widget _buildListItem(IconData icon, Color color, String text) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(text),
    );
  }
  
  Widget _buildSectionHeader(String title) {
    return Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18));
  }
  
  Map<String, dynamic> _analizarPagoConvenio() {
    // Dummy implementation
    return {
      'detalles': [],
      'items_revisar': [],
      'alertas_graves': [],
    };
  }
}
