// ========================================================================
// SISTEMA FEDERAL DE LIQUIDACIÓN DOCENTE ARGENTINA 2026
// Módulo Independiente - No hereda lógica de convenios previos
// ========================================================================

/// Enum para las 24 jurisdicciones (23 provincias + CABA)
enum Jurisdiccion {
  buenosAires,      // Provincia de Buenos Aires
  caba,             // Ciudad Autónoma de Buenos Aires
  catamarca,
  chaco,
  chubut,
  cordoba,
  corrientes,
  entreRios,
  formosa,
  jujuy,
  laPampa,
  laRioja,
  mendoza,
  misiones,
  neuquen,
  rioNegro,
  salta,
  sanJuan,
  sanLuis,
  santaCruz,
  santaFe,
  santiagoDelEstero,
  tierraDelFuego,
  tucuman,
}

/// Tipo de gestión (pública o privada)
enum TipoGestion {
  publica,
  privada,
}

/// Régimen previsional de la institución (Nacional/Provincial)
enum RegimenPrevisional {
  nacional,
  provincial,
}

/// Tipo de caja previsional
enum TipoCajaPrevisional {
  anses,           // ANSES (11%) — Nación, Río Negro, etc.
  ipsPBA,          // IPS PBA (16%)
  ipasCordoba,     // IPAS Córdoba (14.5%)
  ipasSantaFe,     // IPAS Santa Fe
  issn,            // ISSN Neuquén (14.5% Jubilación)
  cajaProvincial,  // Otras cajas provinciales
}

/// Adicional por Ubicación / Ruralidad (base para Plus Ubicación en cascada).
/// Aplica % sobre D = (A + B + Antigüedad). En el norte más ubicación; en el sur complementa Zona Patagónica.
enum NivelUbicacion {
  urbana,    // 0%
  alejada,   // 20%
  inhospita, // 40%
  muyInhospita, // 60% — opcional
}

/// Nivel educativo
enum NivelEducativo {
  inicial,
  primario,
  secundario,
  terciario,
  superior,
}

/// Tipo de cargo docente
enum TipoCargo {
  maestroGrado,           // Maestro de Grado (Primario)
  profesor,              // Profesor (Secundario/Terciario)
  director,              // Director
  vicedirector,          // Vicedirector
  secretario,            // Secretario
  preceptor,             // Preceptor
  bibliotecario,         // Bibliotecario
  maestroEspecial,       // Maestro Especial
  profesorTitular,       // Profesor Titular
  profesorAdjunto,       // Profesor Adjunto
  jefeTrabajosPracticos, // Jefe de Trabajos Prácticos
  ayudante,              // Ayudante
}

/// Zona desfavorable (multiplicador sobre Básico + Antigüedad)
enum ZonaDesfavorable {
  a,   // Normal 0%
  b,   // 20%
  c,   // 40%
  d,   // Muy desfavorable 80%
  e,   // Frontera/Inhóspita 100%-120%
}

/// Tipo nomenclador Omni (puntos por cargo / hora cátedra)
enum TipoNomenclador {
  maestroGrado,
  directorPrimera,
  maestroNivelInicial,
  preceptor,
  horaCatedraMedia,
  horaCatedraTerciaria,
  bibliotecario,
  profesor,
  vicedirector,
  secretario,
  maestroEspecial,
  profesorTitular,
  profesorAdjunto,
  jefeTp,
  ayudante,
  // --- Personal No Docente ---
  portero,
  maestranzaA,
  maestranzaB,
  administrativo,
  cocinero,
}

/// Configuración de una jurisdicción
class ConfiguracionJurisdiccion {
  final Jurisdiccion jurisdiccion;
  final String nombre;
  final double valorIndice; // Valor del índice actualizable
  final double minimoGarantizado; // Mínimo garantizado
  final TipoCajaPrevisional cajaPrevisional;
  final double porcentajeAporte; // Porcentaje de aporte a la caja
  final int topeHorasCatedra; // Tope de horas cátedra (36 o 42)
  final bool actualizacionIPC; // Si tiene actualización por IPC (ej. Neuquén)
  final double? ultimoAumentoParitario; // Último aumento paritario (ej. PBA 4.5%)
  final DateTime? fechaUltimoAumento; // Fecha del último aumento

