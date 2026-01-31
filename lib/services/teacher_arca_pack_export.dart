// ========================================================================
// TEACHER ARCA PACK EXPORT - Pack Completo ARCA 2026 (Guía 4 Docentes)
// MD_Conceptos.txt, Liquidacion.txt, Recibo TXT. ISO-8859-1, \r\n.
// ========================================================================

import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import '../models/teacher_types.dart';
import 'teacher_omni_engine.dart';
import 'teacher_lsd_export.dart';
import 'lsd_engine.dart';
import 'costo_empleador_service.dart';

const String _eol = '\r\n';

/// Resultado de la simulación de estrés Neuquén (Enero 2026) para mostrar y exportar.
class PackNeuquenEstresContenidos {
  final String conceptosTxt;
  final String liquidacionLsdTxt;
  final String reciboOficialTxt;
  final LiquidacionOmniResult liquidacion;

  PackNeuquenEstresContenidos({
    required this.conceptosTxt,
    required this.liquidacionLsdTxt,
    required this.reciboOficialTxt,
    required this.liquidacion,
  });
}

/// Caso de prueba real: Neuquén, ISSN 14.5%, Escuela Privada CUIT 30-12345678-9,
/// Maestra de Grado 2 cargos, 3 años, Ubicación 20% (Alejada), Valor Índice 450.1234.
/// ISO-8859-1 y \\r\\n. Retorna los 3 contenidos para Conceptos_ARCA, Liquidacion_LSD, Recibo_Oficial.
Future<PackNeuquenEstresContenidos> generarContenidosPackNeuquenEstres() async {
  const cuitEmpresa = '30123456789';
  const razonSocial = 'Escuela Privada Neuquen';
  const domicilio = 'Av. Argentina 100, Neuquen';

  final input = DocenteOmniInput(
    nombre: 'Maria Garcia',
    cuil: '27-22233344-9',
    jurisdiccion: Jurisdiccion.neuquen,
    tipoGestion: TipoGestion.privada,
    cargoNomenclador: TipoNomenclador.maestroGrado,
    nivelEducativo: NivelEducativo.primario,
    fechaIngreso: DateTime(2023, 1, 15),
    cargasFamiliares: 0,
    horasCatedra: 0,
    zona: ZonaDesfavorable.a,
    nivelUbicacion: NivelUbicacion.alejada,
    valorIndiceOverride: 450.1234,
  );

  final liq = TeacherOmniEngine.liquidar(
    input,
    periodo: 'Enero 2026',
    fechaPago: '31/01/2026',
    cantidadCargos: 2,
  );

  final conceptos = generarMDConceptosDocente(cajaPrevisional: liq.config.cajaPrevisional);
  final lsd = await teacherOmniToLsdTxt(
    liquidacion: liq,
    cuitEmpresa: cuitEmpresa,
    razonSocial: razonSocial,
    domicilio: domicilio,
  );
  final recibo = generarReciboTxtDocente(
    r: liq,
    razonSocial: razonSocial,
    cuitEmpresa: '30-12345678-9',
    domicilio: domicilio,
    nombreEmpleado: liq.input.nombre,
    cuilEmpleado: liq.input.cuil,
  );

  String norm(String s) => s.replaceAll(RegExp(r'\r?\n'), _eol);

  return PackNeuquenEstresContenidos(
    conceptosTxt: norm(conceptos),
    liquidacionLsdTxt: norm(lsd),
    reciboOficialTxt: norm(recibo),
    liquidacion: liq,
  );
}

/// Genera una línea de exactamente 150 caracteres para MD_Conceptos (ARCA/AFIP 2026).
/// Estructura: cod (1-10), desc (11-60), codigo AFIP (61-66), relleno espacios (67-150).
/// Relleno con espacios en blanco al final de cada campo. ISO-8859-1, \r\n.
String _lineaConcepto150(String codigo, String descripcion, String codigoAfip) {
  final cod = (codigo.trim().toUpperCase()).padRight(10, ' ').substring(0, 10);
  final desc = LSDFormatEngine.limpiarTexto(descripcion).padRight(50, ' ').substring(0, 50);
  final afip = codigoAfip.replaceAll(RegExp(r'[^\d]'), '').padLeft(6, '0').substring(0, 6);
  final relleno = ''.padRight(84, ' ');
  final linea = (cod + desc + afip + relleno);
  return linea.length > 150 ? linea.substring(0, 150) : linea.padRight(150, ' ');
}

