// ========================================================================
// TEACHER OMNI ENGINE - Motor de cálculo federal docente exhaustivo
// Base de datos 24 jurisdicciones, antigüedad, nomenclador, zonas, Ley 13.047
// Integra PayrollCore (Decimal, Strategy Cajas), validación CUIL Módulo 11 y negativos.
// Cascada en capas: 1=Base, 2=Antigüedad, 3=Zona/Ubicación, 4=No Rem (FONID, Conectividad, etc.).
// ========================================================================

import '../core/caja_previsional_strategy.dart';
import '../core/codigos_afip_arca.dart';
import '../core/payroll_core.dart';
import '../models/teacher_types.dart';
import '../models/teacher_constants.dart';
import '../data/rnos_docentes_data.dart';
import 'hybrid_store.dart';

/// Input para liquidación Omni
class DocenteOmniInput {
  final String nombre;
  final String cuil;
  final Jurisdiccion jurisdiccion;
  final TipoGestion tipoGestion;
  final TipoNomenclador cargoNomenclador;
  final NivelEducativo nivelEducativo;
  final DateTime fechaIngreso;
  final int cargasFamiliares;
  final String? codigoRnos;
  final int horasCatedra;
  final ZonaDesfavorable zona;
  /// Adicional por Ubicación/Ruralidad (Cascada ítem F): Urbana 0%, Alejada 20%, Inhóspita 40%, etc.
  final NivelUbicacion nivelUbicacion;
  final double? aporteEstatalPorcentaje;
  final double? subsidioParcialFondoCompensador;
  final bool esHoraCatedraSecundaria; // true = Media 60 pts, false = Terciaria 72 pts
  /// Si no null, reemplaza los puntos del nomenclador para cargo (no hora cátedra)
  final int? puntosCargoOverride;
  /// Si no null, reemplaza 60/72 para hora cátedra
  final int? puntosHoraCatedraOverride;
  /// Si no null, reemplaza el Valor del Índice / Índice Paritario de la jurisdicción (auditoría/paritarias)
  final double? valorIndiceOverride;
  /// Si no null (cargo, no hora cátedra), usa este monto como sueldo básico A en vez de pts×VI/piso. Útil cuando el valor índice o piso config no reflejan el acuerdo vigente.
  final double? sueldoBasicoOverride;
  // --- Campos AFIP/ARCA para LSD ---
  final String? codigoActividad;
  final String? codigoPuesto;
  final String? codigoCondicion;
  final String? codigoModalidad;
  final String modoLiquidacion;
  final double? mejorRemuneracionSemestral;
  final int? diasTrabajadosSemestre;
  final double? promedioVariablesSemestral;
  final int? diasVacaciones;
  final DateTime? fechaCese;
  final String? motivoCese;
  final bool incluyePreaviso;
  final double? baseIndemnizatoria;

  DocenteOmniInput({
    required this.nombre,
    required this.cuil,
    required this.jurisdiccion,
    required this.tipoGestion,
    required this.cargoNomenclador,
    required this.nivelEducativo,
    required this.fechaIngreso,
    this.cargasFamiliares = 0,
    this.codigoRnos,
    this.horasCatedra = 0,
    this.zona = ZonaDesfavorable.a,
    this.nivelUbicacion = NivelUbicacion.urbana,
    this.aporteEstatalPorcentaje,
    this.subsidioParcialFondoCompensador,
    this.esHoraCatedraSecundaria = true,
    this.puntosCargoOverride,
    this.puntosHoraCatedraOverride,
    this.valorIndiceOverride,
    this.sueldoBasicoOverride,
    this.codigoActividad,
    this.codigoPuesto,
    this.codigoCondicion,
    this.codigoModalidad,
    this.modoLiquidacion = "mensual",
    this.mejorRemuneracionSemestral,
    this.diasTrabajadosSemestre,
    this.promedioVariablesSemestral,
    this.diasVacaciones,
    this.fechaCese,
    this.motivoCese,
    this.incluyePreaviso = false,
    this.baseIndemnizatoria,
  });

  int anosAntiguedad() {
    final ahora = DateTime.now();
    int a = ahora.year - fechaIngreso.year;
    if (ahora.month < fechaIngreso.month ||
        (ahora.month == fechaIngreso.month && ahora.day < fechaIngreso.day)) {
      a--;
    }
    return a < 0 ? 0 : a;
  }

  Map<String, dynamic> toJson() {
    return {
      'nombre': nombre,
      'cuil': cuil,
      'jurisdiccion': jurisdiccion.name,
      'tipoGestion': tipoGestion.name,
      'cargoNomenclador': cargoNomenclador.name,
      'nivelEducativo': nivelEducativo.name,
      'fechaIngreso': fechaIngreso.toIso8601String(),
      'cargasFamiliares': cargasFamiliares,
      'codigoRnos': codigoRnos,
      'horasCatedra': horasCatedra,
      'zona': zona.name,
      'nivelUbicacion': nivelUbicacion.name,
      'aporteEstatalPorcentaje': aporteEstatalPorcentaje,
      'subsidioParcialFondoCompensador': subsidioParcialFondoCompensador,
      'esHoraCatedraSecundaria': esHoraCatedraSecundaria,
      'puntosCargoOverride': puntosCargoOverride,
      'puntosHoraCatedraOverride': puntosHoraCatedraOverride,
      'valorIndiceOverride': valorIndiceOverride,
      'sueldoBasicoOverride': sueldoBasicoOverride,
      'codigoActividad': codigoActividad,
      'codigoPuesto': codigoPuesto,
      'codigoCondicion': codigoCondicion,
      'codigoModalidad': codigoModalidad,
      'modoLiquidacion': modoLiquidacion,
    };
  }

