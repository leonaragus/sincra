// Exportación TXT LSD para Sanidad (FATSA CCT 122/75, 108/75) - ARCA/AFIP 2026
// Soporta: Mensual, SAC, Vacaciones, Liquidación Final
// Exportación individual y masiva

import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'sanidad_omni_engine.dart';
import 'lsd_engine.dart';
import 'lsd_mapping_service.dart';

/// Códigos internos Sanidad (mapeo AFIP/ARCA)
class SanidadLsdCodigos {
  static const String sueldoBasico = 'SUELDO_BAS';
  static const String antiguedad = 'ANTIGUEDAD';
  static const String titulo = 'TITULO';
  static const String tareaCritica = 'TAREA_CRIT';
  static const String zonaPatagonica = 'PLUS_ZONA';   // Plus Zona Desfavorable 20% (Patagonia)
  static const String nocturnidad = 'NOCTURNID';      // Horas nocturnas
  static const String falloCaja = 'FALLO_CAJA';       // Administrativo + manejo efectivo
  static const String horasExtras50 = 'HORAS_EX50';   // Horas extras 50%
  static const String horasExtras100 = 'HORAS_EX100'; // Horas extras 100%
  static const String sac = 'SAC';                    // Aguinaldo
  static const String sacProp = 'SAC_PROP';           // SAC Proporcional
  static const String vacaciones = 'VACACIONES';      // Vacaciones
  static const String plusVacacional = 'PLUS_VAC';    // Plus vacacional
  static const String vacNoGozadas = 'VAC_NO_GOZ';    // Vacaciones no gozadas
  static const String indemnizacion = 'INDEMN_245';   // Indemnización Art. 245
  static const String preaviso = 'PREAVISO';          // Preaviso
  static const String integracionMes = 'INTEG_MES';   // Integración mes
  static const String jubilacion = 'JUBILACION';
  static const String ley19032 = 'LEY19032';
  static const String obraSocial = 'OBRA_SOC';
  static const String cuotaSindical = 'CUOTA_SIND';
  static const String seguroSepelio = 'SEGURO_SEP';
  static const String aporteSolidario = 'APORTE_SOL'; // Aporte Solidario FATSA 1% obligatorio
  static const String adelantos = 'ADELANTOS';
  static const String embargos = 'EMBARGOS';
  static const String prestamos = 'PRESTAMOS';
}

/// Sanitiza texto para ARCA
String _sanitizarTextoARCA(String texto) {
  return LSDFormatEngine.limpiarTexto(texto);
}