/// Genera MD_Conceptos.txt (ancho fijo 150 caracteres) con códigos AFIP para conceptos docentes.
/// [cajaPrevisional]: Si es [TipoCajaPrevisional.issn] (Neuquén), Jubilación y Obra Social usan 820000
///   (Aportes Provinciales ISSN, no 810000 SIPA nacional). FONID y Conectividad 110000 (No Remunerativos).
String generarMDConceptosDocente({TipoCajaPrevisional? cajaPrevisional}) {
  final esCajaProvincial = cajaPrevisional == TipoCajaPrevisional.issn;
  final codJubOs = esCajaProvincial ? '820000' : '810000';

  final conceptos = [
    ['SUELDO_BAS', 'Sueldo Basico', '011000'],
    ['ANTIGUEDAD', 'Antiguedad', '012000'],
    ['ADIC_ZONA', 'Adicional Zona Desfavorable', '011000'],
    ['ADIC_PATAG', 'Plus Zona Patagonica (Neuquen 40%)', '011000'],
    ['ADIC_D23315', 'Adic. D 233-15 (Zona Patagonica)', '011000'],
    ['PLUS_UBIC', 'Plus Ubicacion / Ruralidad', '011000'],
    ['MATERIAL_DID', 'Material Didactico', '011000'],
    ['FONID', 'FONID', '110000'],           // No Remunerativo (corrección legal)
    ['CONECTIVID', 'Conectividad', '110000'], // No Remunerativo (corrección legal)
    ['GARANT_SAL', 'Garantia Salarial Nacional', '011000'],
    ['ITEM_AULA', 'Item Aula', '011000'],
    ['ADIC_CIUDAD', 'Adicional Salarial Ciudad', '011000'],
    ['EST_DOC', 'Estado Docente', '011000'],
    ['PRESENTISM', 'Presentismo / Asistencia', '011000'],
    ['TITULO', 'Adicional por Titulo', '012000'],
    ['FALLAS_CAJ', 'Fallas de Caja', '011000'],
    ['VIATICOS', 'Viaticos / Movilidad', '112000'],
    ['EQUIP_13047', 'Ajuste Equiparacion Ley 13.047', '011000'],
    // --- Nuevos Conceptos Suite Profesional ---
    ['SAC', 'Sueldo Anual Complementario', '120000'],
    ['SAC_PROP', 'SAC Proporcional', '120000'],
    ['VACACIONES', 'Vacaciones', '130000'],
    ['VNG', 'Vacaciones No Gozadas', '130000'],
    ['INDEMN_245', 'Indemnizacion Antiguedad Art. 245', '211000'],
    ['PREAVISO', 'Indemnizacion Sustitutiva Preaviso', '212000'],
    ['FONDO_COMP', 'Fondo Compensador', '112000'],
    ['HORAS_CAT', 'Horas Catedra', '011000'],
    ['JUBILACION', esCajaProvincial ? 'Jubilacion (ISSN Prov.)' : 'Jubilacion (SIPA)', codJubOs],
    ['OBRA_SOC', esCajaProvincial ? 'Obra Social (ISSN Prov.)' : 'Obra Social', codJubOs],
    ['LEY19032', 'Ley 19.032 (PAMI)', '810000'],
    ['RET_GANANC', 'Retencion Impuesto Ganancias', '990000'],
  ];
  final sb = StringBuffer();
  for (final c in conceptos) {
    sb.write(_lineaConcepto150(c[0], c[1], c[2]));
    sb.write(_eol);
  }
  return sb.toString();
}

String _normalizarEol(String s) => s.replaceAll(RegExp(r'\r?\n'), _eol);