  factory DocenteOmniInput.fromJson(Map<String, dynamic> json) {
    return DocenteOmniInput(
      nombre: json['nombre'],
      cuil: json['cuil'],
      jurisdiccion: Jurisdiccion.values.firstWhere((j) => j.name == json['jurisdiccion']),
      tipoGestion: TipoGestion.values.firstWhere((g) => g.name == json['tipoGestion']),
      cargoNomenclador: TipoNomenclador.values.firstWhere((n) => n.name == json['cargoNomenclador']),
      nivelEducativo: NivelEducativo.values.firstWhere((n) => n.name == json['nivelEducativo']),
      fechaIngreso: DateTime.parse(json['fechaIngreso']),
      cargasFamiliares: json['cargasFamiliares'],
      codigoRnos: json['codigoRnos'],
      horasCatedra: json['horasCatedra'],
      zona: ZonaDesfavorable.values.firstWhere((z) => z.name == json['zona']),
      nivelUbicacion: NivelUbicacion.values.firstWhere((n) => n.name == json['nivelUbicacion']),
      aporteEstatalPorcentaje: json['aporteEstatalPorcentaje'],
      subsidioParcialFondoCompensador: json['subsidioParcialFondoCompensador'],
      esHoraCatedraSecundaria: json['esHoraCatedraSecundaria'],
      puntosCargoOverride: json['puntosCargoOverride'],
      puntosHoraCatedraOverride: json['puntosHoraCatedraOverride'],
      valorIndiceOverride: json['valorIndiceOverride'],
      sueldoBasicoOverride: json['sueldoBasicoOverride'],
      codigoActividad: json['codigoActividad'],
      codigoPuesto: json['codigoPuesto'],
      codigoCondicion: json['codigoCondicion'],
      codigoModalidad: json['codigoModalidad'],
      modoLiquidacion: json['modoLiquidacion'],
    );
  }
}

/// Concepto propio de institución (ej. Adicional Colegio Bilingüe)
class ConceptoPropioOmni {
  final String codigo;
  final String descripcion;
  final double monto;
  final bool esRemunerativo;
  final bool esBonificable; // Para cálculo de antigüedad y zona
  final String codigoAfip;

  ConceptoPropioOmni({
    required this.codigo,
    required this.descripcion,
    required this.monto,
    required this.esRemunerativo,
    this.esBonificable = false,
    this.codigoAfip = '011000',
  });

  Map<String, dynamic> toJson() {
    return {
      'codigo': codigo,
      'descripcion': descripcion,
      'monto': monto,
      'esRemunerativo': esRemunerativo,
      'esBonificable': esBonificable,
      'codigoAfip': codigoAfip,
    };
  }

  factory ConceptoPropioOmni.fromJson(Map<String, dynamic> json) {
    return ConceptoPropioOmni(
      codigo: json['codigo'],
      descripcion: json['descripcion'],
      monto: (json['monto'] as num).toDouble(),
      esRemunerativo: json['esRemunerativo'],
      esBonificable: json['esBonificable'] ?? false,
      codigoAfip: json['codigoAfip'] ?? '011000',
    );
  }
}

/// Resultado líquido Omni (para simulador en tiempo real y recibo)
class LiquidacionOmniResult {
  final DocenteOmniInput input;
  final JurisdiccionConfigOmni config;
  final String periodo;
  final String fechaPago;

  final double sueldoBasico;
  final double adicionalAntiguedad;
  final double adicionalZona;
  final double adicionalZonaPatagonica;
  /// Plus Ubicación/Ruralidad (Cascada F): % NivelUbicacion × D. Código AFIP/ARCA Guía 4.
  final double plusUbicacion;
  final double adicionalSalarialCiudad;
  final double itemAula;
  final double estadoDocente;
  final double presentismo;
  final double materialDidactico;
  final double fonid;
  final double conectividad;
  final double horasCatedra;
  final double ajusteEquiparacionLey13047;
  final double fondoCompensador;
  final double adicionalGarantiaSalarial;
  final List<ConceptoPropioOmni> conceptosPropios;
  /// Detalle para auditoría: Puntos y Valor del Índice (PDF/recibo)
  final String detallePuntosYValorIndice;
  /// Desglose Cascada A–G: A=Básico, B=Estado Docente, C=A+B, D=Antigüedad, E=C+D, F=Plus Patagonia, G=Plus Ubicación (auditoría).
  final String desgloseBaseBonificable;

  final double totalBrutoRemunerativo;
  final double totalNoRemunerativo;
  final double baseImponibleTopeada;

  final double aporteJubilacion;
  final double aporteObraSocial;
  final double porcentajeObraSocial;
  final double aportePami;
  final double impuestoGanancias;
  final Map<String, double> deduccionesAdicionales;

  /// Recibo Neuquén (Dto 233/15, Ubic. Zona, A5 D335/16, componentes FONID/Conect., Dec. 137/05)
  final double dto23315;
  final double ubicacionZona;
  final double a5D33516;
  final double incDocenteLey25053;
  final double compFonid;
  final double ipcFonid;
  final double conectividadNacional;
  final double conectividadProvincial;
  final double redondeoMonto;
  final double dec13705;

  final double totalDescuentos;
  final double netoACobrar;
  final String bloqueArt12Ley17250;

  /// Costo laboral real estimado (Bruto + No Remunerativo + Contribuciones Patronales aprox)
  /// Por ahora retornamos Bruto + No Remunerativo para compatibilidad
  double get costoLaboralReal => totalBrutoRemunerativo + totalNoRemunerativo;

  LiquidacionOmniResult({
    required this.input,
    required this.config,
    required this.periodo,
    required this.fechaPago,
    required this.sueldoBasico,
    required this.adicionalAntiguedad,
    required this.adicionalZona,
    required this.adicionalZonaPatagonica,
    required this.plusUbicacion,
    required this.adicionalSalarialCiudad,
    required this.itemAula,
    required this.estadoDocente,
    this.presentismo = 0.0,
    required this.materialDidactico,
    required this.fonid,
    required this.conectividad,
    required this.horasCatedra,
    required this.ajusteEquiparacionLey13047,
    required this.fondoCompensador,
    required this.adicionalGarantiaSalarial,
    required this.conceptosPropios,
    required this.detallePuntosYValorIndice,
    required this.desgloseBaseBonificable,
    required this.totalBrutoRemunerativo,
    required this.totalNoRemunerativo,
    required this.baseImponibleTopeada,
    required this.aporteJubilacion,
    required this.aporteObraSocial,
    required this.porcentajeObraSocial,
    required this.aportePami,
    required this.impuestoGanancias,
    required this.deduccionesAdicionales,
    this.dto23315 = 0,
    this.ubicacionZona = 0,
    this.a5D33516 = 0,
    this.incDocenteLey25053 = 0,
    this.compFonid = 0,
    this.ipcFonid = 0,
    this.conectividadNacional = 0,
    this.conectividadProvincial = 0,
    this.redondeoMonto = 0,
    this.dec13705 = 0,
    required this.totalDescuentos,
    required this.netoACobrar,
    required this.bloqueArt12Ley17250,
  });

