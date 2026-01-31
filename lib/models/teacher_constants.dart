// ========================================================================
// TEACHER CONSTANTS - BASE DE DATOS Y TABLAS MAESTRAS
// Sistema Federal de Liquidación Docente Argentina 2026
// Todas las constantes tipadas. Valores editables desde UI.
// ========================================================================

import 'package:syncra_arg/models/teacher_types.dart';

// ---------------------------------------------------------------------------
// 1. TABLA MAESTRA DE ANTIGÜEDAD (Escalafón Docente 2026)
// Aplicable sobre Básico + adicionales remunerativos.
// Por defecto 0-24+. Santa Cruz / Neuquén pueden llegar a 140% según config.
// ---------------------------------------------------------------------------

/// Rango de años → porcentaje sobre (Básico + Adicionales)
class RangoAntiguedad {
  final int anosMin;
  final int anosMax;
  final double porcentaje;

  const RangoAntiguedad({
    required this.anosMin,
    required this.anosMax,
    required this.porcentaje,
  });

  Map<String, dynamic> toJson() {
    return {
      'anosMin': anosMin,
      'anosMax': anosMax,
      'porcentaje': porcentaje,
    };
  }

  factory RangoAntiguedad.fromJson(Map<String, dynamic> json) {
    return RangoAntiguedad(
      anosMin: json['anosMin'],
      anosMax: json['anosMax'],
      porcentaje: (json['porcentaje'] as num).toDouble(),
    );
  }
}

/// Tabla completa. Jurisdicciones con tope 140% usan _tablaAntiguedadExtendida.
class TablaAntiguedadFederal {
  static const List<RangoAntiguedad> estandar = [
    RangoAntiguedad(anosMin: 0, anosMax: 1, porcentaje: 0.0),
    RangoAntiguedad(anosMin: 2, anosMax: 4, porcentaje: 15.0),
    RangoAntiguedad(anosMin: 5, anosMax: 6, porcentaje: 30.0),
    RangoAntiguedad(anosMin: 7, anosMax: 9, porcentaje: 40.0),
    RangoAntiguedad(anosMin: 10, anosMax: 11, porcentaje: 50.0),
    RangoAntiguedad(anosMin: 12, anosMax: 14, porcentaje: 60.0),
    RangoAntiguedad(anosMin: 15, anosMax: 16, porcentaje: 70.0),
    RangoAntiguedad(anosMin: 17, anosMax: 19, porcentaje: 80.0),
    RangoAntiguedad(anosMin: 20, anosMax: 21, porcentaje: 100.0),
    RangoAntiguedad(anosMin: 22, anosMax: 23, porcentaje: 110.0),
    RangoAntiguedad(anosMin: 24, anosMax: 999, porcentaje: 120.0),
  ];

  /// Para Santa Cruz, Neuquén: 24+ → 140%
  static const List<RangoAntiguedad> extendida140 = [
    RangoAntiguedad(anosMin: 0, anosMax: 1, porcentaje: 0.0),
    RangoAntiguedad(anosMin: 2, anosMax: 4, porcentaje: 15.0),
    RangoAntiguedad(anosMin: 5, anosMax: 6, porcentaje: 30.0),
    RangoAntiguedad(anosMin: 7, anosMax: 9, porcentaje: 40.0),
    RangoAntiguedad(anosMin: 10, anosMax: 11, porcentaje: 50.0),
    RangoAntiguedad(anosMin: 12, anosMax: 14, porcentaje: 60.0),
    RangoAntiguedad(anosMin: 15, anosMax: 16, porcentaje: 70.0),
    RangoAntiguedad(anosMin: 17, anosMax: 19, porcentaje: 80.0),
    RangoAntiguedad(anosMin: 20, anosMax: 21, porcentaje: 100.0),
    RangoAntiguedad(anosMin: 22, anosMax: 23, porcentaje: 110.0),
    RangoAntiguedad(anosMin: 24, anosMax: 999, porcentaje: 140.0),
  ];

  static double porcentajePorAnos(int anos, {bool usarExtendida140 = false}) {
    final tabla = usarExtendida140 ? extendida140 : estandar;
    return porcentajePorAnosFromTable(anos, tabla);
  }

  /// Si se pasa una tabla custom (ej. override Neuquén con 1-2: 20%), la usa.
  static double porcentajePorAnosFromTable(int anos, List<RangoAntiguedad> tabla) {
    for (final r in tabla) {
      if (anos >= r.anosMin && anos <= r.anosMax) return r.porcentaje;
    }
    return 0.0;
  }
}

