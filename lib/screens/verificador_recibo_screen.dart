import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

// Servicios y Modelos (Lógica reutilizada, sin dependencias de UI)
import '../services/ocr_service.dart';
import '../services/pdf_report_service.dart';
import '../models/recibo_model.dart';
import '../theme/app_colors.dart';

class VerificadorReciboScreen extends StatefulWidget {
  const VerificadorReciboScreen({super.key});

  @override
  State<VerificadorReciboScreen> createState() => _VerificadorReciboScreenState();
}

class _VerificadorReciboScreenState extends State<VerificadorReciboScreen> with SingleTickerProviderStateMixin {
  final OcrService _ocrService = OcrService();
  final PdfReportService _pdfReportService = PdfReportService();
  final NumberFormat currencyFormat = NumberFormat.currency(locale: 'es_AR', symbol: r'$');

  bool _estaProcesando = false;
  ReciboModel? _reciboModel;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // --- ACCIONES DE RED Y ESCANEO ---

  Future<void> _escanearYAnalizar() async {
    setState(() => _estaProcesando = true);
    try {
      final imagen = await _ocrService.obtenerImagen();
      if (imagen == null) {
        setState(() => _estaProcesando = false);
        return;
      }
      final resultadoOcr = await _ocrService.procesarImagen(imagen);
      if (mounted) {
        setState(() {
          _estaProcesando = false;
          if (resultadoOcr.reciboModel != null) {
            _reciboModel = resultadoOcr.reciboModel;
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No se pudo interpretar el recibo. Intenta con una imagen más clara.')),
            );
          }
        });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      setState(() => _estaProcesando = false);
    }
  }

