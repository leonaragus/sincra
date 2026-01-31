import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/convenio_model.dart';

/// Estado del último intento de sincronización.
class SyncStatus {
  final bool success;
  final DateTime? lastSyncDate;
  final DateTime? dataUpdateDate;

  const SyncStatus({
    required this.success,
    this.lastSyncDate,
    this.dataUpdateDate,
  });

  bool get isActualizadoHoy {
    if (lastSyncDate == null) return false;
    final now = DateTime.now();
    return lastSyncDate!.year == now.year &&
        lastSyncDate!.month == now.month &&
        lastSyncDate!.day == now.day;
  }

  /// Formato DD/MM/YYYY para el SnackBar.
  String get dataUpdateDateFormatted {
    if (dataUpdateDate == null) return '';
    final d = dataUpdateDate!;
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }
}

/// Servicio de sincronización de convenios desde URL externa.
/// Descarga JSON, persiste en local y permite uso offline.
class ApiService {
  ApiService._();

  static const String _conveniosUrl =
      'https://gist.githubusercontent.com/leonaragus/02f28c5630ab5795135cb96712e607ce/raw/d22855446d8c84d71dccfaa4816d113c0df4b96e/convenios.json';

  static const String _keyJson = 'convenios_update_json';
  static const String _keyLastSync = 'convenios_last_sync_date';
  static const String _keyDataUpdateDate = 'convenios_data_update_date';
  static const String _keySuccess = 'convenios_last_sync_success';
  static const String _keyShouldShowSnackBar = 'convenios_show_snackbar';
  static const String _keySnackBarDate = 'convenios_snackbar_date';

  static SyncStatus _lastStatus = const SyncStatus(success: false);

  static String _effectiveUrl = _conveniosUrl;
  static String get conveniosUpdateUrl => _effectiveUrl;

  static void setUpdateUrl(String url) {
    _effectiveUrl = url;
  }

  static SyncStatus get lastSyncStatus => _lastStatus;

  /// Intenta descargar desde la URL. Compara ultimaActualizacion del JSON
  /// con la guardada: solo actualiza locales si el JSON es más reciente.
  /// Si falla, carga desde local.
  static Future<List<ConvenioModel>> syncOrLoadLocal() async {
    try {
      final list = await _fetchFromRemote();
      final remoteDate = _maxUltimaActualizacion(list);
      final storedDate = await _getStoredDataUpdateDate();

      final debeActualizar =
          storedDate == null || (remoteDate != null && remoteDate.isAfter(storedDate));

      if (debeActualizar && list.isNotEmpty) {
        await _saveToLocal(list, remoteDate);
        await _markShowSnackBar(remoteDate);
        _lastStatus = SyncStatus(
          success: true,
          lastSyncDate: DateTime.now(),
          dataUpdateDate: remoteDate,
        );
        return list;
      }

      final local = await loadFromLocal();
      _lastStatus = SyncStatus(
        success: true,
        lastSyncDate: await _getStoredSyncDate(),
        dataUpdateDate: storedDate,
      );
      return local;
    } catch (_) {
      final local = await loadFromLocal();
      _lastStatus = SyncStatus(
        success: false,
        lastSyncDate: await _getStoredSyncDate(),
        dataUpdateDate: await _getStoredDataUpdateDate(),
      );
      return local;
    }
  }

  static DateTime? _maxUltimaActualizacion(List<ConvenioModel> list) {
    if (list.isEmpty) return null;
    DateTime? max;
    for (final e in list) {
      if (max == null || e.ultimaActualizacion.isAfter(max)) {
        max = e.ultimaActualizacion;
      }
    }
    return max;
  }

  static Future<void> _markShowSnackBar(DateTime? date) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyShouldShowSnackBar, true);
    if (date != null) {
      await prefs.setString(_keySnackBarDate, date.toIso8601String());
    }
  }

  static Future<bool> shouldShowUpdateSnackBar() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyShouldShowSnackBar) ?? false;
  }

  static Future<String?> getUpdateSnackBarDate() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_keySnackBarDate);
    if (s == null) return null;
    final d = DateTime.tryParse(s);
    if (d == null) return null;
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  static Future<void> clearShowUpdateSnackBar() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyShouldShowSnackBar);
    await prefs.remove(_keySnackBarDate);
  }

  static Future<List<ConvenioModel>> _fetchFromRemote() async {
    final response = await http.get(Uri.parse(_effectiveUrl)).timeout(
      const Duration(seconds: 15),
      onTimeout: () => throw Exception('Timeout'),
    );
    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }
    return _parseJson(response.body);
  }

  static List<ConvenioModel> _parseJson(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! List<dynamic>) {
      throw Exception('Se esperaba un JSON array');
    }
    return decoded
        .map((e) => ConvenioModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<void> _saveToLocal(
    List<ConvenioModel> list,
    DateTime? dataUpdateDate,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(list.map((e) => e.toJson()).toList());
    await prefs.setString(_keyJson, encoded);
    await prefs.setString(_keyLastSync, DateTime.now().toIso8601String());
    await prefs.setBool(_keySuccess, true);
    if (dataUpdateDate != null) {
      await prefs.setString(
        _keyDataUpdateDate,
        dataUpdateDate.toIso8601String(),
      );
    }
  }

  static Future<DateTime?> _getStoredDataUpdateDate() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_keyDataUpdateDate);
    if (s == null) return null;
    return DateTime.tryParse(s);
  }

  static Future<DateTime?> _getStoredSyncDate() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_keyLastSync);
    if (s == null) return null;
    return DateTime.tryParse(s);
  }

  /// Carga convenios desde almacenamiento local.
  static Future<List<ConvenioModel>> loadFromLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyJson);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((e) => ConvenioModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }
}
