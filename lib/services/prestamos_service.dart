
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:convert';
import '../models/prestamo.dart';

class PrestamosService {
  static const String _cacheKeyPrefix = 'prestamos_empresa_';
  static const String _pendingSyncKey = 'prestamos_pending_sync';

  // ... (métodos crearPrestamo y registrarCuotaPagada se mantienen igual)
  static Future<Prestamo> crearPrestamo({
    required String empleadoCuil,
    required String empresaCuit,
    required double montoTotal,
    required int cantidadCuotas,
    double tasaInteres = 0.0,
    DateTime? fechaOtorgamiento,
    DateTime? fechaPrimeraCuota,
    String? motivoPrestamo,
    String? creadoPor,
  }) async {
    final valorCuota = Prestamo.calcularCuota(
      montoTotal: montoTotal,
      tasaInteres: tasaInteres,
      cantidadCuotas: cantidadCuotas,
    );
    
    final prestamo = Prestamo(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      empleadoCuil: empleadoCuil,
      empresaCuit: empresaCuit,
      montoTotal: montoTotal,
      tasaInteres: tasaInteres,
      cantidadCuotas: cantidadCuotas,
      valorCuota: valorCuota,
      fechaOtorgamiento: fechaOtorgamiento ?? DateTime.now(),
      fechaPrimeraCuota: fechaPrimeraCuota ?? DateTime.now(),
      motivoPrestamo: motivoPrestamo,
      creadoPor: creadoPor,
    );
    
    await guardarPrestamo(prestamo);
    await _generarCuotas(prestamo);
    return prestamo;
  }

  static Future<void> registrarCuotaPagada(
    String prestamoId,
    int numeroCuota, {
    String? liquidacionId,
  }) async {
    // ... (sin cambios)
  }


  /// **NUEVO MÉTODO OPTIMIZADO**
  /// Obtiene todos los préstamos de una empresa en una sola llamada.
  static Future<List<Prestamo>> obtenerPrestamosPorEmpresa(String empresaCuit) async {
    try {
      final connectivity = await Connectivity().checkConnectivity();
      final isOnline = connectivity.isNotEmpty && connectivity.first != ConnectivityResult.none;

      if (isOnline) {
        final res = await Supabase.instance.client
            .from('prestamos')
            .select()
            .eq('empresa_cuit', empresaCuit);

        final prestamos = (res as List).map((m) => Prestamo.fromMap(m)).toList();
        
        // Guardar la lista completa de la empresa en el caché
        await _guardarEnCache(empresaCuit, prestamos);
        
        return prestamos;
      }
    } catch (e) {
      print('Error obteniendo préstamos por empresa desde Supabase: $e');
    }

    // Fallback: cargar desde el caché de la empresa
    return await _cargarDesdeCache(empresaCuit);
  }

  /// Guarda un préstamo y lo sincroniza
  static Future<void> guardarPrestamo(Prestamo prestamo) async {
    await _agregarACache(prestamo);
    
    final connectivity = await Connectivity().checkConnectivity();
    final isOnline = connectivity.isNotEmpty && connectivity.first != ConnectivityResult.none;

    if (isOnline) {
      try {
        await Supabase.instance.client.from('prestamos').upsert(prestamo.toMap());
      } catch (e) {
        print('Error guardando préstamo en Supabase: $e');
        await _marcarPendienteSync(prestamo.id);
      }
    } else {
      await _marcarPendienteSync(prestamo.id);
    }
  }

  /// Genera las cuotas para un nuevo préstamo
  static Future<void> _generarCuotas(Prestamo prestamo) async {
    // ... (sin cambios)
  }

  // ========================================================================
  // MÉTODOS DE CACHÉ (Refactorizados para usar empresaCuit)
  // ========================================================================

  static Future<void> _guardarEnCache(String empresaCuit, List<Prestamo> prestamos) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_cacheKeyPrefix$empresaCuit';
    final json = jsonEncode(prestamos.map((p) => p.toMap()).toList());
    await prefs.setString(key, json);
  }

  static Future<List<Prestamo>> _cargarDesdeCache(String empresaCuit) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_cacheKeyPrefix$empresaCuit';
    final json = prefs.getString(key);

    if (json == null) return [];

    try {
      final list = jsonDecode(json) as List;
      return list.map((m) => Prestamo.fromMap(m)).toList();
    } catch (e) {
      print("Error decodificando caché de préstamos: $e");
      return [];
    }
  }

  static Future<void> _agregarACache(Prestamo prestamo) async {
    final prestamos = await _cargarDesdeCache(prestamo.empresaCuit);
    final index = prestamos.indexWhere((p) => p.id == prestamo.id);

    if (index != -1) {
      prestamos[index] = prestamo; // Actualiza si existe
    } else {
      prestamos.add(prestamo); // Agrega si es nuevo
    }
    await _guardarEnCache(prestamo.empresaCuit, prestamos);
  }

  static Future<void> _marcarPendienteSync(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final pendientes = prefs.getStringList(_pendingSyncKey) ?? [];
    if (!pendientes.contains(id)) {
      pendientes.add(id);
      await prefs.setStringList(_pendingSyncKey, pendientes);
    }
  }
}
