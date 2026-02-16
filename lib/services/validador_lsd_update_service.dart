
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Servicio para mantener actualizadas las reglas de validación LSD desde la nube (Supabase).
/// Permite hot-updates de topes, códigos de error y parámetros sin recompilar la app.
class ValidadorLSDUpdateService {
  static const String _tableName = 'lsd_rules_config';
  static const String _prefsKey = 'lsd_rules_config';

  static Future<bool> checkForUpdates() async {
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
        final remoteVersion = (response['version'] ?? 0) as int;
        final updatedAt = (response['updated_at'] ?? DateTime.now().toIso8601String()).toString();
        final mensaje = (response['mensaje'] ?? 'Reglas actualizadas') as String;
        final rawConfig = response['config_json'];
        final remoteConfigJson = rawConfig is Map 
            ? Map<String, dynamic>.from(rawConfig as Map) 
            : (rawConfig is String ? jsonDecode(rawConfig) as Map<String, dynamic> : <String, dynamic>{});
        final mergedConfig = <String, dynamic>{
          'version': remoteVersion,
          'ultima_sincro': updatedAt,
          'mensaje': mensaje,
          ...remoteConfigJson,
        };
        
        final prefs = await SharedPreferences.getInstance();
        final localConfigStr = prefs.getString(_prefsKey);
        
        bool shouldUpdate = false;
        if (localConfigStr == null) {
          shouldUpdate = true;
        } else {
          final localConfig = jsonDecode(localConfigStr) as Map<String, dynamic>;
          final localVersion = (localConfig['version'] ?? 0) as int;
          
          if (remoteVersion > localVersion) {
            shouldUpdate = true;
          }
        }

        if (shouldUpdate) {
          // Guardamos el JSON de configuración localmente
          await prefs.setString(_prefsKey, jsonEncode(mergedConfig));
          print('LSD Rules updated to version $remoteVersion');
          return true; // Hubo actualización
        }
          // Refrescar fecha de sync para UI aunque no haya nueva versión
          final localConfig = jsonDecode(localConfigStr!) as Map<String, dynamic>;
          localConfig['ultima_sincro'] = updatedAt;
          localConfig['mensaje'] = mensaje;
          await prefs.setString(_prefsKey, jsonEncode(localConfig));
      }
    } catch (e) {
      print('Error checking LSD updates: $e');
    }
    return false; // No hubo cambios o hubo error
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
      "reglas_activas": ["all"],
      "ultima_sincro": DateTime.now().toIso8601String(),
      "mensaje": "Reglas por defecto"
}
  }
}
