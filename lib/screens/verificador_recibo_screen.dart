import 'package:flutter/material.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart'; // Removed for web compatibility
import 'package:elevar_liquidacion/services/ocr_service.dart';
import 'package:elevar_liquidacion/services/verificacion_recibo_service.dart';
import 'package:elevar_liquidacion/models/recibo_escaneado.dart';
import 'package:elevar_liquidacion/models/recibo_model.dart'; // Import nuevo modelo
import 'package:elevar_liquidacion/services/hybrid_store.dart';
import 'package:elevar_liquidacion/screens/glosario_conceptos_screen.dart';
import 'package:elevar_liquidacion/screens/conoce_tu_convenio_screen.dart';
import 'package:elevar_liquidacion/utils/conceptos_builder.dart';
import 'package:elevar_liquidacion/theme/app_colors.dart';
import 'package:elevar_liquidacion/screens/biblioteca_cct_screen.dart';
import 'package:elevar_liquidacion/screens/historial_liquidaciones_screen.dart';
import 'package:elevar_liquidacion/screens/profile_screen.dart';
import 'package:elevar_liquidacion/screens/home_screen.dart';
import 'package:elevar_liquidacion/widgets/academy_promo_dialog.dart';
import 'package:elevar_liquidacion/services/pdf_report_service.dart';
import 'package:elevar_liquidacion/screens/teacher_receipt_scan_screen.dart';
// import 'dart:io'; // Removed for web compatibility

class VerificadorReciboScreen extends StatefulWidget {
  const VerificadorReciboScreen({super.key});

  @override
  State<VerificadorReciboScreen> createState() =>
      _VerificadorReciboScreenState();
}

class _VerificadorReciboScreenState extends State<VerificadorReciboScreen> with SingleTickerProviderStateMixin {
  final OcrService _ocrService = OcrService();
  final VerificacionReciboService _verificacionService =
      VerificacionReciboService();

  bool _estaProcesando = false;
  String _textoOcr = '';
  ResultadoVerificacion? _resultado;
  ReciboEscaneado? _recibo;
  ReciboModel? _reciboModel; // Nuevo modelo estructurado
  late TabController _tabController;
  
  // Gestión de convenios
  String? _convenioSeleccionadoId;
  List<Map<String, dynamic>> _listaConveniosDisponibles = [];
  bool _cargandoConvenios = true;

  double _ipcBase = 8.0;
  // final double _ipcConservador = 6.0; // Unused
  // final double _ipcOptimista = 10.0; // Unused
  double _ajusteMensual = 0.0;
  final TextEditingController _ipcController =
      TextEditingController(text: '8.0');
  final TextEditingController _ajusteController =
      TextEditingController(text: '0.0');
  // double? _smvm;
  
  /// Controlador para el menú hamburguesa
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void dispose() {
    _ocrService.dispose();
    _ipcController.dispose();
    _ajusteController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    debugPrint('VerificadorReciboScreen v1.3 loaded'); // Debug version
    _tabController = TabController(length: 3, vsync: this);
    _cargarDatosAutomaticos();
    _cargarListaConvenios();
  }

