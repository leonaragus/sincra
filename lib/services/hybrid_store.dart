// ========================================================================
// HybridStore - Patrón Repositorio: lectura local (Isar/SP), escritura
// a local + sincronización en background con Supabase. 100% offline.
// En Web: Isar no disponible → SharedPreferences. En móvil/desktop: Isar.
// ========================================================================

import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/plantilla_cargo_omni.dart';

import 'hybrid_isar_stub.dart' as _local;

/// Almacén híbrido: local-first (SharedPreferences; Isar opcional en móvil/desktop), sync a Supabase en background.
class HybridStore {
  HybridStore._();

  /// Inicializar capa local. Con Isar: pasar directory; con stub (SP) se ignora.
  static Future<void> initIsar(String directory) async {
    try {
      await _local.initIsar(directory);
    } catch (_) {}
  }

  static String _cuitLimpio(String? cuit) {
    if (cuit == null || cuit.isEmpty) return '';
    return cuit.replaceAll(RegExp(r'[^\d]'), '');
  }

  // --------- helpers local ---------

  static Future<void> _localPut(String type, String key, String jsonData) async {
    await _local.localPut(type, key, jsonData);
    _pushToSupabase(type, key, jsonData);
  }

  static Future<String?> _localGet(String type, String key) async {
    return _local.localGet(type, key);
  }

  static Future<void> _localRemove(String type, String key) async {
    await _local.localRemove(type, key);
    _removeFromSupabase(type, key);
  }

  // --------- Supabase background ---------

  static void _pushToSupabase(String type, String key, String jsonData) {
    _runAsync(() async {
      final list = await Connectivity().checkConnectivity();
      if (list.isEmpty || list.every((c) => c == ConnectivityResult.none)) return;
      try {
        final client = Supabase.instance.client;
        await client.from(SupabaseConfig.tableEntities).upsert({
          'type': type,
          'key': key,
          'data': jsonDecode(jsonData),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }, onConflict: 'type,key');
      } catch (_) {}
    });
  }

  static void _removeFromSupabase(String type, String key) {
    _runAsync(() async {
      try {
        await Supabase.instance.client
            .from(SupabaseConfig.tableEntities)
            .delete()
            .eq('type', type)
            .eq('key', key);
      } catch (_) {}
    });
  }

  static void _runAsync(Future<void> Function() fn) {
    fn().catchError((_) {});
  }

  /// Pull desde Supabase y merge a local (ej. al abrir app o al estar online). Solo escribe en local, no re-push.
  static Future<void> pullFromSupabase() async {
    final list = await Connectivity().checkConnectivity();
    if (list.isEmpty || list.every((c) => c == ConnectivityResult.none)) return;
    try {
      final res = await Supabase.instance.client.from(SupabaseConfig.tableEntities).select();
      for (final r in res as List) {
        final m = r as Map;
        final type = m['type']?.toString() ?? '';
        final key = m['key']?.toString() ?? '';
        final data = m['data'];
        if (type.isEmpty) continue;
        final jsonData = data != null ? jsonEncode(data) : '[]';
        await _local.localPut(type, key, jsonData);
      }
    } catch (_) {}
  }

  // -------- Instituciones (compatible InstitucionesService) --------

  static const String _tInstituciones = 'instituciones';
  static const String _tLegajosDocente = 'legajos_docente';
  static const String _tLegajosSanidad = 'legajos_sanidad';
  static const String _tPlantillas = 'plantillas_cargo';
  static const String _tEmpresas = 'empresas';
  static const String _tPerfiles = 'perfiles_';
  static const String _tConvenios = 'convenios';
  static const String _tMaestroParitarias = 'maestro_paritarias';
  static const String _tMaestroParitariasSanidad = 'maestro_paritarias_sanidad';

