// ========================================================================
// SANIDAD OMNI ENGINE - Motor de cálculo FATSA CCT 122/75 y 108/75
// Categorías, antigüedad 2%/año, título, tarea crítica/riesgo, deducciones
// Sistema FEDERAL con 24 jurisdicciones - Escalas dinámicas editables
// ========================================================================

import 'sanidad_paritarias_service.dart';

/// Categorías de la actividad sanitaria (FATSA)
enum CategoriaSanidad {
  profesional,
  tecnico,
  servicios,
  administrativo,
  maestranza,
}

/// Nivel de título para adicional
enum NivelTituloSanidad {
  sinTitulo,   // 0%
  auxiliar,    // 5%
  tecnico,     // 7%
  universitario, // 10%
}

/// Ítem del nomenclador Sanidad 2026
class ItemSanidadNomenclador {
  final CategoriaSanidad categoria;
  final double basico;
  final String descripcion;

  const ItemSanidadNomenclador({
    required this.categoria,
    required this.basico,
    required this.descripcion,
  });
}

/// Nomenclador Sanidad 2026 (FATSA CCT 122/75, 108/75) - con soporte para escalas dinámicas
class SanidadNomenclador2026 {
  // Cache de paritarias por jurisdicción
  static final Map<String, ParitariaSanidad> _paritariasCache = {};
  static String _defaultJurisdiccion = 'buenosAires';

  // Items por defecto (fallback)
  static const List<ItemSanidadNomenclador> items = [
    ItemSanidadNomenclador(categoria: CategoriaSanidad.profesional,   basico: 850000.0, descripcion: 'Profesional'),
    ItemSanidadNomenclador(categoria: CategoriaSanidad.tecnico,     basico: 680000.0, descripcion: 'Técnico'),
    ItemSanidadNomenclador(categoria: CategoriaSanidad.servicios,    basico: 580000.0, descripcion: 'Servicios'),
    ItemSanidadNomenclador(categoria: CategoriaSanidad.administrativo, basico: 520000.0, descripcion: 'Administrativo'),
    ItemSanidadNomenclador(categoria: CategoriaSanidad.maestranza,  basico: 480000.0, descripcion: 'Maestranza'),
  ];

  /// Carga las paritarias desde una lista (llamar al iniciar la app)
  static void loadParitariasCache(List<ParitariaSanidad> paritarias) {
    _paritariasCache.clear();
    for (final p in paritarias) {
      _paritariasCache[p.jurisdiccion] = p;
    }
  }

  /// Obtiene la paritaria de una jurisdicción (o genera default si no existe)
  static ParitariaSanidad getParitaria(String? jurisdiccion) {
    final key = jurisdiccion ?? _defaultJurisdiccion;
    if (_paritariasCache.containsKey(key)) {
      return _paritariasCache[key]!;
    }
    
    // Generar default si no está en cache
    final esPatagonica = SanidadParitariasService.jurisdiccionesPatagonicas.contains(key);
    final jInfo = SanidadParitariasService.jurisdicciones.firstWhere(
      (j) => j['key'] == key,
      orElse: () => {'key': key, 'nombre': key},
    );
    
    return esPatagonica
      ? ParitariaSanidad.defaultPatagonica(key, jInfo['nombre']!)
      : ParitariaSanidad.defaultNormal(key, jInfo['nombre']!);
  }

  /// Obtiene básico por categoría, opcionalmente para una jurisdicción específica
  static double basicoPorCategoria(CategoriaSanidad c, {String? jurisdiccion}) {
    final paritaria = getParitaria(jurisdiccion);
    
    switch (c) {
      case CategoriaSanidad.profesional: return paritaria.basicoProfesional;
      case CategoriaSanidad.tecnico: return paritaria.basicoTecnico;
      case CategoriaSanidad.servicios: return paritaria.basicoServicios;
      case CategoriaSanidad.administrativo: return paritaria.basicoAdministrativo;
      case CategoriaSanidad.maestranza: return paritaria.basicoMaestranza;
    }
  }