// ---------------------------------------------------------------------------
// 2. NOMENCLADOR (Puntos por Cargo) - Sueldo = Puntos * Valor Índice
// ---------------------------------------------------------------------------

class ItemNomenclador {
  final TipoNomenclador tipo;
  final int puntos;
  final String descripcion;
  final bool esHoraCatedra; // true = pts por unidad de hora
  final bool esSueldoFijo; // true = usa básico de paritaria no docente
  final String? codigoActividad;
  final String? codigoPuesto;

  const ItemNomenclador({
    required this.tipo,
    required this.puntos,
    required this.descripcion,
    this.esHoraCatedra = false,
    this.esSueldoFijo = false,
    this.codigoActividad,
    this.codigoPuesto,
  });
}

class NomencladorFederal2026 {
  static const List<ItemNomenclador> items = [
    ItemNomenclador(tipo: TipoNomenclador.maestroGrado, puntos: 1100, descripcion: 'Maestro de Grado', codigoActividad: '001', codigoPuesto: '0101'),
    ItemNomenclador(tipo: TipoNomenclador.directorPrimera, puntos: 2500, descripcion: 'Director de 1ra', codigoActividad: '001', codigoPuesto: '0106'),
    ItemNomenclador(tipo: TipoNomenclador.maestroNivelInicial, puntos: 1050, descripcion: 'Maestro de Nivel Inicial', codigoActividad: '001', codigoPuesto: '0101'),
    ItemNomenclador(tipo: TipoNomenclador.preceptor, puntos: 850, descripcion: 'Preceptor', codigoActividad: '001', codigoPuesto: '0103'),
    ItemNomenclador(tipo: TipoNomenclador.horaCatedraMedia, puntos: 60, descripcion: 'Hora Cátedra Media (Secundaria)', esHoraCatedra: true, codigoActividad: '001', codigoPuesto: '0102'),
    ItemNomenclador(tipo: TipoNomenclador.horaCatedraTerciaria, puntos: 72, descripcion: 'Hora Cátedra Terciaria', esHoraCatedra: true, codigoActividad: '001', codigoPuesto: '0102'),
    ItemNomenclador(tipo: TipoNomenclador.bibliotecario, puntos: 950, descripcion: 'Bibliotecario', codigoActividad: '001', codigoPuesto: '0104'),
    ItemNomenclador(tipo: TipoNomenclador.profesor, puntos: 1200, descripcion: 'Profesor', codigoActividad: '001', codigoPuesto: '0102'),
    ItemNomenclador(tipo: TipoNomenclador.vicedirector, puntos: 1800, descripcion: 'Vicedirector', codigoActividad: '001', codigoPuesto: '0107'),
    ItemNomenclador(tipo: TipoNomenclador.secretario, puntos: 1300, descripcion: 'Secretario', codigoActividad: '001', codigoPuesto: '0105'),
    ItemNomenclador(tipo: TipoNomenclador.maestroEspecial, puntos: 1250, descripcion: 'Maestro Especial', codigoActividad: '001', codigoPuesto: '0101'),
    ItemNomenclador(tipo: TipoNomenclador.profesorTitular, puntos: 1400, descripcion: 'Profesor Titular', codigoActividad: '001', codigoPuesto: '0102'),
    ItemNomenclador(tipo: TipoNomenclador.profesorAdjunto, puntos: 1200, descripcion: 'Profesor Adjunto', codigoActividad: '001', codigoPuesto: '0102'),
    ItemNomenclador(tipo: TipoNomenclador.jefeTp, puntos: 1100, descripcion: 'Jefe de Trabajos Prácticos', codigoActividad: '001', codigoPuesto: '0102'),
    ItemNomenclador(tipo: TipoNomenclador.ayudante, puntos: 900, descripcion: 'Ayudante', codigoActividad: '001', codigoPuesto: '0102'),
    // --- Personal No Docente (Sueldo Fijo) ---
    ItemNomenclador(tipo: TipoNomenclador.portero, puntos: 0, descripcion: 'Portero / Auxiliar', esSueldoFijo: true, codigoActividad: '001', codigoPuesto: '0108'),
    ItemNomenclador(tipo: TipoNomenclador.maestranzaA, puntos: 0, descripcion: 'Maestranza A', esSueldoFijo: true, codigoActividad: '001', codigoPuesto: '0108'),
    ItemNomenclador(tipo: TipoNomenclador.administrativo, puntos: 0, descripcion: 'Administrativo', esSueldoFijo: true, codigoActividad: '001', codigoPuesto: '0109'),
    ItemNomenclador(tipo: TipoNomenclador.cocinero, puntos: 0, descripcion: 'Cocinero / Ayudante Cocina', esSueldoFijo: true, codigoActividad: '001', codigoPuesto: '0110'),
  ];

