
import '../models/liquidacion.dart';
import '../models/cct_completo.dart';
import '../data/cct_argentina_completo.dart';
import './antiguedad_service.dart';
import './vacaciones_service.dart';

class LiquidacionService {
  /// Contiene la lógica de negocio principal para calcular una liquidación.
  ///
  /// Recibe todos los datos de entrada de la UI y devuelve un objeto [Liquidacion]
  /// completamente calculado y listo para ser mostrado o exportado.
  /// Esta función es pura: no tiene efectos secundarios y sus resultados
  /// dependen únicamente de sus entradas.
  Liquidacion calcularLiquidacion({
    required String empresaId,
    required String empleadoId,
    required Map<String, dynamic> datosEmpleado,
    required String periodo,
    required String fechaPago,
    required double sueldoBasico,
    // Flags y valores de la UI
    required bool afiliadoSindical,
    required bool calcularGananciasAutomatico,
    required double impuestoGananciasManual,
    required bool presentismoActivo,
    required int diasInasistencia,
    required double porcentajePresentismo,
    required int kilometrosRecorridos,
    required int diasViaticosComida,
    required int diasPernocte,
    required int cantidadHorasExtras50,
    required int cantidadHorasExtras100,
    required Map<String, double> conceptosNoRemunerativosAdicionales,
    required Map<String, double> deduccionesAdicionales,
    // Datos de Vacaciones
    required bool vacacionesActivas,
    required int diasVacaciones,
    required double montoVacaciones,
    required double plusVacacional,
    required bool vacacionesGozadas,
    required String? fechaInicioVacaciones,
    required String? fechaFinVacaciones,
    required bool ajusteManualVacaciones,
  }) {
    if (sueldoBasico <= 0) {
      throw ArgumentError('El sueldo básico debe ser mayor a 0');
    }

    final fechaIngreso = datosEmpleado['fechaIngreso']?.toString() ?? '';
    if (fechaIngreso.isNotEmpty) {
      final aniosAntiguedad = AntiguedadService.calcularAniosAntiguedad(
        fechaIngreso,
        periodo,
      );
      if (aniosAntiguedad < 0) {
        throw ArgumentError('Fecha de ingreso inválida. La fecha de ingreso no puede ser posterior al mes de liquidación.');
      }
    }

    final liquidacion = Liquidacion(
      empresaId: empresaId,
      empleadoId: empleadoId,
      periodo: periodo,
      fechaPago: fechaPago,
    );

    // Asignar propiedades y novedades
    liquidacion.afiliadoSindical = afiliadoSindical;
    liquidacion.calcularGananciasAutomatico = calcularGananciasAutomatico;
    if (!calcularGananciasAutomatico) {
      liquidacion.impuestoGanancias = impuestoGananciasManual;
    }
    liquidacion.presentismoActivo = presentismoActivo;
    liquidacion.diasInasistencia = diasInasistencia;
    liquidacion.porcentajePresentismo = porcentajePresentismo;
    liquidacion.kilometrosRecorridos = kilometrosRecorridos;
    liquidacion.diasViaticosComida = diasViaticosComida;
    liquidacion.diasPernocte = diasPernocte;

    // Antigüedad (usando el servicio de antigüedad)
    _calcularYAsignarAntiguedad(liquidacion, datosEmpleado, sueldoBasico, periodo);

    // Horas Extras
    liquidacion.cantidadHorasExtras50 = cantidadHorasExtras50;
    liquidacion.cantidadHorasExtras100 = cantidadHorasExtras100;
    // TODO: El divisor de horas debe venir del convenio
    liquidacion.horasMensualesDivisor = 173.0;

    // Conceptos y deducciones adicionales
    liquidacion.conceptosNoRemunerativosAdicionales = conceptosNoRemunerativosAdicionales;
    liquidacion.deduccionesAdicionales = deduccionesAdicionales;

    // Vacaciones
    if (vacacionesActivas && diasVacaciones > 0) {
      liquidacion.vacacionesActivas = true;
      liquidacion.diasVacaciones = diasVacaciones;
      liquidacion.montoVacaciones = montoVacaciones;
      liquidacion.plusVacacional = plusVacacional;
      liquidacion.vacacionesGozadas = vacacionesGozadas;
      liquidacion.fechaInicioVacaciones = fechaInicioVacaciones;
      liquidacion.fechaFinVacaciones = fechaFinVacaciones;
      liquidacion.ajusteManualVacaciones = ajusteManualVacaciones;
    }

    return liquidacion;
  }

  /// Lógica encapsulada para el cálculo de la antigüedad.
  void _calcularYAsignarAntiguedad(
    Liquidacion liquidacion,
    Map<String, dynamic> datosEmpleado,
    double sueldoBasico,
    String periodo,
  ) {
    final fechaIngreso = datosEmpleado['fechaIngreso']?.toString() ?? '';
    if (fechaIngreso.isEmpty) return;

    final aniosAntiguedad = AntiguedadService.calcularAniosAntiguedad(
      fechaIngreso,
      periodo,
    );

    if (aniosAntiguedad >= 1) {
      // TODO: Reemplazar cctArgentinaCompleto con ConveniosService
      double porcentajeAntiguedadAnual = 1.0; // Default 1%
      final convenioId = datosEmpleado['convenioId']?.toString();
      if (convenioId != null && convenioId.isNotEmpty && convenioId != 'fuera_convenio') {
        try {
          final convenio = cctArgentinaCompleto.firstWhere((c) => c.id == convenioId);
          porcentajeAntiguedadAnual = convenio.porcentajeAntiguedadAnual;
        } catch (e) {
          // Si no se encuentra el convenio, usar valor por defecto
        }
      }

      final montoAntiguedad = AntiguedadService.calcularMontoAntiguedad(
        sueldoBasico,
        porcentajeAntiguedadAnual,
        aniosAntiguedad,
      );

      if (montoAntiguedad > 0) {
        liquidacion.conceptosRemunerativos['Antigüedad'] = montoAntiguedad;
      }
    }
  }
}
