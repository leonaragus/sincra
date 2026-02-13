
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/contabilidad/mapeo_contable.dart';
import '../models/contabilidad/cuenta_contable.dart';

class ContabilidadConfigService {
  static const String _storageKey = 'perfil_contable_json';

  static Future<void> guardarPerfil(PerfilContable perfil) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(perfil.toMap()));
  }

  static Future<PerfilContable> cargarPerfil() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final content = prefs.getString(_storageKey);
      if (content != null && content.isNotEmpty) {
        return PerfilContable.fromMap(jsonDecode(content));
      }
    } catch (e) {
      // Ignore error, return default
    }
    return _crearPerfilPorDefecto();
  }

  static PerfilContable _crearPerfilPorDefecto() {
    final plan = [
      const CuentaContable(codigo: '5.1.01.01', nombre: 'Sueldos y Jornales', imputacionDefecto: ImputacionDefecto.debe),
      const CuentaContable(codigo: '5.1.01.02', nombre: 'Adicionales', imputacionDefecto: ImputacionDefecto.debe),
      const CuentaContable(codigo: '5.1.01.03', nombre: 'SAC', imputacionDefecto: ImputacionDefecto.debe),
      const CuentaContable(codigo: '5.1.01.04', nombre: 'Vacaciones', imputacionDefecto: ImputacionDefecto.debe),
      const CuentaContable(codigo: '2.1.01.01', nombre: 'Sueldos a Pagar', imputacionDefecto: ImputacionDefecto.haber),
      const CuentaContable(codigo: '2.1.01.02', nombre: 'Retenciones a Depositar (Jub/OS)', imputacionDefecto: ImputacionDefecto.haber),
      const CuentaContable(codigo: '2.1.01.03', nombre: 'Sindicato a Pagar', imputacionDefecto: ImputacionDefecto.haber),
    ];

    final mapeos = [
      const MapeoContable(
        id: '1', 
        nombre: 'Total Remunerativo', 
        tipo: TipoConceptoContable.agrupacion, 
        claveReferencia: 'TOTAL_REMUNERATIVO', 
        cuentaCodigo: '5.1.01.01', 
        imputacion: ImputacionDefecto.debe
      ),
      const MapeoContable(
        id: '2', 
        nombre: 'Total No Remunerativo', 
        tipo: TipoConceptoContable.agrupacion, 
        claveReferencia: 'TOTAL_NO_REMUNERATIVO', 
        cuentaCodigo: '5.1.01.01', 
        imputacion: ImputacionDefecto.debe
      ),
      const MapeoContable(
        id: '3', 
        nombre: 'Jubilación (Desc)', 
        tipo: TipoConceptoContable.conceptoEspecifico, 
        claveReferencia: 'JUBILACION', 
        cuentaCodigo: '2.1.01.02', 
        imputacion: ImputacionDefecto.haber
      ),
      const MapeoContable(
        id: '4', 
        nombre: 'Obra Social (Desc)', 
        tipo: TipoConceptoContable.conceptoEspecifico, 
        claveReferencia: 'OBRA_SOCIAL', 
        cuentaCodigo: '2.1.01.02', 
        imputacion: ImputacionDefecto.haber
      ),
      const MapeoContable(
        id: '5', 
        nombre: 'Ley 19.032 (Desc)', 
        tipo: TipoConceptoContable.conceptoEspecifico, 
        claveReferencia: 'LEY_19032', 
        cuentaCodigo: '2.1.01.02', 
        imputacion: ImputacionDefecto.haber
      ),
      const MapeoContable(
        id: '6', 
        nombre: 'Sueldo Neto a Pagar', 
        tipo: TipoConceptoContable.neto, 
        claveReferencia: null, 
        cuentaCodigo: '2.1.01.01', 
        imputacion: ImputacionDefecto.haber
      ),
    ];

    return PerfilContable(
      id: 'default',
      nombre: 'Perfil Predeterminado',
      planDeCuentas: plan,
      mapeos: mapeos,
    );
  }
}
