// ========================================================================
// SERVICIO DE CCT EN LA NUBE
// Sincronización de CCT actualizados por robot BAT con Supabase
// Misma metodología que ParitariasService (banner + sync)
// ========================================================================

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
// import 'dart:io'; // Removed for web compatibility

/// Modelo de CCT
class CCTMaster {
  final String codigo;
  final String nombre;
  final String? sector;
  final String? subsector;
  final int versionActual;
  final DateTime? fechaActualizacion;
  final Map<String, dynamic>? jsonEstructura;
  final String? descripcion;
  final String? fuenteOficial;
  final bool activo;
  final DateTime? updatedAt;
  
  CCTMaster({
    required this.codigo,
    required this.nombre,
    this.sector,
    this.subsector,
    this.versionActual = 1,
    this.fechaActualizacion,
    this.jsonEstructura,
    this.descripcion,
    this.fuenteOficial,
    this.activo = true,
    this.updatedAt,
  });
  
  factory CCTMaster.fromMap(Map<String, dynamic> map) {
    return CCTMaster(
      codigo: map['codigo'] ?? '',
      nombre: map['nombre'] ?? '',
      sector: map['sector'],
      subsector: map['subsector'],
      versionActual: map['version_actual'] ?? 1,
      fechaActualizacion: map['fecha_actualizacion'] != null 
          ? DateTime.parse(map['fecha_actualizacion']) 
          : null,
      jsonEstructura: map['json_estructura'],
      descripcion: map['descripcion'],
      fuenteOficial: map['fuente_oficial'],
      activo: map['activo'] ?? true,
      updatedAt: map['updated_at'] != null 
          ? DateTime.parse(map['updated_at']) 
          : null,
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'codigo': codigo,
      'nombre': nombre,
      'sector': sector,
      'subsector': subsector,
      'version_actual': versionActual,
      'fecha_actualizacion': fechaActualizacion?.toIso8601String().split('T')[0],
      'json_estructura': jsonEstructura,
      'descripcion': descripcion,
      'fuente_oficial': fuenteOficial,
      'activo': activo,
    };
  }
}

class CCTCloudService {
  static const String _cacheKey = 'maestro_cct_cache';
  static const String _lastSyncKey = 'ultima_sincronizacion_cct';
  
  /// Sincroniza CCT desde Supabase (actualizados por robot BAT)
  static Future<Map<String, dynamic>> sincronizarCCT() async {
    final connectivity = await Connectivity().checkConnectivity();
    final isOnline = connectivity.isNotEmpty && connectivity.first != ConnectivityResult.none;
    
    final prefs = await SharedPreferences.getInstance();
    final lastSyncStr = prefs.getString(_lastSyncKey);
    DateTime? ultimaFecha = lastSyncStr != null ? DateTime.tryParse(lastSyncStr) : null;
    
    if (!isOnline) {
      return {
        'success': false,
        'fecha': ultimaFecha,
        'modo': 'offline',
        'data': await _getCachedData(),
      };
    }
    
    try {
      final res = await Supabase.instance.client
          .from('cct_master')
          .select()
          .eq('activo', true);
      
      final list = res as List;
      if (list.isNotEmpty) {
        await prefs.setString(_cacheKey, jsonEncode(list));
        final ahora = DateTime.now();
        await prefs.setString(_lastSyncKey, ahora.toIso8601String());
        
        return {
          'success': true,
          'fecha': ahora,
          'modo': 'online',
          'data': list,
          'cantidad': list.length,
        };
      }
    } catch (e) {
      print('Error sincronizando CCT desde Supabase: $e');
    }
    
    return {
      'success': false,
      'fecha': ultimaFecha,
      'modo': 'error',
      'data': await _getCachedData(),
    };
  }
  
