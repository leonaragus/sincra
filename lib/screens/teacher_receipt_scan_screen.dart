// TeacherReceiptScanScreen - Entrada: QR (mobile_scanner) o imagen (OCR).
// On-Device: ML Kit OCR + prioridad QR JSON > QR URL > OCR. Loading y manejo de imagen borrosa.
// OCR y QR solo en Android/iOS; en Windows/desktop se muestra aviso (evita MissingPluginException).

import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/teacher_receipt_scan_service.dart';
import '../theme/app_colors.dart';
import 'ocr_review_screen.dart';

class TeacherReceiptScanScreen extends StatefulWidget {
  const TeacherReceiptScanScreen({super.key});

  @override
  State<TeacherReceiptScanScreen> createState() => _TeacherReceiptScanScreenState();
}

class _TeacherReceiptScanScreenState extends State<TeacherReceiptScanScreen> {
  final TeacherReceiptScanService _svc = TeacherReceiptScanService();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _svc.close();
    super.dispose();
  }

  void _goToReview(OcrExtractResult result) {
    if (!mounted) return;
    setState(() { _loading = false; _error = null; });
    Navigator.push(
      context,
      MaterialPageRoute(builder: (ctx) => OcrReviewScreen(extract: result)),
    ).then((value) {
      if (value != null && mounted) Navigator.pop(context, value);
    });
  }

  void _showError(String msg) {
    if (!mounted) return;
    setState(() { _loading = false; _error = msg; });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red.shade700,
        action: SnackBarAction(label: 'Reintentar', onPressed: () => setState(() => _error = null)),
      ),
    );
  }

  Future<void> _pickAndOcr(ImageSource source) async {
    setState(() { _loading = true; _error = null; });
    try {
      final picker = ImagePicker();
      final XFile? f = await picker.pickImage(source: source, imageQuality: 90);
      if (f == null || !mounted) {
        setState(() => _loading = false);
        return;
      }
      final path = f.path;
      if (path.isEmpty) {
        _showError('No se pudo obtener la imagen.');
        return;
      }
      final result = await _svc.runOcrFromPath(path);
      if (result.hasError) {
        _showError(result.error ?? 'No se pudo leer. Complete los datos a mano o escanee una foto con mejor resolución.');
        return;
      }
      _goToReview(result);
    } catch (e) {
      _showError('Error: $e. Complete los datos a mano o escanee una foto con mejor resolución.');
    }
  }

  void _openQrScanner() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => _QrScannerPage(
          onResult: (OcrExtractResult? r) {
            if (r != null) {
              Navigator.pop(ctx);
              _goToReview(r);
            }
          },
          onFallbackToOcr: () {
            Navigator.pop(ctx);
            _pickAndOcr(ImageSource.camera);
          },
        ),
      ),
    );
  }

  /// OCR (ML Kit) y QR (mobile_scanner) solo tienen implementación nativa en Android e iOS.
  /// En Windows/macOS/Linux se evita invocar los plugins para no generar MissingPluginException.
  static bool get _isScanSupported => Platform.isAndroid || Platform.isIOS;

  @override
  Widget build(BuildContext context) {
    if (!_isScanSupported) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary), onPressed: () => Navigator.pop(context)),
          title: const Text('Escanear recibo docente', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.phonelink_off, size: 56, color: AppColors.textMuted),
                const SizedBox(height: 16),
                Text(
                  'El escaneo de recibos (OCR y códigos QR) está disponible solo en Android e iOS.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, color: AppColors.textSecondary, height: 1.35),
                ),
                const SizedBox(height: 8),
                Text(
                  'En Windows puede cargar datos manualmente o usar la app en un celular.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: AppColors.textMuted, height: 1.35),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary), onPressed: () => Navigator.pop(context)),
        title: const Text('Escanear recibo docente', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
      ),
      body: Center(
        child: _loading
            ? const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppColors.pastelBlue),
                  SizedBox(height: 16),
                  Text('Procesando imagen…', style: TextStyle(color: AppColors.textSecondary)),
                ],
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.red.shade900.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(12)),
                          child: Row(children: [
                            Icon(Icons.error_outline, color: Colors.red.shade300),
                            const SizedBox(width: 12),
                            Expanded(child: Text(_error!, style: const TextStyle(color: AppColors.textPrimary))),
                          ]),
                        ),
                      ),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(color: AppColors.glassFillStrong, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.glassBorder)),
                      child: Column(
                        children: [
                          const Text('Procesamiento 100% en el dispositivo (OCR + QR)', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          const SizedBox(height: 20),
                          _Bot(label: 'Escanear código QR', icon: Icons.qr_code_scanner, onTap: _openQrScanner),
                          const SizedBox(height: 12),
                          _Bot(label: 'Tomar foto', icon: Icons.camera_alt, onTap: () => _pickAndOcr(ImageSource.camera)),
                          const SizedBox(height: 12),
                          _Bot(label: 'Elegir de galería', icon: Icons.photo_library, onTap: () => _pickAndOcr(ImageSource.gallery)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _Bot extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _Bot({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.glassFill,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          child: Row(children: [
            Icon(icon, color: AppColors.pastelBlue, size: 28),
            const SizedBox(width: 16),
            Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          ]),
        ),
      ),
    );
  }
}

class _QrScannerPage extends StatefulWidget {
  final void Function(OcrExtractResult?) onResult;
  final VoidCallback onFallbackToOcr;

  const _QrScannerPage({required this.onResult, required this.onFallbackToOcr});

  @override
  State<_QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<_QrScannerPage> {
  final TeacherReceiptScanService _svc = TeacherReceiptScanService();
  bool _processing = false;

  void _onDetect(BarcodeCapture capture) {
    if (_processing) return;
    final raw = _svc.getQrRawFromBarcode(capture);
    if (raw == null || raw.isEmpty) return;
    _processing = true;
    final parsed = _svc.tryParseQr(raw);
    if (parsed != null) {
      if (parsed.source == OcrExtractSource.qrUrl && parsed.cuil == null && parsed.sueldoBasico == null) {
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('URL detectada'),
            content: Text('Se encontró: $raw. Puede usar OCR sobre una foto del recibo para extraer datos.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cerrar')),
              FilledButton(onPressed: () { Navigator.pop(c); widget.onFallbackToOcr(); }, child: const Text('Tomar foto para OCR')),
            ],
          ),
        ).then((_) => _processing = false);
      } else {
        widget.onResult(parsed);
      }
    } else {
      _processing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Escanear QR', style: TextStyle(color: Colors.white)),
        leading: IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context)),
      ),
      body: MobileScanner(
        onDetect: _onDetect,
        controller: MobileScannerController(
          detectionSpeed: DetectionSpeed.normal,
          facing: CameraFacing.back,
          torchEnabled: false,
        ),
      ),
    );
  }
}
