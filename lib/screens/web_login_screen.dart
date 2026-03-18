
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:uuid/uuid.dart';

import '../services/web_auth_service.dart';
import '../theme/app_colors.dart';

import 'package:shared_preferences/shared_preferences.dart';

// Variable global para un bypass de administrador, mantenida por simplicidad.
bool isAdminBypass = false;

/// Carga el estado del bypass desde el almacenamiento local.
Future<void> loadAdminBypass() async {
  final prefs = await SharedPreferences.getInstance();
  isAdminBypass = prefs.getBool('is_admin_bypass') ?? false;
}

/// Guarda el estado del bypass en el almacenamiento local.
Future<void> setAdminBypass(bool value) async {
  isAdminBypass = value;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('is_admin_bypass', value);
}

class WebLoginScreen extends StatefulWidget {
  const WebLoginScreen({super.key});

  @override
  State<WebLoginScreen> createState() => _WebLoginScreenState();
}

class _WebLoginScreenState extends State<WebLoginScreen> {
  final _codigoController = TextEditingController();
  final _webAuthService = WebAuthService();
  
  bool _isLoading = false;
  String _channelId = 'Cargando...';

  @override
  void initState() {
    super.initState();
    // Solo inicializar la lógica de login web si la plataforma es web.
    if (kIsWeb) {
      _initializeQRChannel();
    }
  }

  void _initializeQRChannel() {
    // 1. Generar un ID único para el canal del QR.
    final newChannelId = const Uuid().v4();
    setState(() {
      _channelId = newChannelId;
    });

    // 2. Usar el servicio para escuchar el token de sesión.
    final channel = Supabase.instance.client.channel('web-login-$newChannelId');
    
    channel.onBroadcast(
      event: 'session-token',
      callback: (payload) async {
        final String? receivedToken = payload['token'];
        if (receivedToken != null) {
          // ENVIAR ACK DE REGRESO AL MÓVIL
          await channel.send(
            type: 'broadcast' as dynamic,
            event: 'session-received',
            payload: {},
          );
          _loginWithToken(receivedToken, 'QR');
        }
      },
    ).subscribe();
  }

  Future<void> _loginWithToken(String refreshToken, String method) async {
    if (!mounted) return; // Comprobación de seguridad.
    setState(() => _isLoading = true);
    
    try {
      final response = await Supabase.instance.client.auth.setSession(refreshToken);
      if (response.session != null && mounted) {
        // Navegación exitosa, el WebAuthGate se encargará de mostrar la pantalla de Home.
        Navigator.of(context).pushReplacementNamed('/home');
      } else {
        throw Exception('La sesión recibida no es válida.');
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Error de vinculación ($method): ${e.toString()}');
        setState(() => _isLoading = false);
      }
    }
  }

  void _handleCodeSubmission() {
    final codigoIngresado = _codigoController.text.trim();
    
    // Lógica para el bypass de administrador
    if (codigoIngresado.toLowerCase() == 'vanesa2025') {
      setState(() => _isLoading = true);
      _bypassAdminLogin();
      return;
    }

    // Lógica para el código manual de 6 dígitos
    if (codigoIngresado.length == 6 && int.tryParse(codigoIngresado) != null) {
       _loginWithManualCode(codigoIngresado);
       return;
    }

    _showErrorSnackBar('El código ingresado no es válido.');
  }

  void _loginWithManualCode(String code) {
    if (!mounted) return;
    setState(() => _isLoading = true);

    _webAuthService.requestTokenWithManualCode(
      code: code,
      onTokenReceived: (token) {
        _loginWithToken(token, 'Código Manual');
      },
      onTimeout: () {
        if (mounted && _isLoading) {
          setState(() => _isLoading = false);
          _showErrorSnackBar('El código expiró o no es válido.');
        }
      },
    );
  }

  // Realiza un login anónimo para el modo administrador.
  Future<void> _bypassAdminLogin() async {
    // 1. Forzar el bypass global INMEDIATAMENTE para asegurar la navegación.
    isAdminBypass = true;
    
    try {
      // 2. Intentar el login anónimo en segundo plano pero no bloquear si falla.
      await Supabase.instance.client.auth.signInAnonymously();
    } catch (e) {
      debugPrint('Bypass Admin: Login anónimo falló (esperado), continuando...');
    } finally {
      // 3. Navegar si el widget sigue montado.
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/home');
      }
    }
  }
  
  void _showErrorSnackBar(String message) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
      );
  }

  @override
  void dispose() {
    _codigoController.dispose();
    _webAuthService.dispose(); // Limpia el servicio para evitar memory leaks.
    super.dispose();
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
                    _buildLoginCard(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassBorder),
        boxShadow: [ BoxShadow( color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4), ), ],
      ),
      child: Column(
        children: [
          const Text('Escaneá para ingresar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text( 'Abrí la App Móvil > Menú > Escanear QR', style: TextStyle(fontSize: 14, color: AppColors.textSecondary), ),
          const SizedBox(height: 20),
          _buildQrCode(),
          const SizedBox(height: 24),
          _buildDivider(),
          const SizedBox(height: 24),
          _buildManualCodeInput(),
          const SizedBox(height: 16),
          _buildSubmitButton(),
        ],
      ),
    );
  }

  Widget _buildQrCode() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: _channelId == 'Cargando...'
          ? const SizedBox( width: 200.0, height: 200.0, child: Center(child: CircularProgressIndicator()), )
          : QrImageView(
              data: _channelId,
              version: QrVersions.auto,
              size: 200.0,
              backgroundColor: Colors.white,
            ),
    );
  }

  Widget _buildDivider() {
    return const Row(
      children: [
        Expanded(child: Divider()),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text('O ingresá manualmente', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        ),
        Expanded(child: Divider()),
      ],
    );
  }

  Widget _buildManualCodeInput() {
    return TextField(
      controller: _codigoController,
      decoration: InputDecoration(
        labelText: 'Código de acceso o admin',
        hintText: 'Ej: 123456 o clave admin',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        prefixIcon: const Icon(Icons.vpn_key_outlined),
      ),
      onSubmitted: (_) => _handleCodeSubmission(),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleCodeSubmission,
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
        child: _isLoading 
          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
          : const Text('Ingresar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }
}


// --- WebAuthGate --- //

/// Un widget que actúa como "portero" para las rutas web.
///
/// Redirige a la pantalla de login si el usuario no está autenticado en la web,
/// o muestra el contenido de la aplicación si sí lo está.
class WebAuthGate extends StatefulWidget {
  final Widget child;
  const WebAuthGate({super.key, required this.child});

  @override
  State<WebAuthGate> createState() => _WebAuthGateState();
}

class _WebAuthGateState extends State<WebAuthGate> {
  StreamSubscription<AuthState>? _authSubscription;
  bool? _isLoggedIn;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      // En plataformas no web, siempre se considera "logueado" para este gate.
      _isLoggedIn = true;
      return;
    }
    
    // Comprueba el estado inicial y escucha los cambios.
    _isLoggedIn = Supabase.instance.client.auth.currentSession != null;
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (mounted) {
        setState(() {
          _isLoggedIn = data.session != null;
        });
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb || _isLoggedIn == true) {
      return widget.child;
    }
    if (_isLoggedIn == false) {
      return const WebLoginScreen();
    }
    // Muestra un loader mientras se determina el estado de autenticación.
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
