// Exportación TXT para Libro de Sueldo Digital (LSD) ARCA - Guía 4 Docentes
// Codificación ISO-8859-1, fin de línea \r\n. Validador 150 caracteres por línea.

import 'dart:convert';
import 'dart:math';
import '../core/codigos_afip_arca.dart';
import 'teacher_omni_engine.dart';
import 'lsd_engine.dart';

/// Formatea un importe para ARCA en formato de 15 dígitos sin puntos ni comas
/// Transforma números (ej: 1250.55) en strings de 15 caracteres rellenados con ceros a la izquierda
/// Ejemplo: 1250.55 → '000000000125055'
String formatImporteARCA(double monto) {
  // Convertir a centavos (multiplicar por 100)
  final montoCentavos = (monto * 100).round();
  
  // Formatear con ceros a la izquierda hasta 15 dígitos
  final formateado = montoCentavos.toString().padLeft(15, '0');
  
  // Asegurar que no exceda 15 dígitos (truncar si es necesario)
  if (formateado.length > 15) {
    return formateado.substring(formateado.length - 15);
  }
  
  return formateado;
}

/// Sanitiza texto eliminando acentos y caracteres especiales para evitar errores de codificación en ARCA
String sanitizarTextoARCA(String texto) {
  return LSDFormatEngine.limpiarTexto(texto);
}

/// Códigos internos Guía 4 docentes (mapeo a AFIP)
class TeacherLsdCodigos {
  static const String sueldoBasico = 'SUELDO_BAS';
  static const String antiguedad = 'ANTIGUEDAD';
  static const String fonid = 'FONID';
  static const String conectividad = 'CONECTIVID';
  static const String horasCatedra = 'HORAS_CAT';
  static const String adicionalZona = 'ADIC_ZONA';
  static const String itemAula = 'ITEM_AULA';
  static const String adicionalCiudad = 'ADIC_CIUDAD';
  static const String estadoDocente = 'EST_DOC';
  static const String materialDidactico = 'MAT_DIDACT';
  static const String equiparacion13047 = 'EQUIP_13047';
  static const String fondoCompensador = 'FONDO_COMP';
  static const String plusUbicacion = 'PLUS_UBIC'; // Plus Ubicación/Ruralidad — AFIP Guía 4 Adicionales 011000
  static const String presentismo = 'PRESENTISM';
  static const String titulo = 'TITULO';
  static const String jubilacion = 'JUBILACION';
  static const String obraSocial = 'OBRA_SOC';
  static const String ley19032 = 'LEY19032';
  static const String retGanancias = 'RET_GANANC';
  // --- Nuevos Códigos Suite Profesional ---
  static const String sac = 'SAC';
  static const String sacProp = 'SAC_PROP';
  static const String vacaciones = 'VACACIONES';
  static const String vacNoGozadas = 'VNG';
  static const String indemniz245 = 'INDEMN_245';
  static const String preavisoIndem = 'PREAVISO';
}

