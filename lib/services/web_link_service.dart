import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';
import 'dart:async';

class WebLinkService {
  static const String _localBypassKey = 'web_link_bypass';
  static bool _bypassAuth = false;

  static bool get isBypassed => _bypassAuth;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _bypassAuth = prefs.getBool(_localBypassKey) ?? false;
  }

  static Future<void> setBypass(bool value) async {
    _bypassAuth = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_localBypassKey, value);
  }

  /// Genera un ID de sesión para la vinculación web.
  static String generateSessionId() {
    final rnd = Random();
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return String.fromCharCodes(Iterable.generate(
        16, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));
  }

  /// Crea una sesión de vinculación en Supabase (versión Web).
  static Future<void> createWebSession(String sessionId) async {
    try {
      await Supabase.instance.client.from('web_sessions').upsert({
        'id': sessionId,
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Error creating web session: $e. Asegúrate de que la tabla web_sessions existe.');
    }
  }

  /// Escucha cambios en una sesión específica (versión Web).
  static Stream<Map<String, dynamic>> listenToSession(String sessionId) {
    return Supabase.instance.client
        .from('web_sessions')
        .stream(primaryKey: ['id'])
        .eq('id', sessionId)
        .map((event) => event.first);
  }

  /// Vincula una sesión desde la App.
  static Future<void> linkSessionFromApp(String sessionId) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) throw Exception('Usuario no autenticado en la App');

    final session = Supabase.instance.client.auth.currentSession;
    
    // Obtenemos info del dispositivo si fuera posible, por ahora genérico
    final deviceInfo = 'Web Browser'; 

    await Supabase.instance.client.from('web_sessions').update({
      'status': 'linked',
      'user_id': user.id,
      'device_info': deviceInfo,
      'access_token': session?.accessToken,
      'refresh_token': session?.refreshToken,
      'linked_at': DateTime.now().toIso8601String(),
    }).eq('id', sessionId);
  }

  /// Obtiene sesiones web activas para el usuario actual.
  static Future<List<Map<String, dynamic>>> getActiveWebSessions() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return [];

    try {
      final res = await Supabase.instance.client
          .from('web_sessions')
          .select()
          .eq('user_id', user.id)
          .eq('status', 'linked');
      return List<Map<String, dynamic>>.from(res);
    } catch (_) {
      return [];
    }
  }

  /// Cierra una sesión web desde la App.
  static Future<void> logoutWebSession(String sessionId) async {
    await Supabase.instance.client.from('web_sessions').update({
      'status': 'logged_out',
      'logged_out_at': DateTime.now().toIso8601String(),
    }).eq('id', sessionId);
  }

  /// Valida un código de vinculación o la clave maestra.
  static Future<bool> validateCode(String code) async {
    // Si es la clave maestra "vanesa2025", siempre es válida.
    if (code == 'vanesa2025') return true;

    // Si no, buscamos en la base de datos de perfiles de usuario
    try {
      // En la web, como no estamos logueados, necesitamos buscar por la clave
      // Esto asume que la tabla 'user_profiles' tiene una columna 'custom_web_key'
      final res = await Supabase.instance.client
          .from('user_profiles')
          .select('id')
          .eq('custom_web_key', code)
          .maybeSingle();
      
      return res != null;
    } catch (_) {
      return false;
    }
  }

  /// Actualiza la clave personalizada del usuario actual.
  static Future<void> updateCustomKey(String newKey) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    await Supabase.instance.client.from('user_profiles').upsert({
      'id': user.id,
      'custom_web_key': newKey,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  /// Valida la clave maestra "vanesa2025"
  static bool validateMasterKey(String key) {
    return key == 'vanesa2025';
  }
}
