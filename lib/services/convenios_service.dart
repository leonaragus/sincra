
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/cct_argentina_completo.dart';
import '../models/cct_completo.dart';

/// =======================================================================
/// SERVICIO DE GESTIÓN DE CONVENIOS (CCT)
/// Provee una capa de abstracción para la obtención y persistencia de
/// los Convenios Colectivos de Trabajo.
///
/// Implementa una estrategia de caché local con SharedPreferences, usando
/// un archivo estático como 'semilla' inicial.
/// =======================================================================

class ConveniosService {
  static const String _storageKey = 'user_convenios_list';
  static const String _seedDoneKey = 'convenios_seed_done';

  /// Inicializa el servicio.
  /// Si es la primera vez que se ejecuta, carga los convenios base (semilla)
  /// en el almacenamiento persistente.
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final isSeeded = prefs.getBool(_seedDoneKey) ?? false;

    if (!isSeeded) {
      // Carga los convenios del archivo estático y los guarda en SharedPreferences.
      // Esto solo ocurre una vez en la vida de la aplicación.
      final List<CCTCompleto> baseConvenios = cctArgentinaCompleto;
      await _saveConveniosToPrefs(baseConvenios);
      await prefs.setBool(_seedDoneKey, true);
    }
  }

  /// Obtiene la lista completa de convenios desde el almacenamiento local.
  static Future<List<CCTCompleto>> getConvenios() async {
    await init(); // Asegurarse de que la semilla inicial esté cargada.
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_storageKey);

    if (jsonString != null) {
      try {
        final List<dynamic> jsonList = jsonDecode(jsonString);
        return jsonList.map((json) => CCTCompleto.fromJson(json)).toList();
      } catch (e) {
        // En caso de error de deserialización, retorna una lista vacía.
        print('Error deserializando convenios desde SharedPreferences: $e');
        return [];
      }
    }
    // Si no hay nada en SharedPreferences, retorna una lista vacía.
    return [];
  }

  /// Guarda un único convenio.
  /// Si el convenio ya existe (mismo ID), lo actualiza.
  /// Si es nuevo, lo agrega a la lista.
  static Future<void> saveConvenio(CCTCompleto convenioToSave) async {
    final List<CCTCompleto> currentConvenios = await getConvenios();
    final int existingIndex = currentConvenios.indexWhere((c) => c.id == convenioToSave.id);

    if (existingIndex != -1) {
      // Actualiza el convenio existente.
      currentConvenios[existingIndex] = convenioToSave;
    } else {
      // Agrega el nuevo convenio al inicio de la lista.
      currentConvenios.insert(0, convenioToSave);
    }

    await _saveConveniosToPrefs(currentConvenios);
  }

  /// Elimina un convenio basado en su ID.
  static Future<void> deleteConvenio(String convenioId) async {
    final List<CCTCompleto> currentConvenios = await getConvenios();
    currentConvenios.removeWhere((c) => c.id == convenioId);
    await _saveConveniosToPrefs(currentConvenios);
  }
  
  /// Devuelve un convenio específico por su ID
  static Future<CCTCompleto?> getConvenioById(String id) async {
    final convenios = await getConvenios();
    try {
      return convenios.firstWhere((c) => c.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Función privada para guardar la lista completa de convenios en SharedPreferences.
  static Future<void> _saveConveniosToPrefs(List<CCTCompleto> convenios) async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final List<Map<String, dynamic>> jsonList = convenios.map((c) => c.toJson()).toList();
      final jsonString = jsonEncode(jsonList);
      await prefs.setString(_storageKey, jsonString);
    } catch (e) {
      print('Error serializando convenios para SharedPreferences: $e');
      // Manejar el error apropiadamente, quizás con un log más robusto.
    }
  }
}