/// Genera contenido LSD TXT para un LiquidacionOmniResult (Formato 150 chars, ARCA).
/// 
/// ⚠️ IMPORTANTE - FORMATO ARCA 2026 INALTERABLE:
/// - El formato LSD (posiciones, longitudes, estructura) está HARDCODEADO en LSDGenerator
/// - Los cambios del usuario en paritarias/escalas SOLO afectan los MONTOS calculados
/// - El formato de 150 caracteres por línea es FIJO y SIEMPRE será aceptado por ARCA
/// - Las validaciones garantizan que cada registro cumpla la especificación ARCA 2026
/// - Ninguna edición del usuario puede romper la estructura del archivo LSD
Future<String> teacherOmniToLsdTxt({
  required LiquidacionOmniResult liquidacion,
  required String cuitEmpresa,
  required String razonSocial,
  required String domicilio,
}) async {
  final sb = StringBuffer();
  final cuil = liquidacion.input.cuil.replaceAll(RegExp(r'[^\d]'), '');
  if (cuil.length != 11) throw ArgumentError('CUIL inválido');

  // Sanitizar datos de empresa antes de generar registro
  final razonSocialLimpia = sanitizarTextoARCA(razonSocial);
  final domicilioLimpio = sanitizarTextoARCA(domicilio);
  
  final reg1 = LSDGenerator.generateRegistro1(
    cuitEmpresa: cuitEmpresa,
    periodo: liquidacion.periodo,
    fechaPago: liquidacion.fechaPago,
    razonSocial: razonSocialLimpia,
    domicilio: domicilioLimpio,
  );
  sb.write(latin1.decode(reg1));
  sb.write(LSDGenerator.eolLsd);

  // Registro 2: Datos referenciales (NUEVO ARCA)
  final reg2 = LSDGenerator.generateRegistro2DatosReferenciales(
    cuilEmpleado: cuil,
    legajo: liquidacion.input.nombre.replaceAll(RegExp(r'\s'), '').substring(0, min(10, liquidacion.input.nombre.length)),
    diasBase: 30,
  );
  sb.write(latin1.decode(reg2));
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

  addHaber(TeacherLsdCodigos.sueldoBasico, 'Sueldo Básico', liquidacion.sueldoBasico);
  addHaber(TeacherLsdCodigos.antiguedad, 'Antigüedad', liquidacion.adicionalAntiguedad);
  addHaber(TeacherLsdCodigos.adicionalZona, 'Adicional Zona', liquidacion.adicionalZona);
  if (liquidacion.adicionalZonaPatagonica > 0) {
    addHaber('ADIC_PATAG', 'Plus Zona Patagónica', liquidacion.adicionalZonaPatagonica);
  }
  if (liquidacion.plusUbicacion > 0) {
    addHaber(TeacherLsdCodigos.plusUbicacion, 'Plus Ubicación / Ruralidad', liquidacion.plusUbicacion);
  }
  addHaber(TeacherLsdCodigos.itemAula, 'Ítem Aula', liquidacion.itemAula);
  if (liquidacion.materialDidactico > 0) addHaber('MATERIAL_DID', 'Material Didáctico', liquidacion.materialDidactico);
  addHaber(TeacherLsdCodigos.adicionalCiudad, 'Adicional Salarial Ciudad', liquidacion.adicionalSalarialCiudad);
  addHaber(TeacherLsdCodigos.estadoDocente, 'Estado Docente', liquidacion.estadoDocente);
  addHaber(TeacherLsdCodigos.fonid, 'FONID', liquidacion.fonid);
  addHaber(TeacherLsdCodigos.conectividad, 'Conectividad', liquidacion.conectividad);
  addHaber(TeacherLsdCodigos.horasCatedra, 'Horas Cátedra', liquidacion.horasCatedra);
  addHaber(TeacherLsdCodigos.equiparacion13047, 'Ajuste Equiparación Ley 13.047', liquidacion.ajusteEquiparacionLey13047);
  addHaber(TeacherLsdCodigos.fondoCompensador, 'Fondo Compensador', liquidacion.fondoCompensador);
  
  // Garantía Salarial Nacional 2026 (si aplica)
  if (liquidacion.adicionalGarantiaSalarial > 0) {
    addHaber('GARANT_SAL', 'Adicional Garantia Salarial', liquidacion.adicionalGarantiaSalarial);
  }

  for (final c in liquidacion.conceptosPropios) {
    CodigosAfipArca.validar(c.codigoAfip, c.descripcion);
    addHaber(c.codigo.length > 10 ? c.codigo.substring(0, 10) : c.codigo.padRight(10), c.descripcion, c.monto);
  }

  addDescuento(TeacherLsdCodigos.jubilacion, 'Jubilación', liquidacion.aporteJubilacion);
  addDescuento(TeacherLsdCodigos.obraSocial, 'Obra Social', liquidacion.aporteObraSocial);
  addDescuento(TeacherLsdCodigos.ley19032, 'Ley 19.032 (PAMI)', liquidacion.aportePami);
  addDescuento(TeacherLsdCodigos.retGanancias, 'Retención Ganancias', liquidacion.impuestoGanancias);
  for (final e in liquidacion.deduccionesAdicionales.entries) {
    addDescuento(
      e.key.length > 10 ? e.key.substring(0, 10) : e.key.padRight(10),
      e.key,
      e.value,
    );
  }

  for (final c in conceptos) {
    // Sanitizar código y descripción para evitar errores de codificación
    final codigoLimpio = sanitizarTextoARCA((c['codigo'] as String).trim().toUpperCase());
    final descripcionLimpia = sanitizarTextoARCA(c['desc'] as String? ?? '');
    
    final r3 = LSDGenerator.generateRegistro3Conceptos(
      cuilEmpleado: cuil,
      codigoConcepto: codigoLimpio,
      importe: c['importe'] as double,
      descripcionConcepto: descripcionLimpia,
      tipo: c['tipo'] as String?,
    );
    sb.write(latin1.decode(r3));
    sb.write(LSDGenerator.eolLsd);
  }

  // --- CORRECCIÓN ARCA 2026: Usar generador de 10 bases completas ---
  // Base 1: Sueldo (Jubilación)
  // Base 2: Contribuciones SS (generalmente igual a Base 1)
  // Base 3: Contribuciones OS (generalmente igual a Base 1)
  // Las bases 4 (OS), 8 (Aporte OS) y 9 (LRT) se autocompletan en el motor si no se envían,
  // pero las enviamos explícitamente para mayor seguridad.
  final bases = List<double>.filled(10, 0.0);
  // ARCA 2026: Llenar bases 1 a 9 con el total remunerativo topeado para consistencia federal
  for (int i = 0; i < 9; i++) {
    bases[i] = liquidacion.baseImponibleTopeada;
  }

  final r4 = LSDGenerator.generateRegistro4Bases(
    cuilEmpleado: cuil,
    bases: bases,
  );
  sb.write(latin1.decode(r4));
  sb.write(LSDGenerator.eolLsd);

  final r5 = LSDGenerator.generateRegistro5DatosComplementarios(
    cuilEmpleado: cuil,
    // Para docentes, si no hay RNOS, sugerimos OSDOP (115404) en lugar de OSECAC (126205)
    // OSECAC es el default del motor, aquí lo sobreescribimos si es nulo
    codigoRnos: liquidacion.input.codigoRnos ?? '115404', 
    cantidadFamiliares: liquidacion.input.cargasFamiliares,
    // Actividad Enseñanza Privada (16) suele ser común, pero default 001 es Servicios Comunes
    codigoActividad: liquidacion.input.codigoActividad ?? '016', 
    codigoPuesto: liquidacion.input.codigoPuesto,
    codigoCondicion: liquidacion.input.codigoCondicion,
    codigoModalidad: liquidacion.input.codigoModalidad,
  );
  sb.write(latin1.decode(r5));
  sb.write(LSDGenerator.eolLsd);

  final out = sb.toString();
  LSDGenerator.validarLongitud195(out);
  return out;
}

/// Extrae las líneas de Registro 04 (Bases imponibles) y 05 (Datos complementarios) del Liquidacion.txt
/// generado, para inspección o mostrar en chat. Codificación ISO-8859-1, \r\n. 195 caracteres por línea.
Future<Map<String, String>> extraerRegistro03y04Lsd({
  required LiquidacionOmniResult liquidacion,
  required String cuitEmpresa,
  required String razonSocial,
  required String domicilio,
}) async {
  final txt = await teacherOmniToLsdTxt(liquidacion: liquidacion, cuitEmpresa: cuitEmpresa, razonSocial: razonSocial, domicilio: domicilio);
  final lineas = txt.split(RegExp(r'\r?\n'));
  String? reg04, reg05;
  for (final L in lineas) {
    final s = L.replaceAll('\r', '');
    if (s.isEmpty) continue;
    if (s.length != 195) continue;
    if (s.startsWith('4')) reg04 = s;
    if (s.startsWith('5')) reg05 = s;
  }
  return {'reg04': reg04 ?? '', 'reg05': reg05 ?? ''};
}
