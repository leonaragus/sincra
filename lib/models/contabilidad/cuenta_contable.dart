
enum ImputacionDefecto {
  debe,
  haber,
}

class CuentaContable {
  final String codigo;
  final String nombre;
  final ImputacionDefecto imputacionDefecto;

  const CuentaContable({
    required this.codigo,
    required this.nombre,
    required this.imputacionDefecto,
  });

  Map<String, dynamic> toMap() {
    return {
      'codigo': codigo,
      'nombre': nombre,
      'imputacionDefecto': imputacionDefecto.name,
    };
  }

  factory CuentaContable.fromMap(Map<String, dynamic> map) {
    return CuentaContable(
      codigo: map['codigo'] ?? '',
      nombre: map['nombre'] ?? '',
      imputacionDefecto: ImputacionDefecto.values.firstWhere(
        (e) => e.name == map['imputacionDefecto'],
        orElse: () => ImputacionDefecto.debe,
      ),
    );
  }
}
