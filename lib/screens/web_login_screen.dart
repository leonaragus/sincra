import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../theme/app_colors.dart';

/// Pantalla de acceso para la versión Web: Email/Password o Código de Vinculación.
class WebLoginScreen extends StatefulWidget {
  const WebLoginScreen({super.key});

  @override
  State<WebLoginScreen> createState() => _WebLoginScreenState();
}

class _WebLoginScreenState extends State<WebLoginScreen> {
  final _codigo = TextEditingController();
  bool _loading = false;

  void _ingresarCodigo() {
    final codigoIngresado = _codigo.text.trim();
    
    // Validación de código de administrador
    if (codigoIngresado.toLowerCase() == 'vanesa2025') {
      // Simular login exitoso para administrador
      setState(() => _loading = true);
      
      _bypassAdmin();
      return;
    }

    // Validación de código de app (simulado)
    if (codigoIngresado.length == 6 && int.tryParse(codigoIngresado) != null) {
       // Aquí iría la lógica para validar el código generado por la app móvil
       // Por ahora mostramos error
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Código de vinculación no reconocido o expirado.')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Código incorrecto. Intenta nuevamente.')),
    );
  }

  Future<void> _bypassAdmin() async {
    try {
      // Intentamos login anónimo para tener una sesión válida
      await Supabase.instance.client.auth.signInAnonymously();
      // Si el login es exitoso, navegamos al home
      if (mounted) {
         Navigator.of(context).pushReplacementNamed('/home');
      }
    } catch (e) {
      print('Error en login anónimo: $e');
      // Si falla (probablemente deshabilitado), forzamos la navegación
      // Esto es un parche temporal solicitado por el usuario
      if (mounted) {
         Navigator.of(context).pushReplacementNamed('/home');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(color: AppColors.background),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 450),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    
                    Text('Syncra Arg', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                    const SizedBox(height: 8),
                    Text('La evolución digital de la nómina argentina', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                    
                    const SizedBox(height: 24),
                    
                    // SECCIÓN CÓDIGO QR Y VINCULACIÓN
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.glassBorder),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'Escaneá para ingresar',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Abrí la App Móvil > Menú > Escanear QR',
                            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 20),
                          
                          // CÓDIGO QR
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: QrImageView(
                              data: 'SYNCRA_WEB_LOGIN_V1_${DateTime.now().millisecondsSinceEpoch}',
                              version: QrVersions.auto,
                              size: 200.0,
                              backgroundColor: Colors.white,
                            ),
                          ),
                          
                          const SizedBox(height: 24),
                          const Row(
                            children: [
                              Expanded(child: Divider()),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16),
                                child: Text('O ingresá manualmente', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                              ),
                              Expanded(child: Divider()),
                            ],
                          ),
                          const SizedBox(height: 24),
                          
                          TextField(
                            controller: _codigo,
                            decoration: InputDecoration(
                              labelText: 'Código de acceso o admin',
                              hintText: 'Ej: 123456 o clave admin',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              prefixIcon: const Icon(Icons.vpn_key_outlined),
                            ),
                            onSubmitted: (_) => _ingresarCodigo(),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _loading ? null : _ingresarCodigo,
                              style: ElevatedButton.styleFrom(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                              ),
                              child: _loading 
                                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                                : const Text('Ingresar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// En Web: muestra login si no hay sesión; en móvil/desktop va directo a [child].
class WebAuthGate extends StatefulWidget {
  final Widget child;

  const WebAuthGate({super.key, required this.child});

  @override
  State<WebAuthGate> createState() => _WebAuthGateState();
}

class _WebAuthGateState extends State<WebAuthGate> {
  bool? _logueado;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _logueado = true;
      return;
    }
    try {
      _check();
      Supabase.instance.client.auth.onAuthStateChange.listen((_) => _check());
    } catch (_) {
      _logueado = true;
    }
  }

  Future<void> _check() async {
    try {
      final s = Supabase.instance.client.auth.currentSession;
      if (mounted) setState(() => _logueado = s != null);
    } catch (_) {
      if (mounted) setState(() => _logueado = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb || _logueado == true) return widget.child;
    if (_logueado == false) return const WebLoginScreen();
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
