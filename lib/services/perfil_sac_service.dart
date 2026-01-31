// Perfiles de ítems extras para liquidación SAC. Persistencia en SharedPreferences.

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class PerfilSacService {
  static const String _key = 'perfiles_sac';

  static Future<List<Map<String, dynamic>>> getPerfiles() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_key);
    if (s == null || s.isEmpty) return [];
    try {
      final list = jsonDecode(s) as List<dynamic>?;
      return list == null
          ? []
          : list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> savePerfil({required String nombre, required List items}) async {
    final list = await getPerfiles();
    final i = list.indexWhere((e) => (e['nombre']?.toString() ?? '') == nombre);
    final data = {'nombre': nombre, 'items': items};
    if (i >= 0) {
      list[i] = data;
    } else {
      list.add(data);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(list));
  }
}
