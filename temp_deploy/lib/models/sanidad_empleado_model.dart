// ========================================================================
// MODELO EMPLEADO SANIDAD - Campos completos para LSD ARCA 2026
// CCT 122/75 y 108/75 - FATSA - Sistema Federal 24 Jurisdicciones
// ========================================================================

import '../services/sanidad_omni_engine.dart';

/// Modalidad de contratación AFIP/ARCA
enum ModalidadContratacion {
  permanente,      // 008 - Tiempo indeterminado
  plazoFijo,       // 003 - Contrato a plazo fijo
  eventual,        // 004 - Eventual
  temporada,       // 005 - Temporada
  aprendizaje,     // 010 - Aprendizaje
  pasantia,        // 011 - Pasantía
}

/// Situación de revista del empleado
enum SituacionRevista {
  activo,          // 01 - Activo normal
  licenciaEnfermedad, // 02 - Licencia por enfermedad
  licenciaMaternidad, // 03 - Licencia por maternidad
  licenciaSinGoce, // 04 - Licencia sin goce de haberes
  suspendido,      // 05 - Suspendido
  baja,            // 06 - Baja
  vacaciones,      // 07 - En vacaciones
  accidenteTrabajo, // 08 - Accidente de trabajo
}

/// Tipo de jornada laboral
enum TipoJornada {
  completa,        // 8 horas / 48 semanales
  parcial,         // Menos de 8 horas
  reducida,        // Jornada reducida
}

/// Motivo de egreso para liquidación final
enum MotivoEgreso {
  renuncia,
  despidoConCausa,
  despidoSinCausa,
  mutuoAcuerdo,
  jubilacion,
  fallecimiento,
  finContrato,
}

/// Códigos AFIP para modalidad de contratación
class CodigosModalidadAFIP {
  static String obtenerCodigo(ModalidadContratacion m) {
    switch (m) {
      case ModalidadContratacion.permanente: return '008';
      case ModalidadContratacion.plazoFijo: return '003';
      case ModalidadContratacion.eventual: return '004';
      case ModalidadContratacion.temporada: return '005';
      case ModalidadContratacion.aprendizaje: return '010';
      case ModalidadContratacion.pasantia: return '011';
    }
  }
  
  static String descripcion(ModalidadContratacion m) {
    switch (m) {
      case ModalidadContratacion.permanente: return 'Tiempo Indeterminado';
      case ModalidadContratacion.plazoFijo: return 'Plazo Fijo';
      case ModalidadContratacion.eventual: return 'Eventual';
      case ModalidadContratacion.temporada: return 'Temporada';
      case ModalidadContratacion.aprendizaje: return 'Aprendizaje';
      case ModalidadContratacion.pasantia: return 'Pasantía';
    }
  }
}

/// Códigos AFIP para situación de revista
class CodigosSituacionAFIP {
  static String obtenerCodigo(SituacionRevista s) {
    switch (s) {
      case SituacionRevista.activo: return '01';
      case SituacionRevista.licenciaEnfermedad: return '02';
      case SituacionRevista.licenciaMaternidad: return '03';
      case SituacionRevista.licenciaSinGoce: return '04';
      case SituacionRevista.suspendido: return '05';
      case SituacionRevista.baja: return '06';
      case SituacionRevista.vacaciones: return '07';
      case SituacionRevista.accidenteTrabajo: return '08';
    }
  }
  
  static String descripcion(SituacionRevista s) {
    switch (s) {
      case SituacionRevista.activo: return 'Activo';
      case SituacionRevista.licenciaEnfermedad: return 'Licencia por Enfermedad';
      case SituacionRevista.licenciaMaternidad: return 'Licencia por Maternidad';
      case SituacionRevista.licenciaSinGoce: return 'Licencia Sin Goce';
      case SituacionRevista.suspendido: return 'Suspendido';
      case SituacionRevista.baja: return 'Baja';
      case SituacionRevista.vacaciones: return 'Vacaciones';
      case SituacionRevista.accidenteTrabajo: return 'Accidente de Trabajo';
    }
  }
}

