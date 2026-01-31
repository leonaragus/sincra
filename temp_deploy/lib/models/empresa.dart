// lib/models/empresa.dart

import 'convenio_empresa.dart';
import 'categoria_empresa.dart';
import 'parametro_empresa.dart';

class Empresa {
  String razonSocial;
  String cuit;
  String domicilio;
  String convenioId;
  String convenioNombre;
  bool convenioPersonalizado;
  String? logoPath; // Almacena el logo de la empresa (si se carga uno)
  String? firmaPath; // Almacena la firma digital de la empresa (ARCA 2026)
  List<CategoriaEmpresa> categorias;
  List<ParametroEmpresa> parametros;
  ConvenioEmpresa? convenio; // Campo para el convenio

  // Constructor
  Empresa({
    required this.razonSocial,
    required this.cuit,
    required this.domicilio,
    required this.convenioId,
    required this.convenioNombre,
    required this.convenioPersonalizado,
    this.logoPath,
    this.firmaPath,
    required this.categorias,
    required this.parametros,
    this.convenio,
  });

  // Método para clonar la empresa
  Empresa clone() {
    return Empresa(
      razonSocial: razonSocial,
      cuit: cuit,
      domicilio: domicilio,
      convenioId: convenioId,
      convenioNombre: convenioNombre,
      convenioPersonalizado: convenioPersonalizado,
      logoPath: logoPath,
      firmaPath: firmaPath,
      categorias: List.from(categorias.map((e) => e.clone())),
      parametros: List.from(parametros.map((e) => e.clone())),
      convenio: convenio?.clone(),
    );
  }
}
