// Base de datos completa de Convenios Colectivos de Trabajo (CCT) de Argentina
import '../models/cct_completo.dart';

final List<CCTCompleto> cctArgentinaCompleto = [
  // CCT 130/75 - Empleados de Comercio
  CCTCompleto(
    id: 'cct_130_75',
    numeroCCT: '130/75',
    nombre: 'Empleados de Comercio',
    descripcion: 'Convenio Colectivo de Trabajo para Empleados de Comercio. Escala vigente Febrero 2026.',
    actividad: 'Comercio',
    categorias: [
      const CategoriaCCT(
        id: 'maestranza_a',
        nombre: 'Maestranza A',
        salarioBase: 1050000.0,
        descripcion: 'Personal de maestranza y servicios',
      ),
      const CategoriaCCT(
        id: 'adm_a',
        nombre: 'Administrativo A',
        salarioBase: 1067268.0,
        descripcion: 'Personal administrativo nivel inicial',
      ),
      const CategoriaCCT(
        id: 'adm_b',
        nombre: 'Administrativo B',
        salarioBase: 1075000.0,
        descripcion: 'Personal administrativo nivel intermedio',
      ),
      const CategoriaCCT(
        id: 'adm_c',
        nombre: 'Administrativo C',
        salarioBase: 1100000.0,
        descripcion: 'Personal administrativo nivel superior',
      ),
      const CategoriaCCT(
        id: 'vendedor_b',
        nombre: 'Vendedor B',
        salarioBase: 1085000.0,
        descripcion: 'Personal de ventas',
      ),
      const CategoriaCCT(
        id: 'cajero_b',
        nombre: 'Cajero B',
        salarioBase: 1072000.0,
        descripcion: 'Personal de caja',
      ),
      const CategoriaCCT(
        id: 'auxiliar_a',
        nombre: 'Auxiliar A',
        salarioBase: 1065000.0,
        descripcion: 'Personal auxiliar',
      ),
    ],
    descuentos: [
      const DescuentoCCT(
        id: 'obra_social',
        nombre: 'Obra Social',
        porcentaje: 3.0,
        descripcion: 'Descuento por obra social (OSECAC)',
      ),
      const DescuentoCCT(
        id: 'jubilacion',
        nombre: 'Jubilación',
        porcentaje: 11.0,
        descripcion: 'Aporte jubilatorio',
      ),
      const DescuentoCCT(
        id: 'ley_19032',
        nombre: 'Ley 19.032',
        porcentaje: 3.0,
        descripcion: 'INSSJP',
      ),
      const DescuentoCCT(
        id: 'sindicato',
        nombre: 'Sindicato (SEC)',
        porcentaje: 2.0,
        descripcion: 'Aporte sindical',
      ),
      const DescuentoCCT(
        id: 'faecys',
        nombre: 'FAECyS',
        porcentaje: 0.5,
        descripcion: 'Aporte Federación',
      ),
    ],
    zonas: [
      const ZonaCCT(
        id: 'zona_1',
        nombre: 'Zona Normal',
        adicionalPorcentaje: 0.0,
        descripcion: 'Zona sin adicional',
      ),
      const ZonaCCT(
        id: 'zona_2',
        nombre: 'Zona Desfavorable (Sur)',
        adicionalPorcentaje: 20.0,
        descripcion: 'Chubut, Santa Cruz, Tierra del Fuego, etc.',
      ),
    ],
    adicionalPresentismo: 8.33,
    adicionalAntiguedad: 1.0,
    horasMensualesDivisor: 192.0,
    esDivisorDias: false,
    fechaVigencia: DateTime(2026, 2, 1),
    activo: true,
    pdfUrl: 'https://www.faecys.org.ar/images/CCT130-75.pdf',
  ),

  // CCT 76/75 - Construcción (UOCRA)
  CCTCompleto(
    id: 'cct_76_93',
    numeroCCT: '76/75',
    nombre: 'Construcción - UOCRA',
    descripcion: 'Convenio UOCRA. Escala Febrero 2026 (Valores Hora mensualizados base 200hs).',
    actividad: 'Construcción',
    categorias: [
      CategoriaCCT(
        id: 'oficial_especializado',
        nombre: 'Oficial Especializado',
        salarioBase: 1094000.0,
        descripcion: 'Valor hora: \$5.470 + Suma No Rem: \$121.800',
      ),
      CategoriaCCT(
        id: 'oficial',
        nombre: 'Oficial',
        salarioBase: 935800.0,
        descripcion: 'Valor hora: \$4.679 + Suma No Rem: \$112.200',
      ),
      CategoriaCCT(
        id: 'medio_oficial',
        nombre: 'Medio Oficial',
        salarioBase: 864800.0,
        descripcion: 'Valor hora: \$4.324 + Suma No Rem: \$102.800',
      ),
      CategoriaCCT(
        id: 'ayudante',
        nombre: 'Ayudante',
        salarioBase: 796000.0,
        descripcion: 'Valor hora: \$3.980 + Suma No Rem: \$96.800',
      ),
      CategoriaCCT(
        id: 'sereno',
        nombre: 'Sereno',
        salarioBase: 723032.0,
        descripcion: 'Mensualizado. Suma No Rem: \$96.800',
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
        id: 'zona_a',
        nombre: 'Zona A (CABA/GBA/Centro)',
        adicionalPorcentaje: 0.0,
      ),
      ZonaCCT(
        id: 'zona_b',
        nombre: 'Zona B (Sur BsAs/Neuquén/Río Negro)',
        adicionalPorcentaje: 11.0, // Diferencia aprox de zona
        descripcion: 'Zona Patagónica Norte',
      ),
      ZonaCCT(
        id: 'zona_c',
        nombre: 'Zona C (Austral)',
        adicionalPorcentaje: 50.0, // Zona C suele ser mucho más alta
        descripcion: 'Zona Patagónica Sur',
      ),
    ],
    adicionalPresentismo: 20.0, // UOCRA tiene presentismo del 20% sobre el básico
    adicionalAntiguedad: 1.0,
    horasMensualesDivisor: 200.0,
    esDivisorDias: false,
    fechaVigencia: DateTime(2026, 2, 1),
    activo: true,
    pdfUrl: 'https://www.uocra.org/pdf/9c21ef_76.75.pdf',
  ),

  // CCT Metalúrgico - UOM
  CCTCompleto(
    id: 'cct_metalurgico',
    numeroCCT: '260/75',
    nombre: 'Metalúrgico - UOM',
    descripcion: 'Convenio UOM. Escala Febrero 2026 (Ref IMGR \$1.004.438).',
    actividad: 'Metalurgia',
    categorias: [
      CategoriaCCT(
        id: 'operario',
        nombre: 'Operario',
        salarioBase: 950000.0,
        descripcion: 'Ingreso Mínimo Global Ref: \$1.004.438',
      ),
      CategoriaCCT(
        id: 'operario_calificado',
        nombre: 'Operario Calificado',
        salarioBase: 1050000.0,
      ),
      CategoriaCCT(
        id: 'medio_oficial',
        nombre: 'Medio Oficial',
        salarioBase: 1150000.0,
      ),
      CategoriaCCT(
        id: 'oficial',
        nombre: 'Oficial',
        salarioBase: 1250000.0,
      ),
      CategoriaCCT(
        id: 'oficial_multiple',
        nombre: 'Oficial Múltiple',
        salarioBase: 1350000.0,
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
    fechaVigencia: DateTime(2026, 2, 1),
    activo: true,
    pdfUrl: 'https://uomrosario.org.ar/documentos_varios/Convenio_Colectivo_nro_260-75.pdf',
  ),

  // CCT Docentes - Ley 13.047 / Paritaria Nacional (Federal)
  CCTCompleto(
    id: 'cct_docentes_federal',
    numeroCCT: 'Ley 13.047',
    nombre: 'Docentes (Nacional)',
    descripcion: 'Paritaria Nacional Docente 2026. Piso Salarial Federal Garantizado.',
    actividad: 'Educación',
    categorias: [
      CategoriaCCT(
        id: 'maestro_grado',
        nombre: 'Maestro de Grado',
        salarioBase: 745311.0,
        descripcion: 'Piso Salarial Nacional Garantizado (Jornada Simple)',
      ),
      CategoriaCCT(
        id: 'preceptor',
        nombre: 'Preceptor',
        salarioBase: 650000.0,
        descripcion: 'Referencia Federal aprox.',
      ),
      CategoriaCCT(
        id: 'director',
        nombre: 'Director 1ra Cat.',
        salarioBase: 1200000.0,
        descripcion: 'Referencia Federal aprox.',
      ),
      CategoriaCCT(
        id: 'hora_catedra',
        nombre: 'Hora Cátedra (Media)',
        salarioBase: 35000.0,
        descripcion: 'Valor ref. por hora cátedra',
      ),
    ],
    descuentos: [
      DescuentoCCT(
        id: 'jubilacion',
        nombre: 'Jubilación',
        porcentaje: 11.0,
        descripcion: 'Régimen Nacional (11%) / Provincial (13-16%)',
      ),
      DescuentoCCT(
        id: 'obra_social',
        nombre: 'Obra Social',
        porcentaje: 3.0,
        descripcion: 'Nacional (3%) / Provincial (4-6%)',
      ),
      DescuentoCCT(
        id: 'ley_19032',
        nombre: 'Ley 19.032',
        porcentaje: 3.0,
        descripcion: 'INSSJP (Solo Nacional)',
      ),
    ],
    zonas: [
      ZonaCCT(
        id: 'zona_comun',
        nombre: 'Zona Común',
        adicionalPorcentaje: 0.0,
      ),
      ZonaCCT(
        id: 'zona_desfavorable',
        nombre: 'Zona Desfavorable',
        adicionalPorcentaje: 20.0,
        descripcion: 'Variable por provincia (20% a 120%)',
      ),
    ],
    adicionalPresentismo: 0.0, // FONID no es presentismo técnico
    adicionalAntiguedad: 0.0, // Variable por escala
    horasMensualesDivisor: 20.0, // 20 horas semanales cargo testigo
    esDivisorDias: false,
    fechaVigencia: DateTime(2026, 1, 1),
    activo: true,
    pdfUrl: 'https://www.argentina.gob.ar/sites/default/files/ley_13047.pdf',
  ),

  // CCT Sanidad - FATSA (CCT 122/75)
  CCTCompleto(
    id: 'cct_sanidad_122_75',
    numeroCCT: '122/75',
    nombre: 'Sanidad - FATSA',
    descripcion: 'Convenio Colectivo de Trabajo para Personal de Sanidad (Clínicas y Sanatorios).',
    actividad: 'Salud',
    categorias: [
      CategoriaCCT(
        id: 'profesional',
        nombre: 'Profesional',
        salarioBase: 850000.0,
        descripcion: 'Licenciados, Universitarios',
      ),
      CategoriaCCT(
        id: 'tecnico',
        nombre: 'Técnico',
        salarioBase: 680000.0,
        descripcion: 'Técnicos radiólogos, laboratorio, etc.',
      ),
      CategoriaCCT(
        id: 'servicios',
        nombre: 'Servicios',
        salarioBase: 580000.0,
        descripcion: 'Mucamas, camilleros, cocina',
      ),
      CategoriaCCT(
        id: 'administrativo',
        nombre: 'Administrativo',
        salarioBase: 520000.0,
        descripcion: 'Personal administrativo 1ra',
      ),
      CategoriaCCT(
        id: 'maestranza',
        nombre: 'Maestranza',
        salarioBase: 480000.0,
        descripcion: 'Peón, Sereno, Cadete',
      ),
    ],
    descuentos: [
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
        id: 'obra_social',
        nombre: 'Obra Social',
        porcentaje: 3.0,
      ),
      DescuentoCCT(
        id: 'sindicato',
        nombre: 'Sindicato (ATSA)',
        porcentaje: 2.0,
      ),
      DescuentoCCT(
        id: 'seguro_sepelio',
        nombre: 'Seguro Sepelio',
        porcentaje: 1.0,
      ),
      DescuentoCCT(
        id: 'aporte_solidario',
        nombre: 'Aporte Solidario',
        porcentaje: 1.0,
      ),
    ],
    zonas: [
      ZonaCCT(
        id: 'zona_normal',
        nombre: 'Zona Normal',
        adicionalPorcentaje: 0.0,
      ),
      ZonaCCT(
        id: 'zona_patagonica',
        nombre: 'Zona Patagónica',
        adicionalPorcentaje: 20.0,
        descripcion: 'Adicional 20% Sur',
      ),
    ],
    adicionalPresentismo: 0.0,
    adicionalAntiguedad: 2.0, // 2% por año
    horasMensualesDivisor: 200.0,
    esDivisorDias: false,
    fechaVigencia: DateTime(2026, 1, 1),
    activo: true,
    pdfUrl: 'https://www.sanidad.org.ar/PDF/CCT_122_75.pdf',
  ),

  // CCT Gastronómicos - UTHGRA
  CCTCompleto(
    id: 'cct_gastronomicos',
    numeroCCT: '389/04',
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
    horasMensualesDivisor: 200.0,
    esDivisorDias: false,
    fechaVigencia: DateTime(2024, 1, 1),
    activo: true,
    pdfUrl: 'https://www.fehgracomodoro.com.ar/biblioteca-online/politica-laboral-y-social/Convenio-Colectivo-de-Trabajo-con-Comentarios-y-Recomendaciones.pdf',
  ),

  // CCT Petroleros
  CCTCompleto(
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
    horasMensualesDivisor: 200.0,
    esDivisorDias: false,
    fechaVigencia: DateTime(2024, 1, 1),
    activo: true,
    pdfUrl: 'https://www.oitcinterfor.org/sites/default/files/disposiciones_fp_convenios/CCT644_12.pdf',
  ),

  // CCT Textil
  CCTCompleto(
    id: 'cct_textil',
    numeroCCT: '500/07',
    nombre: 'Textil - AOT',
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
    horasMensualesDivisor: 200.0,
    esDivisorDias: false,
    fechaVigencia: DateTime(2024, 1, 1),
    activo: true,
    pdfUrl: 'https://aot-ra.org.ar/wp-content/uploads/2021/08/CCT-500-07.pdf',
  ),

  // CCT Químico
  CCTCompleto(
    id: 'cct_quimico',
    numeroCCT: '790/21',
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
    horasMensualesDivisor: 200.0,
    esDivisorDias: false,
    fechaVigencia: DateTime(2024, 1, 1),
    activo: true,
    pdfUrl: 'https://festiqypra.org.ar/wp-content/uploads/2021/05/CCT-790-21.pdf',
  ),

  // CCT UOCRA Yacimiento
  CCTCompleto(
    id: 'cct_uocra_yacimiento',
    numeroCCT: '545/08',
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
    horasMensualesDivisor: 200.0,
    esDivisorDias: false,
    fechaVigencia: DateTime(2024, 1, 1),
    activo: true,
    pdfUrl: 'https://perezmarzo.com.ar/wp-content/uploads/2012/09/Construccion-Petroleros-CCT-545-08.pdf',
  ),

  // CCT Petroleros Jerárquicos
  CCTCompleto(
    id: 'cct_petroleros_jerarquicos',
    numeroCCT: '637/11',
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
    horasMensualesDivisor: 173.0,
    esDivisorDias: false,
    fechaVigencia: DateTime(2024, 1, 1),
    activo: true,
    pdfUrl: 'https://www.oitcinterfor.org/sites/default/files/disposiciones_fp_convenios/CCT637_11Petroleros.pdf',
  ),

  // CCT Plástico
  CCTCompleto(
    id: 'cct_plastico',
    numeroCCT: '797/22 (ex 419/05)',
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
    horasMensualesDivisor: 200.0,
    esDivisorDias: false,
    fechaVigencia: DateTime(2024, 1, 1),
    activo: true,
    pdfUrl: 'https://www.argentina.gob.ar/normativa/nacional/resoluci%C3%B3n-363-2023-381750/texto',
  ),

  // CCT Camioneros
  CCTCompleto(
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
    horasMensualesDivisor: 24.0,
    esDivisorDias: true,
    fechaVigencia: DateTime(2024, 1, 1),
    activo: true,
    pdfUrl: 'https://www.fedcam.org.ar/images/sampledata/ja_university/convenio-2020-segunda.pdf',
  ),

  // CCT Alimentación
  CCTCompleto(
    id: 'cct_alimentacion',
    numeroCCT: '244/94',
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
    horasMensualesDivisor: 200.0,
    esDivisorDias: false,
    fechaVigencia: DateTime(2024, 1, 1),
    activo: true,
    pdfUrl: 'https://www.ftiasistema.com.ar/uploads/descargas/1b6e68d95d42d6b0941afbb9a7382297296d3263.pdf',
  ),

  // CCT Gráfico
  CCTCompleto(
    id: 'cct_grafico',
    numeroCCT: '60/89',
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
    fechaVigencia: DateTime(2024, 1, 1),
    activo: true,
    pdfUrl: 'https://fgb.org.ar/wp-content/uploads/2021/01/CCT-Graficos-60-89-2019.pdf',
  ),

  // CCT Madera
  CCTCompleto(
    id: 'cct_madera',
    numeroCCT: '335/75',
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
    horasMensualesDivisor: 200.0,
    esDivisorDias: false,
    fechaVigencia: DateTime(2024, 1, 1),
    activo: true,
    pdfUrl: 'https://cafydma.org/wp-content/uploads/2022/03/CCT-335-75-FAIMA-USIMRA.pdf',
  ),

  // CCT Minería - AOMA
  CCTCompleto(
    id: 'cct_mineria',
    numeroCCT: '36/89',
    nombre: 'Minería - AOMA',
    descripcion: 'Convenio Colectivo de Trabajo para la Industria Minera (Rama Cemento/Cal/Piedra)',
    actividad: 'Minería',
    categorias: [
      CategoriaCCT(
        id: 'operador_equipo_pesado',
        nombre: 'Operador Equipo Pesado',
        salarioBase: 1800000.0,
        descripcion: 'Operador de retroexcavadora, pala cargadora, etc.',
      ),
      CategoriaCCT(
        id: 'oficial_especializado_mineria',
        nombre: 'Oficial Especializado',
        salarioBase: 1600000.0,
        descripcion: 'Mecánico, Electricista de planta',
      ),
      CategoriaCCT(
        id: 'oficial_minero',
        nombre: 'Oficial Minero',
        salarioBase: 1400000.0,
        descripcion: 'Perforista, Operador de planta',
      ),
      CategoriaCCT(
        id: 'medio_oficial_minero',
        nombre: 'Medio Oficial',
        salarioBase: 1200000.0,
      ),
      CategoriaCCT(
        id: 'peon_mineria',
        nombre: 'Peón',
        salarioBase: 1000000.0,
        descripcion: 'Tareas generales de limpieza y ayuda',
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
        nombre: 'Sindicato AOMA',
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
        id: 'zona_cordillera',
        nombre: 'Zona Cordillera/Puna',
        adicionalPorcentaje: 40.0,
        descripcion: 'Adicional por zona inhóspita o altura',
      ),
      ZonaCCT(
        id: 'zona_sur',
        nombre: 'Zona Sur',
        adicionalPorcentaje: 20.0,
      ),
    ],
    adicionalPresentismo: 8.33,
    adicionalAntiguedad: 1.5,
    horasMensualesDivisor: 192.0,
    esDivisorDias: false,
    fechaVigencia: DateTime(2024, 1, 1),
    activo: true,
    pdfUrl: 'http://aoma.org.ar/convenios/CCT-36-89.pdf',
  ),

  // CCT Rurales - UATRE
  CCTCompleto(
    id: 'cct_rurales',
    numeroCCT: 'Ley 26.727',
    nombre: 'Rurales - UATRE',
    descripcion: 'Régimen de Trabajo Agrario (CNTA). Peón Rural.',
    actividad: 'Rural / Agro',
    categorias: [
      CategoriaCCT(
        id: 'capataz',
        nombre: 'Capataz',
        salarioBase: 950000.0,
        descripcion: 'Encargado general',
      ),
      CategoriaCCT(
        id: 'conductor_tractorista',
        nombre: 'Conductor Tractorista',
        salarioBase: 850000.0,
        descripcion: 'Mecánico tractorista',
      ),
      CategoriaCCT(
        id: 'peon_especializado',
        nombre: 'Peón Especializado',
        salarioBase: 780000.0,
        descripcion: 'Cultivos específicos, ordeñadores, etc.',
      ),
      CategoriaCCT(
        id: 'peon_general',
        nombre: 'Peón General',
        salarioBase: 700000.0,
        descripcion: 'Tareas generales de campo',
      ),
    ],
    descuentos: [
      DescuentoCCT(
        id: 'obra_social',
        nombre: 'Obra Social (OSPRERA)',
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
        nombre: 'Sindicato UATRE',
        porcentaje: 2.0,
      ),
      DescuentoCCT(
        id: 'renatre',
        nombre: 'RENATRE',
        porcentaje: 1.5,
        descripcion: 'Registro Nacional de Trabajadores Rurales',
      ),
    ],
    zonas: [
      ZonaCCT(
        id: 'zona_nacional',
        nombre: 'Zona Nacional',
        adicionalPorcentaje: 0.0,
      ),
      ZonaCCT(
        id: 'zona_patagonia',
        nombre: 'Zona Patagonia',
        adicionalPorcentaje: 20.0,
        descripcion: 'Chubut, Santa Cruz, Tierra del Fuego, Río Negro, Neuquén',
      ),
    ],
    adicionalPresentismo: 0.0,
    adicionalAntiguedad: 1.0, // 1% por año
    horasMensualesDivisor: 200.0,
    esDivisorDias: false,
    fechaVigencia: DateTime(2024, 1, 1),
    activo: true,
    pdfUrl: 'https://www.uatre.org.ar/escalas.php',
  ),

  // CCT Transporte Pasajeros - UTA
  CCTCompleto(
    id: 'cct_uta',
    numeroCCT: '460/73',
    nombre: 'Transporte (UTA)',
    descripcion: 'Convenio Colectivo de Trabajo para Conductores de Transporte de Pasajeros',
    actividad: 'Transporte Pasajeros',
    categorias: [
      CategoriaCCT(
        id: 'conductor_guarda',
        nombre: 'Conductor Guarda',
        salarioBase: 1200000.0,
        descripcion: 'Chofer de colectivo urbano/interurbano',
      ),
      CategoriaCCT(
        id: 'conductor_larga_distancia',
        nombre: 'Conductor Larga Distancia',
        salarioBase: 1400000.0,
        descripcion: 'Chofer de ómnibus larga distancia',
      ),
      CategoriaCCT(
        id: 'tecnico_primera',
        nombre: 'Técnico de Primera',
        salarioBase: 1300000.0,
        descripcion: 'Mecánico especializado',
      ),
      CategoriaCCT(
        id: 'administrativo_a',
        nombre: 'Administrativo A',
        salarioBase: 1100000.0,
      ),
      CategoriaCCT(
        id: 'auxiliar',
        nombre: 'Auxiliar / Lavador',
        salarioBase: 900000.0,
        descripcion: 'Personal de limpieza y servicios',
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
        nombre: 'Sindicato UTA',
        porcentaje: 1.5,
      ),
    ],
    zonas: [
      ZonaCCT(
        id: 'zona_normal',
        nombre: 'Zona Normal',
        adicionalPorcentaje: 0.0,
      ),
    ],
    adicionalPresentismo: 0.0, // UTA tiene sumas no remunerativas y viáticos fijos usualmente
    adicionalAntiguedad: 1.5, // Variable según empresa/rama
    horasMensualesDivisor: 192.0,
    esDivisorDias: false,
    fechaVigencia: DateTime(2024, 1, 1),
    activo: true,
    pdfUrl: 'http://www.uta.org.ar/convenios.php',
  ),

  // CCT Seguridad Privada - UPSRA
  CCTCompleto(
    id: 'cct_seguridad',
    numeroCCT: '507/07',
    nombre: 'Seguridad Privada (UPSRA)',
    descripcion: 'Convenio Colectivo de Trabajo para Vigiladores y Seguridad Privada',
    actividad: 'Seguridad',
    categorias: [
      CategoriaCCT(
        id: 'vigilador_general',
        nombre: 'Vigilador General',
        salarioBase: 850000.0,
        descripcion: 'Vigilancia general sin arma',
      ),
      CategoriaCCT(
        id: 'vigilador_bombero',
        nombre: 'Vigilador Bombero',
        salarioBase: 900000.0,
        descripcion: 'Con especialización en prevención de incendios',
      ),
      CategoriaCCT(
        id: 'administrativo',
        nombre: 'Administrativo',
        salarioBase: 880000.0,
      ),
      CategoriaCCT(
        id: 'monitorista',
        nombre: 'Monitorista',
        salarioBase: 920000.0,
        descripcion: 'Operador de monitoreo de alarmas/cámaras',
      ),
    ],
    descuentos: [
      DescuentoCCT(
        id: 'obra_social',
        nombre: 'Obra Social (OSPSIP)',
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
        nombre: 'Sindicato UPSRA',
        porcentaje: 2.0,
      ),
    ],
    zonas: [
      ZonaCCT(
        id: 'zona_normal',
        nombre: 'Zona Normal',
        adicionalPorcentaje: 0.0,
      ),
      ZonaCCT(
        id: 'zona_sur',
        nombre: 'Zona Sur',
        adicionalPorcentaje: 20.0,
        descripcion: 'Adicional por zona desfavorable',
      ),
    ],
    adicionalPresentismo: 8.33,
    adicionalAntiguedad: 1.0, // 1% por año
    horasMensualesDivisor: 200.0,
    esDivisorDias: false,
    fechaVigencia: DateTime(2024, 1, 1),
    activo: true,
    pdfUrl: 'https://upsra.org.ar/gremiales/escalas-salariales/',
  ),
];
