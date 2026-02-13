import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/web_link_service.dart';
import '../theme/app_colors.dart';

class WebLinkDialog extends StatefulWidget {
  const WebLinkDialog({super.key});

  @override
  State<WebLinkDialog> createState() => _WebLinkDialogState();
}

class _WebLinkDialogState extends State<WebLinkDialog> {
  bool _scanning = false;
  final _controller = TextEditingController();
  List<Map<String, dynamic>> _activeSessions = [];
  bool _loadingSessions = true;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    final sessions = await WebLinkService.getActiveWebSessions();
    if (mounted) {
      setState(() {
        _activeSessions = sessions;
        _loadingSessions = false;
      });
    }
  }

  Future<void> _logoutSession(String sessionId) async {
    await WebLinkService.logoutWebSession(sessionId);
    _loadSessions();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      final code = barcode.rawValue;
      if (code != null && code.startsWith('syncra:link:')) {
        final sessionId = code.replaceFirst('syncra:link:', '');
        setState(() => _scanning = false);
        _linkSession(sessionId);
        break;
      }
    }
  }

  Future<void> _linkSession(String sessionId) async {
    try {
      await WebLinkService.linkSessionFromApp(sessionId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Sesión vinculada con éxito!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al vincular: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Vincular Web'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_scanning)
                SizedBox(
                  height: 300,
                  child: MobileScanner(
                    onDetect: _onDetect,
                  ),
                )
              else ...[
                const Text(
                  'Escaneá el código QR que aparece en la versión Web para ingresar.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Ingresá desde tu PC a:',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 4),
                      const SelectableText(
                        'https://sincra.web.app',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () => setState(() => _scanning = true),
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Escanear Código QR'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              const Text(
                'O configurá tu clave de acceso rápido:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _controller,
                decoration: const InputDecoration(
                  labelText: 'Clave personalizada',
                  border: OutlineInputBorder(),
                  hintText: 'Ej: vanesa2025',
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () async {
                      if (_controller.text.isNotEmpty) {
                        try {
                          await WebLinkService.updateCustomKey(_controller.text.trim());
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Clave personalizada actualizada')),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error al actualizar clave: $e')),
                            );
                          }
                        }
                      }
                    },
                    child: const Text('Guardar Clave'),
                  ),
                ),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),
                const Text(
                  'Sesiones Web Activas',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                if (_loadingSessions)
                  const CircularProgressIndicator()
                else if (_activeSessions.isEmpty)
                  const Text('No hay sesiones activas', style: TextStyle(fontSize: 12, color: AppColors.textSecondary))
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _activeSessions.length,
                    itemBuilder: (context, index) {
                      final session = _activeSessions[index];
                      return ListTile(
                        leading: const Icon(Icons.laptop),
                        title: Text(session['device_info'] ?? 'Web Browser'),
                        subtitle: Text('Vinculado: ${session['linked_at']?.toString().split('T')[0] ?? ''}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.logout, color: Colors.red),
                          onPressed: () => _logoutSession(session['id']),
                          tooltip: 'Cerrar sesión remota',
                        ),
                      );
                    },
                  ),
              ],
            ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }
}

