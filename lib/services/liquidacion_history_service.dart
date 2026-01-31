import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import '../models/teacher_types.dart';
import 'teacher_omni_engine.dart';

class LiquidacionHistoryService {
  static final _supabase = Supabase.instance.client;

  /// Guarda una liquidación en el historial (syncra_entities para offline-first)
  static Future<bool> guardarLiquidacion({
    required String cuitInstitucion,
    required LiquidacionOmniResult liquidacion,
  }) async {
    try {
      final cuit = cuitInstitucion.replaceAll(RegExp(r'[^\d]'), '');
      final cuil = liquidacion.input.cuil.replaceAll(RegExp(r'[^\d]'), '');
      
      // La clave será CUIT_CUIL_PERIODO (ej: 30123456789_20123456789_2026-06)
      final periodoKey = liquidacion.periodo.replaceAll(' ', '_').toLowerCase();
      final key = "${cuit}_${cuil}_$periodoKey";

      await _supabase.from('syncra_entities').upsert({
        'type': 'historico_liquidaciones',
        'key': key,
        'data': liquidacion.toJson(),
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'type,key');

      return true;
    } catch (e) {
      print("Error al guardar en historial: $e");
      return false;
    }
  }

  /// Recupera el historial de un empleado para el cálculo del SAC
  static Future<List<LiquidacionOmniResult>> obtenerHistorialSemestre({
    required String cuitInstitucion,
    required String cuilEmpleado,
    required int anio,
    required int semestre, // 1 o 2
  }) async {
    try {
      final cuit = cuitInstitucion.replaceAll(RegExp(r'[^\d]'), '');
      final cuil = cuilEmpleado.replaceAll(RegExp(r'[^\d]'), '');
      
      final response = await _supabase
          .from('syncra_entities')
          .select('data')
          .eq('type', 'historico_liquidaciones')
          .like('key', '${cuit}_${cuil}_%');
      
      if (response == null || response.isEmpty) return [];

      List<LiquidacionOmniResult> resultados = [];
      for (var item in (response as List)) {
        final liq = LiquidacionOmniResult.fromJson(item['data']);
        // Filtrar por semestre aquí si es necesario
        resultados.add(liq);
      }
      
      return resultados;
    } catch (e) {
      print("Error al recuperar historial: $e");
      return [];
    }
  }
}
