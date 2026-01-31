import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:convert';
import 'hybrid_store.dart';
import 'auditoria_service.dart';

/// Modelo de paritaria/escalas para Sanidad (FATSA CCT 122/75, 108/75)
/// Federal: 24 jurisdicciones con valores diferenciados
class ParitariaSanidad {
  final String jurisdiccion;
  final String nombreMostrar;
  
  // Básicos por categoría (editables por el usuario)
  double basicoProfesional;
  double basicoTecnico;
  double basicoServicios;
  double basicoAdministrativo;
  double basicoMaestranza;
  
  // Porcentajes adicionales (editables)
  double antiguedadPctPorAno;      // 2% default
  double tituloAuxiliarPct;        // 5%
  double tituloTecnicoPct;         // 7%
  double tituloUniversitarioPct;   // 10%
  double tareaCriticaRiesgoPct;    // 10%
  double zonaPatagonicaPct;        // 20%
  double nocturnasPct;             // 15% por hora sobre valor hora
  
  // Montos fijos
  double montoFalloCaja;           // $20.000
  
  // Aportes y descuentos (editables)
  double jubilacionPct;            // 11%
  double ley19032Pct;              // 3%
  double obraSocialPct;            // 3%
  double cuotaSindicalAtsaPct;     // 2%
  double seguroSepelioPct;         // 1%
  double aporteSolidarioFatsaPct;  // 1%
  double topeBasePrevisional;      // $2.500.000
  
  // Metadata
  final String? fuenteLegal;
  final String updatedAt;
  final Map<String, dynamic> metadata;

  ParitariaSanidad({
    required this.jurisdiccion,
    required this.nombreMostrar,
    required this.basicoProfesional,
    required this.basicoTecnico,
    required this.basicoServicios,
    required this.basicoAdministrativo,
    required this.basicoMaestranza,
    this.antiguedadPctPorAno = 2.0,
    this.tituloAuxiliarPct = 5.0,
    this.tituloTecnicoPct = 7.0,
    this.tituloUniversitarioPct = 10.0,
    this.tareaCriticaRiesgoPct = 10.0,
    this.zonaPatagonicaPct = 20.0,
    this.nocturnasPct = 15.0,
    this.montoFalloCaja = 20000.0,
    this.jubilacionPct = 11.0,
    this.ley19032Pct = 3.0,
    this.obraSocialPct = 3.0,
    this.cuotaSindicalAtsaPct = 2.0,
    this.seguroSepelioPct = 1.0,
    this.aporteSolidarioFatsaPct = 1.0,
    this.topeBasePrevisional = 2500000.0,
    this.fuenteLegal,
    required this.updatedAt,
    this.metadata = const {},
  });