  static int puntosPorTipo(TipoNomenclador tipo) {
    final l = items.where((e) => e.tipo == tipo).toList();
    return l.isEmpty ? 1000 : l.first.puntos;
  }

  static ItemNomenclador? itemPorTipo(TipoNomenclador tipo) {
    final l = items.where((e) => e.tipo == tipo).toList();
    return l.isEmpty ? null : l.first;
  }
}

// ---------------------------------------------------------------------------
// 3. ADICIONALES POR ZONA (multiplicadores sobre Básico + Antigüedad)
// ---------------------------------------------------------------------------

class ZonaConstants {
  static const Map<ZonaDesfavorable, double> porcentajePorZona = {
    ZonaDesfavorable.a: 0.0,
    ZonaDesfavorable.b: 20.0,
    ZonaDesfavorable.c: 40.0,
    ZonaDesfavorable.d: 80.0,
    ZonaDesfavorable.e: 110.0, // 100-120%, default 110
  };

  static double porcentaje(ZonaDesfavorable z) => porcentajePorZona[z] ?? 0.0;
}

// ---------------------------------------------------------------------------
// 3b. ADICIONAL POR UBICACIÓN / RURALIDAD (Cascada Bonificable — ítem F)
// % sobre D = (A + B + Antigüedad). Norte: más ubicación; Sur: complementa Zona Patagónica.
// ---------------------------------------------------------------------------

class NivelUbicacionConstants {
  static const Map<NivelUbicacion, double> porcentajePorNivel = {
    NivelUbicacion.urbana: 0.0,
    NivelUbicacion.alejada: 20.0,
    NivelUbicacion.inhospita: 40.0,
    NivelUbicacion.muyInhospita: 60.0,
  };

  static double porcentaje(NivelUbicacion n) => porcentajePorNivel[n] ?? 0.0;
}

// ---------------------------------------------------------------------------
// 4. BASE DE DATOS JURISDICCIONES (Enero 2026) – editables en UI
// ---------------------------------------------------------------------------

class JurisdiccionConfigOmni {
  final Jurisdiccion jurisdiccion;
  final String nombre;
  double valorIndice;
  double pisoSalarial;
  final TipoCajaPrevisional cajaPrevisional;
  double porcentajeAporte;
  final int topeHorasCatedra;
  final bool actualizacionIPC;
  final bool actualizacionPorRecaudacion;
  final bool antiguedadHasta140;
  /// Monto fijo adicional (ej. CABA "Adicional Salarial Ciudad")
  final double? adicionalSalarialCiudadMonto;
  /// % sobre Básico+Antigüedad+Zona (ej. Mendoza "Ítem Aula" 10%)
  final double? itemAulaPorcentaje;
  /// Ej. Córdoba "Estado Docente"
  final bool tieneEstadoDocente;
  final double? estadoDocenteMontoFijo;
  /// Material Didáctico (bonificable, ítem B). Null = no aplica en la jurisdicción.
  final double? materialDidacticoMonto;
  /// Plus Zona Patagónica: % sobre (básico+antigüedad). Neuquén 40%, resto Patagonia 20%. Null = 20.
  final double? plusZonaPatagonicaPorcentaje;
  /// Obra Social: ISSN Neuquén 5.5%; resto 3%. Null = 3.
  final double? porcentajeObraSocial;

  // --- Parámetros recibo Neuquén (Colegio Researchers Potter / Plottier) - estructura exacta ---
  /// Si true: antigüedad = % sobre solo básico (A). Recibo: 20% sobre básico.
  final bool? antiguedadSobreSoloBasico;
  /// Tabla antigüedad override (ej. Neuquén 1-2: 20%). Null = tabla federal.
  final List<RangoAntiguedad>? antiguedadTablaOverride;
  /// Ad. Rem. Bonif. Dto 233/15: % sobre básico. Recibo 2025: 49%.
  final double? dto23315PorcentajeSobreBasico;
  /// Ubicación por Zona: % sobre básico. Recibo: 10%.
  final double? ubicacionZonaPorcentaje;
  /// A5 D335/16: % sobre básico. Recibo 2025: 27.2%.
  final double? a5D33516PorcentajeSobreBasico;
  /// Inc. Docente Ley 25053 comp. FONID (monto por cargo). Recibo 2025: 16450.
  final double? incDocenteLey25053Monto;
  /// Comp. FONID (monto). Recibo 2025: 6397.22.
  final double? compFonidMonto;
  /// IPC sobre ítems FONID (monto). Recibo 2025: 26911.87.
  final double? ipcFonidMonto;
  /// Conectividad nacional - Parit. Nacional (no rem). Recibo 2025: 26674.67.
  final double? conectividadNacionalMonto;
  /// Conectividad provincial Liq. FONID (no rem). Recibo 2025: 72852.89.
  final double? conectividadProvincialMonto;
  /// Dec. Suplementario 137/05: % sobre Total Haberes. Recibo: 2%.
  final double? dec13705Porcentaje;
  /// Redondeo (no rem, opcional). Recibo 2025: 0.90.
  final double? redondeoMonto;

