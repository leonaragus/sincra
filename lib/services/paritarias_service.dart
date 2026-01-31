import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:convert';
import '../models/teacher_types.dart'; // Añadido
import 'hybrid_store.dart';

class Paritaria {
  final String jurisdiccion;
  final String nombreMostrar;
  double valorIndice;
  final double pisoSalarial;
  final double montoFonid;
  final double montoConectividad;
  final double porcentajeAporteJub;
  final double porcentajeAporteOs;
  final String? fuenteLegal;
  final Map<String, dynamic> metadata; // Estructura: {"basico_portero": 600000, ...}
  final String updatedAt;

  Paritaria({
    required this.jurisdiccion,
    required this.nombreMostrar,
    required this.valorIndice,
    required this.pisoSalarial,
    required this.montoFonid,
    required this.montoConectividad,
    required this.porcentajeAporteJub,
    required this.porcentajeAporteOs,
    this.fuenteLegal,
    required this.metadata,
    required this.updatedAt,
  });

  factory Paritaria.fromMap(Map<String, dynamic> map) {
    return Paritaria(
      jurisdiccion: map['jurisdiccion'] ?? '',
      nombreMostrar: map['nombre_mostrar'] ?? '',
      valorIndice: (map['valor_indice'] as num?)?.toDouble() ?? 0.0,
      pisoSalarial: (map['piso_salarial'] as num?)?.toDouble() ?? 0.0,
      montoFonid: (map['monto_fonid'] as num?)?.toDouble() ?? 0.0,
      montoConectividad: (map['monto_conectividad'] as num?)?.toDouble() ?? 0.0,
      porcentajeAporteJub: (map['porcentaje_aporte_jub'] as num?)?.toDouble() ?? 11.0,
      porcentajeAporteOs: (map['porcentaje_aporte_os'] as num?)?.toDouble() ?? 3.0,
      fuenteLegal: map['fuente_legal'],
      metadata: map['metadata'] is Map ? map['metadata'] as Map<String, dynamic> : {},
      updatedAt: map['updated_at'] ?? '',
    );
  }
}

class ParitariasService {
  static const String _cacheKey = 'maestro_paritarias_cache';
  static const String _lastSyncKey = 'ultima_sincronizacion_paritarias';

  /// Sincroniza las paritarias desde Supabase y las guarda en local
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
          .from('maestro_paritarias')
          .select();

      final list = res as List;
      if (list.isNotEmpty) {
        await prefs.setString(_cacheKey, jsonEncode(list));
        final ahora = DateTime.now();
        await prefs.setString(_lastSyncKey, ahora.toIso8601String());
        
        // También actualizar el HybridStore para que el motor lo use
        await HybridStore.saveMaestroParitarias(list.cast<Map<String, dynamic>>());

        return {
          'success': true,
          'fecha': ahora,
          'modo': 'online',
          'data': list,
        };
      }
    } catch (e) {
      print('Error sincronizando paritarias Flutter: $e');
    }

    return {
      'success': false,
      'fecha': ultimaFecha,
      'modo': 'error',
      'data': await _getCachedData(),
    };
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