/// Concepto propio adicional (horas extra, adelantos, etc)
class ConceptoSanidadPropio {
  final String codigo;
  final String descripcion;
  final double monto;
  final bool esRemunerativo;
  final bool esDescuento;
  final String codigoAfip;
  
  ConceptoSanidadPropio({
    required this.codigo,
    required this.descripcion,
    required this.monto,
    this.esRemunerativo = true,
    this.esDescuento = false,
    this.codigoAfip = '011000',
  });
  
  Map<String, dynamic> toMap() => {
    'codigo': codigo,
    'descripcion': descripcion,
    'monto': monto,
    'esRemunerativo': esRemunerativo,
    'esDescuento': esDescuento,
    'codigoAfip': codigoAfip,
  };
  
  factory ConceptoSanidadPropio.fromMap(Map<String, dynamic> m) => ConceptoSanidadPropio(
    codigo: m['codigo']?.toString() ?? '',
    descripcion: m['descripcion']?.toString() ?? '',
    monto: (m['monto'] as num?)?.toDouble() ?? 0.0,
    esRemunerativo: m['esRemunerativo'] == true,
    esDescuento: m['esDescuento'] == true,
    codigoAfip: m['codigoAfip']?.toString() ?? '011000',
  );
}

/// Modelo completo de empleado sanidad para LSD ARCA 2026
class EmpleadoSanidadCompleto {
  // === DATOS PERSONALES ===
  final String nombre;
  final String cuil;
  final DateTime fechaNacimiento;
  final String? dni;
  final String? sexo; // 'M' o 'F'
  final String? estadoCivil;
  final String? nacionalidad;
  
  // === DATOS LABORALES ===
  final DateTime fechaIngreso;
  final DateTime? fechaEgreso;
  final CategoriaSanidad categoria;
  final NivelTituloSanidad nivelTitulo;
  final ModalidadContratacion modalidadContratacion;
  final SituacionRevista situacionRevista;
  final TipoJornada tipoJornada;
  final int horasSemanales;
  final MotivoEgreso? motivoEgreso;
  
  // === DATOS ESPECÍFICOS CCT SANIDAD ===
  final bool tareaCriticaRiesgo;
  final bool cuotaSindicalAtsa;
  final bool manejoEfectivoCaja;
  final int horasNocturnas;
  
  // === DATOS BANCARIOS ===
  final String? cbu;
  final String? banco;
  final String? tipoCuenta; // 'CA' o 'CC'
  
  // === DOMICILIO ===
  final String? domicilio;
  final String? localidad;
  final String? codigoPostal;
  final String? provincia;
  
  // === OBRA SOCIAL Y SEGURIDAD SOCIAL ===
  final String? codigoRnos;
  final int cantidadFamiliares;
  final String? numeroAfiliado;
  
  // === CAMPOS AFIP/ARCA ===
  final String? codigoActividad;  // 3 dígitos
  final String? codigoPuesto;     // 4 dígitos
  final String? codigoCondicion;  // 2 dígitos
  final String? codigoSiniestrado; // 2 dígitos
  final String? codigoZona;       // 1 dígito
  
  // === CONCEPTOS ADICIONALES ===
  final List<ConceptoSanidadPropio> conceptosPropios;
  
  // === HORAS EXTRAS ===
  final double horasExtras50;
  final double horasExtras100;
  
  // === ADELANTOS Y EMBARGOS ===
  final double adelantos;
  final double embargos;
  final double prestamos;
  
  // === LIQUIDACIÓN FINAL ===
  final double? mejorRemuneracion;
  final int? diasSAC;
  final int? diasVacacionesNoGozadas;
  final double? baseIndemnizatoria;
  
