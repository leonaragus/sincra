enum TipoParametro {
  fijo,
  porcentaje,
}

class ParametroConvenio {
  final String nombre;
  final TipoParametro tipo;
  final double valor;
  final bool editable;

  const ParametroConvenio({
    required this.nombre,
    required this.tipo,
    required this.valor,
    this.editable = true,
  });
}

class CategoriaConvenio {
  final String nombre;
  final double basico;

  const CategoriaConvenio({
    required this.nombre,
    required this.basico,
  });
}

class ConvenioBase {
  final String id;
  final String nombre;
  final List<CategoriaConvenio> categorias;
  final List<ParametroConvenio> parametros;

  const ConvenioBase({
    required this.id,
    required this.nombre,
    required this.categorias,
    required this.parametros,
  });
}
