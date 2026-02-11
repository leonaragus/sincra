
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Servicio para mantener actualizadas las reglas de validación LSD desde la nube (Supabase).
/// Permite hot-updates de topes, códigos de error y parámetros sin recompilar la app.
class ValidadorLSDUpdateService {
  static const String _tableName = 'lsd_rules_config';
  static const String _prefsKey = 'lsd_rules_config';

  static Future<void> checkForUpdates() async {
    try {
      // Consultar la última configuración activa en Supabase
      final response = await Supabase.instance.client
          .from(_tableName)
          .select()
          .eq('active', true)
          .order('version', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response != null) {
        final remoteConfig = response['config_json'] as Map<String, dynamic>;
        final remoteVersion = response['version'] as int;
        
        final prefs = await SharedPreferences.getInstance();
        final localConfigStr = prefs.getString(_prefsKey);
        
        bool shouldUpdate = false;
        if (localConfigStr == null) {
          shouldUpdate = true;
        } else {
          final localConfig = jsonDecode(localConfigStr);
          final localVersion = localConfig['version'] as int;
          
          if (remoteVersion > localVersion) {
            shouldUpdate = true;
          }
        }

        if (shouldUpdate) {
          // Guardamos el JSON de configuración localmente
          await prefs.setString(_prefsKey, jsonEncode(remoteConfig));
          print('LSD Rules updated to version $remoteVersion');
        }
      }
    } catch (e) {
      print('Error checking LSD updates: $e');
    }
  }

  static Future<Map<String, dynamic>> getActiveRules() async {
    final prefs = await SharedPreferences.getInstance();
    final configStr = prefs.getString(_prefsKey);
    if (configStr != null) {
      return jsonDecode(configStr);
    }
    // Default fallback rules
    return {
      "version": 1,
      "topes": { "min": 0, "max": 99999999 },
      "reglas_activas": ["all"]
    };
  }
}