  EmpleadoSanidadCompleto({
    required this.nombre,
    required this.cuil,
    required this.fechaIngreso,
    required this.categoria,
    DateTime? fechaNacimiento,
    this.dni,
    this.sexo,
    this.estadoCivil,
    this.nacionalidad,
    this.fechaEgreso,
    this.nivelTitulo = NivelTituloSanidad.sinTitulo,
    this.modalidadContratacion = ModalidadContratacion.permanente,
    this.situacionRevista = SituacionRevista.activo,
    this.tipoJornada = TipoJornada.completa,
    this.horasSemanales = 48,
    this.motivoEgreso,
    this.tareaCriticaRiesgo = false,
    this.cuotaSindicalAtsa = false,
    this.manejoEfectivoCaja = false,
    this.horasNocturnas = 0,
    this.cbu,
    this.banco,
    this.tipoCuenta,
    this.domicilio,
    this.localidad,
    this.codigoPostal,
    this.provincia,
    this.codigoRnos,
    this.cantidadFamiliares = 0,
    this.numeroAfiliado,
    this.codigoActividad,
    this.codigoPuesto,
    this.codigoCondicion,
    this.codigoSiniestrado,
    this.codigoZona,
    this.conceptosPropios = const [],
    this.horasExtras50 = 0,
    this.horasExtras100 = 0,
    this.adelantos = 0,
    this.embargos = 0,
    this.prestamos = 0,
    this.mejorRemuneracion,
    this.diasSAC,
    this.diasVacacionesNoGozadas,
    this.baseIndemnizatoria,
  }) : fechaNacimiento = fechaNacimiento ?? DateTime(1980, 1, 1);

  /// Calcula años de antigüedad
  int anosAntiguedad([DateTime? fechaReferencia]) {
    final ref = fechaReferencia ?? DateTime.now();
    int a = ref.year - fechaIngreso.year;
    if (ref.month < fechaIngreso.month ||
        (ref.month == fechaIngreso.month && ref.day < fechaIngreso.day)) {
      a--;
    }
    return a < 0 ? 0 : a;
  }
  
  /// Días de vacaciones según antigüedad (CCT Sanidad)
  int diasVacaciones() {
    final anos = anosAntiguedad();
    if (anos < 5) return 14;
    if (anos < 10) return 21;
    if (anos < 20) return 28;
    return 35;
  }

  /// Convierte a Map para guardar en DB
  Map<String, dynamic> toMap() => {
    'nombre': nombre,
    'cuil': cuil,
    'fechaNacimiento': fechaNacimiento.toIso8601String(),
    'dni': dni,
    'sexo': sexo,
    'estadoCivil': estadoCivil,
    'nacionalidad': nacionalidad,
    'fechaIngreso': fechaIngreso.toIso8601String(),
    'fechaEgreso': fechaEgreso?.toIso8601String(),
    'categoria': categoria.name,
    'nivelTitulo': nivelTitulo.name,
    'modalidadContratacion': modalidadContratacion.name,
    'situacionRevista': situacionRevista.name,
    'tipoJornada': tipoJornada.name,
    'horasSemanales': horasSemanales,
    'motivoEgreso': motivoEgreso?.name,
    'tareaCriticaRiesgo': tareaCriticaRiesgo,
    'cuotaSindicalAtsa': cuotaSindicalAtsa,
    'manejoEfectivoCaja': manejoEfectivoCaja,
    'horasNocturnas': horasNocturnas,
    'cbu': cbu,
    'banco': banco,
    'tipoCuenta': tipoCuenta,
    'domicilio': domicilio,
    'localidad': localidad,
    'codigoPostal': codigoPostal,
    'provincia': provincia,
    'codigoRnos': codigoRnos,
    'cantidadFamiliares': cantidadFamiliares,
    'numeroAfiliado': numeroAfiliado,
    'codigoActividad': codigoActividad,
    'codigoPuesto': codigoPuesto,
    'codigoCondicion': codigoCondicion,
    'codigoSiniestrado': codigoSiniestrado,
    'codigoZona': codigoZona,
    'conceptosPropios': conceptosPropios.map((c) => c.toMap()).toList(),
    'horasExtras50': horasExtras50,
    'horasExtras100': horasExtras100,
    'adelantos': adelantos,
    'embargos': embargos,
    'prestamos': prestamos,
    'mejorRemuneracion': mejorRemuneracion,
    'diasSAC': diasSAC,
    'diasVacacionesNoGozadas': diasVacacionesNoGozadas,
    'baseIndemnizatoria': baseIndemnizatoria,
  };
  
