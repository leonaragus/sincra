
import 'teacher_lsd_export.dart';

// Códigos internos Sanidad (mapeo AFIP/ARCA) - Duplicado para evitar import circular si fuera necesario, 
// pero aquí lo usamos para asegurar que LsdMappingService tenga acceso a los códigos.
class SanidadLsdCodigos {
  static const String sueldoBasico = 'SUELDO_BAS';
  static const String antiguedad = 'ANTIGUEDAD';
  static const String titulo = 'TITULO';
  static const String tareaCritica = 'TAREA_CRIT';
  static const String zonaPatagonica = 'PLUS_ZONA';
  static const String nocturnidad = 'NOCTURNID';
  static const String falloCaja = 'FALLO_CAJA';
  static const String horasExtras50 = 'HORAS_EX50';
  static const String horasExtras100 = 'HORAS_EX100';
  static const String sac = 'SAC';
  static const String sacProp = 'SAC_PROP';
  static const String vacaciones = 'VACACIONES';
  static const String plusVacacional = 'PLUS_VAC';
  static const String vacNoGozadas = 'VAC_NO_GOZ';
  static const String indemnizacion = 'INDEMN_245';
  static const String preaviso = 'PREAVISO';
  static const String integracionMes = 'INTEG_MES';
  static const String jubilacion = 'JUBILACION';
  static const String ley19032 = 'LEY19032';
  static const String obraSocial = 'OBRA_SOC';
  static const String cuotaSindical = 'CUOTA_SIND';
  static const String seguroSepelio = 'SEGURO_SEP';
  static const String aporteSolidario = 'APORTE_SOL';
  static const String adelantos = 'ADELANTOS';
  static const String embargos = 'EMBARGOS';
  static const String prestamos = 'PRESTAMOS';
}

/// Códigos para liquidación general (Convenios CCT)
class GeneralesLsdCodigos {
  static const String sueldoBasico = 'SUELDO_BAS';
  static const String horasExtras50 = 'HORAS_EXTR_50';
  static const String horasExtras100 = 'HORAS_EXTR_100';
  static const String kilometros = 'KM_RECORR';
  static const String viaticos = 'VIAT_COM';
  static const String pernocte = 'PERNOCTE';
  static const String premios = 'GRATIF';
  static const String vacaciones = 'VACACIONES';
  static const String plusVacacional = 'PLUS_VACAC';
  static const String jubilacion = 'JUBILACION';
  static const String obraSocial = 'OBRA_SOC';
  static const String ley19032 = 'LEY_19032';
  static const String ganancias = 'IMP_GANANC';
  static const String sindicato = 'SINDICATO';
}

/// Servicio para generar guías de mapeo de conceptos para AFIP LSD
/// Ayuda al usuario a asociar los conceptos la primera vez que sube el archivo
class LsdMappingService {
  
