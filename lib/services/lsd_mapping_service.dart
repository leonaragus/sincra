
import 'teacher_lsd_export.dart';
import 'sanidad_lsd_export.dart';

/// Servicio para generar guías de mapeo de conceptos para AFIP LSD
/// Ayuda al usuario a asociar los conceptos la primera vez que sube el archivo
class LsdMappingService {
  
  /// Estructura de sugerencia de mapeo
  static const Map<String, Map<String, String>> _mapeoSugerido = {
    // === DOCENTES ===
    TeacherLsdCodigos.sueldoBasico: {
      'afip': '110000', 
      'desc': 'Sueldo', 
      'sub': 'Remunerativo'
    },
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
    // === COMUNES DESCUENTOS ===
    'JUBILACION': {
      'afip': '810002', 
      'desc': 'Jubilación', 
      'sub': 'Descuentos/Aportes'
    },
    'OBRA_SOC': {
      'afip': '810003', 
      'desc': 'Obra Social', 
      'sub': 'Descuentos/Aportes'
    },
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
    'VACACIONES': {
      'afip': '150000', 
      'desc': 'Vacaciones', 
      'sub': 'Remunerativo'
    },
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
      
      // Si no encuentra exacto, busca genéricos
      if (sugerencia == null) {
        if (codigo.contains('ADIC')) sugerencia = _mapeoSugerido[TeacherLsdCodigos.antiguedad];
        else if (codigo.contains('NO_REM')) sugerencia = _mapeoSugerido[TeacherLsdCodigos.fonid];
        else if (codigo.contains('DESC')) sugerencia = _mapeoSugerido['CUOTA_SIND'];
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
