// Servicio de persistencia para Instituciones y Legajos (Docente / Sanidad)
// Delega en HybridStore: local-first + sync Supabase en background. Multi-dispositivo.

import 'hybrid_store.dart';

class InstitucionesService {
  static String _cuitLimpio(String? cuit) {
    if (cuit == null || cuit.isEmpty) return '';
    return cuit.replaceAll(RegExp(r'[^\d]'), '');
  }

  static Future<List<Map<String, dynamic>>> getInstituciones() async =>
      HybridStore.getInstituciones();

  /// Guarda o actualiza una institución. [map] con cuit, razonSocial, domicilio, etc.
  static Future<void> saveInstitucion(Map<String, dynamic> map) async {
    final cuit = _cuitLimpio(map['cuit']?.toString());
    if (cuit.length != 11 || !RegExp(r'^(20|30)\d{9}$').hasMatch(cuit)) return;
    final artPct = map['artPct'] != null
        ? ((map['artPct'] is num) ? (map['artPct'] as num).toDouble() : double.tryParse(map['artPct'].toString()) ?? 3.5)
        : 3.5;
    final artCuotaFija = map['artCuotaFija'] != null
        ? ((map['artCuotaFija'] is num) ? (map['artCuotaFija'] as num).toDouble() : double.tryParse(map['artCuotaFija'].toString()) ?? 800.0)
        : 800.0;
    final seguroVida = map['seguroVidaObligatorio'] != null
        ? ((map['seguroVidaObligatorio'] is num) ? (map['seguroVidaObligatorio'] as num).toDouble() : double.tryParse(map['seguroVidaObligatorio'].toString()) ?? 0.0)
        : 0.0;
    final listaConceptos = map['listaConceptosPropios'];
    final List<dynamic> listConceptos = listaConceptos is List
        ? listaConceptos.map((e) => e is Map ? e : <String, dynamic>{}).toList()
        : [];
    final data = {
      'cuit': map['cuit']?.toString() ?? '',
      'razonSocial': map['razonSocial']?.toString() ?? '',
      'domicilio': map['domicilio']?.toString() ?? '',
      'jurisdiccion': map['jurisdiccion']?.toString() ?? 'buenosAires',
      'tipoGestion': map['tipoGestion']?.toString() ?? 'publica',
      'zonaDefault': map['zonaDefault']?.toString() ?? 'a',
      'regimenPrevisional': map['regimenPrevisional']?.toString() ?? 'provincial',
      'artPct': artPct,
      'artCuotaFija': artCuotaFija,
      'seguroVidaObligatorio': seguroVida,
      'listaConceptosPropios': listConceptos,
      'codigoDIEGEP': map['codigoDIEGEP']?.toString(),
      'aporteJubilatorio': map['aporteJubilatorio'] != null
          ? ((map['aporteJubilatorio'] is num) ? (map['aporteJubilatorio'] as num).toDouble() : double.tryParse(map['aporteJubilatorio'].toString()))
          : null,
      'aplicaItemAula': map['aplicaItemAula'] == true,
      'aporteMunicipal': map['aporteMunicipal'] != null
          ? ((map['aporteMunicipal'] is num) ? (map['aporteMunicipal'] as num).toDouble() : double.tryParse(map['aporteMunicipal'].toString()))
          : null,
      'zonaPatagonica': map['zonaPatagonica'] == true,
      'aporteCajaProvincial': map['aporteCajaProvincial'] != null
          ? ((map['aporteCajaProvincial'] is num) ? (map['aporteCajaProvincial'] as num).toDouble() : double.tryParse(map['aporteCajaProvincial'].toString()))
          : null,
      'asistenciaPerfecta': map['asistenciaPerfecta'] == true,
    };
    await HybridStore.saveInstitucion(data);
  }

  static Future<List<String>> getPerfilesInstitucion(String cuit) async =>
      HybridStore.getPerfilesInstitucion(cuit);
  static Future<void> addPerfilInstitucion(String cuit, String perfilCargoId) async =>
      HybridStore.addPerfilInstitucion(cuit, perfilCargoId);
  static Future<void> removePerfilInstitucion(String cuit, String perfilCargoId) async =>
      HybridStore.removePerfilInstitucion(cuit, perfilCargoId);
  static Future<void> removeInstitucion(String cuit) async =>
      HybridStore.removeInstitucion(cuit);

  static Future<List<Map<String, dynamic>>> getLegajosDocente(String cuitInstitucion) async =>
      HybridStore.getLegajosDocente(cuitInstitucion);
  static Future<void> saveLegajoDocente(String cuitInstitucion, Map<String, dynamic> map) async =>
      HybridStore.saveLegajoDocente(cuitInstitucion, map);
  static Future<void> removeLegajoDocente(String cuitInstitucion, String cuilEmpleado) async =>
      HybridStore.removeLegajoDocente(cuitInstitucion, cuilEmpleado);

  static Future<List<Map<String, dynamic>>> getLegajosSanidad(String cuitInstitucion) async =>
      HybridStore.getLegajosSanidad(cuitInstitucion);
  static Future<void> saveLegajoSanidad(String cuitInstitucion, Map<String, dynamic> map) async =>
      HybridStore.saveLegajoSanidad(cuitInstitucion, map);
  static Future<void> removeLegajoSanidad(String cuitInstitucion, String cuilEmpleado) async =>
      HybridStore.removeLegajoSanidad(cuitInstitucion, cuilEmpleado);
}
