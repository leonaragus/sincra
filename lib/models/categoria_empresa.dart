class CategoriaEmpresa {
  final String id;
  final String nombre;
  final double salarioBase;

  CategoriaEmpresa({
    required this.id,
    required this.nombre,
    required this.salarioBase,
  });

  CategoriaEmpresa clone() {
    return CategoriaEmpresa(
      id: id,
      nombre: nombre,
      salarioBase: salarioBase,
    );
  }
}