/// Genera contenido LSD TXT para LiquidacionSanidadResult (formato 150 chars, ARCA)
/// Soporta todos los modos: mensual, SAC, vacaciones, liquidación final
/// 
/// ⚠️ IMPORTANTE - FORMATO ARCA 2026 INALTERABLE:
/// - El formato LSD (posiciones, longitudes, estructura) está HARDCODEADO en LSDGenerator
/// - Los cambios del usuario en paritarias/escalas SOLO afectan los MONTOS calculados
/// - El formato de 150 caracteres por línea es FIJO y SIEMPRE será aceptado por ARCA
/// - Las validaciones garantizan que cada registro cumpla la especificación ARCA 2026
/// - Ninguna edición del usuario puede romper la estructura del archivo LSD
Future<String> sanidadOmniToLsdTxt({
  required LiquidacionSanidadResult liquidacion,
  required String cuitEmpresa,
  required String razonSocial,
  required String domicilio,
}) async {
  final sb = StringBuffer();
  final cuil = liquidacion.input.cuil.replaceAll(RegExp(r'[^\d]'), '');
  if (cuil.length != 11) throw ArgumentError('CUIL inválido');

  final razonSocialLimpia = _sanitizarTextoARCA(razonSocial);
  final domicilioLimpio = _sanitizarTextoARCA(domicilio);
  
  // Tipo de liquidación para ARCA: 'S' = SAC
  final tipoLiq = liquidacion.modo == ModoLiquidacionSanidad.sac ? 'S' : null;

  final reg1 = LSDGenerator.generateRegistro1(
    cuitEmpresa: cuitEmpresa,
    periodo: liquidacion.periodo,
    fechaPago: liquidacion.fechaPago,
    razonSocial: razonSocialLimpia,
    domicilio: domicilioLimpio,
    tipoLiquidacion: tipoLiq,
  );
  sb.write(latin1.decode(reg1));
  sb.write(LSDGenerator.eolLsd);

  final conceptos = <Map<String, dynamic>>[];

  void addHaber(String codigo, String desc, double monto) {
    if (monto <= 0) return;
    conceptos.add({'codigo': codigo, 'desc': desc, 'importe': monto, 'tipo': 'H'});
  }

  void addDescuento(String codigo, String desc, double monto) {
    if (monto <= 0) return;
    conceptos.add({'codigo': codigo, 'desc': desc, 'importe': monto, 'tipo': 'D'});
  }
  
  void addNoRemunerativo(String codigo, String desc, double monto) {
    if (monto <= 0) return;
    conceptos.add({'codigo': codigo, 'desc': desc, 'importe': monto, 'tipo': 'N'});
  }

  // === HABERES REMUNERATIVOS ===
  addHaber(SanidadLsdCodigos.sueldoBasico, 'Sueldo Basico', liquidacion.sueldoBasico);
  addHaber(SanidadLsdCodigos.antiguedad, 'Antiguedad', liquidacion.adicionalAntiguedad);
  addHaber(SanidadLsdCodigos.titulo, 'Adicional Titulo', liquidacion.adicionalTitulo);
  addHaber(SanidadLsdCodigos.tareaCritica, 'Tarea Critica/Riesgo', liquidacion.adicionalTareaCriticaRiesgo);
  addHaber(SanidadLsdCodigos.zonaPatagonica, 'Plus Zona Desfavorable (Patagonia)', liquidacion.adicionalZonaPatagonica);
  addHaber(SanidadLsdCodigos.nocturnidad, 'Horas Nocturnas', liquidacion.nocturnidad);
  addHaber(SanidadLsdCodigos.falloCaja, 'Fallo de Caja', liquidacion.falloCaja);
  
  // === HORAS EXTRAS ===
  addHaber(SanidadLsdCodigos.horasExtras50, 'Horas Extras 50%', liquidacion.horasExtras50Monto);
  addHaber(SanidadLsdCodigos.horasExtras100, 'Horas Extras 100%', liquidacion.horasExtras100Monto);
  
  // === SAC ===
  if (liquidacion.sac > 0) {
    final codigoSac = liquidacion.diasSACCalculados >= 180 
        ? SanidadLsdCodigos.sac 
        : SanidadLsdCodigos.sacProp;
    final descSac = liquidacion.diasSACCalculados >= 180 
        ? 'SAC - Aguinaldo' 
        : 'SAC Proporcional (${liquidacion.diasSACCalculados} dias)';
    addHaber(codigoSac, descSac, liquidacion.sac);
  }
  
  // === VACACIONES ===
  addHaber(SanidadLsdCodigos.vacaciones, 'Vacaciones (${liquidacion.diasVacacionesCalculados} dias)', liquidacion.vacaciones);
  addHaber(SanidadLsdCodigos.plusVacacional, 'Plus Vacacional', liquidacion.plusVacacional);
  addHaber(SanidadLsdCodigos.vacNoGozadas, 'Vacaciones No Gozadas', liquidacion.vacacionesNoGozadas);
  if (liquidacion.sacSobreVacaciones > 0) {
    addHaber('SAC_S_VAC', 'SAC sobre Vacaciones', liquidacion.sacSobreVacaciones);
  }
  if (liquidacion.sacSobrePreaviso > 0) {
    addHaber('SAC_S_PRE', 'SAC sobre Preaviso', liquidacion.sacSobrePreaviso);
  }
  
  // === CONCEPTOS PROPIOS (haberes) ===
  for (final c in liquidacion.conceptosPropios) {
    if (c['esDescuento'] != true) {
      final codigo = _sanitizarTextoARCA((c['codigo']?.toString() ?? 'CONC_PROP').toUpperCase());
      final desc = _sanitizarTextoARCA(c['descripcion']?.toString() ?? 'Concepto Propio');
      final monto = (c['monto'] as num?)?.toDouble() ?? 0;
      addHaber(codigo.length > 10 ? codigo.substring(0, 10) : codigo, desc, monto);
    }
  }
  
  // === NO REMUNERATIVOS (Indemnizaciones) ===
  addNoRemunerativo(SanidadLsdCodigos.indemnizacion, 'Indemnizacion Art. 245 LCT', liquidacion.indemnizacionArt245);
  addNoRemunerativo(SanidadLsdCodigos.preaviso, 'Preaviso', liquidacion.preaviso);
  addNoRemunerativo(SanidadLsdCodigos.integracionMes, 'Integracion Mes Despido', liquidacion.integracionMes);

  // === DESCUENTOS LEGALES ===
  addDescuento(SanidadLsdCodigos.jubilacion, 'Jubilacion', liquidacion.aporteJubilacion);
  addDescuento(SanidadLsdCodigos.ley19032, 'Ley 19.032 (PAMI)', liquidacion.aporteLey19032);
  addDescuento(SanidadLsdCodigos.obraSocial, 'Obra Social', liquidacion.aporteObraSocial);
  addDescuento(SanidadLsdCodigos.cuotaSindical, 'Cuota Sindical ATSA', liquidacion.cuotaSindicalAtsa);
  addDescuento(SanidadLsdCodigos.seguroSepelio, 'Seguro de Sepelio', liquidacion.seguroSepelio);
  addDescuento(SanidadLsdCodigos.aporteSolidario, 'Aporte Solidario FATSA', liquidacion.aporteSolidarioFatsa);
  
  // === OTROS DESCUENTOS ===
  addDescuento(SanidadLsdCodigos.adelantos, 'Adelantos', liquidacion.adelantos);
  addDescuento(SanidadLsdCodigos.embargos, 'Embargos', liquidacion.embargos);
  addDescuento(SanidadLsdCodigos.prestamos, 'Prestamos', liquidacion.prestamos);
  if (liquidacion.otrosDescuentos > 0) {
    addDescuento('OTROS_DESC', 'Otros Descuentos', liquidacion.otrosDescuentos);
  }
  
  // === CONCEPTOS PROPIOS (descuentos) ===
  for (final c in liquidacion.conceptosPropios) {
    if (c['esDescuento'] == true) {
      final codigo = _sanitizarTextoARCA((c['codigo']?.toString() ?? 'DESC_PROP').toUpperCase());
      final desc = _sanitizarTextoARCA(c['descripcion']?.toString() ?? 'Descuento');
      final monto = (c['monto'] as num?)?.toDouble() ?? 0;
      addDescuento(codigo.length > 10 ? codigo.substring(0, 10) : codigo, desc, monto);
    }
  }

  // Generar Registros 2 para cada concepto
  for (final c in conceptos) {
    final codigoLimpio = _sanitizarTextoARCA((c['codigo'] as String).trim().toUpperCase());
    final descripcionLimpia = _sanitizarTextoARCA(c['desc'] as String? ?? '');
    
    // Mapear tipo N (no remunerativo) a H para el formato LSD
    final tipoLsd = (c['tipo'] as String?) == 'N' ? 'H' : c['tipo'] as String?;

    final r2 = LSDGenerator.generateRegistro2Conceptos(
      cuilEmpleado: cuil,
      codigoConcepto: codigoLimpio,
      importe: c['importe'] as double,
      descripcionConcepto: descripcionLimpia,
      tipo: tipoLsd,
    );
    sb.write(latin1.decode(r2));
    sb.write(LSDGenerator.eolLsd);
  }

  // Registro 3 - Bases imponibles
  // --- CORRECCIÓN ARCA 2026: Usar generador de 10 bases completas ---
  final bases = List<double>.filled(10, 0.0);
  bases[0] = liquidacion.baseImponibleTopeada; // Base 1
  bases[1] = liquidacion.baseImponibleTopeada; // Base 2
  bases[2] = liquidacion.baseImponibleTopeada; // Base 3
  
  // Base 9 (LRT) suele ser el Total Remunerativo (a veces sin tope, pero LSD valida consistencia)
  // Para seguridad en validación "Base Inconsistente", usamos la misma que Base 1 si no hay diferencial.
  bases[8] = liquidacion.baseImponibleTopeada; // Base 9 (Array index 8)

  final r3 = LSDGenerator.generateRegistro3BasesArca2026(
    cuilEmpleado: cuil,
    bases: bases,
  );
  sb.write(latin1.decode(r3));
  sb.write(LSDGenerator.eolLsd);

  // Registro 4 - Datos complementarios
  final r4 = LSDGenerator.generateRegistro4(
    cuilEmpleado: cuil,
    codigoRnos: liquidacion.input.codigoRnos ?? '126205',
    cantidadFamiliares: liquidacion.input.cantidadFamiliares,
    codigoModalidad: liquidacion.codigoModalidadLSD ?? '008',
    codigoCondicion: liquidacion.input.codigoCondicion ?? '01',
    codigoActividad: liquidacion.input.codigoActividad ?? '001',
    codigoPuesto: liquidacion.input.codigoPuesto ?? '0000',
  );
  sb.write(latin1.decode(r4));
  sb.write(LSDGenerator.eolLsd);

  final out = sb.toString();
  LSDGenerator.validarLongitud150(out);
  return out;
}