  /// Obtiene los items del nomenclador para una jurisdicción específica
  static List<ItemSanidadNomenclador> getItemsParaJurisdiccion(String? jurisdiccion) {
    final paritaria = getParitaria(jurisdiccion);
    return [
      ItemSanidadNomenclador(categoria: CategoriaSanidad.profesional, basico: paritaria.basicoProfesional, descripcion: 'Profesional'),
      ItemSanidadNomenclador(categoria: CategoriaSanidad.tecnico, basico: paritaria.basicoTecnico, descripcion: 'Técnico'),
      ItemSanidadNomenclador(categoria: CategoriaSanidad.servicios, basico: paritaria.basicoServicios, descripcion: 'Servicios'),
      ItemSanidadNomenclador(categoria: CategoriaSanidad.administrativo, basico: paritaria.basicoAdministrativo, descripcion: 'Administrativo'),
      ItemSanidadNomenclador(categoria: CategoriaSanidad.maestranza, basico: paritaria.basicoMaestranza, descripcion: 'Maestranza'),
    ];
  }

  static ItemSanidadNomenclador? itemPorCategoria(CategoriaSanidad c) {
    final l = items.where((e) => e.categoria == c).toList();
    return l.isEmpty ? null : l.first;
  }
}

/// Porcentajes de título sobre básico - ahora dinámico por jurisdicción
class PorcentajeTituloSanidad {
  static double porNivel(NivelTituloSanidad n, {String? jurisdiccion}) {
    final paritaria = SanidadNomenclador2026.getParitaria(jurisdiccion);
    
    switch (n) {
      case NivelTituloSanidad.sinTitulo: return 0.0;
      case NivelTituloSanidad.auxiliar: return paritaria.tituloAuxiliarPct;
      case NivelTituloSanidad.tecnico: return paritaria.tituloTecnicoPct;
      case NivelTituloSanidad.universitario: return paritaria.tituloUniversitarioPct;
    }
  }
}

/// Parámetros de deducciones Sanidad - valores por defecto (se pueden override por jurisdicción)
class ParametrosSanidad2026 {
  static const double jubilacionPct = 11.0;
  static const double ley19032Pct = 3.0;
  static const double obraSocialPct = 3.0;
  static const double cuotaSindicalAtsaPct = 2.0;
  static const double seguroSepelioPct = 1.0;
  static const double aporteSolidarioFatsaPct = 1.0; // 1% obligatorio paritarias 2026
  static const double antiguedadPctPorAno = 2.0;
  static const double tareaCriticaRiesgoPct = 10.0;
  static const double topeBasePrevisional = 2500000.0;
  static const double plusZonaPatagonicaPct = 20.0; // 20% sobre básico (Río Negro, Neuquén, Chubut, Santa Cruz, TDF)
}

/// Monto fijo Fallo de Caja 2026 (Administrativo con manejo de efectivo/cobranzas)
const double montoFalloCaja2026 = 20000.0;

/// Modo de liquidación
enum ModoLiquidacionSanidad {
  mensual,      // Liquidación mensual normal
  sac,          // Sueldo Anual Complementario (Aguinaldo)
  vacaciones,   // Liquidación de vacaciones
  liquidacionFinal, // Liquidación final (egreso)
}

/// Input para liquidación Sanidad Omni - COMPLETO ARCA 2026
class SanidadEmpleadoInput {
  final String nombre;
  final String cuil;
  final DateTime fechaIngreso;
  final CategoriaSanidad categoria;
  final NivelTituloSanidad nivelTitulo;
  final bool tareaCriticaRiesgo;
  final bool aplicarCuotaSindicalAtsa;
  final String? codigoRnos;
  final int cantidadFamiliares;
  /// Horas trabajadas en franja nocturna (22 a 6 hs). Fórmula: ((Sueldo Básico/200)*0.15)*horas
  final int horasNocturnas;
  /// Solo aplica si categoría es Administrativo: manejo de efectivo/cobranzas (Fallo de Caja)
  final bool manejoEfectivoCaja;
  
  // === CAMPOS ARCA 2026 OBLIGATORIOS ===
  final String? cbu;
  final String? localidad;
  final String? codigoPostal;
  final String? domicilioEmpleado;
  final String? codigoModalidad;    // 3 dígitos AFIP
  final String? codigoSituacion;    // 2 dígitos AFIP
  final String? codigoActividad;    // 3 dígitos
  final String? codigoPuesto;       // 4 dígitos
  final String? codigoCondicion;    // 2 dígitos
  