  ConfiguracionJurisdiccion({
    required this.jurisdiccion,
    required this.nombre,
    required this.valorIndice,
    required this.minimoGarantizado,
    required this.cajaPrevisional,
    required this.porcentajeAporte,
    required this.topeHorasCatedra,
    this.actualizacionIPC = false,
    this.ultimoAumentoParitario,
    this.fechaUltimoAumento,
  });
}

/// Nomenclador de puntos por cargo
class NomencladorPuntos {
  final TipoCargo cargo;
  final int puntos;
  final String descripcion;

  NomencladorPuntos({
    required this.cargo,
    required this.puntos,
    required this.descripcion,
  });
}

/// Escalafón de antigüedad docente
/// Tabla de saltos: 0-1 (0%), 2-4 (15%), 5-6 (30%), 7-9 (40%), 
/// 10-11 (50%), 12-14 (60%), 15-16 (70%), 17-19 (80%), 
/// 20-21 (100%), 22-23 (110%), 24+ (120%)
class EscalafonAntiguedad {
  static double calcularPorcentajeAntiguedad(int anosAntiguedad) {
    if (anosAntiguedad <= 1) return 0.0;
    if (anosAntiguedad >= 2 && anosAntiguedad <= 4) return 15.0;
    if (anosAntiguedad >= 5 && anosAntiguedad <= 6) return 30.0;
    if (anosAntiguedad >= 7 && anosAntiguedad <= 9) return 40.0;
    if (anosAntiguedad >= 10 && anosAntiguedad <= 11) return 50.0;
    if (anosAntiguedad >= 12 && anosAntiguedad <= 14) return 60.0;
    if (anosAntiguedad >= 15 && anosAntiguedad <= 16) return 70.0;
    if (anosAntiguedad >= 17 && anosAntiguedad <= 19) return 80.0;
    if (anosAntiguedad >= 20 && anosAntiguedad <= 21) return 100.0;
    if (anosAntiguedad >= 22 && anosAntiguedad <= 23) return 110.0;
    if (anosAntiguedad >= 24) return 120.0;
    return 0.0;
  }
}

/// Datos del docente
class Docente {
  final String nombre;
  final String cuil;
  final Jurisdiccion jurisdiccion;
  final TipoGestion tipoGestion;
  final TipoCargo cargo;
  final NivelEducativo nivelEducativo;
  final DateTime fechaIngreso;
  final int cargasFamiliares; // Para cálculo de Ganancias
  final String? codigoRnos; // Código RNOS obra social
  final int horasCatedra; // Horas cátedra (para secundario/terciario)
  final int puntosCargo; // Puntos del cargo según nomenclador
  final double? aporteEstatal; // Porcentaje de aporte estatal (0-100) para gestión privada

  Docente({
    required this.nombre,
    required this.cuil,
    required this.jurisdiccion,
    required this.tipoGestion,
    required this.cargo,
    required this.nivelEducativo,
    required this.fechaIngreso,
    this.cargasFamiliares = 0,
    this.codigoRnos,
    this.horasCatedra = 0,
    this.puntosCargo = 0,
    this.aporteEstatal,
  });

  /// Calcula los años de antigüedad desde la fecha de ingreso
  int calcularAnosAntiguedad() {
    final ahora = DateTime.now();
    int anos = ahora.year - fechaIngreso.year;
    if (ahora.month < fechaIngreso.month ||
        (ahora.month == fechaIngreso.month && ahora.day < fechaIngreso.day)) {
      anos--;
    }
    return anos < 0 ? 0 : anos;
  }
}

/// Conceptos de liquidación docente
class ConceptoDocente {
  final String codigo;
  final String descripcion;
  final double monto;
  final bool esRemunerativo;
  final String codigoAfip;

  ConceptoDocente({
    required this.codigo,
    required this.descripcion,
    required this.monto,
    required this.esRemunerativo,
    required this.codigoAfip,
  });
}

