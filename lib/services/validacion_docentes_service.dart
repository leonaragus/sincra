// Servicio de validacion para docentes

class ValidacionDocenteResult {
  final bool esValido;
  final List<String> advertencias;
  final List<String> errores;
  
  ValidacionDocenteResult({
    required this.esValido,
    this.advertencias = const [],
    this.errores = const [],
  });
  
  bool get tieneAdvertencias => advertencias.isNotEmpty;
  bool get tieneErrores => errores.isNotEmpty;
}

class ValidacionDocentesService {
  static const Map<String, RangoPuntos> RANGOS_PUNTOS_POR_CARGO = {
    'maestro': RangoPuntos(min: 0, max: 30, recomendadoMin: 0, recomendadoMax: 25),
    'profesor': RangoPuntos(min: 0, max: 40, recomendadoMin: 10, recomendadoMax: 35),
    'director': RangoPuntos(min: 30, max: 60, recomendadoMin: 35, recomendadoMax: 55),
    'supervisor': RangoPuntos(min: 40, max: 70, recomendadoMin: 45, recomendadoMax: 65),
  };
  
  static ValidacionDocenteResult validarPuntosVsCargo({
    required String cargo,
    required double puntosTotales,
    String? nombreDocente,
  }) {
    final advertencias = <String>[];
    final errores = <String>[];
    
    final cargoNormalizado = cargo.toLowerCase().trim().replaceAll(' ', '_');
    final rango = RANGOS_PUNTOS_POR_CARGO[cargoNormalizado];
    
    if (rango == null) {
      advertencias.add('Cargo "$cargo" no tiene rangos de puntos definidos.');
      return ValidacionDocenteResult(
        esValido: true,
        advertencias: advertencias,
      );
    }
    
    final prefijo = nombreDocente != null ? '$nombreDocente: ' : '';
    
    if (puntosTotales < rango.min || puntosTotales > rango.max) {
      errores.add(
        '${prefijo}Puntos invalidos para cargo "$cargo". '
        'Rango valido: ${rango.min}-${rango.max} puntos. '
        'Actual: ${puntosTotales.toStringAsFixed(2)} puntos.'
      );
    } else if (puntosTotales < rango.recomendadoMin || puntosTotales > rango.recomendadoMax) {
      advertencias.add(
        '${prefijo}Puntos fuera del rango recomendado para cargo "$cargo". '
        'Rango recomendado: ${rango.recomendadoMin}-${rango.recomendadoMax} puntos. '
        'Actual: ${puntosTotales.toStringAsFixed(2)} puntos.'
      );
    }
    
    return ValidacionDocenteResult(
      esValido: errores.isEmpty,
      advertencias: advertencias,
      errores: errores,
    );
  }
}

class RangoPuntos {
  final double min;
  final double max;
  final double recomendadoMin;
  final double recomendadoMax;
  
  const RangoPuntos({
    required this.min,
    required this.max,
    required this.recomendadoMin,
    required this.recomendadoMax,
  });
}
