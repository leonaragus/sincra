import 'package:intl/intl.dart';
import '../models/cct_completo.dart';

/// Servicio para calcular vacaciones según Ley de Contrato de Trabajo (LCT 20.744)
/// y Convenios Colectivos de Trabajo (CCT)
class VacacionesService {
  /// Escala de días de vacaciones según LCT 20.744 (Art. 150)
  /// La antigüedad se calcula al 31 de diciembre del período a liquidar
  static const Map<String, int> escalaLCT = {
    'menos_6_meses': 0, // Se calcula proporcionalmente: 1 día cada 20 días trabajados
    '6_meses_a_5_anios': 14,
    '5_a_10_anios': 21,
    '10_a_20_anios': 28,
    'mas_20_anios': 35,
  };

  /// Calcula los días de vacaciones según la antigüedad al 31 de diciembre del período
  /// 
  /// [fechaIngreso] - Fecha de ingreso del empleado (formato DD/MM/YYYY)
  /// [periodoLiquidacion] - Período de liquidación (ej: "Enero 2026")
  /// [convenio] - Convenio Colectivo de Trabajo (opcional, si tiene escala superior se prioriza)
  /// [diasTrabajadosEnPeriodo] - Días trabajados en el período (para casos de menos de 6 meses)
  /// 
  /// Retorna un mapa con:
  /// - 'dias': int - Días de vacaciones calculados
  /// - 'fuente': String - 'LCT' o 'CCT' según qué escala se usó
  /// - 'aniosAntiguedad': double - Años de antigüedad al 31 de diciembre
  static Map<String, dynamic> calcularDiasVacaciones({
    required String fechaIngreso,
    required String periodoLiquidacion,
    CCTCompleto? convenio,
    int diasTrabajadosEnPeriodo = 0,
  }) {
    try {
      // Calcular antigüedad al 31 de diciembre del período
      final aniosAntiguedad = _calcularAntiguedadAl31Diciembre(fechaIngreso, periodoLiquidacion);
      
      // Si tiene menos de 6 meses, calcular proporcionalmente
      if (aniosAntiguedad < 0.5) {
        // Calcular días trabajados desde fecha de ingreso hasta fin del período
        final diasTrabajados = _calcularDiasTrabajados(fechaIngreso, periodoLiquidacion);
        final diasVacaciones = (diasTrabajados / 20).floor(); // 1 día cada 20 días trabajados
        
        return {
          'dias': diasVacaciones,
          'fuente': 'LCT',
          'aniosAntiguedad': aniosAntiguedad,
          'diasTrabajados': diasTrabajados,
        };
      }
      
      // Calcular días según LCT
      int diasLCT = _calcularDiasSegunLCT(aniosAntiguedad);
      
      // Verificar si el convenio tiene escala superior
      int? diasCCT;
      if (convenio != null) {
        diasCCT = _obtenerDiasVacacionesCCT(convenio, aniosAntiguedad);
      }
      
      // Priorizar CCT si tiene más días que LCT
      if (diasCCT != null && diasCCT > diasLCT) {
        return {
          'dias': diasCCT,
          'fuente': 'CCT',
          'aniosAntiguedad': aniosAntiguedad,
          'diasLCT': diasLCT,
          'diasCCT': diasCCT,
        };
      }
      
      return {
        'dias': diasLCT,
        'fuente': 'LCT',
        'aniosAntiguedad': aniosAntiguedad,
        'diasLCT': diasLCT,
        'diasCCT': diasCCT,
      };
    } catch (e) {
      // En caso de error, retornar 0 días
      return {
        'dias': 0,
        'fuente': 'LCT',
        'aniosAntiguedad': 0.0,
        'error': e.toString(),
      };
    }
  }