  // === HORAS EXTRAS ===
  final double horasExtras50;       // Cantidad de horas al 50%
  final double horasExtras100;      // Cantidad de horas al 100%
  
  // === ADELANTOS Y DESCUENTOS ===
  final double adelantos;
  final double embargos;
  final double prestamos;
  final double otrosDescuentos;
  
  // === CONCEPTOS PROPIOS ===
  final List<Map<String, dynamic>> conceptosPropios;
  
  // === LIQUIDACIÓN FINAL ===
  final DateTime? fechaEgreso;
  final String? motivoEgreso;       // renuncia, despidoSinCausa, despidoConCausa, etc
  final double? mejorRemuneracion;  // Para SAC/Indemnización
  final int? diasSACProporcional;   // Días para SAC proporcional
  final int? diasVacacionesNoGozadas;
  final double? baseIndemnizatoria; // Override para base de indemnización
  final bool incluyePreaviso;
  final bool incluyeIntegracionMes;

  SanidadEmpleadoInput({
    required this.nombre,
    required this.cuil,
    required this.fechaIngreso,
    required this.categoria,
    this.nivelTitulo = NivelTituloSanidad.sinTitulo,
    this.tareaCriticaRiesgo = false,
    this.aplicarCuotaSindicalAtsa = false,
    this.codigoRnos,
    this.cantidadFamiliares = 0,
    this.horasNocturnas = 0,
    this.manejoEfectivoCaja = false,
    // Campos ARCA
    this.cbu,
    this.localidad,
    this.codigoPostal,
    this.domicilioEmpleado,
    this.codigoModalidad,
    this.codigoSituacion,
    this.codigoActividad,
    this.codigoPuesto,
    this.codigoCondicion,
    // Horas extras
    this.horasExtras50 = 0,
    this.horasExtras100 = 0,
    // Descuentos
    this.adelantos = 0,
    this.embargos = 0,
    this.prestamos = 0,
    this.otrosDescuentos = 0,
    // Conceptos propios
    this.conceptosPropios = const [],
    // Liquidación final
    this.fechaEgreso,
    this.motivoEgreso,
    this.mejorRemuneracion,
    this.diasSACProporcional,
    this.diasVacacionesNoGozadas,
    this.baseIndemnizatoria,
    this.incluyePreaviso = false,
    this.incluyeIntegracionMes = false,
  });

  int anosAntiguedad([DateTime? fechaReferencia]) {
    final ref = fechaReferencia ?? DateTime.now();
    int a = ref.year - fechaIngreso.year;
    if (ref.month < fechaIngreso.month ||
        (ref.month == fechaIngreso.month && ref.day < fechaIngreso.day)) {
      a--;
    }
    return a < 0 ? 0 : a;
  }
  
  /// Días de vacaciones según CCT Sanidad por antigüedad
  int diasVacacionesPorAntiguedad() {
    final anos = anosAntiguedad();
    if (anos < 5) return 14;
    if (anos < 10) return 21;
    if (anos < 20) return 28;
    return 35;
  }
  
  /// Calcula días de preaviso según antigüedad
  int diasPreaviso() {
    final anos = anosAntiguedad();
    if (anos < 3 / 12) return 15; // Período de prueba
    if (anos < 5) return 30;
    return 60; // Más de 5 años
  }
}

/// Resultado de liquidación Sanidad Omni - COMPLETO ARCA 2026
class LiquidacionSanidadResult {
  final SanidadEmpleadoInput input;
  final String periodo;
  final String fechaPago;
  final ModoLiquidacionSanidad modo;

  // === HABERES REMUNERATIVOS ===
  final double sueldoBasico;
  final double adicionalAntiguedad;
  final double adicionalTitulo;
  final double adicionalTareaCriticaRiesgo;
  final double adicionalZonaPatagonica;  // Plus Zona Desfavorable 20% (Patagonia)
  final double nocturnidad;               // Horas nocturnas: ((basico/200)*0.15)*horas
  final double falloCaja;                 // Administrativo + manejo efectivo
  
