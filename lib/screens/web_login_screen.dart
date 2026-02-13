import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import './plan_selection_screen.dart';

class WebLoginScreen extends StatefulWidget {
  final String? selectedPlan;
  
  const WebLoginScreen({super.key, this.selectedPlan});

  @override
  State<WebLoginScreen> createState() => _WebLoginScreenState();
}

class _WebLoginScreenState extends State<WebLoginScreen> {
  final _codigo = TextEditingController();
  bool _loading = false;
  String? _error;
  String _sessionId = '';

  @override
  void initState() {
    super.initState();
    _generateSessionId();
  }

  void _generateSessionId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = (1000 + (DateTime.now().microsecond % 9000));
    setState(() {
      _sessionId = 'syncra_qr_$timestamp$random';
    });
  }

  Future<void> _ingresarCodigo() async {
    if (_codigo.text.length < 6) {
      setState(() => _error = 'Ingresá los 6 dígitos de tu App');
      return;
    }
    setState(() { _error = null; _loading = true; });
    await Future.delayed(const Duration(milliseconds: 1500));
    if (mounted) {
      setState(() {
        _error = 'Clave expirada. Generá una nueva en la App.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Fondo con gradiente animado y formas decorativas
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF0D1B2A),
                  const Color(0xFF1B263B),
                  AppColors.primary.withValues(alpha: 0.8),
                ],
              ),
            ),
          ),
          
          // Círculos decorativos para el efecto Glass
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blue.withValues(alpha: 0.1),
              ),
            ),
          ),
          
          Positioned(
            bottom: -50,
            left: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.indigo.withValues(alpha: 0.1),
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(32),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(32),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                        ),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            bool isWide = constraints.maxWidth > 700;
                            return Row(
                              children: [
                                if (isWide) _buildInfoSide(),
                                Expanded(child: _buildLoginSide()),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSide() {
    return Container(
      width: 400,
      padding: const EdgeInsets.all(48),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        border: Border(right: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.bolt, color: Colors.amber, size: 48),
          const SizedBox(height: 24),
          Text(
            'Syncra\nArg Web',
            style: GoogleFonts.poppins(
              fontSize: 40,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'La evolución digital de la nómina argentina, ahora en tu escritorio con máxima seguridad.',
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: Colors.white.withValues(alpha: 0.7),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 40),
          _buildFeatureItem(Icons.qr_code_scanner, 'Escaneo instantáneo'),
          _buildFeatureItem(Icons.security, 'Encriptación de grado militar'),
          _buildFeatureItem(Icons.phonelink_lock, 'Sin contraseñas'),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(icon, color: Colors.amber.withValues(alpha: 0.8), size: 20),
          const SizedBox(width: 12),
          Text(
            text,
            style: GoogleFonts.poppins(color: Colors.white.withValues(alpha: 0.9), fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginSide() {
    return Padding(
      padding: const EdgeInsets.all(48),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Iniciá sesión',
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Vinculá tu cuenta escaneando el código',
              style: GoogleFonts.poppins(fontSize: 14, color: Colors.white.withValues(alpha: 0.5)),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 40),
            
            // Contenedor del QR con diseño moderno
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 30,
                    offset: const Offset(0, 15),
                  ),
                ],
              ),
              child: QrImageView(
                data: _sessionId,
                version: QrVersions.auto,
                size: 180.0, // Reducido un poco para evitar overflow
                foregroundColor: const Color(0xFF0D1B2A),
                gapless: true,
              ),
            ),
            
            const SizedBox(height: 40),
            
            Row(
              children: [
                Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.1))),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text('o ingresá clave', style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 12)),
                ),
                Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.1))),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Input de clave refinado
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: TextField(
                controller: _codigo,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 20,
                  letterSpacing: 8,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
                maxLength: 6,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: '000000',
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.1)),
                  counterText: '',
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  prefixIcon: const Icon(Icons.key, color: Colors.amber, size: 18),
                  suffixIcon: IconButton(
                    onPressed: _loading ? null : _ingresarCodigo,
                    icon: _loading 
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.amber))
                      : const Icon(Icons.arrow_forward_rounded, color: Colors.amber),
                  ),
                ),
              ),
            ),
            
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                ),
              ),
            
            const SizedBox(height: 32),
            
            Text(
              '¿No tenés la App? Descargala en Play Store',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.4),
                decoration: TextDecoration.underline,
              ),
            ),
          ],
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
