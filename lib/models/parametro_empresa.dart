class ParametroEmpresa {
  final String clave;
  final String nombre;
  final double valor;

  ParametroEmpresa({
    required this.clave,
    required this.nombre,
    required this.valor,
  });

  ParametroEmpresa clone() {
    return ParametroEmpresa(
      clave: clave,
      nombre: nombre,
      valor: valor,
    );
  }
}