/// Resultado de la liquidación docente
class LiquidacionDocente {
  final Docente docente;
  final String periodo;
  final String fechaPago;
  final ConfiguracionJurisdiccion configuracion;
  
  // Haberes
  final double sueldoBasico;
  final double adicionalAntiguedad;
  final double fonid;
  final double conectividad;
  final double horasCatedra;
  final double equiparacionSalarial; // Solo para gestión privada
  final Map<String, ConceptoDocente> conceptosAdicionales;
  
  // Descuentos
  final double aporteJubilacion;
  final double aporteObraSocial;
  final double aportePami;
  final double impuestoGanancias;
  final Map<String, double> deduccionesAdicionales;
  
  // Totales
  final double totalBruto;
  final double totalDescuentos;
  final double totalNoRemunerativo;
  final double netoACobrar;
  
  // Base imponible
  final double baseImponible;
  
  // Información legal
  final String bloqueArt12Ley17250; // Bloque Art. 12 Ley 17.250

  LiquidacionDocente({
    required this.docente,
    required this.periodo,
    required this.fechaPago,
    required this.configuracion,
    required this.sueldoBasico,
    required this.adicionalAntiguedad,
    required this.fonid,
    required this.conectividad,
    required this.horasCatedra,
    required this.equiparacionSalarial,
    required this.conceptosAdicionales,
    required this.aporteJubilacion,
    required this.aporteObraSocial,
    required this.aportePami,
    required this.impuestoGanancias,
    required this.deduccionesAdicionales,
    required this.totalBruto,
    required this.totalDescuentos,
    required this.totalNoRemunerativo,
    required this.netoACobrar,
    required this.baseImponible,
    required this.bloqueArt12Ley17250,
  });
}

/// Parámetros federales Enero 2026
class ParametrosFederales2026 {
  // Piso Salarial Nacional
  static const double pisoSalarialNacional = 745311.0; // Cargo testigo 20hs sin antigüedad
  
  // FONID y Conectividad (montos fijos nacionales)
  static const double fonidMonto = 15000.0; // Proyectado 2026
  static const double conectividadMonto = 8000.0; // Proyectado 2026
  static const int topeCargosFonid = 2; // Tope de 2 cargos para FONID
  
  // SMVM Enero 2026
  static const double smvm = 341000.0;
  
  // Base imponible mínima para Ganancias
  static const double baseImponibleMinimaGanancias = smvm;
  
  // Mínimo no imponible Ganancias (4ta Categoría)
  static const double minimoNoImponibleGanancias = smvm * 15; // $5.115.000
  
  // Escalas Impuesto a las Ganancias 2026 (Primer Semestre)
  static const double escala1Limite = 2000000.0;
  static const double escala1Porcentaje = 27.0;
  static const double escala2Limite = 5000000.0;
  static const double escala2Porcentaje = 30.0;
  static const double escala3Porcentaje = 35.0;
  
  // Deducciones por cargas familiares (2026)
  static const double deduccionPorCargaFamiliar = smvm * 0.5; // 0.5 SMVM por carga
  
  // TOPE PREVISIONAL BASE (Enero 2026)
  static const double topePrevisional = 2500000.0;
}

/// Nomenclador federal de puntos (valores de ejemplo - ajustar según jurisdicción)
class NomencladorFederal {
  static final Map<TipoCargo, int> puntosPorCargo = {
    TipoCargo.maestroGrado: 1100,
    TipoCargo.profesor: 1200,
    TipoCargo.director: 1800,
    TipoCargo.vicedirector: 1500,
    TipoCargo.secretario: 1300,
    TipoCargo.preceptor: 1000,
    TipoCargo.bibliotecario: 1150,
    TipoCargo.maestroEspecial: 1250,
    TipoCargo.profesorTitular: 1400,
    TipoCargo.profesorAdjunto: 1200,
    TipoCargo.jefeTrabajosPracticos: 1100,
    TipoCargo.ayudante: 900,
  };
  
  static int obtenerPuntos(TipoCargo cargo) {
    return puntosPorCargo[cargo] ?? 1000;
  }
}
