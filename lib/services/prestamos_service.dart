// ========================================================================
// SERVICIO DE PRÉSTAMOS
// CRUD de préstamos con generación automática de cuotas
// ========================================================================

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:convert';
import '../models/prestamo.dart';

class PrestamosService {
  static const String _cacheKeyPrefix = 'prestamos_';
  static const String _pendingSyncKey = 'prestamos_pending_sync';
  
  /// Crea un préstamo nuevo con cuotas
  static Future<Prestamo> crearPrestamo({
    required String empleadoCuil,
    required String empresaCuit,
    required double montoTotal,
    required int cantidadCuotas,
    double tasaInteres = 0.0,
    DateTime? fechaOtorgamiento,
    DateTime? fechaPrimeraCuota,
    String? motivoPrestamo,
    String? creadoPor,
  }) async {
    final valorCuota = Prestamo.calcularCuota(
      montoTotal: montoTotal,
      tasaInteres: tasaInteres,
      cantidadCuotas: cantidadCuotas,
    );
    
    final prestamo = Prestamo(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      empleadoCuil: empleadoCuil,
      empresaCuit: empresaCuit,
      montoTotal: montoTotal,
      tasaInteres: tasaInteres,
      cantidadCuotas: cantidadCuotas,
      valorCuota: valorCuota,
      fechaOtorgamiento: fechaOtorgamiento ?? DateTime.now(),
      fechaPrimeraCuota: fechaPrimeraCuota ?? DateTime.now(),
      motivoPrestamo: motivoPrestamo,
      creadoPor: creadoPor,
    );
    
    // Guardar préstamo
    await guardarPrestamo(prestamo);
    
    // Generar cuotas
    await _generarCuotas(prestamo);
    
    return prestamo;
  }
  
  /// Guarda un préstamo (local + sync)
  static Future<void> guardarPrestamo(Prestamo prestamo) async {
    // Guardar en cache local
    await _agregarACache(prestamo);
    
    // Intentar sincronizar con Supabase
    final connectivity = await Connectivity().checkConnectivity();
    final isOnline = connectivity.isNotEmpty && connectivity.first != ConnectivityResult.none;
    
    if (isOnline) {
      try {
        await Supabase.instance.client
            .from('prestamos')
            .upsert(prestamo.toMap());
      } catch (e) {
        print('Error guardando préstamo en Supabase: $e');
        await _marcarPendienteSync(prestamo.id);
      }
    } else {
      await _marcarPendienteSync(prestamo.id);
    }
  }
  
  /// Obtiene préstamos activos de un empleado
  static Future<List<Prestamo>> obtenerPrestamosPorEmpleado(
    String cuil, {
    String? empresaCuit,
    bool soloActivos = false,
  }) async {
    try {
      final connectivity = await Connectivity().checkConnectivity();
      final isOnline = connectivity.isNotEmpty && connectivity.first != ConnectivityResult.none;
      
      if (isOnline) {
        var query = Supabase.instance.client
            .from('prestamos')
            .select()
            .eq('empleado_cuil', cuil);
        
        if (empresaCuit != null) {
          query = query.eq('empresa_cuit', empresaCuit);
        }
        
        if (soloActivos) {
          query = query.eq('estado', 'activo');
        }
        
        final res = await query;
        final prestamos = (res as List).map((m) => Prestamo.fromMap(m)).toList();
        
        await _guardarEnCache(cuil, prestamos);
        
        return prestamos;
      }
    } catch (e) {
      print('Error obteniendo préstamos desde Supabase: $e');
    }
    
    // Fallback: cache local
    final prestamos = await _cargarDesdeCache(cuil);
    
    if (soloActivos) {
      return prestamos.where((p) => p.estado == EstadoPrestamo.activo).toList();
    }
    
    return prestamos;
  }
  
  /// Obtiene cuotas pendientes de un empleado para un período
  static Future<List<CuotaPrestamo>> obtenerCuotasPendientes(
    String cuil,
    int mes,
    int anio,
  ) async {
    try {
      final connectivity = await Connectivity().checkConnectivity();
      final isOnline = connectivity.isNotEmpty && connectivity.first != ConnectivityResult.none;
      
      if (isOnline) {
        final res = await Supabase.instance.client
            .from('prestamos_cuotas')
            .select()
            .eq('pagada', false)
            .lte('periodo_mes', mes)
            .lte('periodo_anio', anio);
        
        return (res as List).map((m) => CuotaPrestamo.fromMap(m)).toList();
      }
    } catch (e) {
      print('Error obteniendo cuotas: $e');
    }
    
    return [];
  }
  
  /// Registra una cuota como pagada
  static Future<void> registrarCuotaPagada(
    String prestamoId,
    int numeroCuota, {
    String? liquidacionId,
  }) async {
    final connectivity = await Connectivity().checkConnectivity();
    final isOnline = connectivity.isNotEmpty && connectivity.first != ConnectivityResult.none;
    
    if (isOnline) {
      try {
        // Usar la función SQL que ya creamos
        await Supabase.instance.client.rpc(
          'registrar_cuota_pagada',
          params: {
            'p_prestamo_id': prestamoId,
            'p_numero_cuota': numeroCuota,
            'p_liquidacion_id': liquidacionId,
          },
        );
      } catch (e) {
        print('Error registrando cuota pagada: $e');
      }
    }
  }
  
  /// Genera cuotas para un préstamo
  static Future<void> _generarCuotas(Prestamo prestamo) async {
    final cuotas = <CuotaPrestamo>[];
    
    DateTime fechaCuota = prestamo.fechaPrimeraCuota;
    
    for (int i = 1; i <= prestamo.cantidadCuotas; i++) {
      final cuota = CuotaPrestamo(
        id: '${prestamo.id}_cuota_$i',
        prestamoId: prestamo.id,
        numeroCuota: i,
        monto: prestamo.valorCuota,
        periodoMes: fechaCuota.month,
        periodoAnio: fechaCuota.year,
      );
      
      cuotas.add(cuota);
      
      // Próximo mes
      fechaCuota = DateTime(fechaCuota.year, fechaCuota.month + 1, fechaCuota.day);
    }
    
    // Guardar cuotas en Supabase
    final connectivity = await Connectivity().checkConnectivity();
    final isOnline = connectivity.isNotEmpty && connectivity.first != ConnectivityResult.none;
    
    if (isOnline) {
      try {
        await Supabase.instance.client
            .from('prestamos_cuotas')
            .insert(cuotas.map((c) => c.toMap()).toList());
      } catch (e) {
        print('Error guardando cuotas: $e');
      }
    }
  }
  
  // Métodos privados de cache
  static Future<void> _guardarEnCache(String cuil, List<Prestamo> prestamos) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_cacheKeyPrefix$cuil';
    final json = jsonEncode(prestamos.map((p) => p.toMap()).toList());
    await prefs.setString(key, json);
  }
  
  static Future<List<Prestamo>> _cargarDesdeCache(String cuil) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_cacheKeyPrefix$cuil';
    final json = prefs.getString(key);
    
    if (json == null) return [];
    
    final list = jsonDecode(json) as List;
    return list.map((m) => Prestamo.fromMap(m)).toList();
  }
  
  static Future<void> _agregarACache(Prestamo prestamo) async {
    final prestamos = await _cargarDesdeCache(prestamo.empleadoCuil);
    prestamos.removeWhere((p) => p.id == prestamo.id);
    prestamos.add(prestamo);
    await _guardarEnCache(prestamo.empleadoCuil, prestamos);
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