  factory ParitariaSanidad.fromMap(Map<String, dynamic> map) {
    return ParitariaSanidad(
      jurisdiccion: map['jurisdiccion'] ?? '',
      nombreMostrar: map['nombre_mostrar'] ?? '',
      basicoProfesional: (map['basico_profesional'] as num?)?.toDouble() ?? 850000.0,
      basicoTecnico: (map['basico_tecnico'] as num?)?.toDouble() ?? 680000.0,
      basicoServicios: (map['basico_servicios'] as num?)?.toDouble() ?? 580000.0,
      basicoAdministrativo: (map['basico_administrativo'] as num?)?.toDouble() ?? 520000.0,
      basicoMaestranza: (map['basico_maestranza'] as num?)?.toDouble() ?? 480000.0,
      antiguedadPctPorAno: (map['antiguedad_pct_por_ano'] as num?)?.toDouble() ?? 2.0,
      tituloAuxiliarPct: (map['titulo_auxiliar_pct'] as num?)?.toDouble() ?? 5.0,
      tituloTecnicoPct: (map['titulo_tecnico_pct'] as num?)?.toDouble() ?? 7.0,
      tituloUniversitarioPct: (map['titulo_universitario_pct'] as num?)?.toDouble() ?? 10.0,
      tareaCriticaRiesgoPct: (map['tarea_critica_riesgo_pct'] as num?)?.toDouble() ?? 10.0,
      zonaPatagonicaPct: (map['zona_patagonica_pct'] as num?)?.toDouble() ?? 20.0,
      nocturnasPct: (map['nocturnas_pct'] as num?)?.toDouble() ?? 15.0,
      montoFalloCaja: (map['monto_fallo_caja'] as num?)?.toDouble() ?? 20000.0,
      jubilacionPct: (map['jubilacion_pct'] as num?)?.toDouble() ?? 11.0,
      ley19032Pct: (map['ley_19032_pct'] as num?)?.toDouble() ?? 3.0,
      obraSocialPct: (map['obra_social_pct'] as num?)?.toDouble() ?? 3.0,
      cuotaSindicalAtsaPct: (map['cuota_sindical_atsa_pct'] as num?)?.toDouble() ?? 2.0,
      seguroSepelioPct: (map['seguro_sepelio_pct'] as num?)?.toDouble() ?? 1.0,
      aporteSolidarioFatsaPct: (map['aporte_solidario_fatsa_pct'] as num?)?.toDouble() ?? 1.0,
      topeBasePrevisional: (map['tope_base_previsional'] as num?)?.toDouble() ?? 2500000.0,
      fuenteLegal: map['fuente_legal'],
      updatedAt: map['updated_at'] ?? '',
      metadata: map['metadata'] is Map ? map['metadata'] as Map<String, dynamic> : {},
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'jurisdiccion': jurisdiccion,
      'nombre_mostrar': nombreMostrar,
      'basico_profesional': basicoProfesional,
      'basico_tecnico': basicoTecnico,
      'basico_servicios': basicoServicios,
      'basico_administrativo': basicoAdministrativo,
      'basico_maestranza': basicoMaestranza,
      'antiguedad_pct_por_ano': antiguedadPctPorAno,
      'titulo_auxiliar_pct': tituloAuxiliarPct,
      'titulo_tecnico_pct': tituloTecnicoPct,
      'titulo_universitario_pct': tituloUniversitarioPct,
      'tarea_critica_riesgo_pct': tareaCriticaRiesgoPct,
      'zona_patagonica_pct': zonaPatagonicaPct,
      'nocturnas_pct': nocturnasPct,
      'monto_fallo_caja': montoFalloCaja,
      'jubilacion_pct': jubilacionPct,
      'ley_19032_pct': ley19032Pct,
      'obra_social_pct': obraSocialPct,
      'cuota_sindical_atsa_pct': cuotaSindicalAtsaPct,
      'seguro_sepelio_pct': seguroSepelioPct,
      'aporte_solidario_fatsa_pct': aporteSolidarioFatsaPct,
      'tope_base_previsional': topeBasePrevisional,
      'fuente_legal': fuenteLegal,
      'updated_at': updatedAt,
      'metadata': metadata,
    };
  }

  /// Básicos por defecto para jurisdicciones patagónicas (20% más altos)
  static ParitariaSanidad defaultPatagonica(String jurisdiccion, String nombreMostrar) {
    return ParitariaSanidad(
      jurisdiccion: jurisdiccion,
      nombreMostrar: nombreMostrar,
      basicoProfesional: 1020000.0,  // +20%
      basicoTecnico: 816000.0,
      basicoServicios: 696000.0,
      basicoAdministrativo: 624000.0,
      basicoMaestranza: 576000.0,
      zonaPatagonicaPct: 20.0,
      updatedAt: DateTime.now().toIso8601String(),
      fuenteLegal: 'FATSA CCT 122/75 - Paritarias 2026',
    );
  }

  /// Básicos por defecto para jurisdicciones normales
  static ParitariaSanidad defaultNormal(String jurisdiccion, String nombreMostrar) {
    return ParitariaSanidad(
      jurisdiccion: jurisdiccion,
      nombreMostrar: nombreMostrar,
      basicoProfesional: 850000.0,
      basicoTecnico: 680000.0,
      basicoServicios: 580000.0,
      basicoAdministrativo: 520000.0,
      basicoMaestranza: 480000.0,
      zonaPatagonicaPct: 0.0,
      updatedAt: DateTime.now().toIso8601String(),
      fuenteLegal: 'FATSA CCT 122/75 - Paritarias 2026',
    );
  }
}

/// Servicio para gestionar paritarias/escalas de Sanidad
/// Sincroniza con Supabase y permite edición local
class SanidadParitariasService {
  static const String _cacheKey = 'maestro_paritarias_sanidad_cache';
  static const String _lastSyncKey = 'ultima_sincronizacion_paritarias_sanidad';