  /// Crea desde Map
  factory EmpleadoSanidadCompleto.fromMap(Map<String, dynamic> m) {
    return EmpleadoSanidadCompleto(
      nombre: m['nombre']?.toString() ?? '',
      cuil: m['cuil']?.toString() ?? '',
      fechaNacimiento: DateTime.tryParse(m['fechaNacimiento']?.toString() ?? ''),
      dni: m['dni']?.toString(),
      sexo: m['sexo']?.toString(),
      estadoCivil: m['estadoCivil']?.toString(),
      nacionalidad: m['nacionalidad']?.toString(),
      fechaIngreso: DateTime.tryParse(m['fechaIngreso']?.toString() ?? '') ?? DateTime.now(),
      fechaEgreso: m['fechaEgreso'] != null ? DateTime.tryParse(m['fechaEgreso'].toString()) : null,
      categoria: CategoriaSanidad.values.firstWhere(
        (e) => e.name == m['categoria'], 
        orElse: () => CategoriaSanidad.profesional,
      ),
      nivelTitulo: NivelTituloSanidad.values.firstWhere(
        (e) => e.name == m['nivelTitulo'], 
        orElse: () => NivelTituloSanidad.sinTitulo,
      ),
      modalidadContratacion: ModalidadContratacion.values.firstWhere(
        (e) => e.name == m['modalidadContratacion'], 
        orElse: () => ModalidadContratacion.permanente,
      ),
      situacionRevista: SituacionRevista.values.firstWhere(
        (e) => e.name == m['situacionRevista'], 
        orElse: () => SituacionRevista.activo,
      ),
      tipoJornada: TipoJornada.values.firstWhere(
        (e) => e.name == m['tipoJornada'], 
        orElse: () => TipoJornada.completa,
      ),
      horasSemanales: (m['horasSemanales'] as num?)?.toInt() ?? 48,
      motivoEgreso: m['motivoEgreso'] != null 
        ? MotivoEgreso.values.firstWhere((e) => e.name == m['motivoEgreso'], orElse: () => MotivoEgreso.renuncia)
        : null,
      tareaCriticaRiesgo: m['tareaCriticaRiesgo'] == true,
      cuotaSindicalAtsa: m['cuotaSindicalAtsa'] == true,
      manejoEfectivoCaja: m['manejoEfectivoCaja'] == true,
      horasNocturnas: (m['horasNocturnas'] as num?)?.toInt() ?? 0,
      cbu: m['cbu']?.toString(),
      banco: m['banco']?.toString(),
      tipoCuenta: m['tipoCuenta']?.toString(),
      domicilio: m['domicilio']?.toString(),
      localidad: m['localidad']?.toString(),
      codigoPostal: m['codigoPostal']?.toString(),
      provincia: m['provincia']?.toString(),
      codigoRnos: m['codigoRnos']?.toString(),
      cantidadFamiliares: (m['cantidadFamiliares'] as num?)?.toInt() ?? 0,
      numeroAfiliado: m['numeroAfiliado']?.toString(),
      codigoActividad: m['codigoActividad']?.toString(),
      codigoPuesto: m['codigoPuesto']?.toString(),
      codigoCondicion: m['codigoCondicion']?.toString(),
      codigoSiniestrado: m['codigoSiniestrado']?.toString(),
      codigoZona: m['codigoZona']?.toString(),
      conceptosPropios: (m['conceptosPropios'] as List?)
        ?.map((c) => ConceptoSanidadPropio.fromMap(c as Map<String, dynamic>))
        .toList() ?? [],
      horasExtras50: (m['horasExtras50'] as num?)?.toDouble() ?? 0,
      horasExtras100: (m['horasExtras100'] as num?)?.toDouble() ?? 0,
      adelantos: (m['adelantos'] as num?)?.toDouble() ?? 0,
      embargos: (m['embargos'] as num?)?.toDouble() ?? 0,
      prestamos: (m['prestamos'] as num?)?.toDouble() ?? 0,
      mejorRemuneracion: (m['mejorRemuneracion'] as num?)?.toDouble(),
      diasSAC: (m['diasSAC'] as num?)?.toInt(),
      diasVacacionesNoGozadas: (m['diasVacacionesNoGozadas'] as num?)?.toInt(),
      baseIndemnizatoria: (m['baseIndemnizatoria'] as num?)?.toDouble(),
    );
  }
  