/// Genera Recibo TXT (texto plano) previsualización.
String generarReciboTxtDocente({
  required LiquidacionOmniResult r,
  required String razonSocial,
  required String cuitEmpresa,
  required String domicilio,
  required String nombreEmpleado,
  required String cuilEmpleado,
}) {
  final fmt = NumberFormat.currency(locale: 'es_AR', symbol: '\$', decimalDigits: 2);
  final sb = StringBuffer();
  sb.writeln('================================================================================');
  sb.writeln('                         RECIBO DE SUELDO - DOCENTE');
  sb.writeln('================================================================================');
  sb.writeln();
  sb.writeln('Empresa: $razonSocial');
  sb.writeln('CUIT: $cuitEmpresa');
  sb.writeln('Domicilio: $domicilio');
  sb.writeln();
  sb.writeln('Empleado: $nombreEmpleado');
  sb.writeln('CUIL: $cuilEmpleado');
  sb.writeln('Periodo: ${r.periodo}  |  Fecha de pago: ${r.fechaPago}');
  sb.writeln();
  sb.writeln('--- HABERES REMUNERATIVOS ---');
  if (r.sueldoBasico > 0) sb.writeln('  Sueldo basico        ${fmt.format(r.sueldoBasico)}');
  if (r.adicionalAntiguedad > 0) sb.writeln('  Antiguedad           ${fmt.format(r.adicionalAntiguedad)}');
  if (r.adicionalZona > 0) sb.writeln('  Ad. zona             ${fmt.format(r.adicionalZona)}');
  if (r.adicionalZonaPatagonica > 0) sb.writeln('  Plus Zona Patagonica ${fmt.format(r.adicionalZonaPatagonica)}');
  if (r.plusUbicacion > 0) sb.writeln('  Plus Ubicacion       ${fmt.format(r.plusUbicacion)}');
  if (r.materialDidactico > 0) sb.writeln('  Material Didactico   ${fmt.format(r.materialDidactico)}');
  if (r.itemAula > 0) sb.writeln('  Item Aula            ${fmt.format(r.itemAula)}');
  if (r.adicionalSalarialCiudad > 0) sb.writeln('  Ad. ciudad           ${fmt.format(r.adicionalSalarialCiudad)}');
  if (r.estadoDocente > 0) sb.writeln('  Estado docente       ${fmt.format(r.estadoDocente)}');
  if (r.fonid > 0) sb.writeln('  FONID                ${fmt.format(r.fonid)}');
  if (r.conectividad > 0) sb.writeln('  Conectividad         ${fmt.format(r.conectividad)}');
  if (r.horasCatedra > 0) sb.writeln('  Horas catedra        ${fmt.format(r.horasCatedra)}');
  if (r.ajusteEquiparacionLey13047 > 0) sb.writeln('  Equip. 13.047        ${fmt.format(r.ajusteEquiparacionLey13047)}');
  for (final c in r.conceptosPropios.where((e) => e.esRemunerativo && e.monto > 0)) {
    sb.writeln('  ${c.descripcion.padRight(20)} ${fmt.format(c.monto)}');
  }
  if (r.adicionalGarantiaSalarial > 0) sb.writeln('  Garantia Salarial    ${fmt.format(r.adicionalGarantiaSalarial)}');
  sb.writeln('  TOTAL BRUTO REM.    ${fmt.format(r.totalBrutoRemunerativo)}');
  sb.writeln();
  sb.writeln('--- HABERES NO REMUNERATIVOS ---');
  if (r.fondoCompensador > 0) sb.writeln('  Fondo compensador    ${fmt.format(r.fondoCompensador)}');
  for (final c in r.conceptosPropios.where((e) => !e.esRemunerativo && e.monto > 0)) {
    sb.writeln('  ${c.descripcion.padRight(20)} ${fmt.format(c.monto)}');
  }
  if (r.totalNoRemunerativo > 0) sb.writeln('  Total no remun.      ${fmt.format(r.totalNoRemunerativo)}');
  sb.writeln();
  sb.writeln('--- DESCUENTOS ---');
  sb.writeln('  Jubilacion          ${fmt.format(-r.aporteJubilacion)}');
  sb.writeln('  Obra Social         ${fmt.format(-r.aporteObraSocial)}');
  sb.writeln('  PAMI (Ley 19.032)   ${fmt.format(-r.aportePami)}');
  if (r.impuestoGanancias > 0) sb.writeln('  Ganancias            ${fmt.format(-r.impuestoGanancias)}');
  for (final e in r.deduccionesAdicionales.entries) {
    sb.writeln('  ${e.key.padRight(20)} ${fmt.format(-e.value)}');
  }
  sb.writeln('  TOTAL DESCUENTOS    ${fmt.format(-r.totalDescuentos)}');
  sb.writeln();
  sb.writeln('================================================================================');
  sb.writeln('  NETO A COBRAR      ${fmt.format(r.netoACobrar)}');
  sb.writeln('================================================================================');
  sb.writeln();
  sb.writeln(r.bloqueArt12Ley17250);
  if (r.detallePuntosYValorIndice.isNotEmpty || r.desgloseBaseBonificable.isNotEmpty) {
    sb.writeln();
    sb.writeln('--- AUDITORIA: PUNTOS E INDICE PARITARIO ---');
    sb.writeln('  ${r.detallePuntosYValorIndice}');
    sb.writeln();
    sb.writeln('--- AUDITORIA: DESGLOSE BASE BONIFICABLE (CASCADA A-G) ---');
    sb.writeln('  ${r.desgloseBaseBonificable}');
  }
  return sb.toString();
}

