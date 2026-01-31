// ========================================================================
// SERVICIO DE AUDITORÍA
// Registro de cambios críticos en el sistema (paritarias, CCT, conceptos)
// ========================================================================

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:convert';

class RegistroAuditoria {
  final String id;
  final String tipo; // 'paritarias', 'cct', 'concepto', 'empleado', 'liquidacion'
  final String accion; // 'crear', 'modificar', 'eliminar'
  final String entidad; // Identificador de la entidad modificada
  final String? descripcion;
  final Map<String, dynamic>? valorAnterior;
  final Map<String, dynamic>? valorNuevo;
  final DateTime fecha;
  final String? usuario;
  final String? empresaCuit;
  
  RegistroAuditoria({
    required this.id,
    required this.tipo,
    required this.accion,
    required this.entidad,
    this.descripcion,
    this.valorAnterior,
    this.valorNuevo,
    required this.fecha,
    this.usuario,
    this.empresaCuit,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tipo': tipo,
      'accion': accion,
      'entidad': entidad,
      'descripcion': descripcion,
      'valor_anterior': valorAnterior,
      'valor_nuevo': valorNuevo,
      'fecha': fecha.toIso8601String(),
      'usuario': usuario,
      'empresa_cuit': empresaCuit,
    };
  }
  
  factory RegistroAuditoria.fromMap(Map<String, dynamic> map) {
    return RegistroAuditoria(
      id: map['id'] ?? '',
      tipo: map['tipo'] ?? '',
      accion: map['accion'] ?? '',
      entidad: map['entidad'] ?? '',
      descripcion: map['descripcion'],
      valorAnterior: map['valor_anterior'],
      valorNuevo: map['valor_nuevo'],
      fecha: DateTime.parse(map['fecha']),
      usuario: map['usuario'],
      empresaCuit: map['empresa_cuit'],
    );
  }
}

class AuditoriaService {
  static const String _cacheKey = 'auditoria_cache';
  
  /// Registra un cambio en paritarias
  static Future<void> registrarCambioParitarias({
    required String jurisdiccion,
    required Map<String, dynamic> valorAnterior,
    required Map<String, dynamic> valorNuevo,
    String? usuario,
  }) async {
    await _registrar(
      tipo: 'paritarias',
      accion: 'modificar',
      entidad: jurisdiccion,
      descripcion: 'Actualización de paritarias para $jurisdiccion',
      valorAnterior: valorAnterior,
      valorNuevo: valorNuevo,
      usuario: usuario,
    );
  }
  
  /// Registra un cambio en CCT
  static Future<void> registrarCambioCCT({
    required String codigoCCT,
    required String accion, // crear, modificar
    Map<String, dynamic>? valorAnterior,
    required Map<String, dynamic> valorNuevo,
    String? usuario,
  }) async {
    await _registrar(
      tipo: 'cct',
      accion: accion,
      entidad: codigoCCT,
      descripcion: 'CCT $codigoCCT $accion',
      valorAnterior: valorAnterior,
      valorNuevo: valorNuevo,
      usuario: usuario,
    );
  }
  
  /// Registra un cambio en concepto recurrente
  static Future<void> registrarCambioConcepto({
    required String conceptoId,
    required String accion,
    required String empleadoCuil,
    Map<String, dynamic>? valorAnterior,
    required Map<String, dynamic> valorNuevo,
    String? usuario,
  }) async {
    await _registrar(
      tipo: 'concepto',
      accion: accion,
      entidad: conceptoId,
      descripcion: 'Concepto $accion para empleado $empleadoCuil',
      valorAnterior: valorAnterior,
      valorNuevo: valorNuevo,
      usuario: usuario,
    );
  }
  
