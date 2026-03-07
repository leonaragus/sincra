class Empleado {
  String nombre;
  String cuil;
  String categoria;
  double sueldoBasico;
  String periodo;
  String fechaPago;
  String? fechaIngreso;
  String? lugarPago;
  String? codigoRnos; // Código RNOS de 6 dígitos para seguridad social

  Empleado({
    required this.nombre,
    required this.cuil,
    required this.categoria,
    required this.sueldoBasico,
    required this.periodo,
    required this.fechaPago,
    this.fechaIngreso,
    this.lugarPago,
    this.codigoRnos,
  });

  factory Empleado.fromMap(Map<String, dynamic> map) {
    return Empleado(
      nombre: map['nombre'] ?? '',
      cuil: map['cuil'] ?? '',
      categoria: map['categoriaId'] ?? '',
      sueldoBasico: (map['sueldoBasico'] as num?)?.toDouble() ?? 0.0,
      periodo: map['periodo'] ?? '',
      fechaPago: map['fechaPago'] ?? '',
      fechaIngreso: map['fechaIngreso'],
      lugarPago: map['lugarPago'],
      codigoRnos: map['codigoRnos'],
    );
  }
}
