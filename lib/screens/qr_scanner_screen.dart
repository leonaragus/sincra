
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../theme/app_colors.dart';
import '../services/web_auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  final MobileScannerController _scannerController = MobileScannerController();
  final _webAuthService = WebAuthService();
  bool _isProcessing = false;

  Future<void> _handleScan(String code) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      final session = Supabase.instance.client.auth.currentSession;
      
      if (user != null && session != null) {
        // Usamos el refreshToken para el handshake ya que es más estable para sesiones web
        final tokenToWeb = session.refreshToken ?? session.accessToken;
        
        // USAR EL NUEVO MÉTODO CON HANDSHAKE (ACK)
        await _webAuthService.sendTokenToChannelWithAck(
          channelId: code,
          token: tokenToWeb,
        );
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('¡Sincronización exitosa!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleManualSync() async {
    _cleanupWebAuth(); // Limpiamos cualquier escucha previa
    
    try {
      setState(() => _isProcessing = true);
      
      final code = await _webAuthService.listenForManualCodeRequest(
        onTokenSent: () {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('¡PC vinculada con éxito!'),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.of(context).pop();
          }
        },
      );

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Código de Vinculación'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Escribí este código en la Web:'),
                const SizedBox(height: 20),
                Text(
                  code,
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 8,
                    color: AppColors.accentBlue,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Mantené esta pantalla abierta hasta que la PC se sincronice.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  _webAuthService.dispose();
                  Navigator.pop(context);
                },
                child: const Text('CANCELAR'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al generar código: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _cleanupWebAuth() {
    _webAuthService.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sincronizar con Web'),
        backgroundColor: AppColors.background,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          MobileScanner(
            controller: _scannerController,
            errorBuilder: (context, error, _) {
              final String errorMessage;
              switch (error.errorCode) {
                case MobileScannerErrorCode.permissionDenied:
                  errorMessage = 'Permiso de cámara denegado.';
                  break;
                case MobileScannerErrorCode.unsupported:
                  errorMessage = 'Escaneo no soportado en este dispositivo.';
                  break;
                default:
                  errorMessage = 'Error al iniciar la cámara.';
                  break;
              }

              return Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  margin: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.redAccent),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
                      const SizedBox(height: 16),
                      Text(
                        errorMessage,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Asegúrate de haber concedido los permisos de cámara en los ajustes del sistema.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              );
            },
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              debugPrint('QR Detectado: ${barcodes.length} códigos');
              if (barcodes.isNotEmpty) {
                final String? code = barcodes.first.rawValue;
                debugPrint('Contenido QR: $code');
                if (code != null && mounted) {
                  _handleScan(code);
                }
              }
            },
          ),
          // Overlay con el recuadro
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.accentBlue, width: 3),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.accentBlue.withOpacity(0.5)),
                    boxShadow: [
                      const BoxShadow(
                        color: Colors.black26,
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Text(
                        '1. Ingresá en tu PC a:',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'sincra.web.app',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.accentBlue, 
                          fontSize: 22, 
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        '2. Escaneá el QR o generá un código',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      const SizedBox(height: 20),
                      if (_isProcessing)
                        const CircularProgressIndicator(color: AppColors.accentBlue)
                      else
                        ElevatedButton.icon(
                          onPressed: _handleManualSync,
                          icon: const Icon(Icons.vpn_key),
                          label: const Text('GENERAR CÓDIGO PARA PC'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accentBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _scannerController.dispose();
    _cleanupWebAuth();
    super.dispose();
  }
}