  /// Estructura de sugerencia de mapeo
  static const Map<String, Map<String, String>> _mapeoSugerido = {
    // === GENERALES / CONVENIOS CCT ===
    GeneralesLsdCodigos.sueldoBasico: {
      'afip': '110000',
      'desc': 'Sueldo Básico',
      'sub': 'Remunerativo'
    },
    GeneralesLsdCodigos.horasExtras50: {
      'afip': '510000',
      'desc': 'Horas Extras 50%',
      'sub': 'Remunerativo'
    },
    GeneralesLsdCodigos.horasExtras100: {
      'afip': '520000',
      'desc': 'Horas Extras 100%',
      'sub': 'Remunerativo'
    },
    GeneralesLsdCodigos.kilometros: {
      'afip': '110000', // O específico si existe
      'desc': 'Kilómetros Recorridos (CCT)',
      'sub': 'Remunerativo'
    },
    GeneralesLsdCodigos.viaticos: {
      'afip': '112000', // Viáticos CCT
      'desc': 'Viáticos / Comida',
      'sub': 'No Remunerativo'
    },
    GeneralesLsdCodigos.pernocte: {
      'afip': '112000',
      'desc': 'Pernocte',
      'sub': 'No Remunerativo'
    },
    GeneralesLsdCodigos.premios: {
      'afip': '110000',
      'desc': 'Premios / Gratificaciones',
      'sub': 'Remunerativo'
    },
    GeneralesLsdCodigos.vacaciones: {
      'afip': '150000',
      'desc': 'Vacaciones',
      'sub': 'Remunerativo'
    },
    GeneralesLsdCodigos.plusVacacional: {
      'afip': '150000',
      'desc': 'Plus Vacacional',
      'sub': 'Remunerativo'
    },
    GeneralesLsdCodigos.jubilacion: {
      'afip': '810002',
      'desc': 'Jubilación (SIPA)',
      'sub': 'Descuentos'
    },
    GeneralesLsdCodigos.obraSocial: {
      'afip': '810003',
      'desc': 'Obra Social',
      'sub': 'Descuentos'
    },
    GeneralesLsdCodigos.ley19032: {
      'afip': '810002',
      'desc': 'Ley 19.032 (INSSJP)',
      'sub': 'Descuentos'
    },
    GeneralesLsdCodigos.ganancias: {
      'afip': '810010',
      'desc': 'Retención Ganancias 4ta Cat.',
      'sub': 'Descuentos'
    },
    GeneralesLsdCodigos.sindicato: {
      'afip': '810008',
      'desc': 'Cuota Sindical',
      'sub': 'Descuentos'
    },

    // === DOCENTES ===
    // TeacherLsdCodigos.sueldoBasico -> Usa GeneralesLsdCodigos.sueldoBasico
    TeacherLsdCodigos.antiguedad: {
      'afip': '110000', 
      'desc': 'Adicionales', 
      'sub': 'Remunerativo'
    },
    TeacherLsdCodigos.fonid: {
      'afip': '550000', 
      'desc': 'Conceptos No Remunerativos Varios', 
      'sub': 'No Remunerativo'
    },
    TeacherLsdCodigos.conectividad: {
      'afip': '550000', 
      'desc': 'Conceptos No Remunerativos Varios', 
      'sub': 'No Remunerativo'
    },
    TeacherLsdCodigos.materialDidactico: {
      'afip': '550000', 
      'desc': 'Conceptos No Remunerativos Varios', 
      'sub': 'No Remunerativo'
    },
    TeacherLsdCodigos.adicionalZona: {
      'afip': '110000', 
      'desc': 'Adicionales - Zona', 
      'sub': 'Remunerativo'
    },
    TeacherLsdCodigos.presentismo: {
      'afip': '110000', 
      'desc': 'Adicionales - Presentismo', 
      'sub': 'Remunerativo'
    },
    TeacherLsdCodigos.titulo: {
      'afip': '110000', 
      'desc': 'Adicionales - Título', 
      'sub': 'Remunerativo'
    },
    // === SANIDAD ===
    SanidadLsdCodigos.nocturnidad: {
      'afip': '110000', 
      'desc': 'Adicionales - Nocturnidad', 
      'sub': 'Remunerativo'
    },
    SanidadLsdCodigos.falloCaja: {
      'afip': '110000', 
      'desc': 'Adicionales - Fallo de Caja', 
      'sub': 'Remunerativo'
    },
    SanidadLsdCodigos.tareaCritica: {
      'afip': '110000', 
      'desc': 'Adicionales - Riesgo', 
      'sub': 'Remunerativo'
    },
    SanidadLsdCodigos.zonaPatagonica: {
      'afip': '110000', 
      'desc': 'Adicional Zona Desfavorable', 
      'sub': 'Remunerativo'
    },
    SanidadLsdCodigos.horasExtras50: {
      'afip': '510000', 
      'desc': 'Horas Extras 50%', 
      'sub': 'Remunerativo'
    },
    SanidadLsdCodigos.horasExtras100: {
      'afip': '520000', 
      'desc': 'Horas Extras 100%', 
      'sub': 'Remunerativo'
    },
    SanidadLsdCodigos.sacProp: {
      'afip': '120000', 
      'desc': 'SAC Proporcional', 
      'sub': 'Remunerativo'
    },
    SanidadLsdCodigos.plusVacacional: {
      'afip': '150000', 
      'desc': 'Plus Vacacional', 
      'sub': 'Remunerativo'
    },
    SanidadLsdCodigos.vacNoGozadas: {
      'afip': '150000', 
      'desc': 'Vacaciones No Gozadas', 
      'sub': 'No Remunerativo' // Suele ser no remunerativo en liquidaciones finales
    },
    SanidadLsdCodigos.preaviso: {
      'afip': '510001', 
      'desc': 'Indemnización Preaviso', 
      'sub': 'No Remunerativo'
    },
    SanidadLsdCodigos.integracionMes: {
      'afip': '510001', 
      'desc': 'Integración Mes Despido', 
      'sub': 'No Remunerativo'
    },
    SanidadLsdCodigos.seguroSepelio: {
      'afip': '810008', 
      'desc': 'Seguro Sepelio', 
      'sub': 'Descuentos'
    },
    SanidadLsdCodigos.aporteSolidario: {
      'afip': '810008', 
      'desc': 'Aporte Solidario FATSA', 
      'sub': 'Descuentos'
    },
    SanidadLsdCodigos.adelantos: {
      'afip': '810008', 
      'desc': 'Adelantos', 
      'sub': 'Descuentos'
    },
    SanidadLsdCodigos.embargos: {
      'afip': '810008', 
      'desc': 'Embargos', 
      'sub': 'Descuentos'
    },
    SanidadLsdCodigos.prestamos: {
      'afip': '810008', 
      'desc': 'Préstamos', 
      'sub': 'Descuentos'
    },
    'SAC_S_VAC': {
      'afip': '120000', 
      'desc': 'SAC sobre Vacaciones', 
      'sub': 'Remunerativo'
    },
    'SAC_S_PRE': {
      'afip': '120000', 
      'desc': 'SAC sobre Preaviso', 
      'sub': 'Remunerativo'
    },
    'OTROS_DESC': {
      'afip': '810008', 
      'desc': 'Otros Descuentos', 
      'sub': 'Descuentos'
    },
    // === COMUNES DESCUENTOS ===
    // Jubilación y Obra Social usan códigos generales (lines 75, 80)
    'LEY19032': {
      'afip': '810002', 
      'desc': 'Ley 19.032', 
      'sub': 'Descuentos/Aportes'
    },
    'CUOTA_SIND': {
      'afip': '810008', 
      'desc': 'Cuota Sindical', 
      'sub': 'Descuentos/Aportes'
    },
    'RET_GANANC': {
      'afip': '810014', 
      'desc': 'Retención Impuesto a las Ganancias', 
      'sub': 'Descuentos/Aportes'
    },
    // === SAC Y VACACIONES ===
    'SAC': {
      'afip': '120000', 
      'desc': 'Sueldo Anual Complementario', 
      'sub': 'Remunerativo'
    },
    // Vacaciones -> Usa GeneralesLsdCodigos.vacaciones
    'INDEMN_245': {
      'afip': '510001', 
      'desc': 'Indemnización Antigüedad', 
      'sub': 'Indemnizaciones'
    },
  };