  /// Copia con cambios
  EmpleadoSanidadCompleto copyWith({
    String? nombre,
    String? cuil,
    DateTime? fechaNacimiento,
    String? dni,
    String? sexo,
    String? estadoCivil,
    String? nacionalidad,
    DateTime? fechaIngreso,
    DateTime? fechaEgreso,
    CategoriaSanidad? categoria,
    NivelTituloSanidad? nivelTitulo,
    ModalidadContratacion? modalidadContratacion,
    SituacionRevista? situacionRevista,
    TipoJornada? tipoJornada,
    int? horasSemanales,
    MotivoEgreso? motivoEgreso,
    bool? tareaCriticaRiesgo,
    bool? cuotaSindicalAtsa,
    bool? manejoEfectivoCaja,
    int? horasNocturnas,
    String? cbu,
    String? banco,
    String? tipoCuenta,
    String? domicilio,
    String? localidad,
    String? codigoPostal,
    String? provincia,
    String? codigoRnos,
    int? cantidadFamiliares,
    String? numeroAfiliado,
    String? codigoActividad,
    String? codigoPuesto,
    String? codigoCondicion,
    String? codigoSiniestrado,
    String? codigoZona,
    List<ConceptoSanidadPropio>? conceptosPropios,
    double? horasExtras50,
    double? horasExtras100,
    double? adelantos,
    double? embargos,
    double? prestamos,
    double? mejorRemuneracion,
    int? diasSAC,
    int? diasVacacionesNoGozadas,
    double? baseIndemnizatoria,
  }) {
    return EmpleadoSanidadCompleto(
      nombre: nombre ?? this.nombre,
      cuil: cuil ?? this.cuil,
      fechaNacimiento: fechaNacimiento ?? this.fechaNacimiento,
      dni: dni ?? this.dni,
      sexo: sexo ?? this.sexo,
      estadoCivil: estadoCivil ?? this.estadoCivil,
      nacionalidad: nacionalidad ?? this.nacionalidad,
      fechaIngreso: fechaIngreso ?? this.fechaIngreso,
      fechaEgreso: fechaEgreso ?? this.fechaEgreso,
      categoria: categoria ?? this.categoria,
      nivelTitulo: nivelTitulo ?? this.nivelTitulo,
      modalidadContratacion: modalidadContratacion ?? this.modalidadContratacion,
      situacionRevista: situacionRevista ?? this.situacionRevista,
      tipoJornada: tipoJornada ?? this.tipoJornada,
      horasSemanales: horasSemanales ?? this.horasSemanales,
      motivoEgreso: motivoEgreso ?? this.motivoEgreso,
      tareaCriticaRiesgo: tareaCriticaRiesgo ?? this.tareaCriticaRiesgo,
      cuotaSindicalAtsa: cuotaSindicalAtsa ?? this.cuotaSindicalAtsa,
      manejoEfectivoCaja: manejoEfectivoCaja ?? this.manejoEfectivoCaja,
      horasNocturnas: horasNocturnas ?? this.horasNocturnas,
      cbu: cbu ?? this.cbu,
      banco: banco ?? this.banco,
      tipoCuenta: tipoCuenta ?? this.tipoCuenta,
      domicilio: domicilio ?? this.domicilio,
      localidad: localidad ?? this.localidad,
      codigoPostal: codigoPostal ?? this.codigoPostal,
      provincia: provincia ?? this.provincia,
      codigoRnos: codigoRnos ?? this.codigoRnos,
      cantidadFamiliares: cantidadFamiliares ?? this.cantidadFamiliares,
      numeroAfiliado: numeroAfiliado ?? this.numeroAfiliado,
      codigoActividad: codigoActividad ?? this.codigoActividad,
      codigoPuesto: codigoPuesto ?? this.codigoPuesto,
      codigoCondicion: codigoCondicion ?? this.codigoCondicion,
      codigoSiniestrado: codigoSiniestrado ?? this.codigoSiniestrado,
      codigoZona: codigoZona ?? this.codigoZona,
      conceptosPropios: conceptosPropios ?? this.conceptosPropios,
      horasExtras50: horasExtras50 ?? this.horasExtras50,
      horasExtras100: horasExtras100 ?? this.horasExtras100,
      adelantos: adelantos ?? this.adelantos,
      embargos: embargos ?? this.embargos,
      prestamos: prestamos ?? this.prestamos,
      mejorRemuneracion: mejorRemuneracion ?? this.mejorRemuneracion,
      diasSAC: diasSAC ?? this.diasSAC,
      diasVacacionesNoGozadas: diasVacacionesNoGozadas ?? this.diasVacacionesNoGozadas,
      baseIndemnizatoria: baseIndemnizatoria ?? this.baseIndemnizatoria,
    );
  }
}