  Map<String, dynamic> toJson() {
    return {
      'input': input.toJson(),
      'config': config.toJson(),
      'periodo': periodo,
      'fechaPago': fechaPago,
      'sueldoBasico': sueldoBasico,
      'adicionalAntiguedad': adicionalAntiguedad,
      'adicionalZona': adicionalZona,
      'adicionalZonaPatagonica': adicionalZonaPatagonica,
      'plusUbicacion': plusUbicacion,
      'adicionalSalarialCiudad': adicionalSalarialCiudad,
      'itemAula': itemAula,
      'estadoDocente': estadoDocente,
      'presentismo': presentismo,
      'materialDidactico': materialDidactico,
      'fonid': fonid,
      'conectividad': conectividad,
      'horasCatedra': horasCatedra,
      'ajusteEquiparacionLey13047': ajusteEquiparacionLey13047,
      'fondoCompensador': fondoCompensador,
      'adicionalGarantiaSalarial': adicionalGarantiaSalarial,
      'conceptosPropios': conceptosPropios.map((c) => c.toJson()).toList(),
      'detallePuntosYValorIndice': detallePuntosYValorIndice,
      'desgloseBaseBonificable': desgloseBaseBonificable,
      'totalBrutoRemunerativo': totalBrutoRemunerativo,
      'totalNoRemunerativo': totalNoRemunerativo,
      'baseImponibleTopeada': baseImponibleTopeada,
      'aporteJubilacion': aporteJubilacion,
      'aporteObraSocial': aporteObraSocial,
      'porcentajeObraSocial': porcentajeObraSocial,
      'aportePami': aportePami,
      'impuestoGanancias': impuestoGanancias,
      'deduccionesAdicionales': deduccionesAdicionales,
      'dto23315': dto23315,
      'ubicacionZona': ubicacionZona,
      'a5D33516': a5D33516,
      'incDocenteLey25053': incDocenteLey25053,
      'compFonid': compFonid,
      'ipcFonid': ipcFonid,
      'conectividadNacional': conectividadNacional,
      'conectividadProvincial': conectividadProvincial,
      'redondeoMonto': redondeoMonto,
      'dec13705': dec13705,
      'totalDescuentos': totalDescuentos,
      'netoACobrar': netoACobrar,
      'bloqueArt12Ley17250': bloqueArt12Ley17250,
    };
  }

  factory LiquidacionOmniResult.fromJson(Map<String, dynamic> json) {
    return LiquidacionOmniResult(
      input: DocenteOmniInput.fromJson(json['input']),
      config: JurisdiccionConfigOmni.fromJson(json['config']),
      periodo: json['periodo'],
      fechaPago: json['fechaPago'],
      sueldoBasico: (json['sueldoBasico'] as num).toDouble(),
      adicionalAntiguedad: (json['adicionalAntiguedad'] as num).toDouble(),
      adicionalZona: (json['adicionalZona'] as num).toDouble(),
      adicionalZonaPatagonica: (json['adicionalZonaPatagonica'] as num).toDouble(),
      plusUbicacion: (json['plusUbicacion'] as num).toDouble(),
      adicionalSalarialCiudad: (json['adicionalSalarialCiudad'] as num).toDouble(),
      itemAula: (json['itemAula'] as num).toDouble(),
      estadoDocente: (json['estadoDocente'] as num).toDouble(),
      presentismo: (json['presentismo'] as num?)?.toDouble() ?? 0.0,
      materialDidactico: (json['materialDidactico'] as num).toDouble(),
      fonid: (json['fonid'] as num).toDouble(),
      conectividad: (json['conectividad'] as num).toDouble(),
      horasCatedra: (json['horasCatedra'] as num).toDouble(),
      ajusteEquiparacionLey13047: (json['ajusteEquiparacionLey13047'] as num).toDouble(),
      fondoCompensador: (json['fondoCompensador'] as num).toDouble(),
      adicionalGarantiaSalarial: (json['adicionalGarantiaSalarial'] as num).toDouble(),
      conceptosPropios: (json['conceptosPropios'] as List).map((c) => ConceptoPropioOmni.fromJson(c)).toList(),
      detallePuntosYValorIndice: json['detallePuntosYValorIndice'],
      desgloseBaseBonificable: json['desgloseBaseBonificable'],
      totalBrutoRemunerativo: (json['totalBrutoRemunerativo'] as num).toDouble(),
      totalNoRemunerativo: (json['totalNoRemunerativo'] as num).toDouble(),
      baseImponibleTopeada: (json['baseImponibleTopeada'] as num).toDouble(),
      aporteJubilacion: (json['aporteJubilacion'] as num).toDouble(),
      aporteObraSocial: (json['aporteObraSocial'] as num).toDouble(),
      porcentajeObraSocial: (json['porcentajeObraSocial'] as num).toDouble(),
      aportePami: (json['aportePami'] as num).toDouble(),
      impuestoGanancias: (json['impuestoGanancias'] as num).toDouble(),
      deduccionesAdicionales: Map<String, double>.from(json['deduccionesAdicionales']),
      dto23315: (json['dto23315'] as num).toDouble(),
      ubicacionZona: (json['ubicacionZona'] as num).toDouble(),
      a5D33516: (json['a5D33516'] as num).toDouble(),
      incDocenteLey25053: (json['incDocenteLey25053'] as num).toDouble(),
      compFonid: (json['compFonid'] as num).toDouble(),
      ipcFonid: (json['ipcFonid'] as num).toDouble(),
      conectividadNacional: (json['conectividadNacional'] as num).toDouble(),
      conectividadProvincial: (json['conectividadProvincial'] as num).toDouble(),
      redondeoMonto: (json['redondeoMonto'] as num).toDouble(),
      dec13705: (json['dec13705'] as num).toDouble(),
      totalDescuentos: (json['totalDescuentos'] as num).toDouble(),
      netoACobrar: (json['netoACobrar'] as num).toDouble(),
      bloqueArt12Ley17250: json['bloqueArt12Ley17250'],
    );
  }
}

/// Motor central Omni
class TeacherOmniEngine {
  static List<Map<String, dynamic>>? _cachedParitarias;

  /// Carga las paritarias desde el cache local (HybridStore) a la memoria para acceso rápido/síncrono
  static Future<void> loadParitariasCache() async {
    try {
      _cachedParitarias = await HybridStore.getMaestroParitarias();
    } catch (e) {
      print('Error cargando cache memoria Engine: $e');
    }
  }