class TeacherArcaPackResult {
  final String carpeta;
  final double neto;
  final double costoLaboralReal;
  final List<String> archivos;

  TeacherArcaPackResult({required this.carpeta, required this.neto, required this.costoLaboralReal, required this.archivos});
}

/// Genera y guarda el Pack Completo ARCA 2026: MD_Conceptos.txt, Liquidacion.txt, Recibo TXT.
Future<TeacherArcaPackResult> generarPackCompletoARCA2026({
  required LiquidacionOmniResult liquidacion,
  required String cuitEmpresa,
  required String razonSocial,
  required String domicilio,
  double artPct = 3.5,
  double artCuotaFija = 800,
}) async {
  final cuit = cuitEmpresa.replaceAll(RegExp(r'[^\d]'), '');
  if (cuit.length != 11) throw ArgumentError('CUIT debe tener 11 dígitos');

  final dir = await getApplicationDocumentsDirectory();
  final stamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
  final carpeta = '${dir.path}${Platform.pathSeparator}ARCA_Pack_2026_$stamp';
  await Directory(carpeta).create(recursive: true);

  final archivos = <String>[];

  final mdConceptos = generarMDConceptosDocente(cajaPrevisional: liquidacion.config.cajaPrevisional);
  final f1 = File('$carpeta${Platform.pathSeparator}MD_Conceptos.txt');
  await f1.writeAsString(_normalizarEol(mdConceptos), encoding: latin1);
  archivos.add(f1.path);

  final liqTxt = await teacherOmniToLsdTxt(liquidacion: liquidacion, cuitEmpresa: cuit, razonSocial: razonSocial, domicilio: domicilio);
  final f2 = File('$carpeta${Platform.pathSeparator}Liquidacion.txt');
  await f2.writeAsString(_normalizarEol(liqTxt), encoding: latin1);
  archivos.add(f2.path);

  final cuilLimpio = liquidacion.input.cuil.replaceAll(RegExp(r'[^\d]'), '');
  final periodoShort = liquidacion.periodo.toLowerCase().contains('enero') ? '202601' : liquidacion.periodo.replaceAll(RegExp(r'[^\d]'), '').padLeft(6, '0').substring(0, 6);
  final recibo = generarReciboTxtDocente(r: liquidacion, razonSocial: razonSocial, cuitEmpresa: cuitEmpresa, domicilio: domicilio, nombreEmpleado: liquidacion.input.nombre, cuilEmpleado: liquidacion.input.cuil);
  final f3 = File('$carpeta${Platform.pathSeparator}Recibo_${cuilLimpio}_$periodoShort.txt');
  await f3.writeAsString(_normalizarEol(recibo), encoding: latin1);
  archivos.add(f3.path);

  final costo = calcularCostoPatronal(liquidacion.totalBrutoRemunerativo, artPct: artPct, artCuotaFija: artCuotaFija);

  return TeacherArcaPackResult(carpeta: carpeta, neto: liquidacion.netoACobrar, costoLaboralReal: costo.totalCostoLaboralReal, archivos: archivos);
}