  /// Lee resultados del robot BAT y los sube a Supabase
  /// 
  /// Tu robot BAT debe guardar los resultados en un archivo JSON con formato:
  /// ```json
  /// {
  ///   "ccts": [
  ///     {
  ///       "codigo": "122/75",
  ///       "nombre": "FATSA",
  ///       "sector": "sanidad",
  ///       "estructura": { ... }
  ///     }
  ///   ]
  /// }
  /// ```
  static Future<Map<String, dynamic>> subirResultadosRobot({
    required String rutaArchivoResultados,
    String? ejecutadoPor,
  }) async {
    final connectivity = await Connectivity().checkConnectivity();
    final isOnline = connectivity.isNotEmpty && connectivity.first != ConnectivityResult.none;
    
    if (!isOnline) {
      return {
        'success': false,
        'error': 'Sin conexión a internet',
      };
    }

    if (kIsWeb) {
      return {
        'success': false,
        'error': 'La carga de resultados del robot no está disponible en la versión Web.',
      };
    }
    
    try {
      /*
      // Leer archivo de resultados del robot
      final file = File(rutaArchivoResultados);
      if (!await file.exists()) {
        return {
          'success': false,
          'error': 'Archivo de resultados no encontrado: $rutaArchivoResultados',
        };
      }
      
      final contenido = await file.readAsString();
      */
      const contenido = ''; // Placeholder for disabled logic
      final datos = jsonDecode(contenido) as Map<String, dynamic>;
      
      final ccts = datos['ccts'] as List? ?? [];
      
      if (ccts.isEmpty) {
        return {
          'success': false,
          'error': 'No hay CCT en el archivo de resultados',
        };
      }
      
      int actualizados = 0;
      int errores = 0;
      final erroresDetalle = <String>[];
      
      final fechaEjecucion = DateTime.now();
      
      // Subir cada CCT a Supabase
      for (final cctData in ccts) {
        try {
          await Supabase.instance.client
              .from('cct_master')
              .upsert({
                'codigo': cctData['codigo'],
                'nombre': cctData['nombre'],
                'sector': cctData['sector'],
                'subsector': cctData['subsector'],
                'json_estructura': cctData['estructura'],
                'descripcion': cctData['descripcion'],
                'fuente_oficial': cctData['fuente_oficial'],
                'activo': true,
                'fecha_actualizacion': fechaEjecucion.toIso8601String().split('T')[0],
                'actualizado_por': ejecutadoPor ?? 'robot_bat',
              });
          
          actualizados++;
        } catch (e) {
          errores++;
          erroresDetalle.add('${cctData['codigo']}: $e');
        }
      }
      
      // Registrar ejecución del robot
      await _registrarEjecucionRobot(
        exitosa: errores == 0,
        cctProcesados: ccts.length,
        cctActualizados: actualizados,
        cctConErrores: errores,
        logCompleto: contenido,
        errores: erroresDetalle,
        ejecutadoPor: ejecutadoPor,
      );
      
      // Actualizar cache local
      await sincronizarCCT();
      
      return {
        'success': errores == 0,
        'cct_procesados': ccts.length,
        'cct_actualizados': actualizados,
        'cct_errores': errores,
        'errores_detalle': erroresDetalle,
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Error procesando resultados del robot: $e',
      };
    }
  }
  
  /// Registra la ejecución del robot BAT en la base de datos
  static Future<void> _registrarEjecucionRobot({
    required bool exitosa,
    required int cctProcesados,
    required int cctActualizados,
    required int cctConErrores,
    String? logCompleto,
    List<String>? errores,
    String? ejecutadoPor,
  }) async {
    try {
      await Supabase.instance.client
          .from('cct_robot_ejecuciones')
          .insert({
            'exitosa': exitosa,
            'cct_procesados': cctProcesados,
            'cct_actualizados': cctActualizados,
            'cct_sin_cambios': cctProcesados - cctActualizados - cctConErrores,
            'cct_con_errores': cctConErrores,
            'log_completo': logCompleto,
            'errores': errores,
            'ejecutado_por': ejecutadoPor,
          });
    } catch (e) {
      print('Error registrando ejecución del robot: $e');
    }
  }
  
  /// Obtiene historial de ejecuciones del robot
  static Future<List<Map<String, dynamic>>> obtenerHistorialRobot({int limit = 10}) async {
    try {
      final res = await Supabase.instance.client
          .from('cct_robot_ejecuciones')
          .select()
          .order('fecha_ejecucion', ascending: false)
          .limit(limit);
      
      return (res as List).cast<Map<String, dynamic>>();
    } catch (e) {
      print('Error obteniendo historial del robot: $e');
      return [];
    }
  }
  
  /// Obtiene un CCT específico
  static Future<CCTMaster?> obtenerCCT(String codigo) async {
    try {
      final connectivity = await Connectivity().checkConnectivity();
      final isOnline = connectivity.isNotEmpty && connectivity.first != ConnectivityResult.none;
      
      if (isOnline) {
        final res = await Supabase.instance.client
            .from('cct_master')
            .select()
            .eq('codigo', codigo)
            .maybeSingle();
        
        if (res != null) {
          return CCTMaster.fromMap(res);
        }
      }
    } catch (e) {
      print('Error obteniendo CCT: $e');
    }
    
    // Buscar en cache
    final cached = await _getCachedData();
    final found = cached.where((c) => c['codigo'] == codigo).toList();
    
    return found.isNotEmpty ? CCTMaster.fromMap(found.first) : null;
  }
  
  static Future<List<dynamic>> _getCachedData() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_cacheKey);
    if (cached != null) {
      return jsonDecode(cached) as List;
    }
    return [];
  }
}
