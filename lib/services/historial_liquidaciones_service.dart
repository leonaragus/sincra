// ========================================================================
// SERVICIO DE HISTORIAL DE LIQUIDACIONES
// Registro y consulta del historial completo de liquidaciones
// ========================================================================

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:convert';
import '../models/historial_liquidacion.dart';

class HistorialLiquidacionesService {
  static const String _cacheKeyPrefix = 'historial_liq_';
  
  /// Registra una liquidación en el historial
  static Future<void> registrarLiquidacion(HistorialLiquidacion liquidacion) async {
    // Guardar en cache local
    await _agregarACache(liquidacion);
    
    // Intentar guardar en Supabase
    final connectivity = await Connectivity().checkConnectivity();
    final isOnline = connectivity.isNotEmpty && connectivity.first != ConnectivityResult.none;
    
    if (isOnline) {
      try {
        await Supabase.instance.client
            .from('historial_liquidaciones')
            .upsert(liquidacion.toMap());
      } catch (e) {
        print('Error guardando historial en Supabase: $e');
      }
    }
  }
  
  /// Registra múltiples liquidaciones (liquidación masiva)
  static Future<void> registrarLiquidacionesMasivas(
    List<HistorialLiquidacion> liquidaciones,
  ) async {
    if (liquidaciones.isEmpty) return;
    
    // Guardar en cache local
    for (final liq in liquidaciones) {
      await _agregarACache(liq);
    }
    
    // Intentar guardar en Supabase
    final connectivity = await Connectivity().checkConnectivity();
    final isOnline = connectivity.isNotEmpty && connectivity.first != ConnectivityResult.none;
    
    if (isOnline) {
      try {
        // Insertar en lotes de 100
        for (int i = 0; i < liquidaciones.length; i += 100) {
          final lote = liquidaciones.skip(i).take(100).toList();
          await Supabase.instance.client
              .from('historial_liquidaciones')
              .upsert(lote.map((l) => l.toMap()).toList());
        }
      } catch (e) {
        print('Error guardando historial masivo en Supabase: $e');
      }
    }
  }
  
  /// Obtiene el historial completo de un empleado
  static Future<List<HistorialLiquidacion>> obtenerHistorialEmpleado(
    String cuil, {
    int? anio,
    int? mes,
    int? limit,
  }) async {
    try {
      final connectivity = await Connectivity().checkConnectivity();
      final isOnline = connectivity.isNotEmpty && connectivity.first != ConnectivityResult.none;
      
      if (isOnline) {
        dynamic query = Supabase.instance.client
            .from('historial_liquidaciones')
            .select()
            .eq('empleado_cuil', cuil);
        
        if (anio != null) {
          query = query.eq('anio', anio);
        }
        
        if (mes != null) {
          query = query.eq('mes', mes);
        }
        
        query = query.order('anio', ascending: false)
                     .order('mes', ascending: false);
        
        if (limit != null) {
          query = query.limit(limit);
        }
        
        final res = await query;
        final historial = (res as List).map((m) => HistorialLiquidacion.fromMap(m)).toList();
        
        // Guardar en cache
        await _guardarEnCache(cuil, historial);
        
        return historial;
      }
    } catch (e) {
      print('Error obteniendo historial desde Supabase: $e');
    }
    
    // Fallback: cache local
    return await _cargarDesdeCache(cuil);
  }
  
  /// Obtiene la mejor remuneración de los últimos 6 meses (para indemnizaciones)
  /// 
  /// Base legal: Art. 245 LCT - Para el cálculo de la indemnización por despido
  /// se toma la mejor remuneración normal y habitual percibida durante el último año
  /// o durante el tiempo de prestación de servicios si fuera menor.
  static Future<double?> obtenerMejorRemuneracionUltimos6Meses(String cuil) async {
    try {
      final connectivity = await Connectivity().checkConnectivity();
      final isOnline = connectivity.isNotEmpty && connectivity.first != ConnectivityResult.none;
      
      if (isOnline) {
        // Usar función SQL que ya creamos
        final res = await Supabase.instance.client.rpc(
          'calcular_mejor_remuneracion_6meses',
          params: {'p_empleado_cuil': cuil},
        );
        
        return (res as num?)?.toDouble();
      }
    } catch (e) {
      print('Error calculando mejor remuneración: $e');
    }
    
    // Fallback: calcular localmente
    final historial = await obtenerHistorialEmpleado(cuil, limit: 6);
    if (historial.isEmpty) return null;
    
    // Considerar solo liquidaciones mensuales (no SAC, ni vacaciones, ni final)
    final mensuales = historial.where((h) => h.tipo == 'mensual').toList();
    if (mensuales.isEmpty) return null;
    
    // Retornar el máximo bruto remunerativo
    return mensuales
        .map((h) => h.totalBrutoRemunerativo)
        .reduce((a, b) => a > b ? a : b);
  }
  
