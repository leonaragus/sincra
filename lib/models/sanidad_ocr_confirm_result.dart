import 'package:syncra_arg/services/sanidad_omni_engine.dart';

class SanidadOcrConfirmResult {
  final String nombre;
  final String cuil;
  final String puesto;
  final DateTime fechaIngreso;
  final CategoriaSanidad categoria;
  final NivelTituloSanidad nivelTitulo;
  final bool tareaCriticaRiesgo;
  final bool cuotaSindicalAtsa;
  final bool manejoEfectivoCaja;
  final int horasNocturnas;
  final double horasExtras50;
  final double horasExtras100;
  final double adelantos;
  final double embargos;
  final double prestamos;
  final double mejorRemuneracion;

  SanidadOcrConfirmResult({
    required this.nombre,
    required this.cuil,
    this.puesto = '',
    required this.fechaIngreso,
    required this.categoria,
    required this.nivelTitulo,
    this.tareaCriticaRiesgo = false,
    this.cuotaSindicalAtsa = false,
    this.manejoEfectivoCaja = false,
    this.horasNocturnas = 0,
    this.horasExtras50 = 0,
    this.horasExtras100 = 0,
    this.adelantos = 0,
    this.embargos = 0,
    this.prestamos = 0,
    this.mejorRemuneracion = 0,
  });
}