  JurisdiccionConfigOmni({
    required this.jurisdiccion,
    required this.nombre,
    required this.valorIndice,
    required this.pisoSalarial,
    required this.cajaPrevisional,
    required this.porcentajeAporte,
    required this.topeHorasCatedra,
    this.actualizacionIPC = false,
    this.actualizacionPorRecaudacion = false,
    this.antiguedadHasta140 = false,
    this.adicionalSalarialCiudadMonto,
    this.itemAulaPorcentaje,
    this.tieneEstadoDocente = false,
    this.estadoDocenteMontoFijo,
    this.materialDidacticoMonto,
    this.plusZonaPatagonicaPorcentaje,
    this.porcentajeObraSocial,
    this.antiguedadSobreSoloBasico,
    this.antiguedadTablaOverride,
    this.dto23315PorcentajeSobreBasico,
    this.ubicacionZonaPorcentaje,
    this.a5D33516PorcentajeSobreBasico,
    this.incDocenteLey25053Monto,
    this.compFonidMonto,
    this.ipcFonidMonto,
    this.conectividadNacionalMonto,
    this.conectividadProvincialMonto,
    this.dec13705Porcentaje,
    this.redondeoMonto,
  });

  Map<String, dynamic> toJson() {
    return {
      'jurisdiccion': jurisdiccion.name,
      'nombre': nombre,
      'valorIndice': valorIndice,
      'pisoSalarial': pisoSalarial,
      'cajaPrevisional': cajaPrevisional.name,
      'porcentajeAporte': porcentajeAporte,
      'topeHorasCatedra': topeHorasCatedra,
      'actualizacionIPC': actualizacionIPC,
      'actualizacionPorRecaudacion': actualizacionPorRecaudacion,
      'antiguedadHasta140': antiguedadHasta140,
      'adicionalSalarialCiudadMonto': adicionalSalarialCiudadMonto,
      'itemAulaPorcentaje': itemAulaPorcentaje,
      'tieneEstadoDocente': tieneEstadoDocente,
      'estadoDocenteMontoFijo': estadoDocenteMontoFijo,
      'materialDidacticoMonto': materialDidacticoMonto,
      'plusZonaPatagonicaPorcentaje': plusZonaPatagonicaPorcentaje,
      'porcentajeObraSocial': porcentajeObraSocial,
      'antiguedadSobreSoloBasico': antiguedadSobreSoloBasico,
      'antiguedadTablaOverride': antiguedadTablaOverride?.map((r) => r.toJson()).toList(),
      'dto23315PorcentajeSobreBasico': dto23315PorcentajeSobreBasico,
      'ubicacionZonaPorcentaje': ubicacionZonaPorcentaje,
      'a5D33516PorcentajeSobreBasico': a5D33516PorcentajeSobreBasico,
      'incDocenteLey25053Monto': incDocenteLey25053Monto,
      'compFonidMonto': compFonidMonto,
      'ipcFonidMonto': ipcFonidMonto,
      'conectividadNacionalMonto': conectividadNacionalMonto,
      'conectividadProvincialMonto': conectividadProvincialMonto,
      'dec13705Porcentaje': dec13705Porcentaje,
      'redondeoMonto': redondeoMonto,
    };
  }

