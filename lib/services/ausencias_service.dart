
// ========================================================================
// SERVICIO DE AUSENCIAS
// CRUD de ausencias con sincronización híbrida
// ========================================================================

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:convert';
import '../models/ausencia.dart';

class AusenciasService {
  static const String _cacheKeyPrefix = 'ausencias_';
  static const String _empresaCacheKeyPrefix = 'ausencias_empresa_';
  static const String _pendingSyncKey = 'ausencias_pending_sync';

  // **NUEVO MÉTODO OPTIMIZADO**
  /// Obtiene TODAS las ausencias de una empresa en una única consulta.
  static Future<List<Ausencia>> obtenerAusenciasPorEmpresa({
    required String empresaCuit,
  }) async {
    try {
      final connectivity = await Connectivity().checkConnectivity();
      final isOnline = connectivity.isNotEmpty && connectivity.first != ConnectivityResult.none;

      if (isOnline) {
        final res = await Supabase.instance.client
            .from('ausencias')
            .select()
            .eq('empresa_cuit', empresaCuit);

        final ausencias = (res as List).map((m) => Ausencia.fromMap(m)).toList();
        
        // Guardar en la nueva caché de empresa
        await _guardarEnCacheEmpresa(empresaCuit, ausencias);
        
        return ausencias;
      }
    } catch (e) {
      print('Error obteniendo ausencias de la empresa desde Supabase: $e');
    }

    // Fallback: cargar desde la caché de empresa si no hay conexión
    return await _cargarDesdeCacheEmpresa(empresaCuit);
  }
  
  // --- MÉTODOS ANTERIORES (se mantienen por ahora) ---

  /// Obtiene ausencias de un empleado (método antiguo, menos eficiente para UI masivas)
  static Future<List<Ausencia>> obtenerAusenciasPorEmpleado(
    String cuil, {
    String? empresaCuit,
    int? mes,
    int? anio,
  }) async {
    // ... (la implementación original se mantiene sin cambios)
    try {
      final connectivity = await Connectivity().checkConnectivity();
      final isOnline = connectivity.isNotEmpty && connectivity.first != ConnectivityResult.none;
      if (isOnline) {
        var query = Supabase.instance.client.from('ausencias').select().eq('empleado_cuil', cuil);
        if (empresaCuit != null) {
          query = query.eq('empresa_cuit', empresaCuit);
        }
        final res = await query;
        final ausencias = (res as List).map((m) => Ausencia.fromMap(m)).toList();
        await _guardarEnCache(cuil, ausencias);
        if (mes != null && anio != null) {
          return ausencias.where((a) => a.estaEnPeriodo(mes, anio)).toList();
        }
        return ausencias;
      }
    } catch (e) {
      print('Error obteniendo ausencias desde Supabase: $e');
    }
    final ausencias = await _cargarDesdeCache(cuil);
    if (mes != null && anio != null) {
      return ausencias.where((a) => a.estaEnPeriodo(mes, anio)).toList();
    }
    return ausencias;
  }
  
  static Future<void> guardarAusencia(Ausencia ausencia) async {
    // ... (la implementación original se mantiene sin cambios)
     await _agregarACache(ausencia);
    final connectivity = await Connectivity().checkConnectivity();
    final isOnline = connectivity.isNotEmpty && connectivity.first != ConnectivityResult.none;
    if (isOnline) {
      try {
        await Supabase.instance.client.from('ausencias').upsert(ausencia.toMap());
      } catch (e) {
        print('Error guardando ausencia en Supabase: $e');
        await _marcarPendienteSync(ausencia.id);
      }
    } else {
      await _marcarPendienteSync(ausencia.id);
    }
  }
  
  static Future<void> actualizarEstadoAusencia(
    String ausenciaId,
    EstadoAusencia nuevoEstado, {
    String? aprobadoPor,
  }) async {
    // ... (la implementación original se mantiene sin cambios)
    final connectivity = await Connectivity().checkConnectivity();
    final isOnline = connectivity.isNotEmpty && connectivity.first != ConnectivityResult.none;
    if (isOnline) {
      try {
        await Supabase.instance.client.from('ausencias').update({
          'estado': nuevoEstado.name,
          'aprobado_por': aprobadoPor,
          'fecha_aprobacion': DateTime.now().toIso8601String(),
        }).eq('id', ausenciaId);
      } catch (e) {
        print('Error actualizando estado de ausencia: $e');
      }
    }
  }

  // --- MÉTODOS PRIVADOS DE CACHE ---

  // **NUEVOS MÉTODOS DE CACHE POR EMPRESA**
  static Future<void> _guardarEnCacheEmpresa(String empresaCuit, List<Ausencia> ausencias) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_empresaCacheKeyPrefix$empresaCuit';
    final json = jsonEncode(ausencias.map((a) => a.toMap()).toList());
    await prefs.setString(key, json);
  }

  static Future<List<Ausencia>> _cargarDesdeCacheEmpresa(String empresaCuit) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_empresaCacheKeyPrefix$empresaCuit';
    final json = prefs.getString(key);
    if (json == null) return [];
    final list = jsonDecode(json) as List;
    return list.map((m) => Ausencia.fromMap(m)).toList();
  }

  // Métodos de cache originales (por empleado)
  static Future<void> _guardarEnCache(String cuil, List<Ausencia> ausencias) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_cacheKeyPrefix$cuil';
    final json = jsonEncode(ausencias.map((a) => a.toMap()).toList());
    await prefs.setString(key, json);
  }
  
  static Future<List<Ausencia>> _cargarDesdeCache(String cuil) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_cacheKeyPrefix$cuil';
    final json = prefs.getString(key);
    if (json == null) return [];
    final list = jsonDecode(json) as List;
    return list.map((m) => Ausencia.fromMap(m)).toList();
  }
  
  static Future<void> _agregarACache(Ausencia ausencia) async {
    final ausencias = await _cargarDesdeCache(ausencia.empleadoCuil);
    ausencias.removeWhere((a) => a.id == ausencia.id);
    ausencias.add(ausencia);
    await _guardarEnCache(ausencia.empleadoCuil, ausencias);
    
    // **AÑADIDO**: Actualizar también la caché de empresa si existe
    final prefs = await SharedPreferences.getInstance();
    final empresaKey = '$_empresaCacheKeyPrefix${ausencia.empresaCuit}';
    if (prefs.containsKey(empresaKey)) {
        final empresaAusencias = await _cargarDesdeCacheEmpresa(ausencia.empresaCuit);
        empresaAusencias.removeWhere((a) => a.id == ausencia.id);
        empresaAusencias.add(ausencia);
        await _guardarEnCacheEmpresa(ausencia.empresaCuit, empresaAusencias);
    }
  }

  static Future<void> _marcarPendienteSync(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final pendientes = prefs.getStringList(_pendingSyncKey) ?? [];
    if (!pendientes.contains(id)) {
      pendientes.add(id);
      await prefs.setStringList(_pendingSyncKey, pendientes);
    }
  }
  
  // ... (otros métodos como sincronizarPendientes se mantienen igual)
}