  static Future<List<Map<String, dynamic>>> getInstituciones() async {
    final s = await _localGet(_tInstituciones, '');
    if (s == null || s.isEmpty) return [];
    try {
      final list = jsonDecode(s) as List?;
      return list?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [];
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveInstitucion(Map<String, dynamic> map) async {
    final cuit = _cuitLimpio(map['cuit']?.toString());
    if (cuit.length != 11 || !RegExp(r'^(20|30)\d{9}$').hasMatch(cuit)) return;
    final list = await getInstituciones();
    final i = list.indexWhere((e) => _cuitLimpio(e['cuit']?.toString()) == cuit);
    if (i >= 0) {
      list[i] = map;
    } else {
      list.add(map);
    }
    await _localPut(_tInstituciones, '', jsonEncode(list));
  }

  static Future<void> removeInstitucion(String cuit) async {
    final c = _cuitLimpio(cuit);
    if (c.isEmpty) return;
    final list = await getInstituciones();
    list.removeWhere((e) => _cuitLimpio(e['cuit']?.toString()) == c);
    await _localPut(_tInstituciones, '', jsonEncode(list));
  }

  // Perfiles por institución
  static Future<List<String>> getPerfilesInstitucion(String cuit) async {
    final c = _cuitLimpio(cuit);
    if (c.isEmpty) return [];
    final s = await _localGet(_tPerfiles + c, '');
    if (s == null || s.isEmpty) return [];
    try {
      final list = jsonDecode(s) as List?;
      return list?.map((e) => e.toString()).where((e) => e.isNotEmpty).toList() ?? [];
    } catch (_) {
      return [];
    }
  }

  static Future<void> addPerfilInstitucion(String cuit, String perfilCargoId) async {
    final c = _cuitLimpio(cuit);
    if (c.isEmpty || perfilCargoId.isEmpty) return;
    final list = await getPerfilesInstitucion(cuit);
    if (list.contains(perfilCargoId)) return;
    list.add(perfilCargoId);
    await _localPut(_tPerfiles + c, '', jsonEncode(list));
  }

  static Future<void> removePerfilInstitucion(String cuit, String perfilCargoId) async {
    final c = _cuitLimpio(cuit);
    if (c.isEmpty) return;
    final list = await getPerfilesInstitucion(cuit);
    list.remove(perfilCargoId);
    await _localPut(_tPerfiles + c, '', jsonEncode(list));
  }

  // Legajos Docente
  static Future<List<Map<String, dynamic>>> getLegajosDocente(String cuitInstitucion) async {
    final c = _cuitLimpio(cuitInstitucion);
    if (c.isEmpty) return [];
    final s = await _localGet(_tLegajosDocente, c);
    if (s == null || s.isEmpty) return [];
    try {
      final list = jsonDecode(s) as List?;
      return list?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [];
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveLegajoDocente(String cuitInstitucion, Map<String, dynamic> map) async {
    final c = _cuitLimpio(cuitInstitucion);
    if (c.isEmpty) return;
    final cuil = (map['cuil']?.toString() ?? '').replaceAll(RegExp(r'[^\d]'), '');
    if (cuil.length != 11) return;
    final list = await getLegajosDocente(cuitInstitucion);
    final i = list.indexWhere((e) => (e['cuil']?.toString() ?? '').replaceAll(RegExp(r'[^\d]'), '') == cuil);
    if (i >= 0) {
      list[i] = map;
    } else {
      list.add(map);
    }
    await _localPut(_tLegajosDocente, c, jsonEncode(list));
  }

  static Future<void> removeLegajoDocente(String cuitInstitucion, String cuilEmpleado) async {
    final c = _cuitLimpio(cuitInstitucion);
    if (c.isEmpty) return;
    final ce = (cuilEmpleado).replaceAll(RegExp(r'[^\d]'), '');
    final list = await getLegajosDocente(cuitInstitucion);
    list.removeWhere((e) => (e['cuil']?.toString() ?? '').replaceAll(RegExp(r'[^\d]'), '') == ce);
    await _localPut(_tLegajosDocente, c, jsonEncode(list));
  }

  // Legajos Sanidad
  static Future<List<Map<String, dynamic>>> getLegajosSanidad(String cuitInstitucion) async {
    final c = _cuitLimpio(cuitInstitucion);
    if (c.isEmpty) return [];
    final s = await _localGet(_tLegajosSanidad, c);
    if (s == null || s.isEmpty) return [];
    try {
      final list = jsonDecode(s) as List?;
      return list?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [];
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveLegajoSanidad(String cuitInstitucion, Map<String, dynamic> map) async {
    final c = _cuitLimpio(cuitInstitucion);
    if (c.isEmpty) return;
    final cuil = (map['cuil']?.toString() ?? '').replaceAll(RegExp(r'[^\d]'), '');
    if (cuil.length != 11) return;
    final list = await getLegajosSanidad(cuitInstitucion);
    final i = list.indexWhere((e) => (e['cuil']?.toString() ?? '').replaceAll(RegExp(r'[^\d]'), '') == cuil);
    if (i >= 0) {
      list[i] = map;
    } else {
      list.add(map);
    }
    await _localPut(_tLegajosSanidad, c, jsonEncode(list));
  }

  static Future<void> removeLegajoSanidad(String cuitInstitucion, String cuilEmpleado) async {
    final c = _cuitLimpio(cuitInstitucion);
    if (c.isEmpty) return;
    final ce = (cuilEmpleado).replaceAll(RegExp(r'[^\d]'), '');
    final list = await getLegajosSanidad(cuitInstitucion);
    list.removeWhere((e) => (e['cuil']?.toString() ?? '').replaceAll(RegExp(r'[^\d]'), '') == ce);
    await _localPut(_tLegajosSanidad, c, jsonEncode(list));
  }

  // Plantillas Cargo (compatible PlantillaCargoService)
  static Future<PlantillaCargoOmni?> getPlantillaByPerfilId(String perfilCargoId) async {
    if (perfilCargoId.isEmpty) return null;
    final s = await _localGet(_tPlantillas, '');
    if (s == null || s.isEmpty) return null;
    try {
      final map = jsonDecode(s) as Map?;
      if (map == null) return null;
      final data = map[perfilCargoId];
      if (data == null || data is! Map) return null;
      return PlantillaCargoOmni.fromMap(Map<String, dynamic>.from(data));
    } catch (_) {
      return null;
    }
  }

  static Future<void> savePlantilla(PlantillaCargoOmni p) async {
    if (p.perfilCargoId.isEmpty) return;
    Map<String, dynamic> map = {};
    final s = await _localGet(_tPlantillas, '');
    if (s != null && s.isNotEmpty) {
      try {
        final decoded = jsonDecode(s);
        if (decoded is Map) map = Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }
    map[p.perfilCargoId] = p.toMap();
    await _localPut(_tPlantillas, '', jsonEncode(map));
  }

  // Empresas (formato HomeScreen: List<Map<String,String>>)
  static Future<List<Map<String, String>>> getEmpresas() async {
    final s = await _localGet(_tEmpresas, '');
    if (s == null || s.isEmpty) return [];
    try {
      final list = jsonDecode(s) as List?;
      return list?.map((e) => Map<String, String>.from(e as Map)).toList() ?? [];
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveEmpresas(List<Map<String, String>> list) async {
    await _localPut(_tEmpresas, '', jsonEncode(list));
  }

  // Convenios (JSON array de ConvenioModel serializado)
  static Future<String?> getConveniosJson() async {
    return _localGet(_tConvenios, '');
  }

  static Future<void> saveConveniosJson(String json) async {
    await _localPut(_tConvenios, '', json);
  }

  // Maestro Paritarias
  static Future<List<Map<String, dynamic>>> getMaestroParitarias() async {
    final s = await _localGet(_tMaestroParitarias, '');
    if (s == null || s.isEmpty) return [];
    try {
      final list = jsonDecode(s) as List?;
      return list?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [];
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveMaestroParitarias(List<Map<String, dynamic>> list) async {
    await _localPut(_tMaestroParitarias, '', jsonEncode(list));
  }

  // Maestro Paritarias Sanidad (FATSA CCT 122/75, 108/75)
  static Future<List<Map<String, dynamic>>> getMaestroParitariasSanidad() async {
    final s = await _localGet(_tMaestroParitariasSanidad, '');
    if (s == null || s.isEmpty) return [];
    try {
      final list = jsonDecode(s) as List?;
      return list?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [];
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveMaestroParitariasSanidad(List<Map<String, dynamic>> list) async {
    await _localPut(_tMaestroParitariasSanidad, '', jsonEncode(list));
  }
}
