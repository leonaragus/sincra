/// Modelo para gestionar parámetros legales vigentes
/// Permite almacenar y actualizar valores legales sin necesidad de reprogramar la aplicación
class ParametrosLegales {
  /// Base imponible máxima (Tope para aportes de Jubilación/Obra Social)
  final double baseImponibleMaxima;
  
  /// Base imponible mínima
  final double baseImponibleMinima;
  
  /// Sueldo Mínimo Vital y Móvil (SMVM)
  final double smvm;
  
  /// Asignación por hijo
  final double asignacionHijo;
  
  /// Tope movilidad F.931
  final double topeMovilidadF931;
  
  /// Fecha de vigencia desde (inicio del trimestre)
  final DateTime vigenciaDesde;
  
  /// Fecha de vigencia hasta (fin del trimestre)
  final DateTime vigenciaHasta;
  
  /// Fecha de última actualización
  final DateTime fechaActualizacion;
  
  /// Usuario que realizó la última actualización
  final String? usuarioActualizacion;

  ParametrosLegales({
    required this.baseImponibleMaxima,
    required this.baseImponibleMinima,
    required this.smvm,
    required this.asignacionHijo,
    required this.topeMovilidadF931,
    required this.vigenciaDesde,
    required this.vigenciaHasta,
    required this.fechaActualizacion,
    this.usuarioActualizacion,
  });

  /// Valores por defecto para el Primer Trimestre 2026 (Enero/Febrero/Marzo)
  factory ParametrosLegales.defaultQ12026() {
    final ahora = DateTime.now();
    return ParametrosLegales(
      baseImponibleMaxima: 2500000.00,
      baseImponibleMinima: 85000.00,
      smvm: 750000.00,
      asignacionHijo: 55000.00,
      topeMovilidadF931: 2500000.00,
      vigenciaDesde: DateTime(2026, 1, 1),
      vigenciaHasta: DateTime(2026, 3, 31),
      fechaActualizacion: ahora,
    );
  }

  /// Convierte el modelo a JSON para almacenamiento
  Map<String, dynamic> toJson() {
    return {
      'baseImponibleMaxima': baseImponibleMaxima,
      'baseImponibleMinima': baseImponibleMinima,
      'smvm': smvm,
      'asignacionHijo': asignacionHijo,
      'topeMovilidadF931': topeMovilidadF931,
      'vigenciaDesde': vigenciaDesde.toIso8601String(),
      'vigenciaHasta': vigenciaHasta.toIso8601String(),
      'fechaActualizacion': fechaActualizacion.toIso8601String(),
      'usuarioActualizacion': usuarioActualizacion,
    };
  }

  /// Crea una instancia desde JSON
  factory ParametrosLegales.fromJson(Map<String, dynamic> json) {
    return ParametrosLegales(
      baseImponibleMaxima: (json['baseImponibleMaxima'] as num).toDouble(),
      baseImponibleMinima: (json['baseImponibleMinima'] as num).toDouble(),
      smvm: (json['smvm'] as num).toDouble(),
      asignacionHijo: (json['asignacionHijo'] as num).toDouble(),
      topeMovilidadF931: (json['topeMovilidadF931'] as num).toDouble(),
      vigenciaDesde: DateTime.parse(json['vigenciaDesde'] as String),
      vigenciaHasta: DateTime.parse(json['vigenciaHasta'] as String),
      fechaActualizacion: DateTime.parse(json['fechaActualizacion'] as String),
      usuarioActualizacion: json['usuarioActualizacion'] as String?,
    );
  }

  /// Crea una copia con algunos campos modificados
  ParametrosLegales copyWith({
    double? baseImponibleMaxima,
    double? baseImponibleMinima,
    double? smvm,
    double? asignacionHijo,
    double? topeMovilidadF931,
    DateTime? vigenciaDesde,
    DateTime? vigenciaHasta,
    DateTime? fechaActualizacion,
    String? usuarioActualizacion,
  }) {
    return ParametrosLegales(
      baseImponibleMaxima: baseImponibleMaxima ?? this.baseImponibleMaxima,
      baseImponibleMinima: baseImponibleMinima ?? this.baseImponibleMinima,
      smvm: smvm ?? this.smvm,
      asignacionHijo: asignacionHijo ?? this.asignacionHijo,
      topeMovilidadF931: topeMovilidadF931 ?? this.topeMovilidadF931,
      vigenciaDesde: vigenciaDesde ?? this.vigenciaDesde,
      vigenciaHasta: vigenciaHasta ?? this.vigenciaHasta,
      fechaActualizacion: fechaActualizacion ?? DateTime.now(),
      usuarioActualizacion: usuarioActualizacion ?? this.usuarioActualizacion,
    );
  }

  /// Valida si los parámetros están vigentes para una fecha dada
  bool estaVigente(DateTime fecha) {
    return fecha.isAfter(vigenciaDesde.subtract(const Duration(days: 1))) &&
           fecha.isBefore(vigenciaHasta.add(const Duration(days: 1)));
  }

  /// Valida si los parámetros están vigentes para la fecha actual
  bool estaVigenteAhora() {
    return estaVigente(DateTime.now());
  }

  /// Calcula la base de cálculo aplicando topes legales
  /// 
  /// [totalRemunerativo] - Suma de todos los conceptos remunerativos
  /// 
  /// Retorna la base ajustada según topes máximo y mínimo
  double calcularBaseCalculo(double totalRemunerativo) {
    // Aplicar tope máximo
    double base = totalRemunerativo > baseImponibleMaxima 
        ? baseImponibleMaxima 
        : totalRemunerativo;
    
    // Aplicar tope mínimo
    base = base < baseImponibleMinima ? baseImponibleMinima : base;
    
    return base;
  }

  /// Valida si un sueldo bruto está por debajo del SMVM
  bool sueldoPorDebajoSMVM(double sueldoBruto) {
    return sueldoBruto < smvm;
  }
}
