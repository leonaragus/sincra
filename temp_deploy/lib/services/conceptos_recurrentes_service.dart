// ========================================================================
// SERVICIO DE CONCEPTOS RECURRENTES
// Gestión híbrida offline-first de conceptos recurrentes con sincronización
// ========================================================================

import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/concepto_recurrente.dart';
import 'hybrid_isar_stub.dart' as _local;

class ConceptosRecurrentesService {
  static const String _tConceptos = 'conceptos_recurrentes';
  static const String _supabaseTable = 'conceptos_recurrentes';
  
  /// Limpia CUIL
  static String _cuilLimpio(String? cuil) {
    if (cuil == null || cuil.isEmpty) return '';
    return cuil.replaceAll(RegExp(r'[^\d]'), '');
  }
  
  // ========================================================================
  // OPERACIONES LOCALES
  // ========================================================================
  
  /// Obtiene todos los conceptos recurrentes (de todos los empleados)
  static Future<List<ConceptoRecurrente>> obtenerTodosConceptos() async {
    final s = await _local.localGet(_tConceptos, '');
    if (s == null || s.isEmpty) return [];
    
    try {
      final list = jsonDecode(s) as List?;
      if (list == null) return [];
      
      return list
          .map((e) => ConceptoRecurrente.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e) {
      print('Error obteniendo conceptos: $e');
      return [];
    }
  }
  
  /// Obtiene conceptos recurrentes de un empleado
  static Future<List<ConceptoRecurrente>> obtenerConceptosPorEmpleado(String cuil) async {
    final conceptos = await obtenerTodosConceptos();
    final cuilLimpio = _cuilLimpio(cuil);
    
    return conceptos.where((c) => _cuilLimpio(c.empleadoCuil) == cuilLimpio).toList();
  }
  
  /// Obtiene conceptos activos para un empleado en un mes/año específico
  static Future<List<ConceptoRecurrente>> obtenerConceptosActivos(
    String cuil, 
    int mes, 
    int anio,
  ) async {
    final conceptos = await obtenerConceptosPorEmpleado(cuil);
    
    return conceptos.where((c) => c.estaActivoEn(mes, anio)).toList();
  }
  
  /// Obtiene un concepto por ID
  static Future<ConceptoRecurrente?> obtenerConceptoPorId(String id) async {
    final conceptos = await obtenerTodosConceptos();
    
    try {
      return conceptos.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }
  
  /// Agrega un nuevo concepto recurrente
  static Future<void> agregarConcepto(ConceptoRecurrente concepto) async {
    // Validar CUIL
    final cuilLimpio = _cuilLimpio(concepto.empleadoCuil);
    if (cuilLimpio.length != 11) {
      throw Exception('CUIL del empleado inválido');
    }
    
    // Generar ID si no tiene
    if (concepto.id.isEmpty) {
      concepto.id = DateTime.now().millisecondsSinceEpoch.toString();
    }
    
    // Set timestamps
    concepto.createdAt = DateTime.now();
    concepto.updatedAt = DateTime.now();
    
    // Obtener lista actual
    final conceptos = await obtenerTodosConceptos();
    conceptos.add(concepto);
    
    // Guardar localmente
    await _local.localPut(
      _tConceptos,
      '',
      jsonEncode(conceptos.map((c) => c.toMap()).toList()),
    );
    
    // Sincronizar con Supabase
    _pushToSupabase(concepto);
  }
  
  /// Actualiza un concepto existente
  static Future<void> actualizarConcepto(ConceptoRecurrente concepto) async {
    concepto.updatedAt = DateTime.now();
    
    final conceptos = await obtenerTodosConceptos();
    final index = conceptos.indexWhere((c) => c.id == concepto.id);
    
    if (index >= 0) {
      conceptos[index] = concepto;
      
      await _local.localPut(
        _tConceptos,
        '',
        jsonEncode(conceptos.map((c) => c.toMap()).toList()),
      );
      
      _pushToSupabase(concepto);
    }
  }
  
  /// Desactiva un concepto (no lo elimina físicamente)
  static Future<void> desactivarConcepto(String id) async {
    final concepto = await obtenerConceptoPorId(id);
    if (concepto == null) return;
    
    concepto.activo = false;
    concepto.updatedAt = DateTime.now();
    
    await actualizarConcepto(concepto);
  }
  
  /// Elimina físicamente un concepto
  static Future<void> eliminarConcepto(String id) async {
    final conceptos = await obtenerTodosConceptos();
    conceptos.removeWhere((c) => c.id == id);
    
    await _local.localPut(
      _tConceptos,
      '',
      jsonEncode(conceptos.map((c) => c.toMap()).toList()),
    );
    
    // Eliminar de Supabase
    _deleteFromSupabase(id);
  }
  
  /// Registra un descuento de embargo y actualiza el acumulado
  static Future<void> registrarDescuentoEmbargo(String conceptoId, double montoDescontado) async {
    final concepto = await obtenerConceptoPorId(conceptoId);
    if (concepto == null) return;
    
    concepto.registrarDescuentoEmbargo(montoDescontado);
    await actualizarConcepto(concepto);
  }
  
  /// Obtiene embargos activos de un empleado
  static Future<List<ConceptoRecurrente>> obtenerEmbargosActivos(
    String cuil,
    int mes,
    int anio,
  ) async {
    final conceptos = await obtenerConceptosActivos(cuil, mes, anio);
    return conceptos.where((c) => 
      c.categoria == 'descuento' && 
      (c.subcategoria == 'embargo' || c.codigo.toUpperCase().contains('EMBARGO'))
    ).toList();
  }
  
  /// Calcula el total de embargos para un empleado en un mes
  static Future<double> calcularTotalEmbargos(
    String cuil,
    int mes,
    int anio,
  ) async {
    final embargos = await obtenerEmbargosActivos(cuil, mes, anio);
    return embargos.fold<double>(0.0, (sum, e) => sum + e.valor);
  }
  
  // ========================================================================
  // SINCRONIZACIÓN CON SUPABASE
  // ========================================================================
  
  static void _pushToSupabase(ConceptoRecurrente concepto) {
    _runAsync(() async {
      final connectivityList = await Connectivity().checkConnectivity();
      if (connectivityList.isEmpty || 
          connectivityList.every((c) => c == ConnectivityResult.none)) {
        return;
      }
      
      try {
        final client = Supabase.instance.client;
        await client.from(_supabaseTable).upsert(
          concepto.toMap(),
          onConflict: 'id',
        );
      } catch (e) {
        print('Error sincronizando concepto a Supabase: $e');
      }
    });
  }
  
  static void _deleteFromSupabase(String id) {
    _runAsync(() async {
      final connectivityList = await Connectivity().checkConnectivity();
      if (connectivityList.isEmpty || 
          connectivityList.every((c) => c == ConnectivityResult.none)) {
        return;
      }
      
      try {
        await Supabase.instance.client
            .from(_supabaseTable)
            .delete()
            .eq('id', id);
      } catch (e) {
        print('Error eliminando concepto de Supabase: $e');
      }
    });
  }
  
  static Future<void> sincronizarDesdeSupabase() async {
    final connectivityList = await Connectivity().checkConnectivity();
    if (connectivityList.isEmpty || 
        connectivityList.every((c) => c == ConnectivityResult.none)) {
      return;
    }
    
    try {
      final client = Supabase.instance.client;
      final response = await client.from(_supabaseTable).select();
      
      if (response is List && response.isNotEmpty) {
        final conceptosLocales = await obtenerTodosConceptos();
        final Map<String, ConceptoRecurrente> mapLocal = {};
        
        for (final c in conceptosLocales) {
          mapLocal[c.id] = c;
        }
        
        // Merge con conceptos de Supabase
        for (final r in response) {
          final map = Map<String, dynamic>.from(r as Map);
          final conceptoRemoto = ConceptoRecurrente.fromMap(map);
          
          // Si no existe localmente, o si el remoto es más nuevo
          if (!mapLocal.containsKey(conceptoRemoto.id) ||
              (conceptoRemoto.updatedAt?.isAfter(mapLocal[conceptoRemoto.id]!.updatedAt ?? DateTime(1900)) ?? false)) {
            mapLocal[conceptoRemoto.id] = conceptoRemoto;
          }
        }
        
        // Guardar merged list
        final conceptosMerged = mapLocal.values.toList();
        await _local.localPut(
          _tConceptos,
          '',
          jsonEncode(conceptosMerged.map((c) => c.toMap()).toList()),
        );
      }
    } catch (e) {
      print('Error sincronizando conceptos desde Supabase: $e');
    }
  }
  
  static void _runAsync(Future<void> Function() fn) {
    fn().catchError((e) {
      print('Error en operación async: $e');
    });
  }
  
  // ========================================================================
  // UTILIDADES Y PLANTILLAS
  // ========================================================================
  
  /// Crea un concepto desde una plantilla
  static ConceptoRecurrente crearDesdePlantilla(
    String empleadoCuil,
    String codigoPlantilla,
    {double? valorPersonalizado}
  ) {
    final plantilla = PlantillasConceptos.comunes.firstWhere(
      (p) => p['codigo'] == codigoPlantilla,
      orElse: () => PlantillasConceptos.comunes.first,
    );
    
    return ConceptoRecurrente(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      empleadoCuil: empleadoCuil,
      codigo: plantilla['codigo'] as String,
      nombre: plantilla['nombre'] as String,
      descripcion: plantilla['descripcion'] as String,
      tipo: plantilla['tipo'] as String,
      valor: valorPersonalizado ?? (plantilla['valor_sugerido'] as double),
      categoria: plantilla['categoria'] as String,
      subcategoria: plantilla['subcategoria'] as String?,
      activoDesde: DateTime.now(),
      activo: true,
      condicion: plantilla['condicion'] as String?,
    );
  }
  
  /// Obtiene estadísticas de conceptos por empleado
  static Future<Map<String, dynamic>> obtenerEstadisticas(String cuil) async {
    final conceptos = await obtenerConceptosPorEmpleado(cuil);
    final activos = conceptos.where((c) => c.activo).length;
    final inactivos = conceptos.length - activos;
    
    final porCategoria = <String, int>{};
    for (final c in conceptos.where((c) => c.activo)) {
      porCategoria[c.categoria] = (porCategoria[c.categoria] ?? 0) + 1;
    }
    
    return {
      'total': conceptos.length,
      'activos': activos,
      'inactivos': inactivos,
      'por_categoria': porCategoria,
    };
  }
}
