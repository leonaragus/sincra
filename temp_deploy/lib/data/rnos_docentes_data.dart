// ========================================================================
// CATALOGO NACIONAL DE OBRAS SOCIALES DOCENTES (RNOS) - ARCA 2026
// Registro Federal de Obras Sociales para Liquidación de Sueldos
// Incluye las 24 jurisdicciones y opciones nacionales.
// ========================================================================

class ObraSocialDocente {
  final String codigoArca; // RNOS 6 dígitos
  final String sigla;
  final String nombreCompleto;
  final String jurisdiccion;
  final double porcentajeAporte; // % Aporte Empleado 2026
  final String descripcion;

  const ObraSocialDocente({
    required this.codigoArca,
    required this.sigla,
    required this.nombreCompleto,
    required this.jurisdiccion,
    required this.porcentajeAporte,
    this.descripcion = '',
  });
}

class CatalogoRNOS2026 {
  static const List<ObraSocialDocente> lista = [
    // --- OPCIONES NACIONALES (Comunes en Colegios Privados/Universidades) ---
    ObraSocialDocente(
      codigoArca: '106101',
      sigla: 'OSPLAD',
      nombreCompleto: 'Obra Social para la Actividad Docente',
      jurisdiccion: 'Nacional',
      porcentajeAporte: 3.0,
      descripcion: 'Obra social nacional docente por excelencia.',
    ),
    ObraSocialDocente(
      codigoArca: '106002',
      sigla: 'OSDOP',
      nombreCompleto: 'Obra Social de Docentes Particulares',
      jurisdiccion: 'Nacional',
      porcentajeAporte: 3.0,
      descripcion: 'SADOP - Docentes de gestión privada.',
    ),
    ObraSocialDocente(
      codigoArca: '126205',
      sigla: 'OSECAC',
      nombreCompleto: 'Obra Social de los Empleados de Comercio y Actividades Civiles',
      jurisdiccion: 'Nacional',
      porcentajeAporte: 3.0,
      descripcion: 'Opción frecuente por desregulación.',
    ),

    // --- OBRAS SOCIALES PROVINCIALES (Jurisdicciones 24) ---
    ObraSocialDocente(
      codigoArca: '906001',
      sigla: 'IOMA',
      nombreCompleto: 'Instituto de Obra Médico Asistencial',
      jurisdiccion: 'Buenos Aires',
      porcentajeAporte: 4.8,
    ),
    ObraSocialDocente(
      codigoArca: '300707',
      sigla: 'ObSBA',
      nombreCompleto: 'Obra Social de la Ciudad de Buenos Aires',
      jurisdiccion: 'CABA',
      porcentajeAporte: 6.0,
    ),
    ObraSocialDocente(
      codigoArca: '910001',
      sigla: 'OSEP Cat.',
      nombreCompleto: 'Obra Social de los Empleados Públicos de Catamarca',
      jurisdiccion: 'Catamarca',
      porcentajeAporte: 4.5,
    ),
    ObraSocialDocente(
      codigoArca: '922001',
      sigla: 'INSSSEP',
      nombreCompleto: 'Inst. de Seg. Social, Seguros y Préstamos del Chaco',
      jurisdiccion: 'Chaco',
      porcentajeAporte: 5.0,
    ),
    ObraSocialDocente(
      codigoArca: '926001',
      sigla: 'SEROS',
      nombreCompleto: 'Inst. de Seg. Social y Seguros del Chubut',
      jurisdiccion: 'Chubut',
      porcentajeAporte: 5.0,
    ),
    ObraSocialDocente(
      codigoArca: '914001',
      sigla: 'APROSS',
      nombreCompleto: 'Administración Provincial de Seguro de Salud',
      jurisdiccion: 'Córdoba',
      porcentajeAporte: 4.5,
    ),
    ObraSocialDocente(
      codigoArca: '918001',
      sigla: 'IOSCOR',
      nombreCompleto: 'Instituto de Obra Social de Corrientes',
      jurisdiccion: 'Corrientes',
      porcentajeAporte: 4.0,
    ),
    ObraSocialDocente(
      codigoArca: '930001',
      sigla: 'IOSPER',
      nombreCompleto: 'Inst. de Obra Social de la Prov. de Entre Ríos',
      jurisdiccion: 'Entre Ríos',
      porcentajeAporte: 3.0,
    ),
    ObraSocialDocente(
      codigoArca: '934001',
      sigla: 'IASEP',
      nombreCompleto: 'Inst. de Asistencia Social para Empleados Públicos',
      jurisdiccion: 'Formosa',
      porcentajeAporte: 3.5,
    ),
    ObraSocialDocente(
      codigoArca: '938001',
      sigla: 'ISJ',
      nombreCompleto: 'Instituto de Seguros de Jujuy',
      jurisdiccion: 'Jujuy',
      porcentajeAporte: 4.0,
    ),
    ObraSocialDocente(
      codigoArca: '942001',
      sigla: 'SEM',
      nombreCompleto: 'Servicio de Emergencias Médicas / IPESA',
      jurisdiccion: 'La Pampa',
      porcentajeAporte: 3.0,
    ),
    ObraSocialDocente(
      codigoArca: '946001',
      sigla: 'APOS',
      nombreCompleto: 'Administración Provincial de Obra Social',
      jurisdiccion: 'La Rioja',
      porcentajeAporte: 4.0,
    ),
    ObraSocialDocente(
      codigoArca: '950001',
      sigla: 'OSEP Mza.',
      nombreCompleto: 'Obra Social de los Empleados Públicos de Mendoza',
      jurisdiccion: 'Mendoza',
      porcentajeAporte: 6.0,
    ),
    ObraSocialDocente(
      codigoArca: '954001',
      sigla: 'IPS Mis.',
      nombreCompleto: 'Instituto de Previsión Social de Misiones',
      jurisdiccion: 'Misiones',
      porcentajeAporte: 5.0,
    ),
    ObraSocialDocente(
      codigoArca: '820000',
      sigla: 'ISSN',
      nombreCompleto: 'Instituto de Seguridad Social del Neuquén',
      jurisdiccion: 'Neuquén',
      porcentajeAporte: 5.5,
    ),
    ObraSocialDocente(
      codigoArca: '962001',
      sigla: 'IPROSS',
      nombreCompleto: 'Inst. Provincial de Seguro de Salud de Río Negro',
      jurisdiccion: 'Río Negro',
      porcentajeAporte: 4.0,
    ),
    ObraSocialDocente(
      codigoArca: '966001',
      sigla: 'IPS Salta',
      nombreCompleto: 'Instituto de Previsión Social de Salta',
      jurisdiccion: 'Salta',
      porcentajeAporte: 3.5,
    ),
    ObraSocialDocente(
      codigoArca: '970001',
      sigla: 'DOS',
      nombreCompleto: 'Dirección de Obra Social de San Juan',
      jurisdiccion: 'San Juan',
      porcentajeAporte: 4.5,
    ),
    ObraSocialDocente(
      codigoArca: '974001',
      sigla: 'DOSEP',
      nombreCompleto: 'Dir. de Obra Social de Empleados Públicos San Luis',
      jurisdiccion: 'San Luis',
      porcentajeAporte: 4.0,
    ),
    ObraSocialDocente(
      codigoArca: '978001',
      sigla: 'CSS',
      nombreCompleto: 'Caja de Servicios Sociales de Santa Cruz',
      jurisdiccion: 'Santa Cruz',
      porcentajeAporte: 4.0,
    ),
    ObraSocialDocente(
      codigoArca: '982001',
      sigla: 'IAPOS',
      nombreCompleto: 'Inst. de Ayuda Médica para Empleados Públicos',
      jurisdiccion: 'Santa Fe',
      porcentajeAporte: 3.0,
    ),
    ObraSocialDocente(
      codigoArca: '986001',
      sigla: 'IOSEP',
      nombreCompleto: 'Inst. de Obra Social del Empleado Provincial',
      jurisdiccion: 'Santiago del Estero',
      porcentajeAporte: 3.0,
    ),
    ObraSocialDocente(
      codigoArca: '994001',
      sigla: 'OSPTF',
      nombreCompleto: 'Obra Social de la Prov. de Tierra del Fuego',
      jurisdiccion: 'Tierra del Fuego',
      porcentajeAporte: 3.0,
    ),
    ObraSocialDocente(
      codigoArca: '990001',
      sigla: 'IPSST',
      nombreCompleto: 'Inst. de Prev. y Seg. Social de Tucumán',
      jurisdiccion: 'Tucumán',
      porcentajeAporte: 4.5,
    ),
  ];

  /// Obtiene una obra social por su código ARCA/RNOS
  static ObraSocialDocente? buscarPorCodigo(String codigo) {
    try {
      return lista.firstWhere((e) => e.codigoArca == codigo);
    } catch (_) {
      return null;
    }
  }

  /// Filtra obras sociales por jurisdicción
  static List<ObraSocialDocente> porJurisdiccion(String juris) {
    return lista.where((e) => e.jurisdiccion == juris || e.jurisdiccion == 'Nacional').toList();
  }
}