  /// Genera un texto explicativo para el usuario con los códigos usados en la liquidación
  /// y su sugerencia de mapeo en AFIP.
  static String generarInstructivo(List<String> codigosUsados) {
    final sb = StringBuffer();
    sb.writeln('╔═══════════════════════════════════════════════════════════════════════╗');
    sb.writeln('║   INSTRUCTIVO DE ASOCIACIÓN DE CONCEPTOS - LIBRO DE SUELDOS DIGITAL   ║');
    sb.writeln('║   (Requerido solo la primera vez que sube estos conceptos a AFIP)     ║');
    sb.writeln('╚═══════════════════════════════════════════════════════════════════════╝');
    sb.writeln('');
    sb.writeln('IMPORTANTE: AFIP rechazará el archivo si los conceptos no están asociados.');
    sb.writeln('Ingrese a la web de AFIP > Libro de Sueldos Digital > Conceptos');
    sb.writeln('y asocie los siguientes códigos de su archivo TXT con los códigos AFIP sugeridos:');
    sb.writeln('');
    sb.writeln('CÓDIGO INTERNO'.padRight(20) + ' | ' + 'SUGERENCIA AFIP'.padRight(40) + ' | ' + 'TIPO');
    sb.writeln('-' * 80);

    for (final codigo in codigosUsados) {
      // Buscar sugerencia exacta o por coincidencia parcial
      Map<String, String>? sugerencia = _mapeoSugerido[codigo];
      
      // Si no encuentra exacto, busca genéricos por palabras clave
      if (sugerencia == null) {
        final up = codigo.toUpperCase();
        if (up.contains('ADIC') || up.contains('ANTIG')) sugerencia = _mapeoSugerido[TeacherLsdCodigos.antiguedad];
        else if (up.contains('NO_REM') || up.contains('FONID')) sugerencia = _mapeoSugerido[TeacherLsdCodigos.fonid];
        else if (up.contains('DESC') || up.contains('SIND') || up.contains('CUOTA')) sugerencia = _mapeoSugerido['CUOTA_SIND'];
        else if (up.contains('EXTR') || up.contains('EX50')) sugerencia = _mapeoSugerido[GeneralesLsdCodigos.horasExtras50];
        else if (up.contains('VAC')) sugerencia = _mapeoSugerido[GeneralesLsdCodigos.vacaciones];
        else if (up.contains('SAC') || up.contains('AGUIN')) sugerencia = _mapeoSugerido['SAC'];
        else if (up.contains('JUB')) sugerencia = _mapeoSugerido[GeneralesLsdCodigos.jubilacion];
        else if (up.contains('OBRA') || up.contains('SOC')) sugerencia = _mapeoSugerido[GeneralesLsdCodigos.obraSocial];
      }

      final afipCode = sugerencia?['afip'] ?? 'Consultar Contador';
      final desc = sugerencia?['desc'] ?? 'Concepto Específico';
      final tipo = sugerencia?['sub'] ?? 'General';
      
      final sugerenciaTexto = '$afipCode - $desc';

      sb.writeln(
        codigo.padRight(20) + ' | ' + 
        sugerenciaTexto.padRight(40).substring(0, 40) + ' | ' + 
        tipo
      );
    }

    sb.writeln('-' * 80);
    sb.writeln('');
    sb.writeln('¿QUÉ PASA SI NO LO HAGO?');
    sb.writeln('AFIP mostrará un error de "Concepto Inexistente" y no permitirá validar la liquidación.');
    sb.writeln('Una vez asociados, AFIP recordará la relación para los próximos meses.');
    
    return sb.toString();
  }
}
