// ========================================================================
// SERVICIO DE EMPLEADOS
// Gestión híbrida offline-first de empleados con sincronización Supabase
// ========================================================================

import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/empleado_completo.dart';
import 'hybrid_isar_stub.dart' as _local;

class EmpleadosService {
  static const String _tEmpleados = 'empleados';
  static const String _supabaseTable = 'empleados';
  
  /// Limpia CUIL/CUIT
  static String _cuilLimpio(String? cuil) {
    if (cuil == null || cuil.isEmpty) return '';
    return cuil.replaceAll(RegExp(r'[^\d]'), '');
  }
  
  // ========================================================================
  // OPERACIONES LOCALES (Offline-first)
  // ========================================================================
  
  /// Obtiene todos los empleados de una empresa (desde local)
  static Future<List<EmpleadoCompleto>> obtenerEmpleados({String? empresaCuit}) async {
    final s = await _local.localGet(_tEmpleados, empresaCuit ?? '');
    if (s == null || s.isEmpty) return [];
    
    try {
      final list = jsonDecode(s) as List?;
      if (list == null) return [];
      
      List<EmpleadoCompleto> empleados = list
          .map((e) => EmpleadoCompleto.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();
      
      // Filtrar por empresa si se especificó
      if (empresaCuit != null && empresaCuit.isNotEmpty) {
        final cuitLimpio = _cuilLimpio(empresaCuit);
        empleados = empleados.where((e) => 
          _cuilLimpio(e.empresaCuit) == cuitLimpio
        ).toList();
      }
      
      return empleados;
    } catch (e) {
      print('Error obteniendo empleados: $e');
      return [];
    }
  }
  
  /// Obtiene un empleado por CUIL
  static Future<EmpleadoCompleto?> obtenerEmpleadoPorCuil(String cuil, {String? empresaCuit}) async {
    final empleados = await obtenerEmpleados(empresaCuit: empresaCuit);
    final cuilLimpio = _cuilLimpio(cuil);
    
    try {
      return empleados.firstWhere((e) => _cuilLimpio(e.cuil) == cuilLimpio);
    } catch (_) {
      return null;
    }
  }
  
  /// Busca empleados por nombre, CUIL, categoría, etc
  static Future<List<EmpleadoCompleto>> buscarEmpleados(String query, {String? empresaCuit}) async {
    final empleados = await obtenerEmpleados(empresaCuit: empresaCuit);
    
    if (query.isEmpty) return empleados;
    
    final queryLower = query.toLowerCase();
    
    return empleados.where((e) {
      return e.nombreCompleto.toLowerCase().contains(queryLower) ||
             e.cuil.contains(queryLower) ||
             (e.categoria.toLowerCase().contains(queryLower)) ||
             (e.apellido?.toLowerCase().contains(queryLower) ?? false) ||
             (e.nombre?.toLowerCase().contains(queryLower) ?? false);
    }).toList();
  }
  
  /// Guarda o actualiza un empleado (local + sync a Supabase)
  static Future<void> guardarEmpleado(EmpleadoCompleto empleado) async {
    final cuilLimpio = _cuilLimpio(empleado.cuil);
    if (cuilLimpio.length != 11) {
      throw Exception('CUIL inválido: debe tener 11 dígitos');
    }
    
    // Actualizar timestamp
    empleado.updatedAt = DateTime.now();
    if (empleado.createdAt == null) {
      empleado.createdAt = DateTime.now();
    }
    
    // Obtener lista actual
    final empleados = await obtenerEmpleados(empresaCuit: empleado.empresaCuit);
    
    // Buscar si ya existe
    final index = empleados.indexWhere((e) => _cuilLimpio(e.cuil) == cuilLimpio);
    
    if (index >= 0) {
      empleados[index] = empleado;
    } else {
      empleados.add(empleado);
    }
    
    // Guardar localmente
    await _local.localPut(
      _tEmpleados, 
      empleado.empresaCuit ?? '', 
      jsonEncode(empleados.map((e) => e.toMap()).toList())
    );
    
    // Sincronizar con Supabase en background
    _pushToSupabase(empleado);
  }
  
  /// Elimina un empleado (marca como de_baja, no elimina físicamente)
  static Future<void> darDeBajaEmpleado(String cuil, {String? empresaCuit, String? motivo}) async {
    final empleado = await obtenerEmpleadoPorCuil(cuil, empresaCuit: empresaCuit);
    if (empleado == null) return;
    
    empleado.estado = 'de_baja';
    empleado.fechaBaja = DateTime.now();
    empleado.motivoBaja = motivo;
    
    await guardarEmpleado(empleado);
  }
  
  /// Obtiene empleados activos solamente
  static Future<List<EmpleadoCompleto>> obtenerEmpleadosActivos({String? empresaCuit}) async {
    final empleados = await obtenerEmpleados(empresaCuit: empresaCuit);
    return empleados.where((e) => e.estado == 'activo').toList();
  }
  
  /// Obtiene empleados por provincia
  static Future<List<EmpleadoCompleto>> obtenerEmpleadosPorProvincia(
    String provincia, 
    {String? empresaCuit}
  ) async {
    final empleados = await obtenerEmpleados(empresaCuit: empresaCuit);
    return empleados.where((e) => 
      e.provincia.toLowerCase() == provincia.toLowerCase()
    ).toList();
  }
  
  /// Obtiene empleados por categoría
  static Future<List<EmpleadoCompleto>> obtenerEmpleadosPorCategoria(
    String categoria,
    {String? empresaCuit}
  ) async {
    final empleados = await obtenerEmpleados(empresaCuit: empresaCuit);
    return empleados.where((e) => 
      e.categoria.toLowerCase() == categoria.toLowerCase()
    ).toList();
  }
  
  /// Obtiene empleados por sector (sanidad, docente, etc)
  static Future<List<EmpleadoCompleto>> obtenerEmpleadosPorSector(
    String sector,
    {String? empresaCuit}
  ) async {
    final empleados = await obtenerEmpleados(empresaCuit: empresaCuit);
    return empleados.where((e) => 
      e.sector?.toLowerCase() == sector.toLowerCase()
    ).toList();
  }
  
  // ========================================================================
  // SINCRONIZACIÓN CON SUPABASE
  // ========================================================================
  
  /// Push de empleado a Supabase (background, no bloquea)
  static void _pushToSupabase(EmpleadoCompleto empleado) {
    _runAsync(() async {
      final connectivityList = await Connectivity().checkConnectivity();
      if (connectivityList.isEmpty || 
          connectivityList.every((c) => c == ConnectivityResult.none)) {
        return;
      }
      
      try {
        final client = Supabase.instance.client;
        await client.from(_supabaseTable).upsert(
          empleado.toMap(),
          onConflict: 'cuil,empresa_cuit',
        );
      } catch (e) {
        print('Error sincronizando empleado a Supabase: $e');
      }
    });
  }
  
  /// Pull desde Supabase (sync manual o al abrir app)
  static Future<void> sincronizarDesdeSupabase({String? empresaCuit}) async {
    final connectivityList = await Connectivity().checkConnectivity();
    if (connectivityList.isEmpty || 
        connectivityList.every((c) => c == ConnectivityResult.none)) {
      return;
    }
    
    try {
      final client = Supabase.instance.client;
      
      // Query con filtro opcional por empresa
      var query = client.from(_supabaseTable).select();
      
      if (empresaCuit != null && empresaCuit.isNotEmpty) {
        query = query.eq('empresa_cuit', _cuilLimpio(empresaCuit));
      }
      
      final response = await query;
      
      if (response.isNotEmpty) {
        // Obtener empleados locales actuales
        final empleadosLocales = await obtenerEmpleados(empresaCuit: empresaCuit);
        final Map<String, EmpleadoCompleto> mapLocal = {};
        
        for (final emp in empleadosLocales) {
          mapLocal[_cuilLimpio(emp.cuil)] = emp;
        }
        
        // Merge con empleados de Supabase
        for (final r in response) {
          final map = Map<String, dynamic>.from(r as Map);
          final empRemoto = EmpleadoCompleto.fromMap(map);
          final cuilLimpio = _cuilLimpio(empRemoto.cuil);
          
          // Si no existe localmente, o si el remoto es más nuevo
          if (!mapLocal.containsKey(cuilLimpio) ||
              (empRemoto.updatedAt?.isAfter(mapLocal[cuilLimpio]!.updatedAt ?? DateTime(1900)) ?? false)) {
            mapLocal[cuilLimpio] = empRemoto;
          }
        }
        
        // Guardar merged list localmente (sin re-push)
        final empleadosMerged = mapLocal.values.toList();
        await _local.localPut(
          _tEmpleados,
          empresaCuit ?? '',
          jsonEncode(empleadosMerged.map((e) => e.toMap()).toList()),
        );
      }
    } catch (e) {
      print('Error sincronizando desde Supabase: $e');
    }
  }
  
  /// Push masivo de empleados locales a Supabase
  static Future<void> subirTodosASupabase({String? empresaCuit}) async {
    final empleados = await obtenerEmpleados(empresaCuit: empresaCuit);
    
    for (final empleado in empleados) {
      _pushToSupabase(empleado);
      await Future.delayed(Duration(milliseconds: 100)); // Rate limiting
    }
  }
  
  static void _runAsync(Future<void> Function() fn) {
    fn().catchError((e) {
      print('Error en operación async: $e');
    });
  }
  
  // ========================================================================
  // ESTADÍSTICAS Y REPORTES
  // ========================================================================
  
  /// Obtiene cantidad de empleados por estado
  static Future<Map<String, int>> obtenerEstadisticasPorEstado({String? empresaCuit}) async {
    final empleados = await obtenerEmpleados(empresaCuit: empresaCuit);
    
    final stats = <String, int>{};
    for (final emp in empleados) {
      stats[emp.estado] = (stats[emp.estado] ?? 0) + 1;
    }
    
    return stats;
  }
  
  /// Obtiene cantidad de empleados por provincia
  static Future<Map<String, int>> obtenerEstadisticasPorProvincia({String? empresaCuit}) async {
    final empleados = await obtenerEmpleados(empresaCuit: empresaCuit);
    
    final stats = <String, int>{};
    for (final emp in empleados) {
      stats[emp.provincia] = (stats[emp.provincia] ?? 0) + 1;
    }
    
    return stats;
  }
  
  /// Obtiene cantidad de empleados por categoría
  static Future<Map<String, int>> obtenerEstadisticasPorCategoria({String? empresaCuit}) async {
    final empleados = await obtenerEmpleados(empresaCuit: empresaCuit);
    
    final stats = <String, int>{};
    for (final emp in empleados) {
      stats[emp.categoria] = (stats[emp.categoria] ?? 0) + 1;
    }
    
    return stats;
  }
  
  /// Obtiene empleados próximos a cumplir años de antigüedad
  static Future<List<EmpleadoCompleto>> obtenerProximosAniversarios({
    String? empresaCuit,
    int diasAnticipacion = 30,
  }) async {
    final empleados = await obtenerEmpleadosActivos(empresaCuit: empresaCuit);
    final ahora = DateTime.now();
    
    return empleados.where((e) {
      final fechaAniversario = DateTime(
        ahora.year,
        e.fechaIngreso.month,
        e.fechaIngreso.day,
      );
      
      final diff = fechaAniversario.difference(ahora).inDays;
      return diff >= 0 && diff <= diasAnticipacion;
    }).toList();
  }
}
