
// ========================================================================
// SERVICIO DE CONCEPTOS RECURRENTES (v2.0 - Optimizado para asignación masiva)
// Gestión híbrida con carga optimizada por empresa y guardado masivo.
// ========================================================================

import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/concepto_recurrente.dart';
// Usamos un stub para la caché local, que puede ser implementado con SharedPreferences o Isar.
import 'hybrid_isar_stub.dart' as _local;

class ConceptosRecurrentesService {
  static const String _cacheKeyPrefix = 'conceptos_empresa_';
  static const String _supabaseTable = 'conceptos_recurrentes';
  static const _uuid = Uuid();

  // ========================================================================
  // OPERACIONES PRIMARIAS (NUEVA ARQUITECTURA)
  // ========================================================================

  /// **NUEVO Y OPTIMIZADO:** Obtiene todos los conceptos de una empresa en una sola consulta.
  static Future<List<ConceptoRecurrente>> obtenerConceptosPorEmpresa(String empresaCuit) async {
    final cacheKey = '$_cacheKeyPrefix$empresaCuit';

    // Prioridad 1: Obtener datos frescos de Supabase si hay conexión.
    final connectivity = await Connectivity().checkConnectivity();
    final isOnline = connectivity != ConnectivityResult.none;

    if (isOnline) {
      try {
        final response = await Supabase.instance.client
            .from(_supabaseTable)
            .select()
            .eq('empresa_cuit', empresaCuit);

        final conceptos = (response as List)
            .map((e) => ConceptoRecurrente.fromMap(Map<String, dynamic>.from(e)))
            .toList();

        // Actualizar la caché local con los datos frescos para uso offline.
        await _local.localPut(cacheKey, '', jsonEncode(conceptos.map((c) => c.toMap()).toList()));

        return conceptos;
      } catch (e) {
        print('Error crítico obteniendo conceptos desde Supabase. Se usará la caché si existe. Error: $e');
      }
    }

    // Prioridad 2 (Fallback): Cargar desde la caché local si no hay conexión o si Supabase falló.
    print('Modo Offline: Cargando conceptos recurrentes desde la caché local.');
    final s = await _local.localGet(cacheKey, '');
    if (s == null || s.isEmpty) return [];
    try {
      final list = jsonDecode(s) as List?;
      return list?.map((e) => ConceptoRecurrente.fromMap(Map<String, dynamic>.from(e as Map))).toList() ?? [];
    } catch (e) {
      print('Error decodificando conceptos desde la caché: $e');
      return [];
    }
  }

  static ConceptoRecurrente crearDesdePlantilla(String empleadoCuil, String codigoPlantilla) {
    final p = PlantillasConceptos.comunes.firstWhere(
      (e) => (e['codigo']?.toString() ?? '').toUpperCase() == codigoPlantilla.toUpperCase(),
      orElse: () => {
        'codigo': codigoPlantilla,
        'nombre': codigoPlantilla,
        'descripcion': '',
        'tipo': 'fijo',
        'categoria': 'no_remunerativo',
        'subcategoria': null,
        'valor_sugerido': 0.0,
      },
    );
    final ahora = DateTime.now();
    return ConceptoRecurrente(
      id: _uuid.v4(),
      empleadoCuil: empleadoCuil,
      codigo: p['codigo']?.toString() ?? codigoPlantilla,
      nombre: p['nombre']?.toString() ?? codigoPlantilla,
      descripcion: p['descripcion']?.toString() ?? '',
      tipo: p['tipo']?.toString() ?? 'fijo',
      valor: (p['valor_sugerido'] as num?)?.toDouble() ?? 0.0,
      categoria: p['categoria']?.toString() ?? 'no_remunerativo',
      subcategoria: p['subcategoria']?.toString(),
      activoDesde: ahora,
      activoHasta: null,
      activo: true,
    );
  }

  static Future<void> agregarConcepto(ConceptoRecurrente concepto) async {
    await guardarConceptosMasivamente(conceptos: [concepto], empresaCuit: '');
  }

  static Future<void> actualizarConcepto(ConceptoRecurrente concepto) async {
    concepto.updatedAt = DateTime.now();
    await guardarConceptosMasivamente(conceptos: [concepto], empresaCuit: '');
  }

  /// **NUEVO:** Guarda una lista de conceptos recurrentes (para asignación masiva).
  static Future<void> guardarConceptosMasivamente({
    required List<ConceptoRecurrente> conceptos,
    required String empresaCuit,
  }) async {
    if (conceptos.isEmpty) return;

    final conceptosParaSubir = conceptos.map((c) {
      // Asegurar que cada concepto tenga un ID y la data de la empresa.
      c.id = c.id.isNotEmpty ? c.id : _uuid.v4();
      c.empresaCuit = empresaCuit;
      c.updatedAt = DateTime.now();
      c.createdAt ??= DateTime.now();
      return c.toMap();
    }).toList();

    // Sincronizar con Supabase en segundo plano.
    _runAsync(() async {
      await Supabase.instance.client.from(_supabaseTable).upsert(conceptosParaSubir, onConflict: 'id');
      print('Se han guardado ${conceptos.length} conceptos masivamente en Supabase.');

      // Forzar la actualización de la caché después del guardado para mantenerla fresca.
      await obtenerConceptosPorEmpresa(empresaCuit);
    });
  }

  /// **NUEVO:** Elimina una lista de conceptos recurrentes por sus IDs.
  static Future<void> eliminarConceptosMasivamente({
    required List<String> ids,
    required String empresaCuit,
  }) async {
    if (ids.isEmpty) return;

    // Eliminar de Supabase en segundo plano.
    _runAsync(() async {
      await Supabase.instance.client.from(_supabaseTable).delete().in_('id', ids);
      print('Se han eliminado ${ids.length} conceptos masivamente de Supabase.');

      // Forzar la actualización de la caché.
      await obtenerConceptosPorEmpresa(empresaCuit);
    });
  }

  // ========================================================================
  // LÓGICA DE SINCRONIZACIÓN ASÍNCRONA
  // ========================================================================

  static void _runAsync(Future<void> Function() fn) {
    fn().catchError((e, stackTrace) {
      print('Error fatal en operación asíncrona de conceptos: $e');
      print(stackTrace);
    });
  }

  // ========================================================================
  // MÉTODOS OBSOLETOS (se mantienen temporalmente por compatibilidad)
  // ========================================================================

  @Deprecated('Usar obtenerConceptosPorEmpresa en su lugar. Este método es ineficiente.')
  static Future<List<ConceptoRecurrente>> obtenerConceptosPorEmpleado(String cuil) async {
    final conceptos = await _obtenerTodosConceptos_DEPRECATED();
    final cuilLimpio = cuil.replaceAll(RegExp(r'[^\d]'), '');
    return conceptos.where((c) => c.empleadoCuil.replaceAll(RegExp(r'[^\d]'), '') == cuilLimpio).toList();
  }

  @Deprecated('Este método carga todos los conceptos sin filtrar por empresa y es ineficiente.')
  static Future<List<ConceptoRecurrente>> _obtenerTodosConceptos_DEPRECATED() async {
    final s = await _local.localGet('conceptos_recurrentes', ''); // Clave antigua
    if (s == null || s.isEmpty) return [];
    try {
      final list = jsonDecode(s) as List?;
      return list?.map((e) => ConceptoRecurrente.fromMap(Map<String, dynamic>.from(e as Map))).toList() ?? [];
    } catch (e) {
      return [];
    }
  }
}
