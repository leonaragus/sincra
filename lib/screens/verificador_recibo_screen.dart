import 'dart:convert';
import 'package:flutter/material.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart'; // Removed for web compatibility
import 'package:syncra_arg/services/ocr_service.dart';
import 'package:syncra_arg/services/verificacion_recibo_service.dart';
import 'teacher_receipt_scan_screen.dart';
import 'package:syncra_arg/models/recibo_escaneado.dart';
import 'package:syncra_arg/models/recibo_model.dart'; // Import nuevo modelo
import 'package:syncra_arg/services/pdf_report_service.dart';
import 'package:syncra_arg/services/hybrid_store.dart';
import 'package:syncra_arg/screens/glosario_conceptos_screen.dart';
import 'package:syncra_arg/screens/conoce_tu_convenio_screen.dart';
// import 'package:syncra_arg/utils/app_help.dart';
import 'package:syncra_arg/utils/conceptos_builder.dart';
import 'package:syncra_arg/theme/app_colors.dart';
// import 'package:url_launcher/url_launcher.dart';
import 'package:syncra_arg/screens/biblioteca_cct_screen.dart';
import 'package:syncra_arg/screens/home_screen.dart';
import 'package:syncra_arg/widgets/academy_promo_dialog.dart';
import 'package:syncra_arg/screens/liquidacion_sac_docente_screen.dart';
import 'package:syncra_arg/screens/liquidacion_vacaciones_docente_screen.dart';
import 'package:syncra_arg/screens/liquidador_final_screen.dart';
import 'package:syncra_arg/widgets/recibo_resultado_widget.dart';

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
      final conveniosJson = await HybridStore.getConveniosJson();
      final List<dynamic> conveniosList = conveniosJson != null ? jsonDecode(conveniosJson) : [];
      
      final List<Map<String, dynamic>> opciones = [];
      
      // Opción por defecto
      opciones.add({
        'id': 'ninguno',
        'nombre': 'Sin convenio específico (Genérico)',
        'data': null
      });

      // Procesar todos los convenios disponibles
      for (var c in conveniosList) {
        if (c is Map<String, dynamic>) {
          // Intentamos obtener un nombre legible
          String nombre = c['nombre'] ?? 'Convenio sin nombre';
          String cct = c['cct'] ?? '';
          if (cct.isNotEmpty) nombre = '$nombre ($cct)';
          
          opciones.add({
            'id': c['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
            'nombre': nombre,
            'data': c,
            'cct': cct, // Guardamos cct para búsqueda
            'tags': c['tags'] ?? [], // Guardamos tags si existen
          });
        }
      }

      // Si la lista está vacía o tiene pocos datos, agregamos fallbacks
      // Pero para asegurar que estén TODOS, los agregamos siempre verificando duplicados
       
       // Lista de fallbacks hardcodeados
       final List<Map<String, dynamic>> fallbacks = [
         // Docentes
         {
            'id': 'docente_caba',
            'nombre': 'Docente - CABA',
            'data': {'jurisdiccion': 'CABA'},
            'cct': 'Estatuto Docente',
            'tags': ['docente', 'educacion', 'maestro', 'profesor', 'colegio', 'escuela']
         },
         {
            'id': 'docente_pba',
            'nombre': 'Docente - PBA',
            'data': {'jurisdiccion': 'PBA'},
            'cct': 'Estatuto Docente',
            'tags': ['docente', 'educacion', 'maestro', 'profesor', 'colegio', 'escuela']
         },
         // Sanidad
         {
            'id': 'sanidad_general',
            'nombre': 'Sanidad - General (CCT 122/75)',
            'data': {'cct': '122/75'},
            'cct': '122/75',
            'tags': ['sanidad', 'salud', 'enfermeria', 'medico', 'clinica', 'sanatorio', 'hospital']
         },
         // Comercio
         {
           'id': 'comercio_general',
           'nombre': 'Comercio - General (CCT 130/75)',
           'data': {'cct': '130/75', 'nombre': 'Comercio'},
           'cct': '130/75',
           'tags': ['comercio', 'vendedor', 'cajero', 'administrativo', 'maestranza']
         },
         // UOCRA
         {
           'id': 'uocra_general',
           'nombre': 'UOCRA - Construcción (CCT 76/75)',
           'data': {'cct': '76/75', 'nombre': 'UOCRA'},
           'cct': '76/75',
           'tags': ['construccion', 'obra', 'albañil', 'oficial', 'ayudante']
         },
         // Gastronómicos
         {
           'id': 'uthgra_general',
           'nombre': 'Gastronómicos - UTHGRA (CCT 389/04)',
           'data': {'cct': '389/04', 'nombre': 'UTHGRA'},
           'cct': '389/04',
           'tags': ['gastronomia', 'mozo', 'cocinero', 'camarera', 'barman', 'hotel']
         },
         // UOM
         {
           'id': 'uom_general',
           'nombre': 'Metalúrgicos - UOM (CCT 260/75)',
           'data': {'cct': '260/75', 'nombre': 'UOM'},
           'cct': '260/75',
           'tags': ['metalurgica', 'operario', 'fabrica', 'metal']
         },
         // Camioneros
         {
           'id': 'camioneros_general',
           'nombre': 'Camioneros (CCT 40/89)',
           'data': {'cct': '40/89', 'nombre': 'Camioneros'},
           'cct': '40/89',
           'tags': ['camionero', 'chofer', 'transporte', 'logistica']
         },
         // Encargados de Edificio (SUTERH)
         {
           'id': 'suterh_general',
           'nombre': 'Encargados de Edificio - SUTERH (CCT 589/10)',
           'data': {'cct': '589/10', 'nombre': 'SUTERH'},
           'cct': '589/10',
           'tags': ['encargado', 'portero', 'edificio', 'consorcio']
         },
         // Petroleros Privados
         {
           'id': 'petroleros_privados',
           'nombre': 'Petroleros Privados (CCT 644/12)',
           'data': {'cct': '644/12', 'nombre': 'Petroleros Privados'},
           'cct': '644/12',
           'tags': ['petroleo', 'pozo', 'yacimiento', 'refineria', 'hidrocarburos']
         },
         // Petroleros Jerárquicos
         {
           'id': 'petroleros_jerarquicos',
           'nombre': 'Petroleros Jerárquicos (CCT 643/12)',
           'data': {'cct': '643/12', 'nombre': 'Petroleros Jerárquicos'},
           'cct': '643/12',
           'tags': ['petroleo', 'jerarquico', 'supervisor', 'jefe', 'encargado']
         },
         // Plásticos (UOYEP)
         {
           'id': 'plasticos_uoyep',
           'nombre': 'Plásticos - UOYEP (CCT 797/22)',
           'data': {'cct': '797/22', 'nombre': 'UOYEP'},
           'cct': '797/22',
           'tags': ['plastico', 'inyeccion', 'extruccion', 'reciclado']
         },
         // Alimentación
         {
           'id': 'alimentacion_stia',
           'nombre': 'Alimentación - STIA (CCT 244/94)',
           'data': {'cct': '244/94', 'nombre': 'Alimentación'},
           'cct': '244/94',
           'tags': ['alimentacion', 'comida', 'bebida', 'planta', 'produccion']
         },
         // Textiles (AOT)
         {
           'id': 'textiles_aot',
           'nombre': 'Textiles - AOT (CCT 500/07)',
           'data': {'cct': '500/07', 'nombre': 'AOT'},
           'cct': '500/07',
           'tags': ['textil', 'hilado', 'tejido', 'tela', 'confeccion']
         },
         // Mecánicos (SMATA)
         {
           'id': 'smata_mecanicos',
           'nombre': 'Mecánicos - SMATA (CCT 27/88)',
           'data': {'cct': '27/88', 'nombre': 'SMATA'},
           'cct': '27/88',
           'tags': ['mecanico', 'automotriz', 'concesionaria', 'taller', 'repuestos']
         },
         // Pasteleros
         {
           'id': 'pasteleros_general',
           'nombre': 'Pasteleros (CCT 272/96)',
           'data': {'cct': '272/96', 'nombre': 'Pasteleros'},
           'cct': '272/96',
           'tags': ['pastelero', 'confiteria', 'heladero', 'pizzero', 'alfajorero']
         },
         // Seguridad Privada (UPSRA)
         {
           'id': 'seguridad_upsra',
           'nombre': 'Seguridad Privada - UPSRA (CCT 507/07)',
           'data': {'cct': '507/07', 'nombre': 'UPSRA'},
           'cct': '507/07',
           'tags': ['vigilador', 'seguridad', 'custodia', 'guardia']
         }
       ];

       for (var fb in fallbacks) {
         // Verificar si ya existe un convenio con ese ID o nombre muy similar
         bool existe = opciones.any((o) => 
            o['id'] == fb['id'] || 
            (o['cct'] == fb['cct'] && fb['cct'].toString().isNotEmpty)
         );
         
         if (!existe) {
           opciones.add(fb);
         }
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

      // Preparar contexto del convenio seleccionado
      String? contextoConvenio;
      if (_convenioSeleccionadoId != null && _convenioSeleccionadoId != 'ninguno') {
        final convenio = _listaConveniosDisponibles.firstWhere(
          (c) => c['id'] == _convenioSeleccionadoId,
          orElse: () => {'data': null}
        );
        
        if (convenio['data'] != null) {
          // Convertimos el mapa del convenio a una string legible para Claude
          // Eliminamos campos innecesarios para ahorrar tokens
          final dataMap = Map<String, dynamic>.from(convenio['data']);
          dataMap.remove('updated_at');
          dataMap.remove('id');
          contextoConvenio = dataMap.toString();
        }
      }

      // setState(() => _rutaImagen = imagenFile.path);

      // 2. Procesar con OCR
      // Refactored to remove direct dependency on MLKit InputImage
      final resultadoOcr = await _ocrService.procesarImagen(
        imagenFile, 
        contextoConvenio: contextoConvenio
      );
      
      setState(() {
        _textoOcr = resultadoOcr.texto;
        _reciboModel = resultadoOcr.reciboModel;
        _estaProcesando = false;
      });

      if (_reciboModel != null) {
        // Intentar detectar convenio automáticamente
        _detectarConvenioAutomaticamente(_reciboModel!);

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
          const SizedBox(height: 20),
          _buildOcrTextSection(),
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

        // Texto OCR - AHORA SIEMPRE VISIBLE
        _buildOcrTextSection(),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          Row(
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
        ],
      ),
    );
  }

  Widget _buildOcrTextSection() {
    return Container(
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Theme.of(context).dividerColor, width: 1),
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
                  color: Theme.of(context).colorScheme.surface.withOpacity(0.5),
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
                        Icon(Icons.text_snippet, size: 16, color: Theme.of(context).colorScheme.primary),
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
                        color: Theme.of(context).hintColor,
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
  }

  // Helper methods to satisfy compilation
  
  void _detectarConvenioAutomaticamente(ReciboModel model) {
    if (_listaConveniosDisponibles.isEmpty) return;

    final cctRecibo = model.cabecera.cctAplicable.toUpperCase();
    final categoriaRecibo = model.cabecera.categoriaProfesional.toUpperCase();
    final empresaRecibo = model.cabecera.empresaNombre.toUpperCase();
    
    debugPrint('Detectando convenio para: CCT=$cctRecibo, Cat=$categoriaRecibo, Emp=$empresaRecibo');

    // 1. Búsqueda exacta o parcial por CCT y Tags en la lista disponible
          for (var convenio in _listaConveniosDisponibles) {
            if (convenio['id'] == 'ninguno') continue;
            
            final cctConvenio = (convenio['cct'] ?? '').toString().toUpperCase();
            final nombreConvenio = (convenio['nombre'] ?? '').toString().toUpperCase();
            final tags = (convenio['tags'] as List<dynamic>?)?.map((e) => e.toString().toUpperCase()).toList() ?? [];
            
            // Coincidencia directa de número de CCT (ej "130/75")
            if (cctConvenio.isNotEmpty && cctRecibo.contains(cctConvenio)) {
              _aplicarConvenio(convenio['id'], 'Detectamos tu convenio por CCT ($cctConvenio).');
              return;
            }
            
            // Coincidencia por nombre (ej "Comercio")
            // Solo si el nombre es significativo (>4 letras) para evitar falsos positivos
            if (nombreConvenio.length > 4 && (cctRecibo.contains(nombreConvenio) || categoriaRecibo.contains(nombreConvenio))) {
               _aplicarConvenio(convenio['id'], 'Detectamos tu convenio: $nombreConvenio.');
               return;
            }

            // Coincidencia por Tags en Categoria o Empresa (Búsqueda heurística)
            for (var tag in tags) {
                if (tag.length < 3) continue; // Ignorar tags muy cortos
                if (categoriaRecibo.contains(tag) || empresaRecibo.contains(tag) || cctRecibo.contains(tag)) {
                    _aplicarConvenio(convenio['id'], 'Detectamos tu convenio por coincidencia con "$tag".');
                    return;
                }
            }
          }

    // 2. Lógica específica (Legacy + Heurística Reforzada)
    
    // Docentes (Reforzado)
    if (cctRecibo.contains('DOCENTE') || 
        categoriaRecibo.contains('DOCENTE') || 
        categoriaRecibo.contains('PROFESOR') || 
        categoriaRecibo.contains('MAESTR') ||
        categoriaRecibo.contains('PRECEPTOR') ||
        empresaRecibo.contains('COLEGIO') ||
        empresaRecibo.contains('INSTITUTO') ||
        empresaRecibo.contains('ESCUELA') ||
        empresaRecibo.contains('EDUCACION')) {
      
      final docente = _listaConveniosDisponibles.firstWhere(
        (c) => c['id'].toString().startsWith('docente_') || c['nombre'].toString().toUpperCase().contains('DOCENTE'),
        orElse: () => {},
      );
      
      if (docente.isNotEmpty) {
        _aplicarConvenio(docente['id'], '🎓 Detectamos que sos Docente. Se aplicó el convenio automáticamente.');
        return;
      }
    }
    
    // Sanidad (Reforzado)
    if (cctRecibo.contains('122/75') || cctRecibo.contains('SANIDAD') || 
        categoriaRecibo.contains('ENFERMER') || categoriaRecibo.contains('MEDIC') || categoriaRecibo.contains('CAMILLER') ||
        empresaRecibo.contains('CLINICA') || empresaRecibo.contains('SANATORIO') || empresaRecibo.contains('HOSPITAL') || empresaRecibo.contains('SALUD')) {
        
      final sanidad = _listaConveniosDisponibles.firstWhere(
        (c) => c['id'].toString().startsWith('sanidad_') || c['nombre'].toString().toUpperCase().contains('SANIDAD'),
        orElse: () => {},
      );
      
      if (sanidad.isNotEmpty) {
        _aplicarConvenio(sanidad['id'], '🏥 Detectamos convenio Sanidad. Se aplicó automáticamente.');
        return;
      }
    }
    
    // Comercio (Reforzado)
    if (cctRecibo.contains('130/75') || cctRecibo.contains('COMERCIO') || 
        categoriaRecibo.contains('VENDEDOR') || categoriaRecibo.contains('ADMINISTRATIVO') || categoriaRecibo.contains('CAJERO') || 
        categoriaRecibo.contains('MAESTRANZA') || categoriaRecibo.contains('AUXILIAR')) {
        
      final comercio = _listaConveniosDisponibles.firstWhere(
        (c) => c['nombre'].toString().toUpperCase().contains('COMERCIO'),
        orElse: () => {},
      );
      
      if (comercio.isNotEmpty) {
        _aplicarConvenio(comercio['id'], '🛒 Detectamos convenio Comercio. Se aplicó automáticamente.');
        return;
      }
    }

    // UOCRA (Construcción)
    if (cctRecibo.contains('76/75') || cctRecibo.contains('UOCRA') || cctRecibo.contains('CONSTRUCCION') ||
        categoriaRecibo.contains('ALBAÑIL') || categoriaRecibo.contains('OFICIAL') || categoriaRecibo.contains('AYUDANTE') ||
        empresaRecibo.contains('CONSTRUCTORA')) {
          
       final uocra = _listaConveniosDisponibles.firstWhere(
        (c) => c['nombre'].toString().toUpperCase().contains('UOCRA') || c['nombre'].toString().toUpperCase().contains('CONSTRUCCION'),
        orElse: () => {},
      );

      if (uocra.isNotEmpty) {
        _aplicarConvenio(uocra['id'], '🏗️ Detectamos convenio UOCRA. Se aplicó automáticamente.');
        return;
      }
    }
  }

  void _aplicarConvenio(String id, String mensaje) {
    if (_convenioSeleccionadoId == id) return;
    
    setState(() {
      _convenioSeleccionadoId = id;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 4),
      ),
    );
  }

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
                    icon: Icons.qr_code_scanner_rounded,
                    label: 'Escanear QR',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const TeacherReceiptScanScreen()));
                    },
                  ),
                  _buildMenuItem(
                    icon: Icons.calculate_outlined,
                    label: 'Calculadora SAC Docente',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const LiquidacionSacDocenteScreen()));
                    },
                  ),
                  _buildMenuItem(
                    icon: Icons.beach_access_outlined,
                    label: 'Calculadora Vacaciones',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const LiquidacionVacacionesDocenteScreen()));
                    },
                  ),
                   _buildMenuItem(
                    icon: Icons.gavel_outlined,
                    label: 'Calculadora Final/Despido',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const LiquidadorFinalScreen()));
                    },
                  ),
                  
                  if (_resultado != null) ...[
                    _buildMenuItem(
                      icon: Icons.check_circle_outline_rounded,
                      label: 'Ver Resultados Verificación',
                      onTap: () {
                        Navigator.pop(context);
                        // Ya estamos en la pantalla, solo cerramos el drawer
                      },
                    ),
                  ],
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

    // Usamos el nuevo widget dedicado para mostrar los resultados
    return ReciboResultadoWidget(recibo: _reciboModel!);
  }
}