  // === HORAS EXTRAS ===
  final double horasExtras50Monto;        // Monto horas extras 50%
  final double horasExtras100Monto;       // Monto horas extras 100%
  
  // === CONCEPTOS PROPIOS ===
  final List<Map<String, dynamic>> conceptosPropios;
  
  // === SAC (Aguinaldo) ===
  final double sac;                       // SAC completo o proporcional
  final int diasSACCalculados;            // Días base del SAC
  
  // === VACACIONES ===
  final double vacaciones;                // Monto vacaciones
  final double plusVacacional;            // Plus vacacional (si aplica)
  final int diasVacacionesCalculados;
  
  // === LIQUIDACIÓN FINAL ===
  final double indemnizacionArt245;       // Indemnización Art. 245 LCT
  final double preaviso;                  // Preaviso
  final double integracionMes;            // Integración mes de despido
  final double vacacionesNoGozadas;       // Vacaciones no gozadas
  final double sacSobreVacaciones;        // SAC sobre vacaciones no gozadas
  final double sacSobrePreaviso;          // SAC sobre preaviso

  final double totalBrutoRemunerativo;
  final double totalNoRemunerativo;       // Indemnizaciones

  // === DESCUENTOS LEGALES ===
  final double aporteJubilacion;
  final double aporteLey19032;
  final double aporteObraSocial;
  final double cuotaSindicalAtsa;
  final double seguroSepelio;
  final double aporteSolidarioFatsa;      // 1% obligatorio paritarias 2026
  
  // === OTROS DESCUENTOS ===
  final double adelantos;
  final double embargos;
  final double prestamos;
  final double otrosDescuentos;

  final double totalDescuentos;
  final double netoACobrar;
  final double baseImponibleTopeada;
  
  // === DATOS PARA LSD ===
  final String? codigoModalidadLSD;
  final String? codigoSituacionLSD;

  LiquidacionSanidadResult({
    required this.input,
    required this.periodo,
    required this.fechaPago,
    this.modo = ModoLiquidacionSanidad.mensual,
    required this.sueldoBasico,
    required this.adicionalAntiguedad,
    required this.adicionalTitulo,
    required this.adicionalTareaCriticaRiesgo,
    required this.adicionalZonaPatagonica,
    required this.nocturnidad,
    required this.falloCaja,
    this.horasExtras50Monto = 0,
    this.horasExtras100Monto = 0,
    this.conceptosPropios = const [],
    this.sac = 0,
    this.diasSACCalculados = 0,
    this.vacaciones = 0,
    this.plusVacacional = 0,
    this.diasVacacionesCalculados = 0,
    this.indemnizacionArt245 = 0,
    this.preaviso = 0,
    this.integracionMes = 0,
    this.vacacionesNoGozadas = 0,
    this.sacSobreVacaciones = 0,
    this.sacSobrePreaviso = 0,
    required this.totalBrutoRemunerativo,
    this.totalNoRemunerativo = 0,
    required this.aporteJubilacion,
    required this.aporteLey19032,
    required this.aporteObraSocial,
    required this.cuotaSindicalAtsa,
    required this.seguroSepelio,
    required this.aporteSolidarioFatsa,
    this.adelantos = 0,
    this.embargos = 0,
    this.prestamos = 0,
    this.otrosDescuentos = 0,
    required this.totalDescuentos,
    required this.netoACobrar,
    required this.baseImponibleTopeada,
    this.codigoModalidadLSD,
    this.codigoSituacionLSD,
  });
  
  /// Total de horas extras
  double get totalHorasExtras => horasExtras50Monto + horasExtras100Monto;
  
  /// Total de descuentos adicionales (no legales)
  double get totalDescuentosAdicionales => adelantos + embargos + prestamos + otrosDescuentos;
  
  /// Total de conceptos propios (haberes)
  double get totalConceptosPropios {
    double total = 0;
    for (final c in conceptosPropios) {
      if (c['esDescuento'] != true) {
        total += (c['monto'] as num?)?.toDouble() ?? 0;
      }
    }
    return total;
  }
}