  /// Obtiene estadísticas del historial de un empleado
  static Future<EstadisticasHistorialEmpleado> obtenerEstadisticasEmpleado(
    String cuil,
  ) async {
    final historial = await obtenerHistorialEmpleado(cuil);
    
    if (historial.isEmpty) {
      return EstadisticasHistorialEmpleado(
        empleadoCuil: cuil,
        cantidadLiquidaciones: 0,
        promedioNeto: 0.0,
        promedioAportes: 0.0,
        maximoNeto: 0.0,
        minimoNeto: 0.0,
        ultimas6Liquidaciones: [],
      );
    }
    
    final mensuales = historial.where((h) => h.tipo == 'mensual').toList();
    
    final promedioNeto = mensuales.isEmpty
        ? 0.0
        : mensuales.map((h) => h.netoACobrar).reduce((a, b) => a + b) / mensuales.length;
    
    final promedioAportes = mensuales.isEmpty
        ? 0.0
        : mensuales.map((h) => h.totalAportes).reduce((a, b) => a + b) / mensuales.length;
    
    final maximoNeto = mensuales.isEmpty
        ? 0.0
        : mensuales.map((h) => h.netoACobrar).reduce((a, b) => a > b ? a : b);
    
    final minimoNeto = mensuales.isEmpty
        ? 0.0
        : mensuales.map((h) => h.netoACobrar).reduce((a, b) => a < b ? a : b);
    
    final mejorRemuneracion = await obtenerMejorRemuneracionUltimos6Meses(cuil);
    
    return EstadisticasHistorialEmpleado(
      empleadoCuil: cuil,
      cantidadLiquidaciones: historial.length,
      promedioNeto: promedioNeto,
      promedioAportes: promedioAportes,
      maximoNeto: maximoNeto,
      minimoNeto: minimoNeto,
      mejorRemuneracionUltimos6Meses: mejorRemuneracion,
      ultimas6Liquidaciones: historial.take(6).toList(),
    );
  }
  
  /// Detecta variaciones inusuales entre liquidaciones consecutivas
  static Future<List<String>> detectarVariacionesInusuales(String cuil) async {
    final historial = await obtenerHistorialEmpleado(cuil, limit: 12);
    
    if (historial.length < 2) return [];
    
    final alertas = <String>[];
    
    // Comparar liquidaciones consecutivas
    for (int i = 0; i < historial.length - 1; i++) {
      final actual = historial[i];
      final anterior = historial[i + 1];
      
      // Solo comparar liquidaciones mensuales
      if (actual.tipo != 'mensual' || anterior.tipo != 'mensual') continue;
      
      // Calcular variación porcentual
      final variacion = ((actual.netoACobrar - anterior.netoACobrar) / anterior.netoACobrar) * 100;
      
      // Si la variación es mayor al 30%, alertar
      if (variacion.abs() > 30.0) {
        alertas.add(
          'Variación inusual de ${variacion.toStringAsFixed(1)}% entre ${anterior.periodo} '
          '(\$${anterior.netoACobrar.toStringAsFixed(0)}) y ${actual.periodo} '
          '(\$${actual.netoACobrar.toStringAsFixed(0)}).'
        );
      }
    }
    
    return alertas;
  }
  
  // Métodos privados de cache
  static Future<void> _guardarEnCache(String cuil, List<HistorialLiquidacion> historial) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_cacheKeyPrefix$cuil';
    final json = jsonEncode(historial.map((h) => h.toMap()).toList());
    await prefs.setString(key, json);
  }
  
  static Future<List<HistorialLiquidacion>> _cargarDesdeCache(String cuil) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_cacheKeyPrefix$cuil';
    final json = prefs.getString(key);
    
    if (json == null) return [];
    
    final list = jsonDecode(json) as List;
    return list.map((m) => HistorialLiquidacion.fromMap(m)).toList();
  }
  
  static Future<void> _agregarACache(HistorialLiquidacion liquidacion) async {
    final historial = await _cargarDesdeCache(liquidacion.empleadoCuil);
    historial.removeWhere((h) => h.id == liquidacion.id);
    historial.insert(0, liquidacion);
    await _guardarEnCache(liquidacion.empleadoCuil, historial);
  }
}