  static JurisdiccionConfigOmni config(Jurisdiccion j) {
    // 1. Intentar cargar desde el Maestro de Paritarias (Sincronizado con Supabase)
    // Nota: como esta función es síncrona por herencia, usamos HybridStore que tiene el cache local
    final maestro = _getMaestroCached(j);
    
    final cfg = JurisdiccionDBOmni.get(j) ??
        JurisdiccionConfigOmni(
          jurisdiccion: j,
          nombre: j.name,
          valorIndice: 210.0,
          pisoSalarial: ParametrosFederales2026Omni.pisoSalarialNacional,
          cajaPrevisional: TipoCajaPrevisional.anses,
          porcentajeAporte: 11.0,
          topeHorasCatedra: 36,
        );

    // 2. Si hay paritaria en cache, sobreescribir valores estáticos
    if (maestro != null) {
      if (maestro['valor_indice'] != null) cfg.valorIndice = (maestro['valor_indice'] as num).toDouble();
      if (maestro['piso_salarial'] != null) cfg.pisoSalarial = (maestro['piso_salarial'] as num).toDouble();
      if (maestro['monto_fonid'] != null) {
        // Nota: el engine federal usa ParametrosFederales2026Omni.fonidMonto, 
        // pero para esta jurisdicción específica podríamos aplicar un override si fuese necesario.
      }
    }

    if (cfg.cajaPrevisional == TipoCajaPrevisional.ipsPBA) {
      cfg.porcentajeAporte = 16.0;
    } else if (cfg.cajaPrevisional == TipoCajaPrevisional.ipasCordoba) {
      cfg.porcentajeAporte = 14.5;
    } else if (cfg.cajaPrevisional == TipoCajaPrevisional.issn) {
      cfg.porcentajeAporte = 14.5; // ISSN Neuquén
    } else if (cfg.cajaPrevisional == TipoCajaPrevisional.anses) {
      cfg.porcentajeAporte = 11.0; // ANSES (Río Negro, Nación, etc.)
    }

    return cfg;
  }

  static double valorIndiceEfectivo(JurisdiccionConfigOmni c) {
    if (!c.actualizacionIPC) return c.valorIndice;
    return c.valorIndice;
  }

  static double sueldoBasico(int puntos, double valorIndice, double pisoSalarial) {
    final bruto = puntos * valorIndice;
    return bruto < pisoSalarial ? pisoSalarial : bruto;
  }

  static double calcularBaseBonificable({
    required double sueldoBasico,
    required List<ConceptoPropioOmni> conceptosPropios,
  }) {
    double base = sueldoBasico;
    for (final c in conceptosPropios) {
      if (c.esRemunerativo && c.esBonificable) base += c.monto;
    }
    return base;
  }

  static double adicionalAntiguedad(double baseBonificable, int anos, bool use140) {
    final pct = TablaAntiguedadFederal.porcentajePorAnos(anos, usarExtendida140: use140);
    return baseBonificable * (pct / 100);
  }

  static double adicionalZona(double baseBonificableMasAntiguedad, ZonaDesfavorable z) {
    final pct = ZonaConstants.porcentaje(z);
    return baseBonificableMasAntiguedad * (pct / 100);
  }

  static double calcularItemAula(double base, double? pct) {
    if (pct == null || pct <= 0) return 0.0;
    return base * (pct / 100);
  }

  static (double fonid, double conectividad) fonidConectividad(int cantidadCargos) {
    final n = cantidadCargos > ParametrosFederales2026Omni.topeCargosFonid
        ? ParametrosFederales2026Omni.topeCargosFonid
        : cantidadCargos;
    if (n <= 0) return (0.0, 0.0);
    return (
      ParametrosFederales2026Omni.fonidMonto * n,
      ParametrosFederales2026Omni.conectividadMonto * n,
    );
  }

  static double montoHorasCatedra(double valorIndice, int puntosUnidad, int horas, int topeHoras) {
    final h = horas > topeHoras ? topeHoras : horas;
    return valorIndice * puntosUnidad * h;
  }

  static double ajusteEquiparacionLey13047(double netoEstatalEquivalente, double netoPrivadoCargado) {
    if (netoEstatalEquivalente <= netoPrivadoCargado) return 0.0;
    return netoEstatalEquivalente - netoPrivadoCargado;
  }

  /// Aportes: Gestión privada siempre ANSES 11% Jub + 3% OS. Pública: ISSN (14.5%+5.5%), IPS, etc. PAMI 3%.
  /// Causa 11% en recibo privado: en instituciones privadas se aporta a ANSES (nacional), no a caja provincial (ISSN).
  static (double jub, double os, double pami) aportes(
    double baseTopeada,
    TipoGestion gestion,
    TipoCajaPrevisional caja,
    double pctCaja, {
    double? porcentajeObraSocial,
  }) {
    final base = baseTopeada > ParametrosFederales2026Omni.topePrevisional
        ? ParametrosFederales2026Omni.topePrevisional
        : baseTopeada;
    double jub;
    double pctOS;
    if (gestion == TipoGestion.privada) {
      // Gestión privada: siempre ANSES (régimen nacional) — 11% Jubilación + 3% Obra Social.
      // La caja de la jurisdicción (ej. ISSN en Neuquén) aplica solo a escuelas públicas.
      jub = base * 0.11;
      pctOS = (porcentajeObraSocial ?? 3.0) / 100;
    } else if (caja == TipoCajaPrevisional.issn) {
      jub = base * (pctCaja / 100); // 14.5% Neuquén público
      pctOS = (porcentajeObraSocial ?? 5.5) / 100; // 5.5% OS ISSN
    } else {
      jub = base * (pctCaja / 100);
      pctOS = (porcentajeObraSocial ?? 3.0) / 100;
    }
    final os = base * pctOS;
    final pami = base * 0.03;
    return (jub, os, pami);
  }

  static double impuestoGanancias(double remuneracionNeta, int cargasFamiliares) {
    final deduccionCargas = cargasFamiliares * ParametrosFederales2026Omni.deduccionPorCargaFamiliar;
    final base = remuneracionNeta - deduccionCargas;
    if (base <= ParametrosFederales2026Omni.minimoNoImponibleGanancias) return 0.0;
    final excedente = base - ParametrosFederales2026Omni.minimoNoImponibleGanancias;
    double impuesto = 0.0;
    if (excedente <= 2000000.0) {
      impuesto = excedente * 0.05;
    } else if (excedente <= 5000000.0) {
      impuesto = 2000000.0 * 0.05 + (excedente - 2000000.0) * 0.27;
    } else if (excedente <= 10000000.0) {
      impuesto = 2000000.0 * 0.05 + 3000000.0 * 0.27 + (excedente - 5000000.0) * 0.30;
    } else {
      impuesto = 2000000.0 * 0.05 + 3000000.0 * 0.27 + 5000000.0 * 0.30 + (excedente - 10000000.0) * 0.35;
    }
    return impuesto;
  }

