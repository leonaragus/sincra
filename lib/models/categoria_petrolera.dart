enum TipoPetrolero {
  cct,
  jerarquico,
}

class CategoriaPetrolera {
  final String nombre;
  final double salarioBase;
  final TipoPetrolero tipo;

  CategoriaPetrolera({
    required this.nombre,
    required this.salarioBase,
    required this.tipo,
  });
}

final List<CategoriaPetrolera> categoriasPetroleros = [
  // CCT 644/12
  CategoriaPetrolera(
    nombre: 'Peón',
    salarioBase: 400000,
    tipo: TipoPetrolero.cct,
  ),
  CategoriaPetrolera(
    nombre: 'Oficial',
    salarioBase: 520000,
    tipo: TipoPetrolero.cct,
  ),
  CategoriaPetrolera(
    nombre: 'Oficial Especializado',
    salarioBase: 650000,
    tipo: TipoPetrolero.cct,
  ),

  // Jerárquicos
  CategoriaPetrolera(
    nombre: 'Supervisor',
    salarioBase: 900000,
    tipo: TipoPetrolero.jerarquico,
  ),
  CategoriaPetrolera(
    nombre: 'Jefe de Área',
    salarioBase: 1200000,
    tipo: TipoPetrolero.jerarquico,
  ),
];
