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
  static const String _pendingSyncKey = 'ausencias_pending_sync';
  
  /// Obtiene ausencias de un empleado
  static Future<List<Ausencia>> obtenerAusenciasPorEmpleado(
    String cuil, {
    String? empresaCuit,
    int? mes,
    int? anio,
  }) async {
    try {
      // Intentar desde Supabase primero
      final connectivity = await Connectivity().checkConnectivity();
      final isOnline = connectivity.isNotEmpty && connectivity.first != ConnectivityResult.none;
      
      if (isOnline) {
        var query = Supabase.instance.client
            .from('ausencias')
            .select()
            .eq('empleado_cuil', cuil);
        
        if (empresaCuit != null) {
          query = query.eq('empresa_cuit', empresaCuit);
        }
        
        final res = await query;
        final ausencias = (res as List).map((m) => Ausencia.fromMap(m)).toList();
        
        // Guardar en cache
        await _guardarEnCache(cuil, ausencias);
        
        // Filtrar por período si aplica
        if (mes != null && anio != null) {
          return ausencias.where((a) => a.estaEnPeriodo(mes, anio)).toList();
        }
        
        return ausencias;
      }
    } catch (e) {
      print('Error obteniendo ausencias desde Supabase: $e');
    }
    
    // Fallback: cargar desde cache local
    final ausencias = await _cargarDesdeCache(cuil);
    
    if (mes != null && anio != null) {
      return ausencias.where((a) => a.estaEnPeriodo(mes, anio)).toList();
    }
    
    return ausencias;
  }
  
  /// Guarda una ausencia (local + sync)
  static Future<void> guardarAusencia(Ausencia ausencia) async {
    // Guardar en cache local
    await _agregarACache(ausencia);
    
    // Intentar sincronizar con Supabase
    final connectivity = await Connectivity().checkConnectivity();
    final isOnline = connectivity.isNotEmpty && connectivity.first != ConnectivityResult.none;
    
    if (isOnline) {
      try {
        await Supabase.instance.client
            .from('ausencias')
            .upsert(ausencia.toMap());
      } catch (e) {
        print('Error guardando ausencia en Supabase: $e');
        await _marcarPendienteSync(ausencia.id);
      }
    } else {
      await _marcarPendienteSync(ausencia.id);
    }
  }
  
  /// Actualiza estado de ausencia (aprobar/rechazar)
  static Future<void> actualizarEstadoAusencia(
    String ausenciaId,
    EstadoAusencia nuevoEstado, {
    String? aprobadoPor,
  }) async {
    final connectivity = await Connectivity().checkConnectivity();
    final isOnline = connectivity.isNotEmpty && connectivity.first != ConnectivityResult.none;
    
    if (isOnline) {
      try {
        await Supabase.instance.client
            .from('ausencias')
            .update({
              'estado': nuevoEstado.name,
              'aprobado_por': aprobadoPor,
              'fecha_aprobacion': DateTime.now().toIso8601String(),
            })
            .eq('id', ausenciaId);
      } catch (e) {
        print('Error actualizando estado de ausencia: $e');
      }
    }
  }
  
  /// Obtiene ausencias pendientes de aprobación
  static Future<List<Ausencia>> obtenerAusenciasPendientes({String? empresaCuit}) async {
    try {
      final connectivity = await Connectivity().checkConnectivity();
      final isOnline = connectivity.isNotEmpty && connectivity.first != ConnectivityResult.none;
      
      if (isOnline) {
        var query = Supabase.instance.client
            .from('ausencias')
            .select()
            .eq('estado', 'pendiente');
        
        if (empresaCuit != null) {
          query = query.eq('empresa_cuit', empresaCuit);
        }
        
        final res = await query;
        return (res as List).map((m) => Ausencia.fromMap(m)).toList();
      }
    } catch (e) {
      print('Error obteniendo ausencias pendientes: $e');
    }
    
    return [];
  }
  
  /// Sincroniza ausencias pendientes
  static Future<void> sincronizarPendientes() async {
    final prefs = await SharedPreferences.getInstance();
    final pendientes = prefs.getStringList(_pendingSyncKey) ?? [];
    
    if (pendientes.isEmpty) return;
    
    final connectivity = await Connectivity().checkConnectivity();
    final isOnline = connectivity.isNotEmpty && connectivity.first != ConnectivityResult.none;
    
    if (!isOnline) return;
    
    // Sincronizar cada ausencia pendiente
    for (final _ in pendientes) {
      // Buscar en cache y sincronizar
      // (implementación completa requeriría reconstruir la ausencia)
    }
  }
  
  // Métodos privados de cache
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
  }
  
  static Future<void> _marcarPendienteSync(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final pendientes = prefs.getStringList(_pendingSyncKey) ?? [];
    if (!pendientes.contains(id)) {
      pendientes.add(id);
      await prefs.setStringList(_pendingSyncKey, pendientes);
    }
  }
}
