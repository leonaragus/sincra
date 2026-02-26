import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cross_file/cross_file.dart';
import '../services/empresa_receipt_scan_service.dart';
import '../theme/app_colors.dart';

class EmpresaReceiptScanScreen extends StatefulWidget {
  const EmpresaReceiptScanScreen({super.key});

  @override
  State<EmpresaReceiptScanScreen> createState() => _EmpresaReceiptScanScreenState();
}

class _EmpresaReceiptScanScreenState extends State<EmpresaReceiptScanScreen> {
  final EmpresaReceiptScanService _svc = EmpresaReceiptScanService();
  bool _loading = false;
  String? _error;

  void _finish(EmpresaExtractResult result) {
    if (!mounted) return;
    Navigator.pop(context, result);
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
      if (f == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }
      
      final result = await _svc.runOcrFromXFile(f);
      
      if (result.hasError) {
        _showError(result.error ?? 'No se pudieron extraer datos de la empresa.');
        return;
      }
      
      _finish(result);
    } catch (e) {
      _showError('Error: $e. Intente nuevamente.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary), 
          onPressed: () => Navigator.pop(context)
        ),
        title: const Text('Escanear Datos de Empresa', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
        actions: [
          AppHelp.buildHelpButton(context, () {
            final helpContent = AppHelp.getHelpContent('EmpresaReceiptScanScreen');
            AppHelp.showHelpDialog(context, helpContent['title'], helpContent['content']);
          }),
        ],
      ),
      body: Center(
        child: _loading
            ? const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppColors.pastelBlue),
                  SizedBox(height: 16),
                  Text('Procesando recibo...', style: TextStyle(color: AppColors.textSecondary)),
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
                      decoration: BoxDecoration(
                        color: AppColors.glassFillStrong, 
                        borderRadius: BorderRadius.circular(20), 
                        border: Border.all(color: AppColors.glassBorder)
                      ),
                      child: Column(
                        children: [
                          const Text('Escanee un recibo para extraer los datos de la empresa', 
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 14, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
                          const SizedBox(height: 24),
                          _Bot(label: 'Tomar foto', icon: Icons.camera_alt, onTap: () => _pickAndOcr(ImageSource.camera)),
                          const SizedBox(height: 16),
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
