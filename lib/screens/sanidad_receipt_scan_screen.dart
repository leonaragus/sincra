// SanidadReceiptScanScreen - Entrada: QR (mobile_scanner) o imagen (OCR).
// On-Device: ML Kit OCR + prioridad QR JSON > QR URL > OCR.
// OCR y QR solo en Android/iOS; en Windows/desktop se muestra aviso.

// import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
// import 'package:mobile_scanner/mobile_scanner.dart'; // Comentado para compatibilidad web
import '../services/sanidad_receipt_scan_service.dart';
import '../theme/app_colors.dart';
import 'sanidad_ocr_review_screen.dart';

class SanidadReceiptScanScreen extends StatefulWidget {
  const SanidadReceiptScanScreen({super.key});

  @override
  State<SanidadReceiptScanScreen> createState() => _SanidadReceiptScanScreenState();
}

class _SanidadReceiptScanScreenState extends State<SanidadReceiptScanScreen> {
  final SanidadReceiptScanService _svc = SanidadReceiptScanService();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _svc.close();
    super.dispose();
  }

  void _goToReview(SanidadOcrExtractResult result) {
    if (!mounted) return;
    setState(() { _loading = false; _error = null; });
    Navigator.push(
      context,
      MaterialPageRoute(builder: (ctx) => SanidadOcrReviewScreen(extract: result)),
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
      
      // Usamos XFile directo para compatibilidad Web
      final result = await _svc.runOcrFromXFile(f);
      
      if (result.hasError) {
        // Truncar error si es muy largo
        String errorMsg = result.error!;
        if (errorMsg.length > 200) {
          errorMsg = '${errorMsg.substring(0, 200)}...';
        }
        _showError(errorMsg);
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
          onResult: (SanidadOcrExtractResult? r) {
            if (r != null) _goToReview(r);
          },
          onFallbackToOcr: () {
            _pickAndOcr(ImageSource.camera);
          },
        ),
      ),
    );
  }

  /// OCR (ML Kit) y QR (mobile_scanner) solo tienen implementación nativa en Android e iOS.
  /// En Windows/macOS/Linux se evita invocar los plugins para no generar MissingPluginException.
  /// ACTUALIZACIÓN: Ahora usamos Claude Vision (Cloud) para OCR, por lo que Web es compatible.
  static bool get _isScanSupported => true;

  @override
  Widget build(BuildContext context) {
    if (!_isScanSupported) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary), onPressed: () => Navigator.pop(context)),
          title: const Text('Escanear Recibo FATSA', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
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
        title: const Text('Escanear Recibo FATSA', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
      ),
      body: Center(
        child: _loading
            ? const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppColors.pastelMint),
                  SizedBox(height: 16),
                  Text('Procesando imagen con IA...', style: TextStyle(color: AppColors.textSecondary)),
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
                          Icon(Icons.receipt_long, size: 48, color: AppColors.pastelMint),
                          const SizedBox(height: 16),
                          const Text('Escaneo Inteligente FATSA', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                          const Text('Procesamiento con IA (OCR + QR)', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
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

/*
  Widget _buildDesktopWarning() {
    return Container(
      margin: const EdgeInsets.all(40),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.glassFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade600),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.warning_amber, size: 60, color: Colors.orange.shade400),
          const SizedBox(height: 20),
          Text(
            kIsWeb ? 'Escaneo no disponible en Web' : 'Escaneo no disponible en Windows/Desktop',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            kIsWeb 
              ? 'El escaneo de recibos (OCR y códigos QR) no está disponible en la versión Web por limitaciones técnicas.'
              : 'El escaneo de recibos (OCR y códigos QR) está disponible solo en Android e iOS.',
            style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Complete los datos manualmente o use la aplicación móvil.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back),
            label: const Text('Volver'),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileOptions() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.glassFill,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Icon(Icons.qr_code_scanner, size: 60, color: AppColors.pastelMint),
                const SizedBox(height: 16),
                const Text(
                  'Escaneo automático de recibos',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Extrae automáticamente CUIL, sueldo básico, categoría, antigüedad y más.',
                  style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Procesamiento 100% en el dispositivo (OCR + QR)',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          if (_loading)
            const Column(
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Procesando imagen...', style: TextStyle(color: Colors.white70)),
              ],
            )
          else ...[
            _Bot(label: 'Escanear código QR', icon: Icons.qr_code_scanner, onTap: _openQrScanner),
            const SizedBox(height: 16),
            _Bot(label: 'Tomar foto', icon: Icons.camera_alt, onTap: () => _pickAndOcr(ImageSource.camera)),
            const SizedBox(height: 16),
            _Bot(label: 'Elegir de galería', icon: Icons.photo_library, onTap: () => _pickAndOcr(ImageSource.gallery)),
          ],
          if (_error != null) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red),
              ),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          ],
        ],
      ),
    );
  }
*/
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
            Icon(icon, color: AppColors.pastelMint, size: 28),
            const SizedBox(width: 16),
            Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          ]),
        ),
      ),
    );
  }
}

class _QrScannerPage extends StatefulWidget {
  final void Function(SanidadOcrExtractResult?) onResult;
  final VoidCallback onFallbackToOcr;

  const _QrScannerPage({required this.onResult, required this.onFallbackToOcr});

  @override
  State<_QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<_QrScannerPage> {
  /*
  void _onDetect(BarcodeCapture capture) {
    final raw = _svc.getQrRawFromBarcode(capture);
    if (raw == null) return;
    
    final parsed = _svc.tryParseQr(raw);
    if (parsed != null) {
      if (parsed.source == OcrExtractSourceSanidad.qrUrl && parsed.cuil == null && parsed.sueldoBasico == null) {
        if (!mounted) return;
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Se encontró: $raw. Puede usar OCR sobre una foto del recibo para extraer datos.'),
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Tomar foto para OCR',
              onPressed: () { 
                Navigator.pop(context); 
                widget.onFallbackToOcr(); 
              },
            ),
          ),
        );
        return;
      }
      Navigator.pop(context);
      widget.onResult(parsed);
    }
  }
  */

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Escanear QR', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black87,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: const Center(
        child: Text(
          'El escaneo QR no está disponible en esta plataforma.',
          style: TextStyle(color: Colors.white),
        ),
      ),
      /*
      body: Stack(
        children: [
          MobileScanner(
            onDetect: _onDetect,
          ),
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Apunte al código QR del recibo FATSA',
                style: TextStyle(color: Colors.white, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
      */
    );
  }
}
