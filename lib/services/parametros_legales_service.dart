import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/arca_lsd_config.dart';
import '../models/parametros_legales.dart';
import 'hybrid_store.dart';
import 'auditoria_service.dart';

/// Servicio para gestionar parámetros legales y paritarias docentes
/// Permite guardar, cargar y actualizar parámetros legales desde SharedPreferences y Supabase
class ParametrosLegalesService {
  static const String _keyParametrosLegales = 'parametros_legales_vigentes';
  static const String _keyVersion = 'parametros_legales_version';
  static const String _keyUltimaSincronizacion = 'ultima_sincronizacion_paritarias';

  /// Sincroniza las paritarias desde Supabase a local
  static Future<Map<String, dynamic>> sincronizarParitarias() async {
    final connectivity = await Connectivity().checkConnectivity();
    final isOnline = connectivity.isNotEmpty && connectivity.first != ConnectivityResult.none;
    
    DateTime? ultimaFecha;
    final prefs = await SharedPreferences.getInstance();
    final lastSyncStr = prefs.getString(_keyUltimaSincronizacion);
    if (lastSyncStr != null) ultimaFecha = DateTime.tryParse(lastSyncStr);

    if (!isOnline) {
      return {
        'success': false,
        'fecha': ultimaFecha,
        'modo': 'offline',
      };
    }

    try {
      final res = await Supabase.instance.client
          .from('maestro_paritarias')
          .select();
      
      final list = res as List;
      if (list.isNotEmpty) {
        await HybridStore.saveMaestroParitarias(list.cast<Map<String, dynamic>>());
        final ahora = DateTime.now();
        await prefs.setString(_keyUltimaSincronizacion, ahora.toIso8601String());
        return {
          'success': true,
          'fecha': ahora,
          'modo': 'online',
        };
      }
    } catch (e) {
      print('Error sincronizando paritarias: $e');
    }

    return {
      'success': false,
      'fecha': ultimaFecha,
      'modo': 'error',
    };
  }

  /// Carga los parámetros legales desde el almacenamiento local
  /// Si no existen, retorna los valores por defecto para Q1 2026
  static Future<ParametrosLegales> cargarParametros() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_keyParametrosLegales);
      
      if (jsonString == null || jsonString.isEmpty) {
        // Si no hay parámetros guardados, retornar valores por defecto
        final defaultParams = ParametrosLegales.defaultQ12026();
        // Guardar valores por defecto para futuras cargas
        await guardarParametros(defaultParams);
        return defaultParams;
      }
      
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return ParametrosLegales.fromJson(json);
    } catch (e) {
      // En caso de error, retornar valores por defecto
      return ParametrosLegales.defaultQ12026();
    }
  }

  /// Guarda los parámetros legales en el almacenamiento local
  static Future<bool> guardarParametros(ParametrosLegales parametros) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(parametros.toJson());
      await prefs.setString(_keyParametrosLegales, jsonString);
      await prefs.setString(_keyVersion, DateTime.now().toIso8601String());
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Actualiza los parámetros legales con nuevos valores
  /// Mantiene las fechas de vigencia si no se especifican
  static Future<bool> actualizarParametros({
    double? baseImponibleMaxima,
    double? baseImponibleMinima,
    double? smvm,
    double? asignacionHijo,
    double? topeMovilidadF931,
    DateTime? vigenciaDesde,
    DateTime? vigenciaHasta,
    String? usuarioActualizacion,
  }) async {
    try {
      final parametrosActuales = await cargarParametros();
      
      final parametrosActualizados = parametrosActuales.copyWith(
        baseImponibleMaxima: baseImponibleMaxima,
        baseImponibleMinima: baseImponibleMinima,
        smvm: smvm,
        asignacionHijo: asignacionHijo,
        topeMovilidadF931: topeMovilidadF931,
        vigenciaDesde: vigenciaDesde,
        vigenciaHasta: vigenciaHasta,
        usuarioActualizacion: usuarioActualizacion,
      );
      
      return await guardarParametros(parametrosActualizados);
    } catch (e) {
      return false;
    }
  }

  /// Obtiene la fecha de última actualización
  static Future<DateTime?> obtenerFechaUltimaActualizacion() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final versionString = prefs.getString(_keyVersion);
      if (versionString == null) return null;
      return DateTime.tryParse(versionString);
    } catch (e) {
      return null;
    }
  }

  /// Resetea los parámetros a los valores por defecto de Q1 2026
  static Future<bool> resetearAPorDefecto() async {
    try {
      final defaultParams = ParametrosLegales.defaultQ12026();
      return await guardarParametros(defaultParams);
    } catch (e) {
      return false;
    }
  }

  /// Verifica si existen parámetros guardados
  static Future<bool> existenParametrosGuardados() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.containsKey(_keyParametrosLegales);
    } catch (e) {
      return false;
    }
  }

  /// Actualiza una paritaria provincial SOLO localmente (sin afectar a otros usuarios)
  static Future<void> actualizarParitariaProvincial(String jurisdiccion, Map<String, dynamic> data) async {
    // 1. Obtener las paritarias actuales del cache
    final list = await HybridStore.getMaestroParitarias();
    
    // 2. Obtener valores anteriores para auditoría
    final valoresAnteriores = list.firstWhere(
      (p) => p['jurisdiccion'] == jurisdiccion,
      orElse: () => <String, dynamic>{},
    );
    
    // 3. Buscar y actualizar la jurisdicción
    final newList = list.map((p) {
      if (p['jurisdiccion'] == jurisdiccion) {
        return { ...p, ...data, 'updated_at': DateTime.now().toIso8601String() };
      }
      return p;
    }).toList();
    
    // 4. AUDITORÍA: Registrar el cambio
    await AuditoriaService.registrarCambio(
      modulo: 'docentes',
      accion: 'modificar_paritaria',
      entidad: 'Paritaria Docentes $jurisdiccion',
      valoresAnteriores: valoresAnteriores,
      valoresNuevos: data,
      observaciones: 'Modificación de paritaria provincial',
    );

    // 5. Guardar en HybridStore (SharedPreferences local)
    await HybridStore.saveMaestroParitarias(newList.cast<Map<String, dynamic>>());
    
    // 6. Actualizar también el cache de ParitariasService si existe
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('maestro_paritarias_cache', jsonEncode(newList));
    } catch (e) {
      print('Error actualizando cache secundario: $e');
    }
  }
}