  factory JurisdiccionConfigOmni.fromJson(Map<String, dynamic> json) {
    return JurisdiccionConfigOmni(
      jurisdiccion: Jurisdiccion.values.firstWhere((j) => j.name == json['jurisdiccion']),
      nombre: json['nombre'],
      valorIndice: (json['valorIndice'] as num).toDouble(),
      pisoSalarial: (json['pisoSalarial'] as num).toDouble(),
      cajaPrevisional: TipoCajaPrevisional.values.firstWhere((c) => c.name == json['cajaPrevisional']),
      porcentajeAporte: (json['porcentajeAporte'] as num).toDouble(),
      topeHorasCatedra: json['topeHorasCatedra'],
      actualizacionIPC: json['actualizacionIPC'],
      actualizacionPorRecaudacion: json['actualizacionPorRecaudacion'],
      antiguedadHasta140: json['antiguedadHasta140'],
      adicionalSalarialCiudadMonto: json['adicionalSalarialCiudadMonto'],
      itemAulaPorcentaje: json['itemAulaPorcentaje'],
      tieneEstadoDocente: json['tieneEstadoDocente'],
      estadoDocenteMontoFijo: json['estadoDocenteMontoFijo'],
      materialDidacticoMonto: json['materialDidacticoMonto'],
      plusZonaPatagonicaPorcentaje: json['plusZonaPatagonicaPorcentaje'],
      porcentajeObraSocial: json['porcentajeObraSocial'],
      antiguedadSobreSoloBasico: json['antiguedadSobreSoloBasico'],
      antiguedadTablaOverride: (json['antiguedadTablaOverride'] as List?)?.map((r) => RangoAntiguedad.fromJson(r)).toList(),
      dto23315PorcentajeSobreBasico: json['dto23315PorcentajeSobreBasico'],
      ubicacionZonaPorcentaje: json['ubicacionZonaPorcentaje'],
      a5D33516PorcentajeSobreBasico: json['a5D33516PorcentajeSobreBasico'],
      incDocenteLey25053Monto: json['incDocenteLey25053Monto'],
      compFonidMonto: json['compFonidMonto'],
      ipcFonidMonto: json['ipcFonidMonto'],
      conectividadNacionalMonto: json['conectividadNacionalMonto'],
      conectividadProvincialMonto: json['conectividadProvincialMonto'],
      dec13705Porcentaje: json['dec13705Porcentaje'],
      redondeoMonto: json['redondeoMonto'],
    );
  }
}

/// Store único de configs por jurisdicción. Editable desde UI.
class JurisdiccionDBOmni {
  static final Map<Jurisdiccion, JurisdiccionConfigOmni> store = _buildInitial();

  static Map<Jurisdiccion, JurisdiccionConfigOmni> _buildInitial() {
    final m = <Jurisdiccion, JurisdiccionConfigOmni>{};
    for (final j in Jurisdiccion.values) {
      final c = _baseMapOmni[j];
      if (c != null) {
        m[j] = JurisdiccionConfigOmni(
        jurisdiccion: c.jurisdiccion,
        nombre: c.nombre,
        valorIndice: c.valorIndice,
        pisoSalarial: c.pisoSalarial,
        cajaPrevisional: c.cajaPrevisional,
        porcentajeAporte: c.porcentajeAporte,
        topeHorasCatedra: c.topeHorasCatedra,
        actualizacionIPC: c.actualizacionIPC,
        actualizacionPorRecaudacion: c.actualizacionPorRecaudacion,
        antiguedadHasta140: c.antiguedadHasta140,
        adicionalSalarialCiudadMonto: c.adicionalSalarialCiudadMonto,
        itemAulaPorcentaje: c.itemAulaPorcentaje,
        tieneEstadoDocente: c.tieneEstadoDocente,
        estadoDocenteMontoFijo: c.estadoDocenteMontoFijo,
        materialDidacticoMonto: c.materialDidacticoMonto,
        plusZonaPatagonicaPorcentaje: c.plusZonaPatagonicaPorcentaje,
        porcentajeObraSocial: c.porcentajeObraSocial,
        antiguedadSobreSoloBasico: c.antiguedadSobreSoloBasico,
        antiguedadTablaOverride: c.antiguedadTablaOverride,
        dto23315PorcentajeSobreBasico: c.dto23315PorcentajeSobreBasico,
        ubicacionZonaPorcentaje: c.ubicacionZonaPorcentaje,
        a5D33516PorcentajeSobreBasico: c.a5D33516PorcentajeSobreBasico,
        incDocenteLey25053Monto: c.incDocenteLey25053Monto,
        compFonidMonto: c.compFonidMonto,
        ipcFonidMonto: c.ipcFonidMonto,
        conectividadNacionalMonto: c.conectividadNacionalMonto,
        conectividadProvincialMonto: c.conectividadProvincialMonto,
        dec13705Porcentaje: c.dec13705Porcentaje,
        redondeoMonto: c.redondeoMonto,
        );
      }
    }
    return m;
  }

