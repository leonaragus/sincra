/// Modelo para los formatos de recibo disponibles.
class FormatoRecibo {
  final String id;
  final String nombre;
  final String descripcion;
  final String orientacion; // 'vertical', 'horizontal', 'digital'
  final bool tieneDuplicado;
  final bool tieneQR;

  const FormatoRecibo({
    required this.id,
    required this.nombre,
    required this.descripcion,
    required this.orientacion,
    this.tieneDuplicado = false,
    this.tieneQR = false,
  });

  static const List<FormatoRecibo> formatosDisponibles = [
    FormatoRecibo(
      id: 'clasico_lct',
      nombre: 'Clásico LCT',
      descripcion: 'Diseño vertical tradicional con datos de empresa arriba y empleado abajo. Cumple con Ley de Contrato de Trabajo.',
      orientacion: 'vertical',
      tieneDuplicado: false,
      tieneQR: false,
    ),
    FormatoRecibo(
      id: 'administrativo_a4',
      nombre: 'Administrativo A4',
      descripcion: 'Formato apaisado o doble (Original/Duplicado en una hoja) para optimizar papel.',
      orientacion: 'horizontal',
      tieneDuplicado: true,
      tieneQR: false,
    ),
    FormatoRecibo(
      id: 'digital_moderno',
      nombre: 'Digital Moderno',
      descripcion: 'Diseño limpio con énfasis en legibilidad, espacio para firma digital y validación QR.',
      orientacion: 'vertical',
      tieneDuplicado: false,
      tieneQR: true,
    ),
  ];

  static FormatoRecibo? obtenerPorId(String id) {
    try {
      return formatosDisponibles.firstWhere((f) => f.id == id);
    } catch (_) {
      return null;
    }
  }
}