  /// Registra una liquidación masiva
  static Future<void> registrarLiquidacionMasiva({
    required String liquidacionId,
    required int cantidadEmpleados,
    required double masaSalarialTotal,
    String? usuario,
    String? empresaCuit,
  }) async {
    await _registrar(
      tipo: 'liquidacion',
      accion: 'liquidacion_masiva',
      entidad: liquidacionId,
      descripcion: 'Liquidación masiva de $cantidadEmpleados empleados',
      valorNuevo: {
        'cantidad_empleados': cantidadEmpleados,
        'masa_salarial_total': masaSalarialTotal,
      },
      usuario: usuario,
      empresaCuit: empresaCuit,
    );
  }
  
  /// Registra un cambio genérico
  static Future<void> registrarCambio({
    required String modulo,
    required String accion,
    required String entidad,
    Map<String, dynamic>? valoresAnteriores,
    Map<String, dynamic>? valoresNuevos,
    String? observaciones,
    String? usuario,
  }) async {
    await _registrar(
      tipo: modulo,
      accion: accion,
      entidad: entidad,
      descripcion: observaciones,
      valorAnterior: valoresAnteriores,
      valorNuevo: valoresNuevos,
      usuario: usuario,
    );
  }
  
  /// Obtiene el historial de auditoría
  static Future<List<RegistroAuditoria>> obtenerHistorial({
    String? tipo,
    String? usuario,
    DateTime? desde,
    DateTime? hasta,
    int limit = 50,
  }) async {
    try {
      final connectivity = await Connectivity().checkConnectivity();
      final isOnline = connectivity.isNotEmpty && connectivity.first != ConnectivityResult.none;
      
      if (isOnline) {
        dynamic query = Supabase.instance.client
            .from('auditoria')
            .select();
        
        if (tipo != null) {
          query = query.eq('tipo', tipo);
        }
        
        if (usuario != null) {
          query = query.eq('usuario', usuario);
        }
        
        if (desde != null) {
          query = query.gte('fecha', desde.toIso8601String());
        }
        
        if (hasta != null) {
          query = query.lte('fecha', hasta.toIso8601String());
        }
        
        query = query.order('fecha', ascending: false).limit(limit);
        
        final res = await query;
        return (res as List).map((m) => RegistroAuditoria.fromMap(m)).toList();
      }
    } catch (e) {
      print('Error obteniendo historial de auditoría: $e');
    }
    
    return [];
  }
  
  /// Método privado para registrar
  static Future<void> _registrar({
    required String tipo,
    required String accion,
    required String entidad,
    String? descripcion,
    Map<String, dynamic>? valorAnterior,
    Map<String, dynamic>? valorNuevo,
    String? usuario,
    String? empresaCuit,
  }) async {
    final registro = RegistroAuditoria(
      id: 'audit_${DateTime.now().millisecondsSinceEpoch}',
      tipo: tipo,
      accion: accion,
      entidad: entidad,
      descripcion: descripcion,
      valorAnterior: valorAnterior,
      valorNuevo: valorNuevo,
      fecha: DateTime.now(),
      usuario: usuario ?? 'Sistema',
      empresaCuit: empresaCuit,
    );
    
    // Guardar en cache local
    await _agregarACache(registro);
    
    // Intentar guardar en Supabase
    final connectivity = await Connectivity().checkConnectivity();
    final isOnline = connectivity.isNotEmpty && connectivity.first != ConnectivityResult.none;
    
    if (isOnline) {
      try {
        await Supabase.instance.client
            .from('auditoria')
            .insert(registro.toMap());
      } catch (e) {
        print('Error guardando auditoría en Supabase: $e');
      }
    }
  }
  
  static Future<void> _agregarACache(RegistroAuditoria registro) async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_cacheKey);
    
    List<dynamic> registros = [];
    if (json != null) {
      registros = jsonDecode(json) as List;
    }
    
    registros.insert(0, registro.toMap());
    
    // Mantener solo los últimos 100 en cache
    if (registros.length > 100) {
      registros = registros.take(100).toList();
    }
    
    await prefs.setString(_cacheKey, jsonEncode(registros));
  }
}
