// Servicio de explicaciones para conceptos comunes de recibos de sueldo argentinos
class ConceptosExplicacionesService {
  // Base de datos de explicaciones para conceptos comunes
  static final Map<String, Map<String, String>> _explicaciones = {
    // CONCEPTOS REMUNERATIVOS
    'sueldo basico': {
      'titulo': 'Sueldo Básico',
      'explicacion': 'Remuneración principal establecida en tu convenio colectivo. Es la base sobre la que se calculan la mayoría de las asignaciones y deducciones.',
      'categoria': 'remunerativo'
    },
    'horas extras': {
      'titulo': 'Horas Extras',
      'explicacion': 'Tiempo trabajado beyond tu jornada normal. Se paga con un recargo del 50% para horas extras simples y 100% para horas extras dobles.',
      'categoria': 'remunerativo'
    },
    'presentismo': {
      'titulo': 'Presentismo',
      'explicacion': 'Premio por asistencia perfecta durante el mes. Suele representar un porcentaje de tu sueldo básico (generalmente 8-12%).',
      'categoria': 'remunerativo'
    },
    'antiguedad': {
      'titulo': 'Antigüedad',
      'explicacion': 'Reconocimiento por años de servicio en la empresa. Generalmente es un porcentaje (1-2%) de tu sueldo básico por cada año de antigüedad.',
      'categoria': 'remunerativo'
    },
    'vacaciones': {
      'titulo': 'Vacaciones',
      'explicacion': 'Pago correspondiente a tu período de descanso anual. Se calcula proporcionalmente a los meses trabajados.',
      'categoria': 'remunerativo'
    },
    
    // CONCEPTOS NO REMUNERATIVOS
    'aguinaldo': {
      'titulo': 'Aguinaldo (SAC)',
      'explicacion': 'Sueldo Anual Complementario. Se paga en dos cuotas (junio y diciembre) equivalentes al 50% de la mejor remuneración de cada semestre.',
      'categoria': 'no remunerativo'
    },
    'bonificacion': {
      'titulo': 'Bonificación',
      'explicacion': 'Pago adicional no sujeto a cargas sociales. Puede ser por productividad, resultados, o otros conceptos discrecionales.',
      'categoria': 'no remunerativo'
    },
    
    // DEDUCCIONES
    'jubilacion': {
      'titulo': 'Aporte Jubilatorio',
      'explicacion': 'Contribución al sistema previsional. Es el 11% de tu remuneración bruta, con tope según escalas móviles de ANSES.',
      'categoria': 'deduccion'
    },
    'obra social': {
      'titulo': 'Aporte Obra Social',
      'explicacion': 'Contribución para tu cobertura de salud. Generalmente es el 3% de tu remuneración bruta, con tope establecido.',
      'categoria': 'deduccion'
    },
    'ley 19032': {
      'titulo': 'Ley 19.032',
      'explicacion': 'Aporte al sistema nacional de seguro de salud. Es el 3% adicional sobre tu remuneración bruta.',
      'categoria': 'deduccion'
    },
    'impuesto ganancias': {
      'titulo': 'Impuesto a las Ganancias',
      'explicacion': 'Tributo progresivo sobre tus ingresos. Se aplica según escalas de la AFIP cuando superás el mínimo no imponible.',
      'categoria': 'deduccion'
    },
    'sindicato': {
      'titulo': 'Aporte Sindical',
      'explicacion': 'Contribución a tu gremio o sindicato. Suele ser un porcentaje pequeño de tu remuneración (0.5-2%).',
      'categoria': 'deduccion'
    }
  };

  /// Obtiene la explicación para un concepto específico
  static Map<String, String>? obtenerExplicacion(String conceptoDescripcion) {
    final descripcionLower = conceptoDescripcion.toLowerCase();
    
    // Buscar coincidencias exactas primero
    for (final key in _explicaciones.keys) {
      if (descripcionLower.contains(key)) {
        return _explicaciones[key];
      }
    }
    
    // Búsqueda por palabras clave
    final palabrasClave = {
      'sueldo': 'sueldo basico',
      'horas': 'horas extras',
      'presente': 'presentismo',
      'antigüedad': 'antiguedad',
      'jubilacion': 'jubilacion',
      'obra social': 'obra social',
      'ganancias': 'impuesto ganancias',
      'sindicato': 'sindicato',
      'aguinaldo': 'aguinaldo',
      'bonus': 'bonificacion',
      'vacacion': 'vacaciones'
    };
    
    for (final palabra in palabrasClave.keys) {
      if (descripcionLower.contains(palabra)) {
        return _explicaciones[palabrasClave[palabra]];
      }
    }
    
    return null;
  }

  /// Obtiene todas las explicaciones disponibles
  static Map<String, Map<String, String>> obtenerTodasExplicaciones() {
    return _explicaciones;
  }

  /// Obtiene explicaciones por categoría
  static Map<String, Map<String, String>> obtenerExplicacionesPorCategoria(String categoria) {
    return Map.from(_explicaciones)
      ..removeWhere((key, value) => value['categoria'] != categoria);
  }
}