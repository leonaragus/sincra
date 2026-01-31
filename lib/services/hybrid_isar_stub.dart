/// Stub para Web: Isar no disponible. Usa SharedPreferences.
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

bool get isUseIsar => false;

Future<void> initIsar(String directory) async {}

Future<void> localPut(String type, String key, String jsonData) async {
  final prefs = await SharedPreferences.getInstance();
  final k = 'hybrid_${type}_$key';
  await prefs.setString(k, jsonEncode({'json': jsonData, 'updatedAt': DateTime.now().toIso8601String()}));
}

Future<String?> localGet(String type, String key) async {
  final prefs = await SharedPreferences.getInstance();
  final k = 'hybrid_${type}_$key';
  final s = prefs.getString(k);
  if (s == null) return null;
  try {
    final m = jsonDecode(s) as Map?;
    return m?['json'] as String?;
  } catch (_) {
    return null;
  }
}

Future<void> localRemove(String type, String key) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove('hybrid_${type}_$key');
}