  Future<void> _launchWhatsApp({String? contextMessage}) async {
    const phoneNumber = '+5492995484312';
    final message = contextMessage ?? 'Hola! Vengo desde la app Asesor de Recibos IA y me gustaría saber más sobre los cursos.';
    final uri = Uri.parse('https://wa.me/$phoneNumber?text=${Uri.encodeComponent(message)}');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo abrir WhatsApp.')));
    }
  }

  // --- LÓGICA DE POPUPS DE CÁLCULO ---

  void _showAguinaldoPopup() {
    final sueldoBruto = _reciboModel!.totales.totalBruto;
    final aguinaldo = sueldoBruto * 0.5;
    _showCalculatorPopup(
      title: 'Cálculo de Aguinaldo (SAC)',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCalcRow('Mejor Sueldo Bruto (actual)', sueldoBruto),
          const Text('Se multiplica por 0.5 (50%)'),
          const Divider(height: 20),
          _buildCalcResult('Aguinaldo Bruto Estimado', aguinaldo),
          const SizedBox(height: 16),
          _buildDisclaimer('Este cálculo asume que el sueldo actual es el más alto del semestre. El cálculo real usa la mayor remuneración de los últimos 6 meses.'),
        ],
      ),
      whatsappContext: 'Hola, quiero saber más sobre cómo se calcula el aguinaldo y los conceptos no remunerativos que lo afectan.',
    );
  }

  void _showIndemnizacionPopup() {
    final sueldoBruto = _reciboModel!.totales.totalBruto;
    final fechaIngresoStr = _reciboModel!.cabecera.fechaIngreso;
    DateTime? fechaIngreso;
    int aniosAntiguedad = 0;
    if (fechaIngresoStr != null && fechaIngresoStr.isNotEmpty) {
      try {
        fechaIngreso = DateFormat('dd/MM/yyyy').parse(fechaIngresoStr);
        aniosAntiguedad = (DateTime.now().difference(fechaIngreso).inDays / 365).ceil();
      } catch (e) { /* Fecha en formato inválido */ }
    }

    if (aniosAntiguedad == 0) { // Fallback si no hay fecha
      _showMissingDataPopup('Fecha de Ingreso');
      return;
    }

    final indemnizacion = sueldoBruto * aniosAntiguedad;

    _showCalculatorPopup(
      title: 'Cálculo de Indemnización',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCalcRow('Mejor Sueldo Bruto', sueldoBruto),
          _buildCalcRow('Años de Antigüedad', aniosAntiguedad.toDouble(), isCurrency: false),
          const Divider(height: 20),
          _buildCalcResult('Indemnización (Art. 245)', indemnizacion),
          const SizedBox(height: 16),
          _buildDisclaimer('Estimación básica. No incluye preaviso, SAC proporcional ni otros rubros. El tope legal puede afectar el monto final.'),
        ],
      ),
      whatsappContext: 'Hola, mi indemnización estimada es ${currencyFormat.format(indemnizacion)}. ¿Es correcta? Quiero una asesoría completa.',
    );
  }

  void _showVacacionesPopup() {
    final sueldoBruto = _reciboModel!.totales.totalBruto;
    final fechaIngresoStr = _reciboModel!.cabecera.fechaIngreso;
    DateTime? fechaIngreso;
    int aniosAntiguedad = 0;
    if (fechaIngresoStr != null && fechaIngresoStr.isNotEmpty) {
      try {
        fechaIngreso = DateFormat('dd/MM/yyyy').parse(fechaIngresoStr);
        aniosAntiguedad = (DateTime.now().difference(fechaIngreso).inDays / 365).floor();
      } catch (e) { /* Fecha en formato inválido */ }
    }

    if (fechaIngreso == null) {
       _showMissingDataPopup('Fecha de Ingreso');
       return;
    }

    int diasVacaciones;
    if (aniosAntiguedad >= 20) diasVacaciones = 35;
    else if (aniosAntiguedad >= 10) diasVacaciones = 28;
    else if (aniosAntiguedad >= 5) diasVacaciones = 21;
    else diasVacaciones = 14;

    final plusVacacional = (sueldoBruto / 25) * diasVacaciones;

    _showCalculatorPopup(
      title: 'Cálculo de Vacaciones',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCalcRow('Sueldo Bruto / 25', sueldoBruto / 25),
          _buildCalcRow('Días por Antigüedad (${aniosAntiguedad} años)', diasVacaciones.toDouble(), isCurrency: false),
          const Divider(height: 20),
          _buildCalcResult('Plus Vacacional Estimado', plusVacacional),
           const SizedBox(height: 16),
          _buildDisclaimer('Este es el monto que se abona por los días de vacaciones. El cálculo puede variar según el convenio.'),
        ],
      ),
       whatsappContext: 'Hola, quiero saber más sobre cómo se calculan las vacaciones y los días que me corresponden.',
    );
  }

  void _showCategoriaInfoPopup() {
    _showCalculatorPopup(
      title: '¿Cuál es mi Categoría Laboral?',
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tu categoría define tu sueldo básico y tus derechos según tu Convenio Colectivo de Trabajo (CCT).', style: TextStyle(fontSize: 15)),
          SizedBox(height: 16),
          Text('Es crucial para saber si tu sueldo está actualizado con las últimas escalas salariales.', style: TextStyle(fontSize: 15)),
        ],
      ),
      whatsappContext: 'Hola, escaneé mi recibo y dice que mi convenio es ${_reciboModel?.inferencias.convenioSugerido}. ¿Me ayudan a encontrar mi categoría y si mi sueldo es correcto?',
    );
  }

  void _showMissingDataPopup(String missingField) {
    showDialog(context: context, builder: (context) => AlertDialog(
      title: const Text('Dato no encontrado'),
      content: Text('No pudimos encontrar el campo \"$missingField\" en tu recibo para hacer este cálculo. Puedes probar con una imagen más clara.'),
      actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Entendido'))],
    ));
  } 

  // --- WIDGETS DE UI PRINCIPALES ---
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Asesor de Recibos IA'), centerTitle: true), body: _estaProcesando ? _buildLoadingState() : _buildBodyContent());

  Widget _buildBodyContent() => SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    _buildScannerCard(),
    const SizedBox(height: 24),
    if (_reciboModel != null) _buildResultadoWidget() else _buildToolsSection(isLocked: true),
  ]));

  Widget _buildScannerCard() => Card(elevation: 4, child: Padding(padding: const EdgeInsets.all(20.0), child: Column(children: [
    const Icon(Icons.document_scanner_outlined, size: 50, color: AppColors.primary),
    const SizedBox(height: 16),
    Text(_reciboModel == null ? 'Escanea tu recibo y activa las herramientas' : '¡Análisis completado!', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
    const SizedBox(height: 10),
    Text(_reciboModel == null ? 'Usa la cámara para obtener tu análisis y usar las calculadoras.' : 'Explora los resultados y usa las herramientas con tus datos.', style: TextStyle(color: Theme.of(context).hintColor, fontSize: 15), textAlign: TextAlign.center),
    if (_reciboModel == null) ...[const SizedBox(height: 20), ElevatedButton.icon(onPressed: _escanearYAnalizar, icon: const Icon(Icons.camera_alt), label: const Text('Escanear y Analizar'), style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white))],
  ])));

  Widget _buildToolsSection({required bool isLocked}) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Padding(padding: const EdgeInsets.only(left: 4, bottom: 8), child: Text('Herramientas Rápidas', style: Theme.of(context).textTheme.titleLarge)),
    GridView.count(crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.1, children: [
      _buildToolCard('¿Cuál es mi categoría?', Icons.business_center_outlined, isLocked, _showCategoriaInfoPopup),
      _buildToolCard('Calcular Indemnización', Icons.exit_to_app, isLocked, _showIndemnizacionPopup),
      _buildToolCard('Calcular Aguinaldo', Icons.savings_outlined, isLocked, _showAguinaldoPopup),
      _buildToolCard('Calcular Vacaciones', Icons.beach_access_outlined, isLocked, _showVacacionesPopup),
      _buildToolCard('Academia Elevar', Icons.school_outlined, false, () => _launchWhatsApp()),
      _buildToolCard('Descargar PDF', Icons.picture_as_pdf_outlined, isLocked, () { _pdfReportService.createAndSharePdf(_reciboModel!); }),
    ]),
  ]);

  Widget _buildToolCard(String title, IconData icon, bool isLocked, VoidCallback onTap) => Card(elevation: 2, child: InkWell(
    onTap: isLocked ? () => _showScanFirstDialog() : onTap,
    child: Opacity(opacity: isLocked ? 0.5 : 1.0, child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(icon, size: 36, color: isLocked ? Colors.grey[600] : AppColors.primary), 
      const SizedBox(height: 12), 
      Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      if (isLocked) const Icon(Icons.lock_outline, size: 16, color: Colors.grey),  
    ])),
  ));

  Widget _buildResultadoWidget() => Column(children: [
    TabBar(controller: _tabController, tabs: const [Tab(text: 'Tu Liquidación'), Tab(text: 'Asesor IA y Academia')]),
    const SizedBox(height: 16),
    // Usamos un LayoutBuilder para que el TabBarView no tenga altura infinita
    SizedBox(height: MediaQuery.of(context).size.height * 0.6, child: TabBarView(controller: _tabController, children: [ _buildLiquidacionTab(), _buildAuditoriaInteligenteTab() ])), 
    const SizedBox(height: 24),
    _buildToolsSection(isLocked: false), // Herramientas desbloqueadas
  ]);

  // --- PESTAÑAS DE RESULTADOS ---
  Widget _buildLiquidacionTab() => ListView(children: [
    _buildSectionCard('Datos Principales', [_buildInfoRow('Empresa', _reciboModel!.cabecera.empresaNombre ?? ''), _buildInfoRow('Empleado', _reciboModel!.cabecera.empleadoNombre ?? '')]),
    if (_reciboModel!.liquidacionDetallada.haberes.isNotEmpty) _buildSectionCard('Ingresos', _reciboModel!.liquidacionDetallada.haberes.map((h) => _buildConceptoRow(h.descripcion, h.monto, Colors.green)).toList()),
    if (_reciboModel!.liquidacionDetallada.retenciones.isNotEmpty) _buildSectionCard('Descuentos', _reciboModel!.liquidacionDetallada.retenciones.map((r) => _buildConceptoRow(r.descripcion, -r.monto, Colors.red)).toList()),
    Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: _buildTotalRow('NETO A COBRAR', _reciboModel!.totales.netoACobrar, isBold: true)),
    const SizedBox(height: 20),ElevatedButton.icon(icon: const Icon(Icons.refresh), label: const Text('Escanear Otro Recibo'), onPressed: () => setState(() { _reciboModel = null; })),
  ]);

  Widget _buildAuditoriaInteligenteTab() => ListView(children: [
    _buildAcademyCtaCard(),
    const SizedBox(height: 16),
    _buildWidgetTuSueldoEnPerspectiva(),
    _buildWidgetDescubriTusDerechos(),
  ]);
  
  // --- HELPERS Y WIDGETS GENÉRICOS ---

  void _showScanFirstDialog() => showDialog(context: context, builder: (context) => AlertDialog(title: const Text('¡Primero escanea un recibo!'), content: const Text('Sube una foto de tu recibo para activar las calculadoras.'), actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Entendido'))]));

  void _showCalculatorPopup({required String title, required Widget content, required String whatsappContext}) => showDialog(context: context, builder: (context) => AlertDialog(
    title: Text(title), 
    content: SingleChildScrollView(child: content), 
    actions: [
      TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cerrar')), 
      ElevatedButton.icon(icon: const Icon(Icons.school_outlined, size: 18), label: const Text('Asesoría Experta'), onPressed: () => _launchWhatsApp(contextMessage: whatsappContext)),
    ],
  ));

  Widget _buildDisclaimer(String text) => Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(8)), child: Text(text, style: TextStyle(color: Colors.amber.shade900, fontSize: 12)));
  Widget _buildCalcRow(String label, double value, {bool isCurrency = true}) => Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label), Text(isCurrency ? currencyFormat.format(value) : value.toStringAsFixed(0), style: const TextStyle(fontWeight: FontWeight.bold))]));
  Widget _buildCalcResult(String label, double value) => Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), Text(currencyFormat.format(value), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.primary))]));
  Widget _buildLoadingState() => const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [CircularProgressIndicator(), SizedBox(height: 20), Text('Tu asesor IA está trabajando...', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600))]));
  Widget _buildSectionCard(String title, List<Widget> children) => Card(elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), child: Padding(padding: const EdgeInsets.all(16.0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)), const Divider(height: 20), ...children])));
  Widget _buildInfoRow(String label, String value) => Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(children: [Expanded(flex: 2, child: Text(label, style: TextStyle(color: Theme.of(context).hintColor))), Expanded(flex: 3, child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500)))]));
  Widget _buildConceptoRow(String d, double m, Color c) => Padding(padding: const EdgeInsets.symmetric(vertical: 2.0), child: Row(children: [Expanded(child: Text(d)), Text(r'$' + m.abs().toStringAsFixed(2), style: TextStyle(fontWeight: FontWeight.bold, color: c))]));
  Widget _buildTotalRow(String l, double a, {bool isBold = false}) => Padding(padding: const EdgeInsets.symmetric(vertical: 2.0), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(l, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal, fontSize: 16)), Text(r'$' + a.toStringAsFixed(2), style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal, fontSize: 16))]));
  Widget _buildAcademyCtaCard() => Card(elevation: 4, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), color: AppColors.backgroundDark, child: Padding(padding: const EdgeInsets.all(20.0), child: Column(children: [
      const Text('Elevar Formación Técnica', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white), textAlign: TextAlign.center),
      const SizedBox(height: 12),
      const Text('Domina la liquidación de sueldos con nuestra Certificación Nacional Habilitante.', style: TextStyle(fontSize: 15, color: Colors.white70), textAlign: TextAlign.center),
      const SizedBox(height: 20),
      ElevatedButton.icon(onPressed: () => _launchWhatsApp(), icon: const Icon(Icons.chat, color: Colors.white), label: const Text('CONSULTAR AHORA', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)))),
    ])));
  Widget _buildWidgetTuSueldoEnPerspectiva() => _buildSectionCard('Tu Sueldo en Perspectiva', [Text.rich(TextSpan(children: [const TextSpan(text: 'Analizamos la distribución de tu sueldo. '), WidgetSpan(child: GestureDetector(onTap: () => _launchWhatsApp(contextMessage: 'Hola, quiero entender la diferencia entre sueldo bruto y neto.'), child: const Text('🎓 Aprende más aquí.', style: TextStyle(color: AppColors.accentBlue, fontWeight: FontWeight.bold))))]))]);
  Widget _buildWidgetDescubriTusDerechos() => _buildSectionCard('💡 Oportunidades de tu Convenio', [Text.rich(TextSpan(children: [const TextSpan(text: 'Buscamos adicionales que podrías estar omitiendo. '), WidgetSpan(child: GestureDetector(onTap: () => _launchWhatsApp(contextMessage: 'Hola, ¿cómo sé qué adicionales de mi convenio me corresponden?'), child: const Text('🎓 Reclama lo que es tuyo.', style: TextStyle(color: AppColors.accentBlue, fontWeight: FontWeight.bold))))]))]);
}
