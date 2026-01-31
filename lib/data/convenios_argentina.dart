// lib/data/convenios_argentina.dart

import '../models/convenio_empresa.dart';
import '../models/categoria_empresa.dart';
import '../models/parametro_empresa.dart';

final List<ConvenioEmpresa> conveniosArgentina = [
  ConvenioEmpresa(
    id: 'comercio',
    nombre: 'Empleados de Comercio',
    descripcion: 'Convenio colectivo empleados de comercio',
    personalizado: false,
    categorias: [
      CategoriaEmpresa(
        id: 'adm_a',
        nombre: 'Administrativo A',
        salarioBase: 500000,
      ),
      CategoriaEmpresa(
        id: 'adm_b',
        nombre: 'Administrativo B',
        salarioBase: 550000,
      ),
    ],
    parametros: [
      ParametroEmpresa(
        clave: 'presentismo',
        nombre: 'Presentismo',
        valor: 0.08,
      ),
    ],
  ),

  ConvenioEmpresa(
    id: 'gastronicos',
    nombre: 'Gastronómicos',
    descripcion: 'Convenio UTHGRA',
    personalizado: false,
    categorias: [
      CategoriaEmpresa(
        id: 'mozo',
        nombre: 'Mozo',
        salarioBase: 480000,
      ),
      CategoriaEmpresa(
        id: 'cocinero',
        nombre: 'Cocinero',
        salarioBase: 600000,
      ),
    ],
    parametros: [
      ParametroEmpresa(
        clave: 'antiguedad',
        nombre: 'Antigüedad',
        valor: 0.01,
      ),
    ],
  ),

  ConvenioEmpresa(
    id: 'construccion',
    nombre: 'Construcción',
    descripcion: 'Convenio UOCRA',
    personalizado: false,
    categorias: [
      CategoriaEmpresa(
        id: 'oficial',
        nombre: 'Oficial',
        salarioBase: 650000,
      ),
      CategoriaEmpresa(
        id: 'ayudante',
        nombre: 'Ayudante',
        salarioBase: 520000,
      ),
    ],
    parametros: [
      ParametroEmpresa(
        clave: 'zona',
        nombre: 'Zona desfavorable',
        valor: 0.2,
      ),
    ],
  ),
];