/// Motor central Sanidad Omni - Sistema Federal con 24 jurisdicciones
class SanidadOmniEngine {
  // Cache de paritarias cargadas
  static bool _paritariasLoaded = false;

  /// Carga las paritarias desde una lista (llamar al iniciar la app)
  static Future<void> loadParitariasCache() async {
    final paritarias = await SanidadParitariasService.obtenerParitarias();
    SanidadNomenclador2026.loadParitariasCache(paritarias);
    _paritariasLoaded = true;
  }

  /// Verifica si las paritarias están cargadas
  static bool get paritariasLoaded => _paritariasLoaded;

  /// Antigüedad usando porcentaje de la jurisdicción
  static double adicionalAntiguedad(double basico, int anos, {String? jurisdiccion}) {
    if (anos <= 0) return 0.0;
    final paritaria = SanidadNomenclador2026.getParitaria(jurisdiccion);
    final pct = anos * paritaria.antiguedadPctPorAno;
    return basico * (pct / 100);
  }

  /// Título usando porcentaje de la jurisdicción
  static double adicionalTitulo(double basico, NivelTituloSanidad nivel, {String? jurisdiccion}) {
    final pct = PorcentajeTituloSanidad.porNivel(nivel, jurisdiccion: jurisdiccion);
    return basico * (pct / 100);
  }

  /// Tarea Crítica/Riesgo usando porcentaje de la jurisdicción
  static double adicionalTareaCriticaRiesgo(double basico, bool activo, {String? jurisdiccion}) {
    if (!activo) return 0.0;
    final paritaria = SanidadNomenclador2026.getParitaria(jurisdiccion);
    return basico * (paritaria.tareaCriticaRiesgoPct / 100);
  }

  /// Plus Zona Patagónica usando porcentaje de la jurisdicción
  /// Para Sanidad (ATSA), la base incluye Básico + Antigüedad + Título + Tarea Crítica + Nocturnidad + Horas Extras
  static double adicionalZonaPatagonica(double baseCalculo, bool esZonaPatagonica, {String? jurisdiccion}) {
    if (!esZonaPatagonica) return 0.0;
    final paritaria = SanidadNomenclador2026.getParitaria(jurisdiccion);
    return baseCalculo * (paritaria.zonaPatagonicaPct / 100);
  }

  /// Nocturnidad usando porcentaje de la jurisdicción
  static double nocturnidad(double basico, int horas, {String? jurisdiccion}) {
    if (horas <= 0) return 0.0;
    final paritaria = SanidadNomenclador2026.getParitaria(jurisdiccion);
    return ((basico / 200) * (paritaria.nocturnasPct / 100)) * horas;
  }

  /// Fallo de Caja usando monto de la jurisdicción
  static double falloCaja(CategoriaSanidad categoria, bool manejoEfectivoCaja, {String? jurisdiccion}) {
    if (categoria != CategoriaSanidad.administrativo || !manejoEfectivoCaja) return 0.0;
    final paritaria = SanidadNomenclador2026.getParitaria(jurisdiccion);
    return paritaria.montoFalloCaja;
  }

  /// Base topeada usando tope de la jurisdicción
  static double baseTopeada(double bruto, {String? jurisdiccion}) {
    final paritaria = SanidadNomenclador2026.getParitaria(jurisdiccion);
    return bruto > paritaria.topeBasePrevisional
        ? paritaria.topeBasePrevisional
        : bruto;
  }

  // === CÁLCULO HORAS EXTRAS ===
  
  /// Valor hora para horas extras (sueldo / 200 para jornada completa)
  static double valorHora(double sueldoBasico, {int horasSemanales = 48}) {
    final horasMensuales = horasSemanales * 4.33; // Promedio semanal × semanas
    return sueldoBasico / horasMensuales;
  }
  
  /// Horas extras al 50% (días hábiles)
  static double horasExtras50(double sueldoBasico, double cantidadHoras) {
    if (cantidadHoras <= 0) return 0;
    return valorHora(sueldoBasico) * 1.5 * cantidadHoras;
  }
  