/// Asignaciones Familiares ANSES 2026 (valores actualizados)
class AsignacionesFamiliaresANSES2026 {
  // Rangos de ingreso y montos (Enero 2026 - sujeto a actualización)
  static const double rangoMinimo = 0;
  static const double rangoMaximo1 = 495000;  // Hasta $495.000
  static const double rangoMaximo2 = 725000;  // $495.001 a $725.000
  static const double rangoMaximo3 = 945000;  // $725.001 a $945.000
  
  // Montos por hijo
  static const double hijoRango1 = 28000;
  static const double hijoRango2 = 19000;
  static const double hijoRango3 = 11500;
  
  // Montos por hijo con discapacidad (x4)
  static const double hijoDiscapacidadRango1 = 91000;
  static const double hijoDiscapacidadRango2 = 67000;
  static const double hijoDiscapacidadRango3 = 42000;
  
  // Ayuda escolar anual
  static const double ayudaEscolar = 38000;
  
  /// Calcula asignación por hijo según ingreso del grupo familiar
  static double calcularPorHijo(double ingresoGrupoFamiliar, int cantidadHijos, {int hijosConDiscapacidad = 0}) {
    if (ingresoGrupoFamiliar > rangoMaximo3) return 0;
    
    double montoPorHijoNormal = 0;
    double montoPorHijoDisc = 0;
    
    if (ingresoGrupoFamiliar <= rangoMaximo1) {
      montoPorHijoNormal = hijoRango1;
      montoPorHijoDisc = hijoDiscapacidadRango1;
    } else if (ingresoGrupoFamiliar <= rangoMaximo2) {
      montoPorHijoNormal = hijoRango2;
      montoPorHijoDisc = hijoDiscapacidadRango2;
    } else {
      montoPorHijoNormal = hijoRango3;
      montoPorHijoDisc = hijoDiscapacidadRango3;
    }
    
    final hijosNormales = cantidadHijos - hijosConDiscapacidad;
    return (hijosNormales * montoPorHijoNormal) + (hijosConDiscapacidad * montoPorHijoDisc);
  }
}
