// ========================================================================
// SERVICIO DE VERSIONADO DE CCT CON ROLLBACK
// Mantiene historial de versiones de CCT y permite volver a versiones anteriores
// ========================================================================

import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';

class VersionCCT {
  final String id;
  final String cctCodigo;
  final int numeroVersion;
  final Map<String, dynamic> contenido;
  final String? descripcionCambios;
  final DateTime fechaCreacion;
  final String? creadoPor;
  final bool esVersionActiva;
  
  VersionCCT({
    required this.id,
    required this.cctCodigo,
    required this.numeroVersion,
    required this.contenido,
    this.descripcionCambios,
    required this.fechaCreacion,
    this.creadoPor,
    this.esVersionActiva = false,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'cct_codigo': cctCodigo,
      'numero_version': numeroVersion,
      'contenido': contenido,
      'descripcion_cambios': descripcionCambios,
      'fecha_creacion': fechaCreacion.toIso8601String(),
      'creado_por': creadoPor,
      'es_version_activa': esVersionActiva,
    };
  }
  
  factory VersionCCT.fromMap(Map<String, dynamic> map) {
    return VersionCCT(
      id: map['id'] ?? '',
      cctCodigo: map['cct_codigo'] ?? '',
      numeroVersion: map['numero_version'] ?? 1,
      contenido: map['contenido'] is String 
          ? jsonDecode(map['contenido']) 
          : map['contenido'] ?? {},
      descripcionCambios: map['descripcion_cambios'],
      fechaCreacion: DateTime.parse(map['fecha_creacion']),
      creadoPor: map['creado_por'],
      esVersionActiva: map['es_version_activa'] ?? false,
    );
  }
}

class VersionadoCCTService {
  /// Crea una nueva versión de un CCT
  static Future<VersionCCT> crearVersion({
    required String cctCodigo,
    required Map<String, dynamic> contenido,
    String? descripcionCambios,
    String? usuario,
  }) async {
    try {
      // 1. Obtener número de última versión
      final ultimaVersion = await _obtenerUltimaVersion(cctCodigo);
      final numeroVersion = (ultimaVersion?.numeroVersion ?? 0) + 1;
      
      // 2. Crear nueva versión
      final nuevaVersion = VersionCCT(
        id: 'ver_${cctCodigo}_v${numeroVersion}_${DateTime.now().millisecondsSinceEpoch}',
        cctCodigo: cctCodigo,
        numeroVersion: numeroVersion,
        contenido: contenido,
        descripcionCambios: descripcionCambios ?? 'Versión $numeroVersion',
        fechaCreacion: DateTime.now(),
        creadoPor: usuario ?? 'Sistema',
        esVersionActiva: true,
      );
      
      // 3. Marcar versión anterior como inactiva
      if (ultimaVersion != null) {
        await Supabase.instance.client
            .from('cct_versiones')
            .update({'es_version_activa': false})
            .eq('cct_codigo', cctCodigo)
            .eq('es_version_activa', true);
      }
      
      // 4. Insertar nueva versión
      await Supabase.instance.client
          .from('cct_versiones')
          .insert(nuevaVersion.toMap());
      
      return nuevaVersion;
    } catch (e) {
      print('Error creando versión de CCT: $e');
      rethrow;
    }
  }
  
  /// Obtiene la última versión (activa) de un CCT
  static Future<VersionCCT?> _obtenerUltimaVersion(String cctCodigo) async {
    try {
      final res = await Supabase.instance.client
          .from('cct_versiones')
          .select()
          .eq('cct_codigo', cctCodigo)
          .order('numero_version', ascending: false)
          .limit(1);
      
      if (res.isEmpty) return null;
      
      return VersionCCT.fromMap(res.first);
    } catch (e) {
      print('Error obteniendo última versión: $e');
      return null;
    }
  }
  
  /// Obtiene la versión activa de un CCT
  static Future<VersionCCT?> obtenerVersionActiva(String cctCodigo) async {
    try {
      final res = await Supabase.instance.client
          .from('cct_versiones')
          .select()
          .eq('cct_codigo', cctCodigo)
          .eq('es_version_activa', true)
          .limit(1);
      
      if (res.isEmpty) return null;
      
      return VersionCCT.fromMap(res.first);
    } catch (e) {
      print('Error obteniendo versión activa: $e');
      return null;
    }
  }
  
  /// Obtiene todo el historial de versiones de un CCT
  static Future<List<VersionCCT>> obtenerHistorialVersiones(String cctCodigo) async {
    try {
      final res = await Supabase.instance.client
          .from('cct_versiones')
          .select()
          .eq('cct_codigo', cctCodigo)
          .order('numero_version', ascending: false);
      
      return (res as List).map((m) => VersionCCT.fromMap(m)).toList();
    } catch (e) {
      print('Error obteniendo historial de versiones: $e');
      return [];
    }
  }
  
