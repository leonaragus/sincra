import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_colors.dart';
import './plan_selection_screen.dart';

/// Pantalla de acceso para la versión Web: Email/Password o Código de Vinculación.
class WebLoginScreen extends StatefulWidget {
  final String? selectedPlan;
  
  const WebLoginScreen({super.key, this.selectedPlan});

  @override
  State<WebLoginScreen> createState() => _WebLoginScreenState();
}

class _WebLoginScreenState extends State<WebLoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _codigo = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _modoCodigo = false;

  Future<void> _ingresarEmail() async {
    setState(() { _error = null; _loading = true; });
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _email.text.trim(),
        password: _password.text,
      );
      if (mounted) setState(() => _loading = false);
    } on AuthException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = 'Error de conexión'; _loading = false; });
    }
  }

  void _ingresarCodigo() {
    // Próximamente: validar código de vinculación (estilo WhatsApp)
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Código de vinculación: próximamente. Usá Email/Contraseña.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isFreePlan = widget.selectedPlan == 'free' || widget.selectedPlan == null;
    
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
                    // Botón para volver a selección de planes
                    if (widget.selectedPlan != null)
                      Align(
                        alignment: Alignment.topLeft,
                        child: TextButton.icon(
                          icon: const Icon(Icons.arrow_back, size: 16),
                          onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const PlanSelectionScreen())),
                          label: const Text('Cambiar plan'),
                          style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
                        ),
                      ),
                    
                    Text('Syncra Arg', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                    const SizedBox(height: 8),
                    Text('La evolución digital de la nómina argentina', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                    
                    // Mensaje destacado sobre primer mes gratis
                    if (!isFreePlan)
                      Container(
                        margin: const EdgeInsets.only(top: 24),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.star, color: Colors.green, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                '¡PRIMER MES GRATIS! - 30 días de prueba completa',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    
                    // Mensaje para verificador gratis
                    if (isFreePlan)
                      Container(
                        margin: const EdgeInsets.only(top: 24),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.verified, color: AppColors.primary, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Verificador de recibos - Siempre gratuito',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    
                    const SizedBox(height: 24),
                    if (_modoCodigo) ...[
                      TextField(controller: _codigo, decoration: const InputDecoration(labelText: 'Código de vinculación', border: OutlineInputBorder()), keyboardType: TextInputType.number, maxLength: 8),
                      const SizedBox(height: 16),
                      SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _loading ? null : _ingresarCodigo, child: const Text('Vincular dispositivo'))),
                    ] else ...[
                      TextField(controller: _email, decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()), keyboardType: TextInputType.emailAddress, textInputAction: TextInputAction.next),
                      const SizedBox(height: 12),
                      TextField(controller: _password, decoration: const InputDecoration(labelText: 'Contraseña', border: OutlineInputBorder()), obscureText: true, textInputAction: TextInputAction.done, onSubmitted: (_) => _ingresarEmail()),
                      if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12))),
                      const SizedBox(height: 16),
                      SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _loading ? null : _ingresarEmail, child: _loading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Iniciar sesión'))),
                      
                      // Botón temporal para testing - BORRAR DESPUÉS
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: _loading ? null : () {
                            // Saltear autenticación e ir directo al HomeScreen
                            Navigator.pushReplacementNamed(context, '/home');
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.orange,
                            side: const BorderSide(color: Colors.orange),
                          ),
                          child: const Text('🔧 MODO PRUEBA - Cargar credenciales'),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    TextButton(onPressed: () => setState(() { _modoCodigo = !_modoCodigo; _error = null; }), child: Text(_modoCodigo ? 'Usar Email / Contraseña' : 'Vincular con código')),
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
    if (_logueado == false) return const PlanSelectionScreen();
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
