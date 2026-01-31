// lib/models/convenio_empresa.dart

import 'categoria_empresa.dart';
import 'parametro_empresa.dart';

class ConvenioEmpresa {
  final String id;
  final String nombre;
  final String descripcion;
  final bool personalizado;
  final List<CategoriaEmpresa> categorias;
  final List<ParametroEmpresa> parametros;

  const ConvenioEmpresa({
    required this.id,
    required this.nombre,
    required this.descripcion,
    required this.personalizado,
    required this.categorias,
    required this.parametros,
  });

  ConvenioEmpresa clone() {
    return ConvenioEmpresa(
      id: id,
      nombre: nombre,
      descripcion: descripcion,
      personalizado: personalizado,
      categorias: categorias.map((c) => c.clone()).toList(),
      parametros: parametros.map((p) => p.clone()).toList(),
    );
  }
}
