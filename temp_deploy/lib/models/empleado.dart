class Empleado {
  String nombre;
  String categoria;
  double sueldoBasico;
  String periodo;
  String fechaPago;
  String? fechaIngreso;
  String? lugarPago;
  String? codigoRnos; // Código RNOS de 6 dígitos para seguridad social

  Empleado({
    required this.nombre,
    required this.categoria,
    required this.sueldoBasico,
    required this.periodo,
    required this.fechaPago,
    this.fechaIngreso,
    this.lugarPago,
    this.codigoRnos,
  });
}
