// Base de datos completa de Convenios Colectivos de Trabajo (CCT) de Argentina
import '../models/cct_completo.dart';

final List<CCTCompleto> cctArgentinaCompleto = [
  // CCT 130/75 - Empleados de Comercio
  const CCTCompleto(
    id: 'cct_130_75',
    numeroCCT: '130/75',
    nombre: 'Empleados de Comercio',
    descripcion: 'Convenio Colectivo de Trabajo para Empleados de Comercio',
    actividad: 'Comercio',
    categorias: [
      CategoriaCCT(
        id: 'adm_a',
        nombre: 'Administrativo A',
        salarioBase: 850000.0,
        descripcion: 'Personal administrativo nivel inicial',
      ),
      CategoriaCCT(
        id: 'adm_b',
        nombre: 'Administrativo B',
        salarioBase: 950000.0,
        descripcion: 'Personal administrativo nivel intermedio',
      ),
      CategoriaCCT(
        id: 'adm_c',
        nombre: 'Administrativo C',
        salarioBase: 1100000.0,
        descripcion: 'Personal administrativo nivel superior',
      ),
      CategoriaCCT(
        id: 'vendedor',
        nombre: 'Vendedor',
        salarioBase: 900000.0,
        descripcion: 'Personal de ventas',
      ),
      CategoriaCCT(
        id: 'cajero',
        nombre: 'Cajero',
        salarioBase: 880000.0,
        descripcion: 'Personal de caja',
      ),
      CategoriaCCT(
        id: 'jefe_seccion',
        nombre: 'Jefe de Sección',
        salarioBase: 1300000.0,
        descripcion: 'Jefe de sección o departamento',
      ),
    ],
    descuentos: [
      DescuentoCCT(
        id: 'obra_social',
        nombre: 'Obra Social',
        porcentaje: 3.0,
        descripcion: 'Descuento por obra social',
      ),
      DescuentoCCT(
        id: 'jubilacion',
        nombre: 'Jubilación',
        porcentaje: 11.0,
        descripcion: 'Aporte jubilatorio',
      ),
      DescuentoCCT(
        id: 'ley_19032',
        nombre: 'Ley 19.032',
        porcentaje: 3.0,
        descripcion: 'Descuento Ley 19.032',
      ),
      DescuentoCCT(
        id: 'sindicato',
        nombre: 'Sindicato',
        porcentaje: 2.5,
        descripcion: 'Aporte sindical',
      ),
    ],
    zonas: [
      ZonaCCT(
        id: 'zona_1',
        nombre: 'Zona Normal',
        adicionalPorcentaje: 0.0,
        descripcion: 'Zona sin adicional',
      ),
      ZonaCCT(
        id: 'zona_2',
        nombre: 'Zona Desfavorable',
        adicionalPorcentaje: 15.0,
        descripcion: 'Zona con adicional del 15%',
      ),
      ZonaCCT(
        id: 'zona_3',
        nombre: 'Zona Muy Desfavorable',
        adicionalPorcentaje: 25.0,
        descripcion: 'Zona con adicional del 25%',
      ),
    ],
    adicionalPresentismo: 8.33,
    adicionalAntiguedad: 1.0,
    horasMensualesDivisor: 192.0, // CCT 130/75: 192 horas mensuales (48 horas semanales)
    esDivisorDias: false,
  ),

  // CCT 76/93 - Construcción (UOCRA)
  const CCTCompleto(
    id: 'cct_76_93',
    numeroCCT: '76/93',
    nombre: 'Construcción - UOCRA',
    descripcion: 'Convenio Colectivo de Trabajo para la Actividad de la Construcción',
    actividad: 'Construcción',
    categorias: [
      CategoriaCCT(
        id: 'oficial_especializado',
        nombre: 'Oficial Especializado',
        salarioBase: 1200000.0,
        descripcion: 'Oficial con especialización',
      ),
      CategoriaCCT(
        id: 'oficial',
        nombre: 'Oficial',
        salarioBase: 1000000.0,
        descripcion: 'Oficial de obra',
      ),
      CategoriaCCT(
        id: 'medio_oficial',
        nombre: 'Medio Oficial',
        salarioBase: 850000.0,
        descripcion: 'Medio oficial',
      ),
      CategoriaCCT(
        id: 'ayudante',
        nombre: 'Ayudante',
        salarioBase: 750000.0,
        descripcion: 'Ayudante de obra',
      ),
      CategoriaCCT(
        id: 'peon',
        nombre: 'Peón',
        salarioBase: 700000.0,
        descripcion: 'Peón de obra',
      ),
      CategoriaCCT(
        id: 'capataz',
        nombre: 'Capataz',
        salarioBase: 1400000.0,
        descripcion: 'Capataz de obra',
      ),
    ],
    descuentos: [
      DescuentoCCT(
        id: 'obra_social',
        nombre: 'Obra Social',
        porcentaje: 3.0,
      ),
      DescuentoCCT(
        id: 'jubilacion',
        nombre: 'Jubilación',
        porcentaje: 11.0,
      ),
      DescuentoCCT(
        id: 'ley_19032',
        nombre: 'Ley 19.032',
        porcentaje: 3.0,
      ),
      DescuentoCCT(
        id: 'sindicato',
        nombre: 'Sindicato UOCRA',
        porcentaje: 2.5,
      ),
    ],
    zonas: [
      ZonaCCT(
        id: 'zona_normal',
        nombre: 'Zona Normal',
        adicionalPorcentaje: 0.0,
      ),
      ZonaCCT(
        id: 'zona_desfavorable',
        nombre: 'Zona Desfavorable',
        adicionalPorcentaje: 20.0,
        descripcion: 'Adicional zona desfavorable 20%',
      ),
      ZonaCCT(
        id: 'zona_muy_desfavorable',
        nombre: 'Zona Muy Desfavorable',
        adicionalPorcentaje: 30.0,
        descripcion: 'Adicional zona muy desfavorable 30%',
      ),
    ],
    adicionalPresentismo: 8.33,
    adicionalAntiguedad: 1.0,
    horasMensualesDivisor: 200.0, // CCT 76/93: 200 horas mensuales (estándar construcción)
    esDivisorDias: false,
  ),

  // CCT Metalúrgico - UOM
  const CCTCompleto(
    id: 'cct_metalurgico',
    numeroCCT: '260/75',
    nombre: 'Metalúrgico - UOM',
    descripcion: 'Convenio Colectivo de Trabajo para la Industria Metalúrgica',
    actividad: 'Metalurgia',
    categorias: [
      CategoriaCCT(
        id: 'operario_especializado',
        nombre: 'Operario Especializado',
        salarioBase: 1100000.0,
      ),
      CategoriaCCT(
        id: 'operario',
        nombre: 'Operario',
        salarioBase: 950000.0,
      ),
      CategoriaCCT(
        id: 'medio_oficial',
        nombre: 'Medio Oficial',
        salarioBase: 850000.0,
      ),
      CategoriaCCT(
        id: 'ayudante',
        nombre: 'Ayudante',
        salarioBase: 750000.0,
      ),
      CategoriaCCT(
        id: 'maquinista',
        nombre: 'Maquinista',
        salarioBase: 1200000.0,
      ),
      CategoriaCCT(
        id: 'supervisor',
        nombre: 'Supervisor',
        salarioBase: 1400000.0,
      ),
    ],
    descuentos: [
      DescuentoCCT(
        id: 'obra_social',
        nombre: 'Obra Social',
        porcentaje: 3.0,
      ),
      DescuentoCCT(
        id: 'jubilacion',
        nombre: 'Jubilación',
        porcentaje: 11.0,
      ),
      DescuentoCCT(
        id: 'ley_19032',
        nombre: 'Ley 19.032',
        porcentaje: 3.0,
      ),
      DescuentoCCT(
        id: 'sindicato',
        nombre: 'Sindicato UOM',
        porcentaje: 2.5,
      ),
    ],
    zonas: [
      ZonaCCT(
        id: 'zona_normal',
        nombre: 'Zona Normal',
        adicionalPorcentaje: 0.0,
      ),
      ZonaCCT(
        id: 'zona_desfavorable',
        nombre: 'Zona Desfavorable',
        adicionalPorcentaje: 12.0,
      ),
    ],
    adicionalPresentismo: 8.33,
    adicionalAntiguedad: 1.0,
  ),

  // CCT Gastronómicos - UTHGRA
  const CCTCompleto(
    id: 'cct_gastronomicos',
    numeroCCT: '297/89',
    nombre: 'Gastronómicos - UTHGRA',
    descripcion: 'Convenio Colectivo de Trabajo para la Actividad Gastronómica',
    actividad: 'Gastronomía',
    categorias: [
      CategoriaCCT(
        id: 'cocinero_jefe',
        nombre: 'Cocinero Jefe',
        salarioBase: 1300000.0,
      ),
      CategoriaCCT(
        id: 'cocinero',
        nombre: 'Cocinero',
        salarioBase: 1000000.0,
      ),
      CategoriaCCT(
        id: 'pastelero',
        nombre: 'Pastelero',
        salarioBase: 1050000.0,
      ),
      CategoriaCCT(
        id: 'mozo',
        nombre: 'Mozo',
        salarioBase: 850000.0,
      ),
      CategoriaCCT(
        id: 'barman',
        nombre: 'Barman',
        salarioBase: 950000.0,
      ),
      CategoriaCCT(
        id: 'ayudante_cocina',
        nombre: 'Ayudante de Cocina',
        salarioBase: 750000.0,
      ),
    ],
    descuentos: [
      DescuentoCCT(
        id: 'obra_social',
        nombre: 'Obra Social',
        porcentaje: 3.0,
      ),
      DescuentoCCT(
        id: 'jubilacion',
        nombre: 'Jubilación',
        porcentaje: 11.0,
      ),
      DescuentoCCT(
        id: 'ley_19032',
        nombre: 'Ley 19.032',
        porcentaje: 3.0,
      ),
      DescuentoCCT(
        id: 'sindicato',
        nombre: 'Sindicato UTHGRA',
        porcentaje: 2.5,
      ),
    ],
    zonas: [
      ZonaCCT(
        id: 'zona_normal',
        nombre: 'Zona Normal',
        adicionalPorcentaje: 0.0,
      ),
      ZonaCCT(
        id: 'zona_turistica',
        nombre: 'Zona Turística',
        adicionalPorcentaje: 10.0,
      ),
    ],
    adicionalPresentismo: 8.33,
    adicionalAntiguedad: 1.0,
    horasMensualesDivisor: 200.0, // CCT 260/75: 200 horas mensuales (estándar metalúrgico)
    esDivisorDias: false,
  ),

  // CCT Petroleros
  const CCTCompleto(
    id: 'cct_petroleros',
    numeroCCT: '644/12',
    nombre: 'Petroleros',
    descripcion: 'Convenio Colectivo de Trabajo para la Actividad Petrolera',
    actividad: 'Petróleo',
    categorias: [
      CategoriaCCT(
        id: 'operario_especializado',
        nombre: 'Operario Especializado',
        salarioBase: 1500000.0,
      ),
      CategoriaCCT(
        id: 'operario',
        nombre: 'Operario',
        salarioBase: 1300000.0,
      ),
      CategoriaCCT(
        id: 'medio_oficial',
        nombre: 'Medio Oficial',
        salarioBase: 1100000.0,
      ),
      CategoriaCCT(
        id: 'ayudante',
        nombre: 'Ayudante',
        salarioBase: 950000.0,
      ),
      CategoriaCCT(
        id: 'supervisor',
        nombre: 'Supervisor',
        salarioBase: 1700000.0,
      ),
    ],
    descuentos: [
      DescuentoCCT(
        id: 'obra_social',
        nombre: 'Obra Social',
        porcentaje: 3.0,
      ),
      DescuentoCCT(
        id: 'jubilacion',
        nombre: 'Jubilación',
        porcentaje: 11.0,
      ),
      DescuentoCCT(
        id: 'ley_19032',
        nombre: 'Ley 19.032',
        porcentaje: 3.0,
      ),
      DescuentoCCT(
        id: 'sindicato',
        nombre: 'Sindicato Petroleros',
        porcentaje: 2.5,
      ),
    ],
    zonas: [
      ZonaCCT(
        id: 'zona_normal',
        nombre: 'Zona Normal',
        adicionalPorcentaje: 0.0,
      ),
      ZonaCCT(
        id: 'zona_aislada',
        nombre: 'Zona Aislada',
        adicionalPorcentaje: 30.0,
        descripcion: 'Adicional zona aislada 30%',
      ),
    ],
    adicionalPresentismo: 8.33,
    adicionalAntiguedad: 1.5,
    horasMensualesDivisor: 200.0, // Petroleros general: 200 horas mensuales
    esDivisorDias: false,
  ),

  // CCT Textil
  const CCTCompleto(
    id: 'cct_textil',
    numeroCCT: '130/75',
    nombre: 'Textil',
    descripcion: 'Convenio Colectivo de Trabajo para la Industria Textil',
    actividad: 'Textil',
    categorias: [
      CategoriaCCT(
        id: 'operario_especializado',
        nombre: 'Operario Especializado',
        salarioBase: 900000.0,
      ),
      CategoriaCCT(
        id: 'operario',
        nombre: 'Operario',
        salarioBase: 800000.0,
      ),
      CategoriaCCT(
        id: 'ayudante',
        nombre: 'Ayudante',
        salarioBase: 700000.0,
      ),
    ],
    descuentos: [
      DescuentoCCT(
        id: 'obra_social',
        nombre: 'Obra Social',
        porcentaje: 3.0,
      ),
      DescuentoCCT(
        id: 'jubilacion',
        nombre: 'Jubilación',
        porcentaje: 11.0,
      ),
      DescuentoCCT(
        id: 'ley_19032',
        nombre: 'Ley 19.032',
        porcentaje: 3.0,
      ),
    ],
    zonas: [
      ZonaCCT(
        id: 'zona_normal',
        nombre: 'Zona Normal',
        adicionalPorcentaje: 0.0,
      ),
    ],
    adicionalPresentismo: 8.33,
    adicionalAntiguedad: 1.0,
    horasMensualesDivisor: 200.0, // Textil: 200 horas mensuales (estándar)
    esDivisorDias: false,
  ),

  // CCT Químico
  const CCTCompleto(
    id: 'cct_quimico',
    numeroCCT: '130/75',
    nombre: 'Químico',
    descripcion: 'Convenio Colectivo de Trabajo para la Industria Química',
    actividad: 'Química',
    categorias: [
      CategoriaCCT(
        id: 'operario_especializado',
        nombre: 'Operario Especializado',
        salarioBase: 1200000.0,
      ),
      CategoriaCCT(
        id: 'operario',
        nombre: 'Operario',
        salarioBase: 1000000.0,
      ),
      CategoriaCCT(
        id: 'ayudante',
        nombre: 'Ayudante',
        salarioBase: 850000.0,
      ),
    ],
    descuentos: [
      DescuentoCCT(
        id: 'obra_social',
        nombre: 'Obra Social',
        porcentaje: 3.0,
      ),
      DescuentoCCT(
        id: 'jubilacion',
        nombre: 'Jubilación',
        porcentaje: 11.0,
      ),
      DescuentoCCT(
        id: 'ley_19032',
        nombre: 'Ley 19.032',
        porcentaje: 3.0,
      ),
    ],
    zonas: [
      ZonaCCT(
        id: 'zona_normal',
        nombre: 'Zona Normal',
        adicionalPorcentaje: 0.0,
      ),
    ],
    adicionalPresentismo: 8.33,
    adicionalAntiguedad: 1.0,
    horasMensualesDivisor: 200.0, // Químico: 200 horas mensuales (estándar)
    esDivisorDias: false,
  ),

  // CCT UOCRA Yacimiento
  const CCTCompleto(
    id: 'cct_uocra_yacimiento',
    numeroCCT: '76/93 Yacimiento',
    nombre: 'UOCRA Yacimiento',
    descripcion: 'Convenio Colectivo de Trabajo para la Construcción en Yacimientos',
    actividad: 'Construcción Yacimiento',
    categorias: [
      CategoriaCCT(
        id: 'oficial_especializado_yac',
        nombre: 'Oficial Especializado Yacimiento',
        salarioBase: 1400000.0,
        descripcion: 'Oficial especializado en yacimientos',
      ),
      CategoriaCCT(
        id: 'oficial_yac',
        nombre: 'Oficial Yacimiento',
        salarioBase: 1200000.0,
        descripcion: 'Oficial de obra en yacimiento',
      ),
      CategoriaCCT(
        id: 'medio_oficial_yac',
        nombre: 'Medio Oficial Yacimiento',
        salarioBase: 1000000.0,
        descripcion: 'Medio oficial en yacimiento',
      ),
      CategoriaCCT(
        id: 'ayudante_yac',
        nombre: 'Ayudante Yacimiento',
        salarioBase: 900000.0,
        descripcion: 'Ayudante en yacimiento',
      ),
      CategoriaCCT(
        id: 'supervisor_yac',
        nombre: 'Supervisor Yacimiento',
        salarioBase: 1600000.0,
        descripcion: 'Supervisor de obra en yacimiento',
      ),
    ],
    descuentos: [
      DescuentoCCT(
        id: 'obra_social',
        nombre: 'Obra Social',
        porcentaje: 3.0,
      ),
      DescuentoCCT(
        id: 'jubilacion',
        nombre: 'Jubilación',
        porcentaje: 11.0,
      ),
      DescuentoCCT(
        id: 'ley_19032',
        nombre: 'Ley 19.032',
        porcentaje: 3.0,
      ),
      DescuentoCCT(
        id: 'sindicato',
        nombre: 'Sindicato UOCRA',
        porcentaje: 2.5,
      ),
    ],
    zonas: [
      ZonaCCT(
        id: 'zona_normal',
        nombre: 'Zona Normal',
        adicionalPorcentaje: 0.0,
      ),
      ZonaCCT(
        id: 'zona_yacimiento',
        nombre: 'Zona Yacimiento',
        adicionalPorcentaje: 35.0,
        descripcion: 'Adicional zona yacimiento 35%',
      ),
    ],
    adicionalPresentismo: 8.33,
    adicionalAntiguedad: 1.5,
    horasMensualesDivisor: 200.0, // UOCRA Yacimiento: 200 horas mensuales (estándar)
    esDivisorDias: false,
  ),

  // CCT Petroleros Jerárquicos
  const CCTCompleto(
    id: 'cct_petroleros_jerarquicos',
    numeroCCT: '644/12 Jerárquicos',
    nombre: 'Petroleros Jerárquicos',
    descripcion: 'Convenio Colectivo de Trabajo para Personal Jerárquico de la Actividad Petrolera',
    actividad: 'Petróleo Jerárquico',
    categorias: [
      CategoriaCCT(
        id: 'gerente',
        nombre: 'Gerente',
        salarioBase: 2500000.0,
        descripcion: 'Gerente de área',
      ),
      CategoriaCCT(
        id: 'jefe_departamento',
        nombre: 'Jefe de Departamento',
        salarioBase: 2200000.0,
        descripcion: 'Jefe de departamento',
      ),
      CategoriaCCT(
        id: 'supervisor_jerarquico',
        nombre: 'Supervisor Jerárquico',
        salarioBase: 2000000.0,
        descripcion: 'Supervisor nivel jerárquico',
      ),
      CategoriaCCT(
        id: 'jefe_turno',
        nombre: 'Jefe de Turno',
        salarioBase: 1800000.0,
        descripcion: 'Jefe de turno',
      ),
      CategoriaCCT(
        id: 'coordinador',
        nombre: 'Coordinador',
        salarioBase: 1600000.0,
        descripcion: 'Coordinador de área',
      ),
    ],
    descuentos: [
      DescuentoCCT(
        id: 'obra_social',
        nombre: 'Obra Social',
        porcentaje: 3.0,
      ),
      DescuentoCCT(
        id: 'jubilacion',
        nombre: 'Jubilación',
        porcentaje: 11.0,
      ),
      DescuentoCCT(
        id: 'ley_19032',
        nombre: 'Ley 19.032',
        porcentaje: 3.0,
      ),
      DescuentoCCT(
        id: 'sindicato',
        nombre: 'Sindicato Petroleros',
        porcentaje: 2.5,
      ),
    ],
    zonas: [
      ZonaCCT(
        id: 'zona_normal',
        nombre: 'Zona Normal',
        adicionalPorcentaje: 0.0,
      ),
      ZonaCCT(
        id: 'zona_aislada',
        nombre: 'Zona Aislada',
        adicionalPorcentaje: 30.0,
        descripcion: 'Adicional zona aislada 30%',
      ),
    ],
    adicionalPresentismo: 8.33,
    adicionalAntiguedad: 2.0,
    horasMensualesDivisor: 173.0, // Petroleros Jerárquicos: 173 horas mensuales
    esDivisorDias: false,
  ),

  // CCT Plástico
  const CCTCompleto(
    id: 'cct_plastico',
    numeroCCT: '130/75',
    nombre: 'Industria del Plástico',
    descripcion: 'Convenio Colectivo de Trabajo para la Industria del Plástico',
    actividad: 'Plástico',
    categorias: [
      CategoriaCCT(
        id: 'operario_especializado',
        nombre: 'Operario Especializado',
        salarioBase: 1100000.0,
        descripcion: 'Operario especializado en plástico',
      ),
      CategoriaCCT(
        id: 'operario',
        nombre: 'Operario',
        salarioBase: 950000.0,
        descripcion: 'Operario de producción',
      ),
      CategoriaCCT(
        id: 'medio_oficial',
        nombre: 'Medio Oficial',
        salarioBase: 850000.0,
        descripcion: 'Medio oficial',
      ),
      CategoriaCCT(
        id: 'ayudante',
        nombre: 'Ayudante',
        salarioBase: 750000.0,
        descripcion: 'Ayudante de producción',
      ),
      CategoriaCCT(
        id: 'moldeador',
        nombre: 'Moldeador',
        salarioBase: 1200000.0,
        descripcion: 'Moldeador de plástico',
      ),
      CategoriaCCT(
        id: 'supervisor',
        nombre: 'Supervisor',
        salarioBase: 1400000.0,
        descripcion: 'Supervisor de producción',
      ),
    ],
    descuentos: [
      DescuentoCCT(
        id: 'obra_social',
        nombre: 'Obra Social',
        porcentaje: 3.0,
      ),
      DescuentoCCT(
        id: 'jubilacion',
        nombre: 'Jubilación',
        porcentaje: 11.0,
      ),
      DescuentoCCT(
        id: 'ley_19032',
        nombre: 'Ley 19.032',
        porcentaje: 3.0,
      ),
      DescuentoCCT(
        id: 'sindicato',
        nombre: 'Sindicato Plástico',
        porcentaje: 2.5,
      ),
    ],
    zonas: [
      ZonaCCT(
        id: 'zona_normal',
        nombre: 'Zona Normal',
        adicionalPorcentaje: 0.0,
      ),
      ZonaCCT(
        id: 'zona_desfavorable',
        nombre: 'Zona Desfavorable',
        adicionalPorcentaje: 15.0,
      ),
    ],
    adicionalPresentismo: 8.33,
    adicionalAntiguedad: 1.0,
    horasMensualesDivisor: 200.0, // Plástico: 200 horas mensuales (estándar)
    esDivisorDias: false,
  ),

  // CCT Camioneros
  const CCTCompleto(
    id: 'cct_camioneros',
    numeroCCT: '40/89',
    nombre: 'Camioneros',
    descripcion: 'Convenio Colectivo de Trabajo para Choferes de Camiones',
    actividad: 'Transporte',
    categorias: [
      CategoriaCCT(
        id: 'chofer_larga_distancia',
        nombre: 'Chofer Larga Distancia',
        salarioBase: 1300000.0,
        descripcion: 'Chofer de larga distancia',
      ),
      CategoriaCCT(
        id: 'chofer_corta_distancia',
        nombre: 'Chofer Corta Distancia',
        salarioBase: 1100000.0,
        descripcion: 'Chofer de corta distancia',
      ),
      CategoriaCCT(
        id: 'chofer_local',
        nombre: 'Chofer Local',
        salarioBase: 1000000.0,
        descripcion: 'Chofer de distribución local',
      ),
      CategoriaCCT(
        id: 'ayudante',
        nombre: 'Ayudante',
        salarioBase: 850000.0,
        descripcion: 'Ayudante de chofer',
      ),
      CategoriaCCT(
        id: 'mecanico',
        nombre: 'Mecánico',
        salarioBase: 1200000.0,
        descripcion: 'Mecánico de camiones',
      ),
    ],
    descuentos: [
      DescuentoCCT(
        id: 'obra_social',
        nombre: 'Obra Social',
        porcentaje: 3.0,
      ),
      DescuentoCCT(
        id: 'jubilacion',
        nombre: 'Jubilación',
        porcentaje: 11.0,
      ),
      DescuentoCCT(
        id: 'ley_19032',
        nombre: 'Ley 19.032',
        porcentaje: 3.0,
      ),
      DescuentoCCT(
        id: 'sindicato',
        nombre: 'Sindicato Camioneros',
        porcentaje: 2.5,
      ),
    ],
    zonas: [
      ZonaCCT(
        id: 'zona_normal',
        nombre: 'Zona Normal',
        adicionalPorcentaje: 0.0,
      ),
      ZonaCCT(
        id: 'zona_larga_distancia',
        nombre: 'Zona Larga Distancia',
        adicionalPorcentaje: 25.0,
        descripcion: 'Adicional larga distancia 25%',
      ),
    ],
    adicionalPresentismo: 8.33,
    adicionalAntiguedad: 1.0,
    horasMensualesDivisor: 24.0, // CCT 40/89: Divisor 24 días (especial para camioneros)
    esDivisorDias: true, // Camioneros usa divisor de días, no de horas
  ),

  // CCT Alimentación
  const CCTCompleto(
    id: 'cct_alimentacion',
    numeroCCT: '130/75',
    nombre: 'Alimentación',
    descripcion: 'Convenio Colectivo de Trabajo para la Industria Alimenticia',
    actividad: 'Alimentación',
    categorias: [
      CategoriaCCT(
        id: 'operario_especializado',
        nombre: 'Operario Especializado',
        salarioBase: 1000000.0,
      ),
      CategoriaCCT(
        id: 'operario',
        nombre: 'Operario',
        salarioBase: 900000.0,
      ),
      CategoriaCCT(
        id: 'ayudante',
        nombre: 'Ayudante',
        salarioBase: 800000.0,
      ),
    ],
    descuentos: [
      DescuentoCCT(
        id: 'obra_social',
        nombre: 'Obra Social',
        porcentaje: 3.0,
      ),
      DescuentoCCT(
        id: 'jubilacion',
        nombre: 'Jubilación',
        porcentaje: 11.0,
      ),
      DescuentoCCT(
        id: 'ley_19032',
        nombre: 'Ley 19.032',
        porcentaje: 3.0,
      ),
    ],
    zonas: [
      ZonaCCT(
        id: 'zona_normal',
        nombre: 'Zona Normal',
        adicionalPorcentaje: 0.0,
      ),
    ],
    adicionalPresentismo: 8.33,
    adicionalAntiguedad: 1.0,
    horasMensualesDivisor: 200.0, // Alimentación: 200 horas mensuales (estándar)
    esDivisorDias: false,
  ),

  // CCT Gráfico
  const CCTCompleto(
    id: 'cct_grafico',
    numeroCCT: '130/75',
    nombre: 'Gráfico',
    descripcion: 'Convenio Colectivo de Trabajo para la Industria Gráfica',
    actividad: 'Gráfico',
    categorias: [
      CategoriaCCT(
        id: 'maquinista',
        nombre: 'Maquinista',
        salarioBase: 1150000.0,
      ),
      CategoriaCCT(
        id: 'operario',
        nombre: 'Operario',
        salarioBase: 950000.0,
      ),
      CategoriaCCT(
        id: 'ayudante',
        nombre: 'Ayudante',
        salarioBase: 800000.0,
      ),
    ],
    descuentos: [
      DescuentoCCT(
        id: 'obra_social',
        nombre: 'Obra Social',
        porcentaje: 3.0,
      ),
      DescuentoCCT(
        id: 'jubilacion',
        nombre: 'Jubilación',
        porcentaje: 11.0,
      ),
      DescuentoCCT(
        id: 'ley_19032',
        nombre: 'Ley 19.032',
        porcentaje: 3.0,
      ),
    ],
    zonas: [
      ZonaCCT(
        id: 'zona_normal',
        nombre: 'Zona Normal',
        adicionalPorcentaje: 0.0,
      ),
    ],
    adicionalPresentismo: 8.33,
    adicionalAntiguedad: 1.0,
  ),

  // CCT Madera
  const CCTCompleto(
    id: 'cct_madera',
    numeroCCT: '130/75',
    nombre: 'Madera',
    descripcion: 'Convenio Colectivo de Trabajo para la Industria de la Madera',
    actividad: 'Madera',
    categorias: [
      CategoriaCCT(
        id: 'ebanista',
        nombre: 'Ebanista',
        salarioBase: 1100000.0,
      ),
      CategoriaCCT(
        id: 'operario',
        nombre: 'Operario',
        salarioBase: 950000.0,
      ),
      CategoriaCCT(
        id: 'ayudante',
        nombre: 'Ayudante',
        salarioBase: 800000.0,
      ),
    ],
    descuentos: [
      DescuentoCCT(
        id: 'obra_social',
        nombre: 'Obra Social',
        porcentaje: 3.0,
      ),
      DescuentoCCT(
        id: 'jubilacion',
        nombre: 'Jubilación',
        porcentaje: 11.0,
      ),
      DescuentoCCT(
        id: 'ley_19032',
        nombre: 'Ley 19.032',
        porcentaje: 3.0,
      ),
    ],
    zonas: [
      ZonaCCT(
        id: 'zona_normal',
        nombre: 'Zona Normal',
        adicionalPorcentaje: 0.0,
      ),
    ],
    adicionalPresentismo: 8.33,
    adicionalAntiguedad: 1.0,
    horasMensualesDivisor: 200.0, // Madera: 200 horas mensuales (estándar)
    esDivisorDias: false,
  ),
];