  /// Horas extras al 100% (feriados, nocturnos, sábados después 13hs, domingos)
  static double horasExtras100(double sueldoBasico, double cantidadHoras) {
    if (cantidadHoras <= 0) return 0;
    return valorHora(sueldoBasico) * 2.0 * cantidadHoras;
  }
  
  // === CÁLCULO SAC (Aguinaldo) ===
  
  /// SAC semestral completo (50% de la mejor remuneración del semestre)
  static double sacSemestral(double mejorRemuneracionSemestre) {
    return mejorRemuneracionSemestre / 2;
  }
  
  /// SAC proporcional (días trabajados / 180 × mejorRemuneración / 2)
  static double sacProporcional(double mejorRemuneracion, int diasTrabajados) {
    if (diasTrabajados <= 0) return 0;
    return (diasTrabajados / 180) * (mejorRemuneracion / 2);
  }
  
  // === CÁLCULO VACACIONES ===
  
  /// Vacaciones según días y sueldo diario (sueldo / 25)
  static double vacaciones(double sueldoMensual, int diasVacaciones) {
    if (diasVacaciones <= 0) return 0;
    final sueldoDiario = sueldoMensual / 25;
    return sueldoDiario * diasVacaciones;
  }
  
  /// Plus vacacional (10% adicional sobre vacaciones en algunas jurisdicciones)
  static double plusVacacional(double montoVacaciones, double porcentaje) {
    return montoVacaciones * (porcentaje / 100);
  }
  
  // === CÁLCULO LIQUIDACIÓN FINAL ===
  
  /// Indemnización Art. 245 LCT (1 sueldo por año trabajado, tope 3 sueldos SMVM)
  static double indemnizacionArt245(double mejorRemuneracion, int anosAntiguedad, {double? topeSmvm}) {
    if (anosAntiguedad <= 0) return 0;
    final tope = topeSmvm ?? (mejorRemuneracion * 3); // Tope = 3 veces SMVM o sueldo
    final base = mejorRemuneracion > tope ? tope : mejorRemuneracion;
    return base * anosAntiguedad;
  }
  
  /// Preaviso (1 o 2 meses según antigüedad)
  static double preaviso(double sueldoMensual, int anosAntiguedad) {
    if (anosAntiguedad < 5) return sueldoMensual; // 1 mes
    return sueldoMensual * 2; // 2 meses
  }
  
  /// Integración mes de despido (días restantes del mes)
  static double integracionMes(double sueldoMensual, int diasRestantes) {
    if (diasRestantes <= 0) return 0;
    return (sueldoMensual / 30) * diasRestantes;
  }

