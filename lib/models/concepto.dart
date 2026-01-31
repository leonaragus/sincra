enum TipoConcepto {
  remunerativo,
  noRemunerativo,
  descuento,
}

enum ModoConcepto {
  fijo,
  porcentaje,
}

class Concepto {
  final String descripcion;
  final TipoConcepto tipo;
  final ModoConcepto modo;
  final double valor;

  Concepto({
    required this.descripcion,
    required this.tipo,
    required this.modo,
    required this.valor,
  });

  double calcular(double bruto) {
    if (modo == ModoConcepto.fijo) {
      return valor;
    }
    return bruto * valor / 100;
  }
}