  /// Las 24 jurisdicciones argentinas
  static const List<Map<String, String>> jurisdicciones = [
    {'key': 'buenosAires', 'nombre': 'Buenos Aires'},
    {'key': 'caba', 'nombre': 'Ciudad Autónoma de Buenos Aires'},
    {'key': 'catamarca', 'nombre': 'Catamarca'},
    {'key': 'chaco', 'nombre': 'Chaco'},
    {'key': 'chubut', 'nombre': 'Chubut'},
    {'key': 'cordoba', 'nombre': 'Córdoba'},
    {'key': 'corrientes', 'nombre': 'Corrientes'},
    {'key': 'entreRios', 'nombre': 'Entre Ríos'},
    {'key': 'formosa', 'nombre': 'Formosa'},
    {'key': 'jujuy', 'nombre': 'Jujuy'},
    {'key': 'laPampa', 'nombre': 'La Pampa'},
    {'key': 'laRioja', 'nombre': 'La Rioja'},
    {'key': 'mendoza', 'nombre': 'Mendoza'},
    {'key': 'misiones', 'nombre': 'Misiones'},
    {'key': 'neuquen', 'nombre': 'Neuquén'},
    {'key': 'rioNegro', 'nombre': 'Río Negro'},
    {'key': 'salta', 'nombre': 'Salta'},
    {'key': 'sanJuan', 'nombre': 'San Juan'},
    {'key': 'sanLuis', 'nombre': 'San Luis'},
    {'key': 'santaCruz', 'nombre': 'Santa Cruz'},
    {'key': 'santaFe', 'nombre': 'Santa Fe'},
    {'key': 'santiagoDelEstero', 'nombre': 'Santiago del Estero'},
    {'key': 'tierraDelFuego', 'nombre': 'Tierra del Fuego'},
    {'key': 'tucuman', 'nombre': 'Tucumán'},
  ];

  /// Jurisdicciones patagónicas (aplica +20% zona patagónica)
  static const List<String> jurisdiccionesPatagonicas = [
    'chubut',
    'neuquen',
    'rioNegro',
    'santaCruz',
    'tierraDelFuego',
    'laPampa', // Sur de La Pampa
  ];

  /// Genera las 24 jurisdicciones con valores por defecto
  static List<ParitariaSanidad> generarDefaultCompleto() {
    return jurisdicciones.map((j) {
      final key = j['key']!;
      final nombre = j['nombre']!;
      final esPatagonica = jurisdiccionesPatagonicas.contains(key);
      return esPatagonica 
        ? ParitariaSanidad.defaultPatagonica(key, nombre)
        : ParitariaSanidad.defaultNormal(key, nombre);
    }).toList();
  }