  /// Liquida empleado de sanidad usando todas las escalas de la jurisdicción
  /// [jurisdiccion] clave de la jurisdicción (ej: 'buenosAires', 'neuquen')
  /// [esZonaPatagonica] se detecta automáticamente si no se especifica
  /// [modo] tipo de liquidación: mensual, sac, vacaciones, liquidacionFinal
  static LiquidacionSanidadResult liquidar(
    SanidadEmpleadoInput input, {
    required String periodo,
    required String fechaPago,
    double? basicoOverride,
    bool? esZonaPatagonica,
    String? jurisdiccion,
    ModoLiquidacionSanidad modo = ModoLiquidacionSanidad.mensual,
  }) {
    // Determinar jurisdicción
    final jur = jurisdiccion ?? 'buenosAires';
    final paritaria = SanidadNomenclador2026.getParitaria(jur);
    
    // Obtener básico: prioridad override > paritaria jurisdicción
    final basico = basicoOverride ?? SanidadNomenclador2026.basicoPorCategoria(input.categoria, jurisdiccion: jur);
    final anos = input.anosAntiguedad();

    // Calcular adicionales usando la jurisdicción
    final antig = adicionalAntiguedad(basico, anos, jurisdiccion: jur);
    final titulo = adicionalTitulo(basico, input.nivelTitulo, jurisdiccion: jur);
    final tareaCrit = adicionalTareaCriticaRiesgo(basico, input.tareaCriticaRiesgo, jurisdiccion: jur);
    final noct = nocturnidad(basico, input.horasNocturnas, jurisdiccion: jur);
    
    // === HORAS EXTRAS ===
    final horas50 = horasExtras50(basico, input.horasExtras50);
    final horas100 = horasExtras100(basico, input.horasExtras100);
    
    // Zona patagónica: para Sanidad (ATSA), la base incluye Básico + Antigüedad + Título + Tarea Crítica + Nocturnidad + Horas Extras
    final esPatagonica = esZonaPatagonica ?? SanidadParitariasService.jurisdiccionesPatagonicas.contains(jur);
    final baseZona = basico + antig + titulo + tareaCrit + noct + horas50 + horas100;
    final plusPatagonia = adicionalZonaPatagonica(baseZona, esPatagonica, jurisdiccion: jur);
    
    final fallo = falloCaja(input.categoria, input.manejoEfectivoCaja, jurisdiccion: jur);
    
    // === CONCEPTOS PROPIOS (haberes) ===
    double totalConceptosPropios = 0;
    for (final c in input.conceptosPropios) {
      if (c['esDescuento'] != true) {
        totalConceptosPropios += (c['monto'] as num?)?.toDouble() ?? 0;
      }
    }

    // Base para cálculos (sueldo mensual completo)
    final sueldoMensualCompleto = basico + antig + titulo + tareaCrit + plusPatagonia + noct + fallo + horas50 + horas100 + totalConceptosPropios;
    final mejorRem = input.mejorRemuneracion ?? sueldoMensualCompleto;
    
    // === VARIABLES DE LIQUIDACIÓN ESPECIAL ===
    double montoSAC = 0;
    int diasSAC = 0;
    double montoVacaciones = 0;
    double montoPlusVacacional = 0;
    int diasVac = 0;
    double montoIndemnizacion = 0;
    double montoPreaviso = 0;
    double montoIntegracion = 0;
    double montoVacNoGozadas = 0;
    double sacSobreVac = 0;
    double sacSobrePreav = 0;
    double totalNoRem = 0;
    
    // Calcular según modo de liquidación
    switch (modo) {
      case ModoLiquidacionSanidad.sac:
        diasSAC = input.diasSACProporcional ?? 180;
        montoSAC = diasSAC >= 180 
            ? sacSemestral(mejorRem) 
            : sacProporcional(mejorRem, diasSAC);
        break;
        
      case ModoLiquidacionSanidad.vacaciones:
        diasVac = input.diasVacacionesNoGozadas ?? input.diasVacacionesPorAntiguedad();
        montoVacaciones = vacaciones(sueldoMensualCompleto, diasVac);
        montoPlusVacacional = plusVacacional(montoVacaciones, 10); // 10% plus vacacional
        break;
        
      case ModoLiquidacionSanidad.liquidacionFinal:
        // SAC proporcional
        diasSAC = input.diasSACProporcional ?? _calcularDiasSACProporcional(input.fechaEgreso);
        montoSAC = sacProporcional(mejorRem, diasSAC);
        
        // Vacaciones no gozadas
        diasVac = input.diasVacacionesNoGozadas ?? input.diasVacacionesPorAntiguedad();
        montoVacNoGozadas = vacaciones(sueldoMensualCompleto, diasVac);
        sacSobreVac = montoVacNoGozadas / 12; // SAC sobre vacaciones
        
        // Indemnización según motivo
        if (input.motivoEgreso == 'despidoSinCausa' || input.motivoEgreso == 'despido_sin_causa') {
          final baseIndem = input.baseIndemnizatoria ?? mejorRem;
          montoIndemnizacion = indemnizacionArt245(baseIndem, anos > 0 ? anos : 1);
          
          if (input.incluyePreaviso) {
            montoPreaviso = preaviso(sueldoMensualCompleto, anos);
            sacSobrePreav = montoPreaviso / 12;
          }
          
          if (input.incluyeIntegracionMes && input.fechaEgreso != null) {
            final diasRestantes = 30 - input.fechaEgreso!.day;
            montoIntegracion = integracionMes(sueldoMensualCompleto, diasRestantes);
          }
        }
        
        totalNoRem = montoIndemnizacion + montoPreaviso + montoIntegracion;
        break;
        
      case ModoLiquidacionSanidad.mensual:
        // Liquidación mensual normal - no hay cálculos adicionales
        break;
    }

    // Total bruto remunerativo
    double totalBruto = sueldoMensualCompleto + montoSAC + montoVacaciones + montoPlusVacacional + montoVacNoGozadas + sacSobreVac + sacSobrePreav;
    
    // Base imponible
    final base = baseTopeada(totalBruto, jurisdiccion: jur);

    // Calcular descuentos legales usando porcentajes de la jurisdicción
    final jub = base * (paritaria.jubilacionPct / 100);
    final ley19032 = base * (paritaria.ley19032Pct / 100);
    final os = base * (paritaria.obraSocialPct / 100);
    final cuotaAtsa = input.aplicarCuotaSindicalAtsa
        ? base * (paritaria.cuotaSindicalAtsaPct / 100)
        : 0.0;
    final sepelio = base * (paritaria.seguroSepelioPct / 100);
    final aporteSolidario = base * (paritaria.aporteSolidarioFatsaPct / 100);

    // Descuentos adicionales
    final descAdelantos = input.adelantos;
    final descEmbargos = input.embargos;
    final descPrestamos = input.prestamos;
    final descOtros = input.otrosDescuentos;
    
    // Descuentos de conceptos propios
    double descConceptosPropios = 0;
    for (final c in input.conceptosPropios) {
      if (c['esDescuento'] == true) {
        descConceptosPropios += (c['monto'] as num?)?.toDouble() ?? 0;
      }
    }

    final totalDescLegales = jub + ley19032 + os + cuotaAtsa + sepelio + aporteSolidario;
    final totalDescAdicionales = descAdelantos + descEmbargos + descPrestamos + descOtros + descConceptosPropios;
    final totalDesc = totalDescLegales + totalDescAdicionales;
    
    final neto = totalBruto + totalNoRem - totalDesc;

    return LiquidacionSanidadResult(
      input: input,
      periodo: periodo,
      fechaPago: fechaPago,
      modo: modo,
      sueldoBasico: basico,
      adicionalAntiguedad: antig,
      adicionalTitulo: titulo,
      adicionalTareaCriticaRiesgo: tareaCrit,
      adicionalZonaPatagonica: plusPatagonia,
      nocturnidad: noct,
      falloCaja: fallo,
      horasExtras50Monto: horas50,
      horasExtras100Monto: horas100,
      conceptosPropios: input.conceptosPropios,
      sac: montoSAC,
      diasSACCalculados: diasSAC,
      vacaciones: montoVacaciones,
      plusVacacional: montoPlusVacacional,
      diasVacacionesCalculados: diasVac,
      indemnizacionArt245: montoIndemnizacion,
      preaviso: montoPreaviso,
      integracionMes: montoIntegracion,
      vacacionesNoGozadas: montoVacNoGozadas,
      sacSobreVacaciones: sacSobreVac,
      sacSobrePreaviso: sacSobrePreav,
      totalBrutoRemunerativo: totalBruto,
      totalNoRemunerativo: totalNoRem,
      aporteJubilacion: jub,
      aporteLey19032: ley19032,
      aporteObraSocial: os,
      cuotaSindicalAtsa: cuotaAtsa,
      seguroSepelio: sepelio,
      aporteSolidarioFatsa: aporteSolidario,
      adelantos: descAdelantos,
      embargos: descEmbargos,
      prestamos: descPrestamos,
      otrosDescuentos: descOtros + descConceptosPropios,
      totalDescuentos: totalDesc,
      netoACobrar: neto,
      baseImponibleTopeada: base,
      codigoModalidadLSD: input.codigoModalidad ?? '008',
      codigoSituacionLSD: input.codigoSituacion ?? '01',
    );
  }
  
  /// Calcula días SAC proporcional desde inicio del semestre hasta fecha de egreso
  static int _calcularDiasSACProporcional(DateTime? fechaEgreso) {
    if (fechaEgreso == null) return 0;
    final mes = fechaEgreso.month;
    final inicioSemestre = mes <= 6 
        ? DateTime(fechaEgreso.year, 1, 1)
        : DateTime(fechaEgreso.year, 7, 1);
    return fechaEgreso.difference(inicioSemestre).inDays + 1;
  }
}
