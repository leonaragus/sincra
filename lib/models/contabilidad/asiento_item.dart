
class AsientoItem {
  final String cuentaCodigo;
  final String cuentaNombre; // Denormalized for convenience
  final double debe;
  final double haber;
  final String leyenda; // Optional description
  final String? centroCostos; // Optional

  AsientoItem({
    required this.cuentaCodigo,
    required this.cuentaNombre,
    this.debe = 0.0,
    this.haber = 0.0,
    this.leyenda = '',
    this.centroCostos,
  });

  Map<String, dynamic> toMap() {
    return {
      'cuentaCodigo': cuentaCodigo,
      'cuentaNombre': cuentaNombre,
      'debe': debe,
      'haber': haber,
      'leyenda': leyenda,
      'centroCostos': centroCostos,
    };
  }
}

class AsientoResult {
  final List<AsientoItem> items;
  final double totalDebe;
  final double totalHaber;
  final bool balanceado;

  AsientoResult({
    required this.items,
  })  : totalDebe = items.fold(0.0, (sum, item) => sum + item.debe),
        totalHaber = items.fold(0.0, (sum, item) => sum + item.haber),
        balanceado = (items.fold(0.0, (sum, item) => sum + item.debe) -
                items.fold(0.0, (sum, item) => sum + item.haber))
            .abs() <
            0.01;
}