  static double calcularGarantiaSalarial(double netoACobrar) {
    const double pisoSalarialNacional = 745311.0;
    if (netoACobrar >= pisoSalarialNacional) return 0.0;
    return pisoSalarialNacional - netoACobrar;
  }

  static String bloqueArt12(String periodo, String fechaPago, double jub, double os, double pami) {
    return 'ART. 12 LEY 17.250 - ÚLTIMO DEPÓSITO DE APORTES\n'
        'Período: $periodo | Fecha de Pago: $fechaPago\n'
        'Jubilación: \$${jub.toStringAsFixed(2)} | Obra Social: \$${os.toStringAsFixed(2)} | PAMI: \$${pami.toStringAsFixed(2)}\n'
        'Total: \$${(jub + os + pami).toStringAsFixed(2)}';
  }

  static Map<String, dynamic>? _getMaestroCached(Jurisdiccion j) {
    if (_cachedParitarias == null) return null;
    try {
      return _cachedParitarias!.firstWhere((p) => p['jurisdiccion'] == j.name);
    } catch (_) {
      return null;
    }
  }

  static LiquidacionOmniResult liquidar(
    DocenteOmniInput input, {
    required String periodo,
    required String fechaPago,
    int cantidadCargos = 1,
    List<ConceptoPropioOmni> conceptosPropios = const [],
    Map<String, double> deduccionesAdicionales = const {},
  }) {
    PayrollCore.validarCUILCUIT(input.cuil, 'DocenteOmniInput');
    for (final c in conceptosPropios) {
      CodigosAfipArca.validar(c.codigoAfip, c.descripcion);
      PayrollCore.requireNoNegativo(c.monto, 'Concepto ${c.codigo}');
    }
    final cfg = config(input.jurisdiccion);
    final maestro = _getMaestroCached(input.jurisdiccion);
    
    // Resolver porcentaje de Obra Social desde el catálogo si hay un código RNOS válido
    double? pctOSCatalogo;
    if (input.codigoRnos != null) {
      final osInfo = CatalogoRNOS2026.buscarPorCodigo(input.codigoRnos!);
      if (osInfo != null) {
        pctOSCatalogo = osInfo.porcentajeAporte;
      }
    }
    final double pctOSFinal = pctOSCatalogo ?? cfg.porcentajeObraSocial ?? 3.0;

    final usePayrollCore = cfg.cajaPrevisional == TipoCajaPrevisional.issn
        || cfg.cajaPrevisional == TipoCajaPrevisional.anses;
    final PayrollCore? core = usePayrollCore
        ? PayrollCore(
            strategy: cfg.cajaPrevisional == TipoCajaPrevisional.issn
                ? RegimenProvincialNeuquenStrategy()
                : RegimenNacionalStrategy(),
          )
        : null;
    final double vi = input.valorIndiceOverride ?? valorIndiceEfectivo(cfg);
    final anos = input.anosAntiguedad();
    final use140 = cfg.antiguedadHasta140;

    final item = NomencladorFederal2026.itemPorTipo(input.cargoNomenclador);
    
    // Resolver códigos AFIP por defecto si no vienen en el input
    final actFinal = input.codigoActividad ?? item?.codigoActividad ?? '001';
    final pstFinal = input.codigoPuesto ?? item?.codigoPuesto ?? '0000';
    final conFinal = input.codigoCondicion ?? '01';
    final modFinal = input.codigoModalidad ?? '008';

    final esHoraCat = item?.esHoraCatedra ?? false;
    int pts = 0;
    double horasCat = 0.0;

    if (esHoraCat) {
      pts = input.puntosHoraCatedraOverride ?? (input.esHoraCatedraSecundaria ? 60 : 72);
      final h = input.horasCatedra > cfg.topeHorasCatedra ? cfg.topeHorasCatedra : input.horasCatedra;
      horasCat = vi * pts * h;
    } else {
      pts = input.puntosCargoOverride ?? NomencladorFederal2026.puntosPorTipo(input.cargoNomenclador);
    }

    // Doble/múltiple cargo: para cargo (no hora cátedra), multiplicar puntos por cantidad de cargos
    final int ptsEfectivos = (!esHoraCat && cantidadCargos > 1) ? (pts * cantidadCargos) : pts;

    // ═══════════════════════════════════════════════════════════════════════
    // CASCADA BONIFICABLE (orden estricto para coincidir con recibo real)
    // ═══════════════════════════════════════════════════════════════════════
    // A = Sueldo Básico: (Puntos × Valor Índice) o Horas Cátedra; sueldoBasicoOverride reemplaza cuando se precisa (ej. acuerdo/recibo real)
    double basico = 0.0;
    if (!esHoraCat) {
      if (input.modoLiquidacion == "sac") {
        final mejorRemu = input.mejorRemuneracionSemestral ?? 0.0;
        final dias = input.diasTrabajadosSemestre ?? 180;
        basico = (mejorRemu / 2) * (dias / 180);
      } else if (input.modoLiquidacion == "vacaciones") {
        final baseVac = input.promedioVariablesSemestral ?? input.sueldoBasicoOverride ?? 0.0;
        final diasVac = input.diasVacaciones ?? 14;
        basico = (baseVac / 25) * diasVac;
      } else if (input.modoLiquidacion == "final") {
        final fCese = input.fechaCese ?? DateTime.now();
        final diasTrabajadosMes = fCese.day;
        final double baseMensual = input.sueldoBasicoOverride ?? (ptsEfectivos * vi < cfg.pisoSalarial ? cfg.pisoSalarial : ptsEfectivos * vi);
        basico = (baseMensual / 30) * diasTrabajadosMes;
      } else if (input.modoLiquidacion == "proporcional") {
        final dias = input.diasTrabajadosSemestre ?? 30;
        final double baseMensual = input.sueldoBasicoOverride ?? (ptsEfectivos * vi < cfg.pisoSalarial ? cfg.pisoSalarial : ptsEfectivos * vi);
        basico = (baseMensual / 30) * dias;
      } else if (input.sueldoBasicoOverride != null) {
        basico = input.sueldoBasicoOverride!;
      } else if (item?.esSueldoFijo == true) {
        // Resolver sueldo fijo para no docentes
        final keyMetadata = 'basico_${input.cargoNomenclador.name.toLowerCase()}';
        final basicoMetadata = maestro?['metadata']?[keyMetadata] ?? maestro?['metadata']?['basico_portero'];
        basico = (basicoMetadata as num?)?.toDouble() ?? 650000.0; // Fallback
      } else {
        basico = sueldoBasico(ptsEfectivos, vi, cfg.pisoSalarial);
      }
    }
    final double A = esHoraCat ? horasCat : basico;

    const jurisdiccionesPatagonia = [Jurisdiccion.rioNegro, Jurisdiccion.neuquen, Jurisdiccion.chubut, Jurisdiccion.santaCruz, Jurisdiccion.tierraDelFuego];
    final esZonaPatagonica = jurisdiccionesPatagonia.contains(input.jurisdiccion);

    double estadoDoc = 0.0, materialDidactico = 0.0, antig = 0.0, zonaAdd = 0.0, plusUbicacion = 0.0;
    double montoItemAula = 0.0, addCiudad = 0.0, fonid = 0.0, conectividad = 0.0;
    double dto23315 = 0.0, ubicacionZona = 0.0, a5D33516 = 0.0;
    double incDocenteLey25053 = 0.0, compFonid = 0.0, ipcFonid = 0.0;
    double conectividadNacional = 0.0, conectividadProvincial = 0.0, redondeoMonto = 0.0, dec13705 = 0.0;
    double adicionalZonaPatagonica = 0.0;

    final bool modoNeuquenRecibo = cfg.dto23315PorcentajeSobreBasico != null && !esHoraCat;

    if (modoNeuquenRecibo) {
      // Cascada exacta recibo Plottier/Researchers Potter: Antig 20% sobre básico; Dto 233/15, Ubic. 10%, Zona 40% sobre (A+Antig+Dto+Ubic); componentes FONID; Dec. 137/05 2%.
      final double pctAntig = cfg.antiguedadTablaOverride != null
          ? TablaAntiguedadFederal.porcentajePorAnosFromTable(anos, cfg.antiguedadTablaOverride!)
          : TablaAntiguedadFederal.porcentajePorAnos(anos, usarExtendida140: use140);
      antig = (cfg.antiguedadSobreSoloBasico == true) ? (A * pctAntig / 100) : (A * pctAntig / 100);
      dto23315 = A * (cfg.dto23315PorcentajeSobreBasico! / 100);
      ubicacionZona = A * (cfg.ubicacionZonaPorcentaje! / 100);
      final double baseZona = A + antig + dto23315 + ubicacionZona;
      final double pctPat = cfg.plusZonaPatagonicaPorcentaje ?? 20.0;
      adicionalZonaPatagonica = esZonaPatagonica && baseZona > 0 ? baseZona * (pctPat / 100) : 0.0;
      a5D33516 = A * (cfg.a5D33516PorcentajeSobreBasico! / 100);
      incDocenteLey25053 = (cfg.incDocenteLey25053Monto ?? 0) * (cantidadCargos > 0 ? cantidadCargos : 1);
      compFonid = cfg.compFonidMonto ?? 0;
      ipcFonid = cfg.ipcFonidMonto ?? 0;
      conectividadNacional = cfg.conectividadNacionalMonto ?? 0;
      conectividadProvincial = cfg.conectividadProvincialMonto ?? 0;
      redondeoMonto = cfg.redondeoMonto ?? 0;
    } else {
      // B = Estado Docente (automático, bonificable)
      if (!esHoraCat && cantidadCargos >= 1) {
        final basicoPorCargo = A / (cantidadCargos > 0 ? cantidadCargos : 1);
        final porPct = basicoPorCargo * (ParametrosFederales2026Omni.estadoDocentePctSobreBasico / 100);
        final montoPorCargo = (porPct > ParametrosFederales2026Omni.estadoDocenteMontoMinimoPorCargo)
            ? porPct
            : ParametrosFederales2026Omni.estadoDocenteMontoMinimoPorCargo;
        final n = cantidadCargos > ParametrosFederales2026Omni.topeCargosFonid
            ? ParametrosFederales2026Omni.topeCargosFonid
            : cantidadCargos;
        estadoDoc = montoPorCargo * n;
      }
      materialDidactico = cfg.materialDidacticoMonto ?? 0.0;
      final double otrosBonif = conceptosPropios.where((c) => c.esRemunerativo && c.esBonificable).fold(0.0, (s, c) => s + c.monto);
      final double B_bonif = estadoDoc + materialDidactico + otrosBonif;
      final double C_bonif = A + B_bonif;
      antig = TeacherOmniEngine.adicionalAntiguedad(C_bonif, anos, use140);

      final double remuSinZona = A + estadoDoc + materialDidactico + antig + conceptosPropios.where((c) => c.esRemunerativo).fold(0.0, (s, c) => s + c.monto);
      final double D = remuSinZona;
      final double pctPatagonia = cfg.plusZonaPatagonicaPorcentaje ?? 20.0;
      adicionalZonaPatagonica = esZonaPatagonica && D > 0 ? D * (pctPatagonia / 100) : 0.0;
      zonaAdd = adicionalZona(D, input.zona);
      final double pctUbic = NivelUbicacionConstants.porcentaje(input.nivelUbicacion);
      plusUbicacion = D > 0 ? D * (pctUbic / 100) : 0.0;
      final double baseParaAula = D + adicionalZonaPatagonica + zonaAdd + plusUbicacion;
      montoItemAula = calcularItemAula(baseParaAula, cfg.itemAulaPorcentaje);
      addCiudad = cfg.adicionalSalarialCiudadMonto ?? 0.0;
      final (double f, double c) = fonidConectividad(cantidadCargos);
      fonid = f;
      conectividad = c;
    }

    final double C = A + (modoNeuquenRecibo ? 0 : (estadoDoc + materialDidactico)) + (modoNeuquenRecibo ? 0 : conceptosPropios.where((c) => c.esRemunerativo && c.esBonificable).fold(0.0, (s, c) => s + c.monto));
    final double D = C + antig;
    final double capa3 = adicionalZonaPatagonica + zonaAdd + plusUbicacion + montoItemAula + addCiudad;
    final String desgloseBaseBonificable = modoNeuquenRecibo
        ? 'Neuquén recibo: A=\$${A.toStringAsFixed(2)} | Antig \$${antig.toStringAsFixed(2)} | Dto 233/15 \$${dto23315.toStringAsFixed(2)} | Ubic.Zona \$${ubicacionZona.toStringAsFixed(2)} | Zona 40% \$${adicionalZonaPatagonica.toStringAsFixed(2)} | A5 D335/16 \$${a5D33516.toStringAsFixed(2)} | FONID/Conect. \$${(incDocenteLey25053+compFonid+ipcFonid).toStringAsFixed(2)}'
        : 'A=Básico: \$${A.toStringAsFixed(2)} | B=Estado Docente: \$${estadoDoc.toStringAsFixed(2)} | C=A+B: \$${C.toStringAsFixed(2)} | D=Antigüedad: \$${antig.toStringAsFixed(2)} | E=C+D: \$${D.toStringAsFixed(2)} | F=Plus Patagonia: \$${adicionalZonaPatagonica.toStringAsFixed(2)} | G=Plus Ubicación: \$${plusUbicacion.toStringAsFixed(2)}\nCapas: 3=Zona+Ubic= \$${capa3.toStringAsFixed(2)} | 4=FONID+Conect= \$${(fonid + conectividad).toStringAsFixed(2)}';

    final String detallePuntosYValorIndice = esHoraCat
        ? 'Puntos/unidad: $pts | Horas: ${input.horasCatedra > cfg.topeHorasCatedra ? cfg.topeHorasCatedra : input.horasCatedra} | Valor Índice: \$${vi.toStringAsFixed(2)}'
        : 'Puntos: $ptsEfectivos | Valor Índice: \$${vi.toStringAsFixed(2)}';

    // --- CONCEPTOS AUTOMÁTICOS PARA LIQUIDACIÓN FINAL ---
    final List<ConceptoPropioOmni> conceptosFinales = List.from(conceptosPropios);
    if (input.modoLiquidacion == "final") {
      final fCese = input.fechaCese ?? DateTime.now();
      
      // SAC Proporcional
      final mejorRemu = input.mejorRemuneracionSemestral ?? A;
      final inicioSemestre = fCese.month <= 6 ? DateTime(fCese.year, 1, 1) : DateTime(fCese.year, 7, 1);
      final diasSemestre = fCese.difference(inicioSemestre).inDays + 1;
      final sacProp = (mejorRemu / 2) * (diasSemestre / 180);
      conceptosFinales.add(ConceptoPropioOmni(
        codigo: 'SAC_PROP',
        descripcion: 'SAC Proporcional',
        monto: sacProp,
        esRemunerativo: true,
        codigoAfip: '120000'
      ));

      // Vacaciones No Gozadas
      final baseVng = input.promedioVariablesSemestral ?? A;
      final diffAnos = fCese.year - input.fechaIngreso.year;
      int diasDure = 14;
      if (diffAnos >= 5) diasDure = 21;
      if (diffAnos >= 10) diasDure = 28;
      if (diffAnos >= 20) diasDure = 35;
      
      final diasVng = (diasDure / 360) * (fCese.difference(DateTime(fCese.year, 1, 1)).inDays + 1);
      final vng = (baseVng / 25) * diasVng;
      conceptosFinales.add(ConceptoPropioOmni(
        codigo: 'VNG',
        descripcion: 'Vacaciones No Gozadas',
        monto: vng,
        esRemunerativo: false,
        codigoAfip: '130000'
      ));

      // Indemnización Art. 245 (si aplica)
      if (input.motivoCese == "despido_sin_causa") {
        final baseIndem = input.baseIndemnizatoria ?? A;
        final antiguedadAnos = (fCese.difference(input.fechaIngreso).inDays / 365).floor();
        final mesesExcedentes = (fCese.difference(input.fechaIngreso).inDays % 365) / 30;
        final factorIndem = mesesExcedentes > 3 ? antiguedadAnos + 1 : antiguedadAnos;
        final indem245 = baseIndem * factorIndem;
        
        conceptosFinales.add(ConceptoPropioOmni(
          codigo: 'INDEMN_245',
          descripcion: 'Indemnizacion Antiguedad Art. 245',
          monto: indem245,
          esRemunerativo: false,
          codigoAfip: '211000'
        ));

        if (input.incluyePreaviso) {
          final preaviso = baseIndem * (antiguedadAnos >= 5 ? 2 : 1);
          conceptosFinales.add(ConceptoPropioOmni(
            codigo: 'PREAVISO',
            descripcion: 'Indemnizacion Sustitutiva Preaviso',
            monto: preaviso,
            esRemunerativo: false,
            codigoAfip: '212000'
          ));
        }
      }
    }

    double brutoRem;
    if (modoNeuquenRecibo) {
      brutoRem = A + antig + dto23315 + ubicacionZona + adicionalZonaPatagonica + a5D33516 + incDocenteLey25053 + compFonid + ipcFonid;
    } else {
      brutoRem = A + antig + zonaAdd + adicionalZonaPatagonica + plusUbicacion + montoItemAula + addCiudad + estadoDoc + materialDidactico + fonid + conectividad;
    }
    for (final c in conceptosFinales) { if (c.esRemunerativo) brutoRem += c.monto; }

    double noRem = 0.0;
    if (modoNeuquenRecibo) {
      noRem = conectividadNacional + conectividadProvincial + redondeoMonto;
    } else {
      for (final c in conceptosFinales) { if (!c.esRemunerativo) noRem += c.monto; }
    }
    final double fondoComp = input.subsidioParcialFondoCompensador ?? 0.0;
    noRem += fondoComp;

    if (cfg.dec13705Porcentaje != null && cfg.dec13705Porcentaje! > 0) {
      dec13705 = brutoRem * (cfg.dec13705Porcentaje! / 100);
    }

    double ajuste13047 = 0.0;
    final double baseTopeadaAntes = brutoRem > ParametrosFederales2026Omni.topePrevisional ? ParametrosFederales2026Omni.topePrevisional : brutoRem;

    if (input.tipoGestion == TipoGestion.privada && !modoNeuquenRecibo) {
      final (jE, oE, pE) = core?.aportesFromDouble(baseTopeadaAntes) ??
          aportes(baseTopeadaAntes, TipoGestion.publica, cfg.cajaPrevisional, cfg.porcentajeAporte, porcentajeObraSocial: pctOSFinal);
      final (jP, oP, pP) = PayrollCore(strategy: RegimenNacionalStrategy()).aportesFromDouble(baseTopeadaAntes);
      final netoEstatal = brutoRem - (jE + oE + pE);
      final netoPrivado = brutoRem - (jP + oP + pP);
      ajuste13047 = ajusteEquiparacionLey13047(netoEstatal, netoPrivado);
      brutoRem += ajuste13047;
    }

    final double baseTopeada = brutoRem > ParametrosFederales2026Omni.topePrevisional ? ParametrosFederales2026Omni.topePrevisional : brutoRem;

    final (jub, os, pami) = input.tipoGestion == TipoGestion.privada
        ? aportes(baseTopeada, TipoGestion.privada, cfg.cajaPrevisional, cfg.porcentajeAporte, porcentajeObraSocial: pctOSFinal)
        : (core?.aportesFromDouble(baseTopeada) ?? aportes(baseTopeada, input.tipoGestion, cfg.cajaPrevisional, cfg.porcentajeAporte, porcentajeObraSocial: pctOSFinal));

    final remunNeta = brutoRem - jub - os - pami;
    final ganancias = impuestoGanancias(remunNeta, input.cargasFamiliares);

    double descTotal = jub + os + pami + ganancias + dec13705;
    for (final d in deduccionesAdicionales.values) { descTotal += d; }

    double netoInicial = brutoRem - descTotal + noRem;
    double garantiaSalarial = calcularGarantiaSalarial(netoInicial);
    double brutoRemFinal = brutoRem;
    double baseTopeadaFinal = baseTopeada;
    double jubFinal = jub, osFinal = os, pamiFinal = pami, gananciasFinal = ganancias, descTotalFinal = descTotal, netoFinal = netoInicial;
    double dec13705Result = dec13705;

    if (garantiaSalarial > 0) {
      brutoRemFinal += garantiaSalarial;
      baseTopeadaFinal = brutoRemFinal > ParametrosFederales2026Omni.topePrevisional ? ParametrosFederales2026Omni.topePrevisional : brutoRemFinal;
      final (jubNuevo, osNuevo, pamiNuevo) = input.tipoGestion == TipoGestion.privada
          ? aportes(baseTopeadaFinal, TipoGestion.privada, cfg.cajaPrevisional, cfg.porcentajeAporte, porcentajeObraSocial: pctOSFinal)
          : (core?.aportesFromDouble(baseTopeadaFinal) ?? aportes(baseTopeadaFinal, input.tipoGestion, cfg.cajaPrevisional, cfg.porcentajeAporte, porcentajeObraSocial: pctOSFinal));
      jubFinal = jubNuevo; osFinal = osNuevo; pamiFinal = pamiNuevo;
      final remunNetaNueva = brutoRemFinal - jubFinal - osFinal - pamiFinal;
      gananciasFinal = impuestoGanancias(remunNetaNueva, input.cargasFamiliares);
      dec13705Result = (cfg.dec13705Porcentaje != null && cfg.dec13705Porcentaje! > 0)
          ? brutoRemFinal * (cfg.dec13705Porcentaje! / 100) : dec13705;
      descTotalFinal = jubFinal + osFinal + pamiFinal + gananciasFinal + dec13705Result;
      for (final d in deduccionesAdicionales.values) { descTotalFinal += d; }
      netoFinal = brutoRemFinal - descTotalFinal + noRem;
    }

    final bloque = bloqueArt12(periodo, fechaPago, jubFinal, osFinal, pamiFinal);
    PayrollCore.requireNoNegativo(netoFinal, 'netoACobrar');

    return LiquidacionOmniResult(
      input: DocenteOmniInput(
        nombre: input.nombre,
        cuil: input.cuil,
        jurisdiccion: input.jurisdiccion,
        tipoGestion: input.tipoGestion,
        cargoNomenclador: input.cargoNomenclador,
        nivelEducativo: input.nivelEducativo,
        fechaIngreso: input.fechaIngreso,
        cargasFamiliares: input.cargasFamiliares,
        codigoRnos: input.codigoRnos,
        horasCatedra: input.horasCatedra,
        zona: input.zona,
        nivelUbicacion: input.nivelUbicacion,
        aporteEstatalPorcentaje: input.aporteEstatalPorcentaje,
        subsidioParcialFondoCompensador: input.subsidioParcialFondoCompensador,
        esHoraCatedraSecundaria: input.esHoraCatedraSecundaria,
        puntosCargoOverride: input.puntosCargoOverride,
        puntosHoraCatedraOverride: input.puntosHoraCatedraOverride,
        valorIndiceOverride: input.valorIndiceOverride,
        sueldoBasicoOverride: input.sueldoBasicoOverride,
        codigoActividad: actFinal,
        codigoPuesto: pstFinal,
        codigoCondicion: conFinal,
        codigoModalidad: modFinal,
      ),
      config: cfg,
      periodo: periodo,
      fechaPago: fechaPago,
      sueldoBasico: basico,
      adicionalAntiguedad: antig,
      adicionalZona: zonaAdd,
      adicionalZonaPatagonica: adicionalZonaPatagonica,
      plusUbicacion: plusUbicacion,
      adicionalSalarialCiudad: addCiudad,
      itemAula: montoItemAula,
      estadoDocente: estadoDoc,
      presentismo: 0.0,
      materialDidactico: materialDidactico,
      fonid: fonid,
      conectividad: conectividad,
      horasCatedra: horasCat,
      ajusteEquiparacionLey13047: ajuste13047,
      fondoCompensador: fondoComp,
      adicionalGarantiaSalarial: garantiaSalarial,
      conceptosPropios: conceptosFinales,
      detallePuntosYValorIndice: detallePuntosYValorIndice,
      desgloseBaseBonificable: desgloseBaseBonificable,
      totalBrutoRemunerativo: brutoRemFinal,
      totalNoRemunerativo: noRem,
      baseImponibleTopeada: baseTopeadaFinal,
      aporteJubilacion: jubFinal,
      aporteObraSocial: osFinal,
      porcentajeObraSocial: pctOSFinal,
      aportePami: pamiFinal,
      impuestoGanancias: gananciasFinal,
      deduccionesAdicionales: deduccionesAdicionales,
      dto23315: dto23315,
      ubicacionZona: ubicacionZona,
      a5D33516: a5D33516,
      incDocenteLey25053: incDocenteLey25053,
      compFonid: compFonid,
      ipcFonid: ipcFonid,
      conectividadNacional: conectividadNacional,
      conectividadProvincial: conectividadProvincial,
      redondeoMonto: redondeoMonto,
      dec13705: dec13705Result,
      totalDescuentos: descTotalFinal,
      netoACobrar: netoFinal,
      bloqueArt12Ley17250: bloque,
    );
  }
}
