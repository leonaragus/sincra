// ========================================================================
// COSTO EMPLEADOR - Contribuciones patronales (informativo, no afecta recibo)
// Seguridad Social 24%, Obra Social 6%, ART editable, SVO fijo
// ========================================================================

/// Monto fijo Seguro de Vida Obligatorio por empleado (estimado 2026)
const double svoMonto2026 = 1200.0;

/// Cuota fija ART por defecto (estimado 2026)
const double artCuotaFijaDefault2026 = 800.0;

/// Porcentaje ART por defecto sobre bruto (según siniestralidad)
const double artPctDefault = 3.5;

/// Contribuciones Seguridad Social: Jubilación, Asignaciones, PAMI, Fondo Nacional de Empleo
const double pctSeguridadSocial = 24.0;

/// Contribuciones Obra Social patronal
const double pctObraSocialPatronal = 6.0;

/// Total contribuciones patronales (24 + 6)
const double pctContribucionesPatronales = 30.0;

/// Provisión SAC (Aguinaldo): 1/12 del bruto ≈ 8,33%
const double pctProvisionSac = 100 / 12;

/// Provisión Vacaciones: ~4% del bruto (reserva legal promedio)
const double pctProvisionVacaciones = 4.0;

/// Cargas sociales sobre SAC y Vacaciones al abonarlos (~30%)
const double pctCargasSobreProvisiones = 30.0;

/// Resultado del cálculo de costo total para el empleador (incluye provisiones LCT)
class CostoEmpleadorResult {
  final double sueldoBruto;
  final double contribucionesSeguridadSocial;
  final double contribucionesObraSocial;
  final double contribucionesPatronalesTotal;
  final double art;
  final double svo;
  final double artYSeguros;
  final double totalCostoLaboral;
  final double provisionSAC;
  final double provisionVacaciones;
  final double provisionSACYVacaciones;
  final double cargasSocialesSobreProvisiones;
  final double totalCostoLaboralReal;

  CostoEmpleadorResult({
    required this.sueldoBruto,
    required this.contribucionesSeguridadSocial,
    required this.contribucionesObraSocial,
    required this.contribucionesPatronalesTotal,
    required this.art,
    required this.svo,
    required this.artYSeguros,
    required this.totalCostoLaboral,
    required this.provisionSAC,
    required this.provisionVacaciones,
    required this.provisionSACYVacaciones,
    required this.cargasSocialesSobreProvisiones,
    required this.totalCostoLaboralReal,
  });
}

/// Calcula el costo total para el empleador (contribuciones patronales, ART, SVO).
/// [bruto] Sueldo bruto remunerativo del empleado.
/// [artPct] Porcentaje ART sobre bruto (por siniestralidad). Default 3.5.
/// [artCuotaFija] Cuota fija ART. Default 800.
CostoEmpleadorResult calcularCostoPatronal(
  double bruto, {
  double artPct = artPctDefault,
  double artCuotaFija = artCuotaFijaDefault2026,
}) {
  final segSoc = bruto * (pctSeguridadSocial / 100);
  final osPat = bruto * (pctObraSocialPatronal / 100);
  final contribPatronal = segSoc + osPat;

  final art = (bruto * (artPct / 100)) + artCuotaFija;
  const svo = svoMonto2026;
  final artYSeg = art + svo;

  final total = bruto + contribPatronal + artYSeg;

  // Provisiones legales LCT: SAC (1/12) y Vacaciones (~4%)
  final provSAC = bruto * (pctProvisionSac / 100);
  final provVac = bruto * (pctProvisionVacaciones / 100);
  final provSACYVac = provSAC + provVac;
  final cargasSobreProv = provSACYVac * (pctCargasSobreProvisiones / 100);
  final totalReal = total + provSACYVac + cargasSobreProv;

  return CostoEmpleadorResult(
    sueldoBruto: bruto,
    contribucionesSeguridadSocial: segSoc,
    contribucionesObraSocial: osPat,
    contribucionesPatronalesTotal: contribPatronal,
    art: art,
    svo: svo,
    artYSeguros: artYSeg,
    totalCostoLaboral: total,
    provisionSAC: provSAC,
    provisionVacaciones: provVac,
    provisionSACYVacaciones: provSACYVac,
    cargasSocialesSobreProvisiones: cargasSobreProv,
    totalCostoLaboralReal: totalReal,
  );
}

/// Genera texto para el informe de costos (exportar para el dueño)
String generarInformeCostosTxt({
  required String empleado,
  required String cuil,
  required String institucion,
  required String periodo,
  required CostoEmpleadorResult costo,
  required String convenio,
}) {
  final sb = StringBuffer();
  sb.writeln('INFORME DE COSTO LABORAL - SOLO PARA LA EMPRESA');
  sb.writeln('================================================');
  sb.writeln('Fecha: ${DateTime.now().day.toString().padLeft(2, '0')}/${DateTime.now().month.toString().padLeft(2, '0')}/${DateTime.now().year}');
  sb.writeln('Convenio: $convenio');
  sb.writeln('');
  sb.writeln('Empleado: $empleado');
  sb.writeln('CUIL: $cuil');
  sb.writeln('Institución: $institucion');
  sb.writeln('Período: $periodo');
  sb.writeln('');
  sb.writeln('--- DESGLOSE DE COSTO EMPLEADOR ---');
  sb.writeln('Sueldo Bruto: \$${costo.sueldoBruto.toStringAsFixed(2)}');
  sb.writeln('Contribuciones Patronales (30%): \$${costo.contribucionesPatronalesTotal.toStringAsFixed(2)}');
  sb.writeln('  - Seguridad Social (24%): \$${costo.contribucionesSeguridadSocial.toStringAsFixed(2)}');
  sb.writeln('  - Obra Social (6%): \$${costo.contribucionesObraSocial.toStringAsFixed(2)}');
  sb.writeln('ART y Seguros: \$${costo.artYSeguros.toStringAsFixed(2)}');
  sb.writeln('  - ART: \$${costo.art.toStringAsFixed(2)}');
  sb.writeln('  - SVO: \$${costo.svo.toStringAsFixed(2)}');
  sb.writeln('');
  sb.writeln('--- PROVISIÓN LEGAL SAC Y VACACIONES (LCT) ---');
  sb.writeln('Provisión SAC y Vacaciones: \$${costo.provisionSACYVacaciones.toStringAsFixed(2)}');
  sb.writeln('  - SAC (8,33%): \$${costo.provisionSAC.toStringAsFixed(2)}');
  sb.writeln('  - Vacaciones (4%): \$${costo.provisionVacaciones.toStringAsFixed(2)}');
  sb.writeln('Cargas Sociales s/ Provisiones (30%): \$${costo.cargasSocialesSobreProvisiones.toStringAsFixed(2)}');
  sb.writeln('');
  sb.writeln('TOTAL COSTO LABORAL REAL: \$${costo.totalCostoLaboralReal.toStringAsFixed(2)}');
  sb.writeln('');
  sb.writeln('(El Costo Laboral Real incluye la reserva mensual para Aguinaldo y Vacaciones y sus cargas patronales. Este informe no integra el LSD ni el recibo del empleado.)');
  return sb.toString();
}