  /// Calcula la antigüedad al 31 de diciembre del período de liquidación
  /// 
  /// [fechaIngreso] - Fecha de ingreso del empleado
  /// [periodoLiquidacion] - Período de liquidación (ej: "Enero 2026")
  /// 
  /// Retorna los años de antigüedad como double (puede ser fraccionario)
  static double _calcularAntiguedadAl31Diciembre(String fechaIngreso, String periodoLiquidacion) {
    try {
      // Parsear fecha de ingreso
      final fechaIngresoDate = DateFormat('dd/MM/yyyy').parse(fechaIngreso);
      
      // Parsear período y obtener el 31 de diciembre de ese año
      final periodoDate = _parsearPeriodo(periodoLiquidacion);
      final fechaReferencia = DateTime(periodoDate.year, 12, 31);
      
      // Validar que la fecha de ingreso no sea posterior al 31 de diciembre
      if (fechaIngresoDate.isAfter(fechaReferencia)) {
        return 0.0;
      }
      
      // Calcular diferencia en años (puede ser fraccionario)
      final diferencia = fechaReferencia.difference(fechaIngresoDate);
      final anios = diferencia.inDays / 365.25; // Usar 365.25 para considerar años bisiestos
      
      return anios < 0 ? 0.0 : anios;
    } catch (e) {
      return 0.0;
    }
  }

  /// Calcula los días trabajados desde la fecha de ingreso hasta el fin del período
  static int _calcularDiasTrabajados(String fechaIngreso, String periodoLiquidacion) {
    try {
      final fechaIngresoDate = DateFormat('dd/MM/yyyy').parse(fechaIngreso);
      final periodoDate = _parsearPeriodo(periodoLiquidacion);
      final finPeriodo = DateTime(periodoDate.year, periodoDate.month + 1, 0); // Último día del mes
      
      if (fechaIngresoDate.isAfter(finPeriodo)) {
        return 0;
      }
      
      final diferencia = finPeriodo.difference(fechaIngresoDate);
      return diferencia.inDays + 1; // +1 para incluir el día de ingreso
    } catch (e) {
      return 0;
    }
  }

  /// Calcula los días de vacaciones según la escala de la LCT
  static int _calcularDiasSegunLCT(double aniosAntiguedad) {
    if (aniosAntiguedad < 0.5) {
      return 0; // Se calcula proporcionalmente
    } else if (aniosAntiguedad < 5) {
      return escalaLCT['6_meses_a_5_anios']!;
    } else if (aniosAntiguedad < 10) {
      return escalaLCT['5_a_10_anios']!;
    } else if (aniosAntiguedad < 20) {
      return escalaLCT['10_a_20_anios']!;
    } else {
      return escalaLCT['mas_20_anios']!;
    }
  }

  /// Obtiene los días de vacaciones según el convenio (si tiene escala definida)
  /// 
  /// Obtiene los días de vacaciones según el convenio colectivo de trabajo
  /// 
  /// Por ahora, los convenios no tienen escalas de vacaciones definidas en el modelo,
  /// pero esta función está preparada para cuando se agreguen.
  /// 
  /// [convenio] - El convenio colectivo de trabajo
  /// [aniosAntiguedad] - Años de antigüedad del empleado
  /// 
  /// Retorna null si no hay escala definida en el convenio
  static int? _obtenerDiasVacacionesCCT(CCTCompleto convenio, double aniosAntiguedad) {
    // Nota: Cuando se agregue la escala de vacaciones al modelo CCTCompleto,
    // implementar la lógica aquí para obtener los días según el convenio
    // Por ahora, retornar null para usar siempre LCT
    return null;
  }

  /// Calcula el monto de vacaciones usando el divisor 25 (Art. 155 LCT)
  /// 
  /// [sueldoBruto] - Sueldo bruto de la categoría
  /// [diasVacaciones] - Días de vacaciones a liquidar
  /// 
  /// Retorna el monto de vacaciones: (Sueldo Bruto / 25) * Días
  static double calcularMontoVacaciones(double sueldoBruto, int diasVacaciones) {
    if (diasVacaciones <= 0) return 0.0;
    return (sueldoBruto / 25) * diasVacaciones;
  }