  /// Hace rollback a una versión específica
  /// 
  /// Esto marca la versión especificada como activa y las demás como inactivas.
  /// También crea una nueva versión (copia) para mantener el historial.
  static Future<bool> rollbackAVersion({
    required String cctCodigo,
    required int numeroVersion,
    String? usuario,
    String? motivoRollback,
  }) async {
    try {
      // 1. Obtener la versión a la que se quiere hacer rollback
      final versionesRes = await Supabase.instance.client
          .from('cct_versiones')
          .select()
          .eq('cct_codigo', cctCodigo)
          .eq('numero_version', numeroVersion)
          .limit(1);
      
      if (versionesRes.isEmpty) {
        print('Versión $numeroVersion no encontrada para CCT $cctCodigo');
        return false;
      }
      
      final versionAnterior = VersionCCT.fromMap(versionesRes.first);
      
      // 2. Crear nueva versión con el contenido de la versión anterior
      final descripcion = motivoRollback ?? 
          'Rollback a versión $numeroVersion (${versionAnterior.fechaCreacion.toString().split(' ')[0]})';
      
      await crearVersion(
        cctCodigo: cctCodigo,
        contenido: versionAnterior.contenido,
        descripcionCambios: descripcion,
        usuario: usuario,
      );
      
      return true;
    } catch (e) {
      print('Error haciendo rollback: $e');
      return false;
    }
  }
  
  /// Compara dos versiones de un CCT
  static Map<String, dynamic> compararVersiones({
    required VersionCCT version1,
    required VersionCCT version2,
  }) {
    final cambios = <String, dynamic>{};
    final keys = {...version1.contenido.keys, ...version2.contenido.keys};
    
    for (final key in keys) {
      final valor1 = version1.contenido[key];
      final valor2 = version2.contenido[key];
      
      if (valor1 != valor2) {
        cambios[key] = {
          'version_${version1.numeroVersion}': valor1,
          'version_${version2.numeroVersion}': valor2,
        };
      }
    }
    
    return cambios;
  }
  
  /// Genera reporte de cambios entre versiones
  static String generarReporteCambios(
    VersionCCT versionNueva,
    VersionCCT versionAnterior,
  ) {
    final buffer = StringBuffer();
    
    buffer.writeln('═══════════════════════════════════════════════════════════');
    buffer.writeln('   REPORTE DE CAMBIOS - CCT ${versionNueva.cctCodigo}');
    buffer.writeln('═══════════════════════════════════════════════════════════');
    buffer.writeln('');
    buffer.writeln('Versión anterior:  v${versionAnterior.numeroVersion} (${versionAnterior.fechaCreacion.toString().split(' ')[0]})');
    buffer.writeln('Versión nueva:     v${versionNueva.numeroVersion} (${versionNueva.fechaCreacion.toString().split(' ')[0]})');
    buffer.writeln('Autor:             ${versionNueva.creadoPor ?? "Sistema"}');
    buffer.writeln('');
    buffer.writeln('Descripción cambios:');
    buffer.writeln(versionNueva.descripcionCambios ?? '(sin descripción)');
    buffer.writeln('');
    buffer.writeln('═══ CAMBIOS DETECTADOS ═══');
    buffer.writeln('');
    
    final cambios = compararVersiones(
      version1: versionAnterior,
      version2: versionNueva,
    );
    
    if (cambios.isEmpty) {
      buffer.writeln('(Sin cambios en el contenido)');
    } else {
      for (final entry in cambios.entries) {
        buffer.writeln('Campo: ${entry.key}');
        buffer.writeln('  Antes: ${entry.value['version_${versionAnterior.numeroVersion}']}');
        buffer.writeln('  Ahora: ${entry.value['version_${versionNueva.numeroVersion}']}');
        buffer.writeln('');
      }
    }
    
    buffer.writeln('═══════════════════════════════════════════════════════════');
    
    return buffer.toString();
  }
  
  /// Elimina versiones antiguas (mantiene últimas N versiones)
  static Future<int> limpiarVersionesAntiguas({
    required String cctCodigo,
    int mantenerUltimas = 10,
  }) async {
    try {
      final versiones = await obtenerHistorialVersiones(cctCodigo);
      
      if (versiones.length <= mantenerUltimas) {
        return 0; // No hay nada que eliminar
      }
      
      // Obtener versiones a eliminar (las más antiguas)
      final versionesAEliminar = versiones.skip(mantenerUltimas).toList();
      
      // Eliminar
      int eliminadas = 0;
      for (final version in versionesAEliminar) {
        await Supabase.instance.client
            .from('cct_versiones')
            .delete()
            .eq('id', version.id);
        eliminadas++;
      }
      
      return eliminadas;
    } catch (e) {
      print('Error limpiando versiones antiguas: $e');
      return 0;
    }
  }
}