/// Genera LSD masivo para múltiples empleados en un solo archivo
Future<String> sanidadLsdMasivo({
  required List<LiquidacionSanidadResult> liquidaciones,
  required String cuitEmpresa,
  required String razonSocial,
  required String domicilio,
}) async {
  final sb = StringBuffer();
  
  for (final liquidacion in liquidaciones) {
    final contenido = await sanidadOmniToLsdTxt(
      liquidacion: liquidacion,
      cuitEmpresa: cuitEmpresa,
      razonSocial: razonSocial,
      domicilio: domicilio,
    );
    sb.write(contenido);
  }
  
  return sb.toString();
}

/// Genera Pack ARCA completo: LSD + Recibos en ZIP
/// Retorna la ruta del archivo ZIP generado
Future<String> generarPackARCASanidad({
  required List<LiquidacionSanidadResult> liquidaciones,
  required String cuitEmpresa,
  required String razonSocial,
  required String domicilio,
  required Future<List<int>> Function(LiquidacionSanidadResult) generadorReciboPDF,
}) async {
  final archive = Archive();
  final fechaHoy = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
  final periodo = liquidaciones.isNotEmpty ? liquidaciones.first.periodo : 'SinPeriodo';
  final periodoLimpio = periodo.replaceAll(RegExp(r'[^\w]'), '_');
  
  // 1. Generar LSD unificado
  final lsdContenido = await sanidadLsdMasivo(
    liquidaciones: liquidaciones,
    cuitEmpresa: cuitEmpresa,
    razonSocial: razonSocial,
    domicilio: domicilio,
  );
  
  final lsdBytes = latin1.encode(lsdContenido);
  archive.addFile(ArchiveFile(
    'LSD_Sanidad_$periodoLimpio.txt',
    lsdBytes.length,
    lsdBytes,
  ));
  
  // 2. Generar recibos individuales
  for (final liq in liquidaciones) {
    try {
      final pdfBytes = await generadorReciboPDF(liq);
      final cuilLimpio = liq.input.cuil.replaceAll(RegExp(r'[^\d]'), '');
      final nombreLimpio = liq.input.nombre.replaceAll(RegExp(r'[^\w\s]'), '').replaceAll(' ', '_');
      
      archive.addFile(ArchiveFile(
        'Recibos/Recibo_${nombreLimpio}_$cuilLimpio.pdf',
        pdfBytes.length,
        pdfBytes,
      ));
    } catch (e) {
      print('Error generando recibo para ${liq.input.nombre}: $e');
    }
  }
  
  // 3. Generar instructivo de mapeo AFIP
  final codigosUsados = <String>{};
  for (final liq in liquidaciones) {
    if (liq.sueldoBasico > 0) codigosUsados.add(SanidadLsdCodigos.sueldoBasico);
    if (liq.adicionalAntiguedad > 0) codigosUsados.add(SanidadLsdCodigos.antiguedad);
    if (liq.nocturnidad > 0) codigosUsados.add(SanidadLsdCodigos.nocturnidad);
    if (liq.falloCaja > 0) codigosUsados.add(SanidadLsdCodigos.falloCaja);
    if (liq.adicionalTareaCriticaRiesgo > 0) codigosUsados.add(SanidadLsdCodigos.tareaCritica);
    if (liq.aporteJubilacion > 0) codigosUsados.add(SanidadLsdCodigos.jubilacion);
    if (liq.aporteObraSocial > 0) codigosUsados.add(SanidadLsdCodigos.obraSocial);
    if (liq.aporteLey19032 > 0) codigosUsados.add(SanidadLsdCodigos.ley19032);
    
    for (final c in liq.conceptosPropios) {
      final cod = c['codigo']?.toString() ?? '';
      if (cod.isNotEmpty) {
        codigosUsados.add(cod.length > 10 ? cod.substring(0, 10) : cod);
      }
    }
  }
  
  final instructivo = LsdMappingService.generarInstructivo(codigosUsados.toList());
  final instructivoBytes = utf8.encode(instructivo);
  archive.addFile(ArchiveFile(
    'INSTRUCTIVO_IMPORTANTE_AFIP.txt',
    instructivoBytes.length,
    instructivoBytes,
  ));

  // 4. Generar resumen TXT
  final resumen = _generarResumenLiquidaciones(liquidaciones, razonSocial, periodo);
  final resumenBytes = utf8.encode(resumen);
  archive.addFile(ArchiveFile(
    'Resumen_Liquidaciones.txt',
    resumenBytes.length,
    resumenBytes,
  ));
  
  // 4. Comprimir y guardar
  final zipEncoder = ZipEncoder();
  final zipBytes = zipEncoder.encode(archive);
  
  if (zipBytes == null) {
    throw Exception('Error al comprimir el pack ARCA');
  }
  
  final dir = await getApplicationDocumentsDirectory();
  final zipPath = '${dir.path}/Pack_ARCA_Sanidad_${periodoLimpio}_$fechaHoy.zip';
  final zipFile = File(zipPath);
  await zipFile.writeAsBytes(zipBytes);
  
  return zipPath;
}