  static JurisdiccionConfigOmni? get(Jurisdiccion j) => store[j];
}

final Map<Jurisdiccion, JurisdiccionConfigOmni> _baseMapOmni = {
  Jurisdiccion.buenosAires: JurisdiccionConfigOmni(
    jurisdiccion: Jurisdiccion.buenosAires,
    nombre: 'Buenos Aires (PBA)',
    valorIndice: 220.50,
    pisoSalarial: 745311.0,
    cajaPrevisional: TipoCajaPrevisional.ipsPBA,
    porcentajeAporte: 16.0,
    topeHorasCatedra: 36,
  ),
  Jurisdiccion.caba: JurisdiccionConfigOmni(
    jurisdiccion: Jurisdiccion.caba,
    nombre: 'CABA',
    valorIndice: 215.10,
    pisoSalarial: 745311.0,
    cajaPrevisional: TipoCajaPrevisional.anses,
    porcentajeAporte: 11.0,
    topeHorasCatedra: 36,
    adicionalSalarialCiudadMonto: 12500.0,
  ),
  Jurisdiccion.cordoba: JurisdiccionConfigOmni(
    jurisdiccion: Jurisdiccion.cordoba,
    nombre: 'Córdoba',
    valorIndice: 218.00,
    pisoSalarial: 745311.0,
    cajaPrevisional: TipoCajaPrevisional.ipasCordoba,
    porcentajeAporte: 14.5,
    topeHorasCatedra: 42,
    tieneEstadoDocente: true,
    estadoDocenteMontoFijo: 8000.0,
  ),
  Jurisdiccion.santaFe: JurisdiccionConfigOmni(
    jurisdiccion: Jurisdiccion.santaFe,
    nombre: 'Santa Fe',
    valorIndice: 222.15,
    pisoSalarial: 745311.0,
    cajaPrevisional: TipoCajaPrevisional.ipasSantaFe,
    porcentajeAporte: 14.0,
    topeHorasCatedra: 36,
    actualizacionPorRecaudacion: true,
  ),
  Jurisdiccion.neuquen: JurisdiccionConfigOmni(
    jurisdiccion: Jurisdiccion.neuquen,
    nombre: 'Neuquén',
    valorIndice: 230.00,
    pisoSalarial: 745311.0,
    cajaPrevisional: TipoCajaPrevisional.issn,
    porcentajeAporte: 14.5,
    topeHorasCatedra: 36,
    actualizacionIPC: true,
    antiguedadHasta140: true,
    plusZonaPatagonicaPorcentaje: 40.0,
    porcentajeObraSocial: 5.5,
    // Estructura recibo Plottier/Researchers Potter (exacta). 2026: mismos %; montos FONID/Conect. actualizables por paritaria.
    antiguedadSobreSoloBasico: true,
    antiguedadTablaOverride: const [
      RangoAntiguedad(anosMin: 0, anosMax: 0, porcentaje: 0.0),
      RangoAntiguedad(anosMin: 1, anosMax: 2, porcentaje: 20.0),
      RangoAntiguedad(anosMin: 2, anosMax: 4, porcentaje: 15.0),
      RangoAntiguedad(anosMin: 5, anosMax: 6, porcentaje: 30.0),
      RangoAntiguedad(anosMin: 7, anosMax: 9, porcentaje: 40.0),
      RangoAntiguedad(anosMin: 10, anosMax: 11, porcentaje: 50.0),
      RangoAntiguedad(anosMin: 12, anosMax: 14, porcentaje: 60.0),
      RangoAntiguedad(anosMin: 15, anosMax: 16, porcentaje: 70.0),
      RangoAntiguedad(anosMin: 17, anosMax: 19, porcentaje: 80.0),
      RangoAntiguedad(anosMin: 20, anosMax: 21, porcentaje: 100.0),
      RangoAntiguedad(anosMin: 22, anosMax: 23, porcentaje: 110.0),
      RangoAntiguedad(anosMin: 24, anosMax: 999, porcentaje: 140.0),
    ],
    dto23315PorcentajeSobreBasico: 49.0,
    ubicacionZonaPorcentaje: 10.0,
    a5D33516PorcentajeSobreBasico: 27.2,
    incDocenteLey25053Monto: 16450.0,
    compFonidMonto: 6397.22,
    ipcFonidMonto: 26911.87,
    conectividadNacionalMonto: 26674.67,
    conectividadProvincialMonto: 72852.89,
    dec13705Porcentaje: 2.0,
    redondeoMonto: 0.90,
  ),
  Jurisdiccion.mendoza: JurisdiccionConfigOmni(
    jurisdiccion: Jurisdiccion.mendoza,
    nombre: 'Mendoza',
    valorIndice: 212.00,
    pisoSalarial: 745311.0,
    cajaPrevisional: TipoCajaPrevisional.anses,
    porcentajeAporte: 11.0,
    topeHorasCatedra: 36,
    itemAulaPorcentaje: 10.0,
  ),
  Jurisdiccion.santaCruz: JurisdiccionConfigOmni(
    jurisdiccion: Jurisdiccion.santaCruz,
    nombre: 'Santa Cruz',
    valorIndice: 228.00,
    pisoSalarial: 745311.0,
    cajaPrevisional: TipoCajaPrevisional.anses,
    porcentajeAporte: 11.0,
    topeHorasCatedra: 36,
    antiguedadHasta140: true,
  ),
  Jurisdiccion.catamarca: JurisdiccionConfigOmni(
    jurisdiccion: Jurisdiccion.catamarca,
    nombre: 'Catamarca',
    valorIndice: 208.00,
    pisoSalarial: 745311.0,
    cajaPrevisional: TipoCajaPrevisional.anses,
    porcentajeAporte: 11.0,
    topeHorasCatedra: 36,
  ),
  Jurisdiccion.chaco: JurisdiccionConfigOmni(
    jurisdiccion: Jurisdiccion.chaco,
    nombre: 'Chaco',
    valorIndice: 205.00,
    pisoSalarial: 745311.0,
    cajaPrevisional: TipoCajaPrevisional.anses,
    porcentajeAporte: 11.0,
    topeHorasCatedra: 36,
  ),
  Jurisdiccion.chubut: JurisdiccionConfigOmni(
    jurisdiccion: Jurisdiccion.chubut,
    nombre: 'Chubut',
    valorIndice: 218.00,
    pisoSalarial: 745311.0,
    cajaPrevisional: TipoCajaPrevisional.anses,
    porcentajeAporte: 11.0,
    topeHorasCatedra: 36,
  ),
  Jurisdiccion.corrientes: JurisdiccionConfigOmni(
    jurisdiccion: Jurisdiccion.corrientes,
    nombre: 'Corrientes',
    valorIndice: 206.00,
    pisoSalarial: 745311.0,
    cajaPrevisional: TipoCajaPrevisional.anses,
    porcentajeAporte: 11.0,
    topeHorasCatedra: 36,
  ),
  Jurisdiccion.entreRios: JurisdiccionConfigOmni(
    jurisdiccion: Jurisdiccion.entreRios,
    nombre: 'Entre Ríos',
    valorIndice: 210.00,
    pisoSalarial: 745311.0,
    cajaPrevisional: TipoCajaPrevisional.anses,
    porcentajeAporte: 11.0,
    topeHorasCatedra: 36,
  ),
  Jurisdiccion.formosa: JurisdiccionConfigOmni(
    jurisdiccion: Jurisdiccion.formosa,
    nombre: 'Formosa',
    valorIndice: 202.00,
    pisoSalarial: 745311.0,
    cajaPrevisional: TipoCajaPrevisional.anses,
    porcentajeAporte: 11.0,
    topeHorasCatedra: 36,
  ),
  Jurisdiccion.jujuy: JurisdiccionConfigOmni(
    jurisdiccion: Jurisdiccion.jujuy,
    nombre: 'Jujuy',
    valorIndice: 208.00,
    pisoSalarial: 745311.0,
    cajaPrevisional: TipoCajaPrevisional.anses,
    porcentajeAporte: 11.0,
    topeHorasCatedra: 36,
  ),
  Jurisdiccion.laPampa: JurisdiccionConfigOmni(
    jurisdiccion: Jurisdiccion.laPampa,
    nombre: 'La Pampa',
    valorIndice: 212.00,
    pisoSalarial: 745311.0,
    cajaPrevisional: TipoCajaPrevisional.anses,
    porcentajeAporte: 11.0,
    topeHorasCatedra: 36,
  ),
  Jurisdiccion.laRioja: JurisdiccionConfigOmni(
    jurisdiccion: Jurisdiccion.laRioja,
    nombre: 'La Rioja',
    valorIndice: 207.00,
    pisoSalarial: 745311.0,
    cajaPrevisional: TipoCajaPrevisional.anses,
    porcentajeAporte: 11.0,
    topeHorasCatedra: 36,
  ),
  Jurisdiccion.misiones: JurisdiccionConfigOmni(
    jurisdiccion: Jurisdiccion.misiones,
    nombre: 'Misiones',
    valorIndice: 209.00,
    pisoSalarial: 745311.0,
    cajaPrevisional: TipoCajaPrevisional.anses,
    porcentajeAporte: 11.0,
    topeHorasCatedra: 36,
  ),
  Jurisdiccion.rioNegro: JurisdiccionConfigOmni(
    jurisdiccion: Jurisdiccion.rioNegro,
    nombre: 'Río Negro',
    valorIndice: 216.00,
    pisoSalarial: 745311.0,
    cajaPrevisional: TipoCajaPrevisional.anses, // ANSES 11%
    porcentajeAporte: 11.0,
    topeHorasCatedra: 36,
  ),
  Jurisdiccion.salta: JurisdiccionConfigOmni(
    jurisdiccion: Jurisdiccion.salta,
    nombre: 'Salta',
    valorIndice: 208.00,
    pisoSalarial: 745311.0,
    cajaPrevisional: TipoCajaPrevisional.anses,
    porcentajeAporte: 11.0,
    topeHorasCatedra: 36,
  ),
  Jurisdiccion.sanJuan: JurisdiccionConfigOmni(
    jurisdiccion: Jurisdiccion.sanJuan,
    nombre: 'San Juan',
    valorIndice: 211.00,
    pisoSalarial: 745311.0,
    cajaPrevisional: TipoCajaPrevisional.anses,
    porcentajeAporte: 11.0,
    topeHorasCatedra: 36,
  ),
  Jurisdiccion.sanLuis: JurisdiccionConfigOmni(
    jurisdiccion: Jurisdiccion.sanLuis,
    nombre: 'San Luis',
    valorIndice: 210.00,
    pisoSalarial: 745311.0,
    cajaPrevisional: TipoCajaPrevisional.anses,
    porcentajeAporte: 11.0,
    topeHorasCatedra: 36,
  ),
  Jurisdiccion.santiagoDelEstero: JurisdiccionConfigOmni(
    jurisdiccion: Jurisdiccion.santiagoDelEstero,
    nombre: 'Santiago del Estero',
    valorIndice: 204.00,
    pisoSalarial: 745311.0,
    cajaPrevisional: TipoCajaPrevisional.anses,
    porcentajeAporte: 11.0,
    topeHorasCatedra: 36,
  ),
  Jurisdiccion.tierraDelFuego: JurisdiccionConfigOmni(
    jurisdiccion: Jurisdiccion.tierraDelFuego,
    nombre: 'Tierra del Fuego',
    valorIndice: 235.00,
    pisoSalarial: 745311.0,
    cajaPrevisional: TipoCajaPrevisional.anses,
    porcentajeAporte: 11.0,
    topeHorasCatedra: 36,
  ),
  Jurisdiccion.tucuman: JurisdiccionConfigOmni(
    jurisdiccion: Jurisdiccion.tucuman,
    nombre: 'Tucumán',
    valorIndice: 209.00,
    pisoSalarial: 745311.0,
    cajaPrevisional: TipoCajaPrevisional.anses,
    porcentajeAporte: 11.0,
    topeHorasCatedra: 36,
  ),
};

