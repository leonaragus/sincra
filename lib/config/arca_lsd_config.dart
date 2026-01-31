/// Configuración del motor de exportación ARCA LSD (Enero 2026)
/// 
/// Este archivo contiene la configuración técnica oficial para la generación
/// de archivos LSD según las especificaciones de ARCA para enero 2026.
class ArcaLsdConfig {
  /// Configuración general del formato LSD
  static const Map<String, dynamic> configuracionEnero2026 = {
    'tope_base_imponible_max': 2500000.00,
    'tope_base_imponible_min': 85000.00,
    'formato_archivo': 'Longitud fija 150 caracteres',
    'codificacion': 'Windows-1252 (ANSI)',
  };

  /// Mapeo de conceptos internos a códigos AFIP oficiales
  /// 
  /// Cada entrada contiene:
  /// - interno: Nombre del concepto en el sistema interno
  /// - afip: Código AFIP oficial de 6 dígitos
  /// - tipo: Tipo de concepto (Remunerativo, No Remunerativo, Descuento)
  /// - aporta_jub: Si aporta a jubilación
  /// - aporta_os: Si aporta a obra social
  static const List<Map<String, dynamic>> mapeoConceptosOficiales = [
    {
      'interno': 'Sueldo Básico',
      'afip': '011000',
      'tipo': 'Remunerativo',
      'aporta_jub': true,
      'aporta_os': true,
    },
    {
      'interno': 'Antigüedad',
      'afip': '012000',
      'tipo': 'Remunerativo',
      'aporta_jub': true,
      'aporta_os': true,
    },
    {
      'interno': 'Adicionales',
      'afip': '011000',
      'tipo': 'Remunerativo',
      'aporta_jub': true,
      'aporta_os': true,
    },
    {
      'interno': 'Horas Extras',
      'afip': '051000',
      'tipo': 'Remunerativo',
      'aporta_jub': true,
      'aporta_os': true,
    },
    {
      'interno': 'SAC (Aguinaldo)',
      'afip': '031000',
      'tipo': 'Remunerativo',
      'aporta_jub': true,
      'aporta_os': true,
    },
    {
      'interno': 'Vacaciones',
      'afip': '015000',
      'tipo': 'Remunerativo',
      'aporta_jub': true,
      'aporta_os': true,
    },
    {
      'interno': 'Jubilación',
      'afip': '810000',
      'tipo': 'Descuento',
      'aporta_jub': false,
      'aporta_os': false,
    },
    {
      'interno': 'Obra Social',
      'afip': '810000',
      'tipo': 'Descuento',
      'aporta_jub': false,
      'aporta_os': false,
    },
    {
      'interno': 'Ley 19032',
      'afip': '810000',
      'tipo': 'Descuento',
      'aporta_jub': false,
      'aporta_os': false,
    },
    {
      'interno': 'Cuota Sindical',
      'afip': '820000',
      'tipo': 'Descuento',
      'aporta_jub': false,
      'aporta_os': false,
    },
    {
      'interno': 'Asig. Familiares',
      'afip': '111000',
      'tipo': 'No Remunerativo',
      'aporta_jub': false,
      'aporta_os': false,
    },
  ];

  /// Obtiene el código AFIP para un concepto interno
  /// 
  /// [conceptoInterno] - Nombre del concepto en el sistema interno
  /// 
  /// Retorna el código AFIP de 6 dígitos o null si no se encuentra
  static String? obtenerCodigoAfip(String conceptoInterno) {
    final concepto = mapeoConceptosOficiales.firstWhere(
      (c) => c['interno'] == conceptoInterno,
      orElse: () => {},
    );
    
    if (concepto.isEmpty) {
      return null;
    }
    
    return concepto['afip'] as String?;
  }

  /// Obtiene la información completa de un concepto por su nombre interno
  /// 
  /// [conceptoInterno] - Nombre del concepto en el sistema interno
  /// 
  /// Retorna un mapa con toda la información del concepto o null si no se encuentra
  static Map<String, dynamic>? obtenerConcepto(String conceptoInterno) {
    try {
      final concepto = mapeoConceptosOficiales.firstWhere(
        (c) => c['interno'] == conceptoInterno,
      );
      return Map<String, dynamic>.from(concepto);
    } catch (e) {
      return null;
    }
  }

  /// Obtiene el código AFIP para un concepto por coincidencia parcial
  /// Útil para conceptos con variaciones en el nombre
  /// 
  /// [conceptoInterno] - Nombre del concepto (puede ser parcial)
  /// 
  /// Retorna el código AFIP de 6 dígitos o null si no se encuentra
  static String? obtenerCodigoAfipPorCoincidencia(String conceptoInterno) {
    final conceptoLower = conceptoInterno.toLowerCase().trim();
    
    for (final concepto in mapeoConceptosOficiales) {
      final internoLower = (concepto['interno'] as String).toLowerCase();
      
      // Coincidencia exacta
      if (internoLower == conceptoLower) {
        return concepto['afip'] as String;
      }
      
      // Coincidencia parcial (el concepto interno contiene el buscado o viceversa)
      if (internoLower.contains(conceptoLower) || conceptoLower.contains(internoLower)) {
        return concepto['afip'] as String;
      }
    }
    
    return null;
  }

  /// Valida si un monto está dentro de los topes de base imponible
  /// 
  /// [monto] - Monto a validar
  /// [topeMin] - Opcional. Tope mínimo específico para la validación. Si es null usa el global.
  /// [topeMax] - Opcional. Tope máximo específico para la validación. Si es null usa el global.
  /// 
  /// Retorna true si está dentro de los límites, false en caso contrario
  static bool validarTopeBaseImponible(double monto, {double? topeMin, double? topeMax}) {
    final min = topeMin ?? configuracionEnero2026['tope_base_imponible_min'] as double;
    final max = topeMax ?? configuracionEnero2026['tope_base_imponible_max'] as double;
    
    return monto >= min && monto <= max;
  }

  /// Obtiene el tope máximo de base imponible
  static double get topeBaseImponibleMax {
    return configuracionEnero2026['tope_base_imponible_max'] as double;
  }

  /// Obtiene el tope mínimo de base imponible
  static double get topeBaseImponibleMin {
    return configuracionEnero2026['tope_base_imponible_min'] as double;
  }

  /// Obtiene la codificación del archivo
  static String get codificacion {
    return configuracionEnero2026['codificacion'] as String;
  }

  /// Obtiene el formato del archivo
  static String get formatoArchivo {
    return configuracionEnero2026['formato_archivo'] as String;
  }
}
