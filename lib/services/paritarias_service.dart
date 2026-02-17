import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:convert';
import 'hybrid_store.dart';

/// Estado del último intento de sincronización de paritarias.
class ParitariasSyncStatus {
  final bool success;
  final DateTime? lastSyncDate;
  final DateTime? dataUpdateDate;

  const ParitariasSyncStatus({
    required this.success,
    this.lastSyncDate,
    this.dataUpdateDate,
  });

  /// Formato DD/MM/YYYY para el SnackBar.
  String get dataUpdateDateFormatted {
    if (dataUpdateDate == null) return '';
    final d = dataUpdateDate!;
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  /// Formato DD/MM/YYYY del último intento de sincronización.
  String get lastSyncDateFormatted {
    if (lastSyncDate == null) return '';
    final d = lastSyncDate!;
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }
}

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

  static ParitariasSyncStatus _lastSyncStatus = const ParitariasSyncStatus(success: false);

  static ParitariasSyncStatus get lastSyncStatus => _lastSyncStatus;

  /// Sincroniza las paritarias desde Supabase y las guarda en local
  static Future<Map<String, dynamic>> sincronizarParitarias() async {
    _lastSyncStatus = const ParitariasSyncStatus(success: false); // Reset status at start

    final connectivity = await Connectivity().checkConnectivity();
    final isOnline = connectivity.isNotEmpty && connectivity.first != ConnectivityResult.none;

    final prefs = await SharedPreferences.getInstance();
    final lastSyncStr = prefs.getString(_lastSyncKey);
    DateTime? ultimaFecha = lastSyncStr != null ? DateTime.tryParse(lastSyncStr) : null;

    if (!isOnline) {
      _lastSyncStatus = ParitariasSyncStatus(
        success: false,
        lastSyncDate: ultimaFecha, // Last recorded sync date
        dataUpdateDate: _lastSyncStatus.dataUpdateDate, // Keep previous if any
      );
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

        // Determine the latest data update date from the fetched list
        DateTime? latestDataUpdate;
        // Assuming 'updated_at' in the map is a string that can be parsed to DateTime.
        latestDataUpdate = list
            .map((item) => DateTime.tryParse(item['updated_at'] ?? ''))
            .whereType<DateTime>()
            .fold<DateTime?>(null, (prev, current) => prev == null || current.isAfter(prev) ? current : prev);

        _lastSyncStatus = ParitariasSyncStatus(
          success: true,
          lastSyncDate: ahora,
          dataUpdateDate: latestDataUpdate,
        );

        return {
          'success': true,
          'fecha': ahora,
          'modo': 'online',
          'data': list,
        };
      }
      // If list is empty, it falls through to the final return, which is 'success: false, modo: error'.
      // This matches the original behavior.
    } catch (e) {
      print('Error sincronizando paritarias Flutter: $e');
      _lastSyncStatus = ParitariasSyncStatus(
        success: false,
        lastSyncDate: DateTime.now(), // Sync attempt happened now, but failed
        dataUpdateDate: _lastSyncStatus.dataUpdateDate, // Keep previous data update date if sync fails
      );
    }

    // This return is for error case (from catch) or if list was empty (from try).
    _lastSyncStatus = ParitariasSyncStatus(
      success: false,
      lastSyncDate: DateTime.now(), // Sync attempt happened now, but failed
      dataUpdateDate: _lastSyncStatus.dataUpdateDate, // Keep previous data update date if sync fails
    );
    return {
      'success': false,
      'fecha': ultimaFecha, // This should be the last successful sync date, not now.
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