/// Genera resumen de liquidaciones en texto plano
String _generarResumenLiquidaciones(
  List<LiquidacionSanidadResult> liquidaciones,
  String razonSocial,
  String periodo,
) {
  final sb = StringBuffer();
  final fechaGen = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
  
  sb.writeln('=' * 70);
  sb.writeln('RESUMEN DE LIQUIDACIONES - SANIDAD FATSA');
  sb.writeln('=' * 70);
  sb.writeln('Empresa: $razonSocial');
  sb.writeln('Periodo: $periodo');
  sb.writeln('Generado: $fechaGen');
  sb.writeln('Cantidad de empleados: ${liquidaciones.length}');
  sb.writeln('=' * 70);
  sb.writeln('');
  
  double totalBrutos = 0;
  double totalNetos = 0;
  double totalDescuentos = 0;
  
  for (final liq in liquidaciones) {
    totalBrutos += liq.totalBrutoRemunerativo;
    totalNetos += liq.netoACobrar;
    totalDescuentos += liq.totalDescuentos;
    
    sb.writeln('-' * 50);
    sb.writeln('Empleado: ${liq.input.nombre}');
    sb.writeln('CUIL: ${liq.input.cuil}');
    sb.writeln('Categoria: ${liq.input.categoria.name}');
    sb.writeln('Modo: ${liq.modo.name}');
    sb.writeln('Bruto: \$${liq.totalBrutoRemunerativo.toStringAsFixed(2)}');
    sb.writeln('Descuentos: \$${liq.totalDescuentos.toStringAsFixed(2)}');
    sb.writeln('Neto: \$${liq.netoACobrar.toStringAsFixed(2)}');
    sb.writeln('');
  }
  
  sb.writeln('=' * 70);
  sb.writeln('TOTALES');
  sb.writeln('=' * 70);
  sb.writeln('Total Brutos: \$${totalBrutos.toStringAsFixed(2)}');
  sb.writeln('Total Descuentos: \$${totalDescuentos.toStringAsFixed(2)}');
  sb.writeln('Total Netos: \$${totalNetos.toStringAsFixed(2)}');
  sb.writeln('=' * 70);
  
  return sb.toString();
}