  Future<void> _cargarListaConvenios() async {
    try {
      final docentes = await HybridStore.getMaestroParitarias();
      final sanidad = await HybridStore.getMaestroParitariasSanidad();
      
      final List<Map<String, dynamic>> opciones = [];
      
      // Opción por defecto
      opciones.add({
        'id': 'ninguno',
        'nombre': 'Sin convenio específico (Genérico)',
        'data': null
      });

      // Procesar Docentes
      for (var d in docentes) {
        final juris = d['jurisdiccion'] ?? 'Desconocida';
        opciones.add({
          'id': 'docente_$juris',
          'nombre': 'Docente - $juris',
          'data': d
        });
      }

      // Procesar Sanidad
      for (var s in sanidad) {
        final juris = s['jurisdiccion'] ?? 'Desconocida';
        opciones.add({
          'id': 'sanidad_$juris',
          'nombre': 'Sanidad - $juris (CCT 122/75)',
          'data': s
        });
      }

      if (mounted) {
        setState(() {
          _listaConveniosDisponibles = opciones;
          _convenioSeleccionadoId = 'ninguno';
          _cargandoConvenios = false;
        });
      }
    } catch (e) {
      print('Error cargando convenios: $e');
      if (mounted) {
        setState(() => _cargandoConvenios = false);
      }
    }
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
      // final params = await ParametrosLegalesService.cargarParametros(); // Unused
      // final smvm = params.smvm; // Unused
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
          // _smvm = smvm > 0 ? smvm : null;
        });
      }
    } catch (_) {}
  }

  Future<void> _escanearYVerificar() async {
    // Si estamos en web, permitimos continuar sin restricciones de plataforma nativa
    // Si estamos en desktop nativo (Windows .exe), mostramos aviso solo si no hay fallback implementado
    // Pero como OCRService tiene fallback a Tesseract en Web y FilePicker en Desktop, 
    // deberíamos permitir intentar.
    
    // 0. Verificar cuota Freemium - DESHABILITADO
    /*
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
    */

    setState(() {
        _estaProcesando = true;
        // _rutaImagen = null;
        _textoOcr = '';
        _resultado = null;
        _recibo = null;
        _reciboModel = null;
      });

    try {
      // 1. Obtener imagen
      final imagenFile = await _ocrService.obtenerImagen();
      if (imagenFile == null) {
        setState(() => _estaProcesando = false);
        return;
      }
      
      // Registrar uso de cuota - DESHABILITADO
      // await SubscriptionService.registerOcrScan();


      // setState(() => _rutaImagen = imagenFile.path);

      // 2. Procesar con OCR
      // Refactored to remove direct dependency on MLKit InputImage
      final resultadoOcr = await _ocrService.procesarImagen(imagenFile);
      
      setState(() {
        _textoOcr = resultadoOcr.texto;
        _reciboModel = resultadoOcr.reciboModel;
        _estaProcesando = false;
      });

      if (_reciboModel != null) {
        // Si tenemos el modelo estructurado, ya tenemos todo lo necesario.
        // Asignamos valores dummy a _recibo y _resultado para activar la vista de resultados
        // pero usaremos _reciboModel para renderizar.
        setState(() {
           _recibo = ReciboEscaneado(); 
           _resultado = ResultadoVerificacion();
        });
        return;
      }

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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Theme.of(context).textTheme.bodyLarge?.color),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text('Verificador de Recibo',
            style: TextStyle(
                color: Theme.of(context).textTheme.bodyLarge?.color,
                fontSize: 20,
                fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.glassFill,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.glassBorder, width: 1),
              ),
              child: Icon(Icons.menu, color: Theme.of(context).textTheme.bodyLarge?.color, size: 20),
            ),
            onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
          ),
          const SizedBox(width: 8),
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
              // _buildSelectorConvenio(),

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
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Theme.of(context).dividerColor, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
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
              color: Theme.of(context).hintColor,
              fontSize: 15,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Theme.of(context).dividerColor, width: 1),
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
                    color: Theme.of(context).hintColor,
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
          // Selector de Convenio (Opcional)
          if (!_cargandoConvenios && _listaConveniosDisponibles.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Theme.of(context).dividerColor),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.gavel, size: 16, color: Theme.of(context).primaryColor),
                      const SizedBox(width: 8),
                      Text(
                        "Convenio aplicable (Opcional)",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _convenioSeleccionadoId,
                      hint: const Text("Seleccionar convenio..."),
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                        fontSize: 14,
                      ),
                      dropdownColor: Theme.of(context).cardColor,
                      items: _listaConveniosDisponibles.map((c) {
                        return DropdownMenuItem<String>(
                          value: c['id'],
                          child: Text(
                            c['nombre'],
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() {
                          _convenioSeleccionadoId = val;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),

          // Tarjeta principal de escaneo
          Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Theme.of(context).dividerColor, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
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
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3), width: 2),
                  ),
                  child: Icon(
                    Icons.document_scanner_outlined,
                    size: 50,
                    color: Theme.of(context).colorScheme.primary,
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
                    color: Theme.of(context).hintColor,
                    fontSize: 15,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 25),
                ElevatedButton(
                  onPressed: _escanearYVerificar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
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
                  icon: Icon(Icons.library_books, color: Theme.of(context).colorScheme.onSecondary),
                  label: Text(
                    'Biblioteca de Convenios',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSecondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    backgroundColor: Theme.of(context).colorScheme.secondary,
                    foregroundColor: Theme.of(context).colorScheme.onSecondary,
                    side: BorderSide(color: Theme.of(context).dividerColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 4,
                  ),
                ),
                const SizedBox(height: 12),
                // Botón Glosario Interactivo
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const GlosarioConceptosScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.menu_book_outlined, color: AppColors.accentBlue),
                  label: const Text(
                    'Glosario Interactivo',
                    style: TextStyle(
                      color: AppColors.accentBlue,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    side: const BorderSide(color: AppColors.accentBlue, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
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
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Theme.of(context).dividerColor, width: 1),
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
          
          // SECCION EDUCATIVA
          _buildEducationSection(),
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
                color: Theme.of(context).hintColor,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- NUEVA SECCIÓN EDUCATIVA EN EL HOME DEL VERIFICADOR ---
  Widget _buildEducationSection() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'Aprende sobre tu sueldo',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const GlosarioConceptosScreen()),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.secondary.withOpacity(0.9), AppColors.secondary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.secondary.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.school, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Glosario Interactivo',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '¿Qué es el Básico? ¿Por qué me descuentan jubilación?',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultadoWidget() {
    if (_reciboModel != null) {
      return Column(
        children: [
          _buildStructuredResult(),
          const SizedBox(height: 20),
          _buildActionButtons(),

        ],
      );
    }

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
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Theme.of(context).dividerColor, width: 1),
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
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.help_outline, color: Theme.of(context).colorScheme.primary, size: 20),
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
                        Icon(Icons.arrow_forward_ios, color: Theme.of(context).colorScheme.primary, size: 16),
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
                          convenio: 'No especificado',
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

        // Botones de acción
        _buildActionButtons(),


      ],
    );
  }

  Widget _buildActionButtons() {
    return Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: _escanearYVerificar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
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
                  side: BorderSide(color: Theme.of(context).dividerColor),
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
        );
  }

  

  // Helper methods to satisfy compilation
  
  Widget _buildMenuHamburguesa() {
    return Drawer(
      backgroundColor: AppColors.background,
      child: SafeArea(
        child: Column(
          children: [
            // Header del Drawer
            Container(
              padding: const EdgeInsets.all(24),
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                border: Border(bottom: BorderSide(color: AppColors.glassBorder, width: 1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.accentBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.accentBlue.withValues(alpha: 0.2)),
                    ),
                    child: const Icon(Icons.account_balance_wallet, color: AppColors.accentBlue, size: 32),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Sincra Arg',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const Text(
                    'Verificador de Recibos',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            // Lista de items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 12),
                children: [
                  _buildSectionHeader('PRINCIPAL'),
                  _buildMenuItem(
                    icon: Icons.home_rounded,
                    label: 'Inicio',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (context) => const HomeScreen()),
                        (route) => false,
                      );
                    },
                  ),
                  _buildMenuItem(
                    icon: Icons.library_books_rounded,
                    label: 'Biblioteca de Convenios',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const BibliotecaCCTScreen()));
                    },
                  ),
                  _buildMenuItem(
                    icon: Icons.book_rounded,
                    label: 'Glosario de Conceptos',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const GlosarioConceptosScreen()));
                    },
                  ),

                  const Divider(height: 32, color: AppColors.glassBorder, indent: 20, endIndent: 20),
                  
                  _buildSectionHeader('HERRAMIENTAS'),
                  _buildMenuItem(
                    icon: Icons.history_rounded,
                    label: 'Historial de Liquidaciones',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context, 
                        MaterialPageRoute(
                          builder: (context) => HistorialLiquidacionesScreen(
                            empleadoCuil: _recibo?.cuilEmpleado ?? '00-00000000-0',
                            empleadoNombre: _recibo?.nombreEmpleado ?? 'Usuario',
                          ),
                        ),
                      );
                    },
                  ),
                  _buildMenuItem(
                    icon: Icons.qr_code_scanner_rounded,
                    label: 'Escanear QR Docente',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const TeacherReceiptScanScreen()));
                    },
                  ),

                  const Divider(height: 32, color: AppColors.glassBorder, indent: 20, endIndent: 20),

                  _buildSectionHeader('CUENTA'),
                  _buildMenuItem(
                    icon: Icons.person_rounded,
                    label: 'Mi Perfil',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen()));
                    },
                  ),
                ],
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.backgroundDark,
                border: Border(top: BorderSide(color: AppColors.glassBorder, width: 1)),
              ),
              child: Row(
                children: [
                  const Text(
                    'v1.3.5',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                  const Spacer(),
                  Text(
                    '© 2026 Sincra',
                    style: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.7), fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isHighlight = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: ListTile(
        onTap: onTap,
        dense: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: Icon(
          icon,
          color: isHighlight ? AppColors.accentYellow : AppColors.textPrimary,
          size: 22,
        ),
        title: Text(
          label,
          style: TextStyle(
            color: isHighlight ? AppColors.accentYellow : AppColors.textPrimary,
            fontSize: 15,
            fontWeight: isHighlight ? FontWeight.bold : FontWeight.w500,
          ),
        ),
        trailing: Icon(Icons.chevron_right_rounded, color: AppColors.textMuted.withValues(alpha: 0.5), size: 18),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Text(
        title,
        style: const TextStyle(
          color: AppColors.textMuted,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
  
  Widget _buildListItem(IconData icon, Color color, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _analizarPagoConvenio() {
    // Dummy implementation
    return {
      'detalles': [],
      'items_revisar': [],
      'alertas_graves': [],
    };
  }

  // --- NUEVA UI ESTRUCTURADA ---

  Widget _buildStructuredResult() {
    if (_reciboModel == null) return const SizedBox.shrink();

    return Column(
      children: [
        // TabBar
        Container(
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: TabBar(
            controller: _tabController,
            indicatorColor: Theme.of(context).primaryColor,
            labelColor: Theme.of(context).primaryColor,
            unselectedLabelColor: Theme.of(context).hintColor,
            tabs: const [
              Tab(text: 'Datos'),
              Tab(text: 'Liquidación'),
              Tab(text: 'Auditoría IA'),
            ],
          ),
        ),

        // Contenido de las tabs
        SizedBox(
          height: 600, // Altura fija o usar Expanded si el padre lo permite
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildDatosGeneralesTab(),
              _buildLiquidacionTab(),
              _buildAuditoriaTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDatosGeneralesTab() {
    final cabecera = _reciboModel!.cabecera;
    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('Empresa', cabecera.empresaNombre),
            _buildInfoRow('CUIT Empresa', cabecera.empresaCuit),
            const Divider(),
            _buildInfoRow('Empleado', cabecera.empleadoNombre),
            _buildInfoRow('CUIL Empleado', cabecera.empleadoCuil),
            _buildInfoRow('Legajo', cabecera.legajo),
            _buildInfoRow('Fecha Ingreso', cabecera.fechaIngreso),
            _buildInfoRow('Antigüedad', cabecera.antiguedadReconocida),
            const Divider(),
            _buildInfoRow('Categoría', cabecera.categoriaProfesional),
            _buildInfoRow('CCT', cabecera.cctAplicable),
            _buildInfoRow('Período', cabecera.periodoAbonado),
            _buildInfoRow('Lugar Pago', cabecera.lugarPago),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).hintColor,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isNotEmpty ? value : '-',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiquidacionTab() {
    final liq = _reciboModel!.liquidacionDetallada;
    final totales = _reciboModel!.totales;

    return SingleChildScrollView(
      child: Column(
        children: [
          // Haberes
          if (liq.haberes.isNotEmpty)
            _buildSectionCard('Haberes', liq.haberes.map((h) => 
              _buildConceptoRow(h.codigo, h.descripcion, h.monto, Colors.green)
            ).toList()),
          
          // Retenciones
          if (liq.retenciones.isNotEmpty)
            _buildSectionCard('Retenciones', liq.retenciones.map((r) => 
              _buildConceptoRow(r.codigo, r.descripcion, -r.monto, Colors.red)
            ).toList()),

          // Otros
          if (liq.otrosConceptos.isNotEmpty)
            _buildSectionCard('Otros Conceptos', liq.otrosConceptos.map((o) => 
              _buildConceptoRow('', o.descripcion, o.monto, Colors.blue)
            ).toList()),

          // Totales
          Container(
            margin: const EdgeInsets.only(top: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Theme.of(context).primaryColor),
            ),
            child: Column(
              children: [
                _buildTotalRow('Total Bruto (Reportado)', totales.totalBruto),
                _buildTotalRow('Total Retenciones (Reportado)', -totales.totalRetenciones, isNegative: true),
                _buildTotalRow('No Remunerativo (Reportado)', totales.totalNoRemunerativo),
                const Divider(),
                _buildTotalRow('NETO A COBRAR (Reportado)', totales.netoACobrar, isBold: true, fontSize: 18),
                
                // Validación Matemática
                _buildValidacionMatematica(liq, totales),

                if (totales.netoEnLetras.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      totales.netoEnLetras,
                      style: TextStyle(fontStyle: FontStyle.italic, color: Theme.of(context).hintColor),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildValidacionMatematica(LiquidacionDetallada liq, Totales totales) {
    // Calcular sumas de items individuales (para validación futura)
    /*
    double sumHaberesRem = 0;
    double sumHaberesNoRem = 0;
    
    for (var h in liq.haberes) {
      if (h.esRemunerativo) {
        sumHaberesRem += h.monto;
      } else {
        sumHaberesNoRem += h.monto;
      }
    }

    double sumRetenciones = liq.retenciones.fold(0, (sum, item) => sum + item.monto);
    double sumOtros = liq.otrosConceptos.fold(0, (sum, item) => sum + item.monto);
    */
    
    // Asumimos que "otros conceptos" suelen ser no remunerativos o ajustes netos, 
    // pero para simplificar la validación básica:
    // Neto Calculado = (Remunerativo + No Remunerativo + Otros) - Retenciones
    
    // Nota: El modelo JSON tiene "total_no_remunerativo" en totales, que debería coincidir con sumHaberesNoRem + sumOtros (aprox)
    // Vamos a usar los totales reportados para la validación cruzada principal:
    // Neto Teorico = Bruto + No Remunerativo - Retenciones
    
    final netoTeorico = totales.totalBruto + totales.totalNoRemunerativo - totales.totalRetenciones;
    final diferencia = (totales.netoACobrar - netoTeorico).abs();
    
    if (diferencia < 1.0) {
      return Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
             Icon(Icons.check_circle_outline, size: 16, color: Colors.green),
             SizedBox(width: 8),
             Text("Cálculo matemático correcto", style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
      );
    } else {
      return Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                 Icon(Icons.warning_amber_rounded, size: 16, color: Colors.orange),
                 SizedBox(width: 8),
                 Text("Diferencia matemática detectada", style: TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              "Neto calculado: \$${netoTeorico.toStringAsFixed(2)} (Dif: \$${diferencia.toStringAsFixed(2)})",
              style: const TextStyle(color: Colors.orange, fontSize: 11),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildSectionCard(String title, List<Widget> children) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const Divider(),
          ...children,
        ],
      ),
    );
  }

  Widget _buildConceptoRow(String codigo, String descripcion, double monto, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          if (codigo.isNotEmpty)
            SizedBox(width: 40, child: Text(codigo, style: const TextStyle(fontSize: 12))),
          Expanded(child: Text(descripcion)),
          Text(
            '\$${monto.abs().toStringAsFixed(2)}',
            style: TextStyle(fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalRow(String label, double amount, {bool isNegative = false, bool isBold = false, double fontSize = 14}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal, fontSize: fontSize)),
          Text(
            '${isNegative ? "-" : ""}\$${amount.abs().toStringAsFixed(2)}',
            style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal, fontSize: fontSize),
          ),
        ],
      ),
    );
  }

  Widget _buildAuditoriaTab() {
    final audit = _reciboModel!.auditoriaIA;
    return SingleChildScrollView(
      child: Column(
        children: [
          // Confianza
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.green),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green),
                const SizedBox(width: 12),
                Text(
                  'Confianza del análisis: ${(audit.puntuacionConfianzaOcr * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                ),
              ],
            ),
          ),

          // Análisis Legal
          _buildSectionCard('Análisis Legal', [
            Text(audit.analisisLegal.isNotEmpty ? audit.analisisLegal : 'Sin observaciones.'),
          ]),

          // Alertas
          if (audit.alertasCriticas.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.orange),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.orange),
                      SizedBox(width: 8),
                      Text('Alertas Críticas', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                    ],
                  ),
                  const Divider(color: Colors.orange),
                  ...audit.alertasCriticas.map((a) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• ', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                        Expanded(child: Text(a)),
                      ],
                    ),
                  )),
                ],
              ),
            ),

          // Conceptos Complejos
          if (audit.explicacionConceptosComplejos.isNotEmpty)
            _buildSectionCard('Conceptos Complejos', [
              Text(audit.explicacionConceptosComplejos),
            ]),
        ],
      ),
    );
  }
}
