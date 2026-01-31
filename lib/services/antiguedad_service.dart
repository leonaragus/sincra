import 'package:intl/intl.dart';

/// Servicio para calcular antigüedad automáticamente
class AntiguedadService {
  /// Calcula los años de antigüedad comparando la fecha de ingreso con el mes de liquidación
  /// 
  /// [fechaIngreso] - Fecha de ingreso del empleado (formato DD/MM/YYYY)
  /// [periodoLiquidacion] - Período de liquidación (ej: "Enero 2026")
  /// 
  /// Retorna el número de años completos de antigüedad
  /// Si la fecha de ingreso es posterior al mes de liquidación, retorna -1 (error)
  static int calcularAniosAntiguedad(String fechaIngreso, String periodoLiquidacion) {
    try {
      // Parsear fecha de ingreso
      final fechaIngresoDate = DateFormat('dd/MM/yyyy').parse(fechaIngreso);
      
      // Parsear período de liquidación (ej: "Enero 2026")
      final periodoDate = _parsearPeriodo(periodoLiquidacion);
      
      // Validar que la fecha de ingreso no sea posterior al mes de liquidación
      if (fechaIngresoDate.isAfter(periodoDate)) {
        return -1; // Error: fecha inválida
      }
      
      // Calcular diferencia en años
      int anios = periodoDate.year - fechaIngresoDate.year;
      
      // Ajustar si aún no se cumplió el mes/aniversario
      if (periodoDate.month < fechaIngresoDate.month ||
          (periodoDate.month == fechaIngresoDate.month && periodoDate.day < fechaIngresoDate.day)) {
        anios--;
      }
      
      // Retornar años completos (mínimo 0)
      return anios < 0 ? 0 : anios;
    } catch (e) {
      // En caso de error, retornar -1
      return -1;
    }
  }
  
  /// Calcula el monto de antigüedad según la fórmula:
  /// MontoAntiguedad = (SueldoBasico * %AntiguedadAnual / 100) * AñosCalculados
  /// 
  /// [sueldoBasico] - Sueldo básico del empleado
  /// [porcentajeAntiguedadAnual] - Porcentaje anual de antigüedad del convenio (ej: 1.0 para 1%)
  /// [aniosAntiguedad] - Años de antigüedad calculados
  /// 
  /// Retorna el monto de antigüedad a aplicar
  static double calcularMontoAntiguedad(
    double sueldoBasico,
    double porcentajeAntiguedadAnual,
    int aniosAntiguedad,
  ) {
    if (aniosAntiguedad < 1) {
      return 0.0; // No se aplica antigüedad si tiene menos de 1 año
    }
    
    return (sueldoBasico * porcentajeAntiguedadAnual / 100) * aniosAntiguedad;
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
  
  /// Valida que la fecha de ingreso no sea posterior al mes de liquidación
  /// 
  /// Retorna true si es válida, false si es inválida
  static bool validarFechaIngreso(String fechaIngreso, String periodoLiquidacion) {
    final anios = calcularAniosAntiguedad(fechaIngreso, periodoLiquidacion);
    return anios >= 0;
  }
}