// ---------------------------------------------------------------------------
// 5. FONID, CONECTIVIDAD, TOPES Y GANANCIAS 2026
// ---------------------------------------------------------------------------

class ParametrosFederales2026Omni {
  static const double smvm = 341000.0;
  static const double topePrevisional = 2500000.0;
  static const double pisoSalarialNacional = 745311.0;
  static const double fonidMonto = 15000.0;
  static const double conectividadMonto = 8000.0;
  static const int topeCargosFonid = 2;
  /// Estado Docente (bonificable): monto por cargo = el mayor entre [estadoDocentePctSobreBasico]% del básico por cargo y [estadoDocenteMontoMinimoPorCargo]. Máx. [topeCargosFonid] cargos. No aplica en hora cátedra.
  static const double estadoDocenteMontoMinimoPorCargo = 85000.0;
  static const double estadoDocentePctSobreBasico = 10.0;

  static const double minimoNoImponibleGanancias = smvm * 15; // 5.115.000
  static const double deduccionPorCargaFamiliar = smvm * 0.5;

  static const double escala1Limite = 2000000.0;
  static const double escala1Porcentaje = 27.0;
  static const double escala2Limite = 5000000.0;
  static const double escala2Porcentaje = 30.0;
  static const double escala3Porcentaje = 35.0;
}