  /// Sincroniza las paritarias de sanidad desde Supabase y las guarda en local
  static Future<Map<String, dynamic>> sincronizarParitarias() async {
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
          .from('maestro_paritarias_sanidad')
          .select();

      final list = res as List;
      if (list.isNotEmpty) {
        await prefs.setString(_cacheKey, jsonEncode(list));
        final ahora = DateTime.now();
        await prefs.setString(_lastSyncKey, ahora.toIso8601String());
        
        // También actualizar el HybridStore para que el motor lo use
        await HybridStore.saveMaestroParitariasSanidad(list.cast<Map<String, dynamic>>());

        return {
          'success': true,
          'fecha': ahora,
          'modo': 'online',
          'data': list,
        };
      } else {
        // Si la tabla está vacía en Supabase, usar valores por defecto
        final defaults = generarDefaultCompleto().map((p) => p.toMap()).toList();
        await prefs.setString(_cacheKey, jsonEncode(defaults));
        await HybridStore.saveMaestroParitariasSanidad(defaults);
        
        return {
          'success': true,
          'fecha': DateTime.now(),
          'modo': 'default',
          'data': defaults,
        };
      }
    } catch (e) {
      print('Error sincronizando paritarias sanidad: $e');
      
      // Si hay error, intentar usar datos cacheados o generar defaults
      final cached = await _getCachedData();
      if (cached.isEmpty) {
        // Generar valores por defecto
        final defaults = generarDefaultCompleto().map((p) => p.toMap()).toList();
        await prefs.setString(_cacheKey, jsonEncode(defaults));
        await HybridStore.saveMaestroParitariasSanidad(defaults);
        return {
          'success': false,
          'fecha': ultimaFecha,
          'modo': 'default',
          'data': defaults,
        };
      }
      
      return {
        'success': false,
        'fecha': ultimaFecha,
        'modo': 'error',
        'data': cached,
      };
    }
  }

  /// Obtiene datos cacheados localmente
  static Future<List<dynamic>> _getCachedData() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_cacheKey);
    if (cached != null) {
      return jsonDecode(cached) as List;
    }
    return [];
  }

  /// Obtiene la fecha de última sincronización
  static Future<DateTime?> obtenerFechaUltimaSincronizacion() async {
    final prefs = await SharedPreferences.getInstance();
    final lastSyncStr = prefs.getString(_lastSyncKey);
    return lastSyncStr != null ? DateTime.tryParse(lastSyncStr) : null;
  }

  /// Obtiene todas las paritarias (desde cache local)
  static Future<List<ParitariaSanidad>> obtenerParitarias() async {
    final list = await HybridStore.getMaestroParitariasSanidad();
    if (list.isEmpty) {
      // Si no hay datos, sincronizar primero
      await sincronizarParitarias();
      final newList = await HybridStore.getMaestroParitariasSanidad();
      return newList.map((e) => ParitariaSanidad.fromMap(e)).toList();
    }
    return list.map((e) => ParitariaSanidad.fromMap(e)).toList();
  }

  /// Obtiene paritaria de una jurisdicción específica
  static Future<ParitariaSanidad?> obtenerPorJurisdiccion(String jurisdiccion) async {
    final list = await obtenerParitarias();
    return list.cast<ParitariaSanidad?>().firstWhere(
      (p) => p?.jurisdiccion == jurisdiccion,
      orElse: () => null,
    );
  }

  /// Actualiza una paritaria de sanidad SOLO localmente (sin afectar a otros usuarios)
  static Future<void> actualizarParitariaProvincial(String jurisdiccion, Map<String, dynamic> data) async {
    // 1. Obtener las paritarias actuales del cache
    final list = await HybridStore.getMaestroParitariasSanidad();
    
    // 2. Obtener valores anteriores para auditoría
    final valoresAnteriores = list.firstWhere(
      (p) => p['jurisdiccion'] == jurisdiccion,
      orElse: () => <String, dynamic>{},
    );
    
    // 3. Buscar y actualizar la jurisdicción
    final newList = list.map((p) {
      if (p['jurisdiccion'] == jurisdiccion) {
        return { ...p, ...data, 'updated_at': DateTime.now().toIso8601String() };
      }
      return p;
    }).toList();

    // 4. Si la jurisdicción no existía, agregarla
    final esNueva = !list.any((p) => p['jurisdiccion'] == jurisdiccion);
    if (esNueva) {
      newList.add({
        'jurisdiccion': jurisdiccion,
        ...data,
        'updated_at': DateTime.now().toIso8601String(),
      });
    }

    // 5. AUDITORÍA: Registrar el cambio
    final nombreJuris = jurisdicciones.firstWhere(
      (j) => j['key'] == jurisdiccion,
      orElse: () => {'nombre': jurisdiccion},
    )['nombre'] as String;
    
    await AuditoriaService.registrarCambio(
      modulo: 'sanidad',
      accion: esNueva ? 'crear_paritaria' : 'modificar_paritaria',
      entidad: 'Paritaria Sanidad $nombreJuris',
      valoresAnteriores: valoresAnteriores,
      valoresNuevos: data,
      observaciones: esNueva ? 'Creación de nueva paritaria' : 'Modificación de escala salarial',
    );

    // 6. Guardar en HybridStore (SharedPreferences local)
    await HybridStore.saveMaestroParitariasSanidad(newList.cast<Map<String, dynamic>>());
    
    // 7. Actualizar también el cache secundario
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(newList));
    } catch (e) {
      print('Error actualizando cache secundario sanidad: $e');
    }
  }

  /// Resetea una jurisdicción a valores por defecto
  static Future<void> resetearJurisdiccion(String jurisdiccion) async {
    final jInfo = jurisdicciones.firstWhere(
      (j) => j['key'] == jurisdiccion,
      orElse: () => {'key': jurisdiccion, 'nombre': jurisdiccion},
    );
    
    final esPatagonica = jurisdiccionesPatagonicas.contains(jurisdiccion);
    final defaultData = esPatagonica
      ? ParitariaSanidad.defaultPatagonica(jurisdiccion, jInfo['nombre']!)
      : ParitariaSanidad.defaultNormal(jurisdiccion, jInfo['nombre']!);
    
    await actualizarParitariaProvincial(jurisdiccion, defaultData.toMap());
  }

  /// Resetea todas las jurisdicciones a valores por defecto
  static Future<void> resetearTodo() async {
    final defaults = generarDefaultCompleto().map((p) => p.toMap()).toList();
    await HybridStore.saveMaestroParitariasSanidad(defaults);
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cacheKey, jsonEncode(defaults));
  }
}