  /// Calcula el Plus Vacacional (diferencia entre valor día normal y valor día de vacaciones)
  /// 
  /// Valor día normal (divisor 30): Sueldo Bruto / 30
  /// Valor día vacaciones (divisor 25): Sueldo Bruto / 25
  /// Plus Vacacional = (Valor día vacaciones - Valor día normal) * Días de vacaciones
  /// 
  /// Simplificado: Plus = (Sueldo Bruto / 25 - Sueldo Bruto / 30) * Días
  ///               = Sueldo Bruto * Días * (1/25 - 1/30)
  ///               = Sueldo Bruto * Días * (6 - 5) / 150
  ///               = Sueldo Bruto * Días / 150
  /// 
  /// [sueldoBruto] - Sueldo bruto de la categoría
  /// [diasVacaciones] - Días de vacaciones
  /// 
  /// Retorna el monto del plus vacacional
  static double calcularPlusVacacional(double sueldoBruto, int diasVacaciones) {
    if (diasVacaciones <= 0) return 0.0;
    // Plus = Sueldo Bruto * Días / 150
    return (sueldoBruto * diasVacaciones) / 150;
  }

  /// Calcula el monto a deducir del sueldo básico mensual (divisor 30)
  /// para evitar pagar los mismos días dos veces
  /// 
  /// [sueldoBasico] - Sueldo básico mensual
  /// [diasVacaciones] - Días de vacaciones
  /// 
  /// Retorna el monto a deducir: (Sueldo Básico / 30) * Días
  static double calcularDeduccionSueldoBasico(double sueldoBasico, int diasVacaciones) {
    if (diasVacaciones <= 0) return 0.0;
    return (sueldoBasico / 30) * diasVacaciones;
  }

  /// Valida que los días de vacaciones no excedan el máximo legal (35 días para 2026)
  /// 
  /// [diasVacaciones] - Días de vacaciones a validar
  /// 
  /// Retorna true si es válido, false si excede el máximo
  static bool validarDiasVacaciones(int diasVacaciones) {
    return diasVacaciones <= 35;
  }

  /// Obtiene un mensaje descriptivo del cálculo de vacaciones
  /// 
  /// [resultado] - Resultado de calcularDiasVacaciones
  /// [nombreConvenio] - Nombre del convenio (opcional)
  /// 
  /// Retorna un mensaje formateado para mostrar en la UI
  static String obtenerMensajeCalculo(Map<String, dynamic> resultado, {String? nombreConvenio}) {
    final dias = resultado['dias'] as int? ?? 0;
    final fuente = resultado['fuente'] as String? ?? 'LCT';
    final aniosAntiguedad = resultado['aniosAntiguedad'] as double? ?? 0.0;
    
    final aniosFormateados = aniosAntiguedad < 1 
        ? '${(aniosAntiguedad * 12).toStringAsFixed(0)} meses'
        : '${aniosAntiguedad.toStringAsFixed(1)} años';
    
    String mensaje = 'Basado en $aniosFormateados de antigüedad';
    
    if (nombreConvenio != null && fuente == 'CCT') {
      mensaje += ' y CCT $nombreConvenio';
    }
    
    mensaje += ', corresponden $dias ${dias == 1 ? 'día' : 'días'} de vacaciones';
    
    return mensaje;
  }

  /// Parsea un período de liquidación (ej: "Enero 2026") a DateTime
  /// Retorna el primer día del mes correspondiente
  static DateTime _parsearPeriodo(String periodo) {
    final meses = {
      'enero': 1, 'febrero': 2, 'marzo': 3, 'abril': 4,
      'mayo': 5, 'junio': 6, 'julio': 7, 'agosto': 8,
      'septiembre': 9, 'octubre': 10, 'noviembre': 11, 'diciembre': 12,
    };
    
    final partes = periodo.toLowerCase().trim().split(' ');
    if (partes.length < 2) {
      // Si no se puede parsear, usar fecha actual
      final ahora = DateTime.now();
      return DateTime(ahora.year, ahora.month, 1);
    }
    
    final mesNombre = partes[0];
    final anio = int.tryParse(partes[1]) ?? DateTime.now().year;
    final mes = meses[mesNombre] ?? DateTime.now().month;
    
    return DateTime(anio, mes, 1);
  }
}
