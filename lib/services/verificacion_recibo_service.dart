import 'package:syncra_arg/models/recibo_escaneado.dart';

// Representación simplificada de un CCT. Deberías usar tu modelo `Cct` real.
class CctSimplificado {
  final String nombre;
  final double jubilacionPct;
  final double ley19032Pct;
  final double obraSocialPct;
  // ... otros campos como cuota sindical, etc.

  CctSimplificado({
    required this.nombre,
    this.jubilacionPct = 11.0,
    this.ley19032Pct = 3.0,
    this.obraSocialPct = 3.0,
  });
}

class ResultadoVerificacion {
  final bool esCorrecto;
  final List<String> inconsistencias;
  final List<String> sugerencias;

  ResultadoVerificacion({
    this.esCorrecto = true,
    this.inconsistencias = const [],
    this.sugerencias = const [],
  });
}

// Clase para almacenar todos los patterns OCR de recibos argentinos
class ReceiptOCRPatterns {
  static final Map<String, RegExp> patterns = {
    // Conceptos Remunerativos
    'sueldo_basico': RegExp(
      r'SUELDO\s*BÁSICO|SUELDO\s*BASICO|S\.\s*BÁSICO[\s:]*([\d.,]+)',
      caseSensitive: false,
      multiLine: true,
    ),
    'antiguedad': RegExp(
      r'ANTIGÜEDAD|ANTIGUEDAD|SENIORIDAD[\s:]*([\d.,]+)',
      caseSensitive: false,
      multiLine: true,
    ),
    'presentismo': RegExp(
      r'PRESENTISMO|ASISTENCIA|INASISTENCIA[\s:]*([\d.,]+)',
      caseSensitive: false,
      multiLine: true,
    ),
    'horas_extras': RegExp(
      r'HORAS\s*EXTRAS|H\.\s*EXTRAS|HS\.\s*EXTRAS[\s:]*([\d.,]+)',
      caseSensitive: false,
      multiLine: true,
    ),
    'feriados': RegExp(
      r'FERIADO|FERIADOS|DIAS\s*FERIADOS[\s:]*([\d.,]+)',
      caseSensitive: false,
      multiLine: true,
    ),
    'vacaciones': RegExp(
      r'VACACIONES|VACACION[\s:]*([\d.,]+)',
      caseSensitive: false,
      multiLine: true,
    ),
    'sac': RegExp(
      r'S\.A\.C\.|SAC|SUELDO\s*ANUAL\s*COMPLEMENTARIO|AGUINALDO[\s:]*([\d.,]+)',
      caseSensitive: false,
      multiLine: true,
    ),
    'adicionales': RegExp(
      r'ADICIONAL|ADICIONALES[\s:]*([\d.,]+)',
      caseSensitive: false,
      multiLine: true,
    ),
    'titulo': RegExp(
      r'TÍTULO|TITULO|HABILITACIÓN[\s:]*([\d.,]+)',
      caseSensitive: false,
      multiLine: true,
    ),
    'funcion': RegExp(
      r'FUNCIÓN|FUNCION|RESPONSABILIDAD[\s:]*([\d.,]+)',
      caseSensitive: false,
      multiLine: true,
    ),
    'zona': RegExp(
      r'ZONA|ZONAL[\s:]*([\d.,]+)',
      caseSensitive: false,
      multiLine: true,
    ),
    
    // Conceptos No Remunerativos
    'no_remunerativo': RegExp(
      r'NO\s*REMUNERATIVO|CONCEPTO\s*NO\s*REMUNERATIVO[\s:]*([\d.,]+)',
      caseSensitive: false,
      multiLine: true,
    ),
    'ayuda_escolar': RegExp(
      r'AYUDA\s*ESCOLAR|AUXILIO\s*ESCOLAR[\s:]*([\d.,]+)',
      caseSensitive: false,
      multiLine: true,
    ),
    
    // Deducciones Personales
    'jubilacion': RegExp(
      r'JUBILACIÓN|JUBILACION|APORTE\s*JUBILATORIO|JUBILACIÓN\s*11%|JUBILACION\s*11%[\s:]*([\d.,]+)',
      caseSensitive: false,
      multiLine: true,
    ),
    'ley_19032': RegExp(
      r'LEY\s*19032|Ley\s*19032|LEY\s*19\.032|19\.032[\s:]*([\d.,]+)',
      caseSensitive: false,
      multiLine: true,
    ),
    'obra_social': RegExp(
      r'OBRA\s*SOCIAL|O\.\s*S\.|OS|PAMI|OBRA\s*SOCIAL\s*3%|OBRA\s*SOCIAL\s*3\s*%[\s:]*([\d.,]+)',
      caseSensitive: false,
      multiLine: true,
    ),
    'cuota_sindical': RegExp(
      r'CUOTA\s*SINDICAL|SINDICATO|C\.\s*SINDICAL[\s:]*([\d.,]+)',
      caseSensitive: false,
      multiLine: true,
    ),
    'ganancias': RegExp(
      r'GANANCIAS|RETENCIÓN\s*GANANCIAS|IMPUESTO\s*GANANCIAS[\s:]*([\d.,]+)',
      caseSensitive: false,
      multiLine: true,
    ),
    
    // Totales
    'total_remunerativo': RegExp(
      r'TOTAL\s*REMUNERATIVO|TOTAL\s*HABERES|TOTAL\s*REMUNERATIVOS[\s:]*([\d.,]+)',
      caseSensitive: false,
      multiLine: true,
    ),
    'total_no_remunerativo': RegExp(
      r'TOTAL\s*NO\s*REMUNERATIVO|TOTAL\s*NO\s*REMUNERATIVOS[\s:]*([\d.,]+)',
      caseSensitive: false,
      multiLine: true,
    ),
    'total_deducciones': RegExp(
      r'TOTAL\s*DEDUCCIONES|TOTAL\s*DESCUENTOS|DEDUCCIONES\s*TOTALES[\s:]*([\d.,]+)',
      caseSensitive: false,
      multiLine: true,
    ),
    'sueldo_neto': RegExp(
      r'SUELDO\s*NETO|NETO\s*A\s*COBRAR|NETO\s*PAGADO|LÍQUIDO|TOTAL\s*NETO[\s:]*([\d.,]+)',
      caseSensitive: false,
      multiLine: true,
    ),
    
    // Datos del empleado/empleador
    'nombre_empleado': RegExp(
      r'NOMBRE\s*Y\s*APELLIDO|APELLIDO\s*Y\s*NOMBRE|EMPLEADO[\s:]*([A-Za-z\s]+)',
      caseSensitive: false,
      multiLine: true,
    ),
    'cuit_empleado': RegExp(
      r'C\.U\.I\.T\.|CUIT|C\.U\.I\.L\.|CUIL[\s:]*([\d-]+)',
      caseSensitive: false,
      multiLine: true,
    ),
    'periodo': RegExp(
      r'PERIODO|PERIODO\s*LIQUIDADO|MES|AÑO[\s:]*([A-Za-z\s\d/]+)',
      caseSensitive: false,
      multiLine: true,
    ),
    'fecha_liquidacion': RegExp(
      r'FECHA\s*LIQUIDACIÓN|FECHA\s*DE\s*LIQUIDACIÓN|LIQUIDADO\s*EL[\s:]*([\d/]+)',
      caseSensitive: false,
      multiLine: true,
    ),
  };
  
  /// Valida si el texto contiene elementos de un recibo válido
  static bool esReciboValido(String texto) {
    final textoLower = texto.toLowerCase();
    
    // Debe contener al menos 3 de estos elementos para ser un recibo válido
    final elementosClave = [
      'sueldo',
      'recibo',
      'liquidación',
      'haberes',
      'remunerativo',
      'neto',
      'cuit',
      'cuil',
      'empleado',
      'antigüedad'
    ];
    
    int coincidencias = 0;
    for (final elemento in elementosClave) {
      if (textoLower.contains(elemento)) {
        coincidencias++;
      }
    }
    
    // También debe tener números (montos)
    final tieneNumeros = RegExp(r'\d+[\d.,]*').hasMatch(texto);
    
    return coincidencias >= 3 && tieneNumeros;
  }
  
  /// Extrae monto de una línea usando regex
  static double? extraerMonto(String texto, RegExp regex) {
    final match = regex.firstMatch(texto);
    if (match != null && match.groupCount >= 1) {
      final montoStr = match.group(1)?.replaceAll('.', '').replaceAll(',', '.');
      return double.tryParse(montoStr ?? '');
    }
    return null;
  }
  
  /// Busca conceptos en todo el texto, no solo por línea
  static Map<String, double> buscarConceptos(String texto) {
    final resultados = <String, double>{};
    
    for (final entry in patterns.entries) {
      final concepto = entry.key;
      final regex = entry.value;
      
      // Buscar todas las ocurrencias
      final matches = regex.allMatches(texto);
      double suma = 0.0;
      
      for (final match in matches) {
        if (match.groupCount >= 1) {
          final montoStr = match.group(1)?.replaceAll('.', '').replaceAll(',', '.');
          final monto = double.tryParse(montoStr ?? '');
          if (monto != null && monto > 0) {
            suma += monto;
          }
        }
      }
      
      if (suma > 0) {
        resultados[concepto] = suma;
      }
    }
    
    return resultados;
  }
}

class VerificacionReciboService {
  /// Parsea el texto crudo del OCR y lo convierte en un objeto [ReciboEscaneado].
  /// Utiliza patrones avanzados para detectar todos los conceptos de recibos argentinos.
  Future<ReciboEscaneado> parsearTextoOcr(String textoCrudo) async {
    final conceptos = <ConceptoRecibo>[];
    
    // Primero validamos que sea un recibo válido
    if (!ReceiptOCRPatterns.esReciboValido(textoCrudo)) {
      throw Exception('El texto escaneado no parece ser un recibo de sueldo válido');
    }
    
    // Buscar todos los conceptos usando los patrones avanzados
    final conceptosEncontrados = ReceiptOCRPatterns.buscarConceptos(textoCrudo);
    
    // Convertir conceptos encontrados a objetos ConceptoRecibo
    for (final entry in conceptosEncontrados.entries) {
      final tipoConcepto = entry.key;
      final monto = entry.value;
      
      // Clasificar el concepto
      if (_esRemunerativo(tipoConcepto)) {
        conceptos.add(ConceptoRecibo(
          descripcion: _getDescripcionConcepto(tipoConcepto),
          remunerativo: monto,
        ));
      } else if (_esNoRemunerativo(tipoConcepto)) {
        conceptos.add(ConceptoRecibo(
          descripcion: _getDescripcionConcepto(tipoConcepto),
          noRemunerativo: monto,
        ));
      } else if (_esDeduccion(tipoConcepto)) {
        conceptos.add(ConceptoRecibo(
          descripcion: _getDescripcionConcepto(tipoConcepto),
          deducciones: monto,
        ));
      }
    }
    
    // Si no encontramos conceptos, intentar parsing por líneas como fallback
    if (conceptos.isEmpty) {
      return _parsearPorLineas(textoCrudo);
    }
    
    // Calcular totales
    double totalRemunerativo = 0.0;
    double totalNoRemunerativo = 0.0;
    double totalDeducciones = 0.0;
    
    for (final concepto in conceptos) {
      if (concepto.remunerativo != null) {
        totalRemunerativo += concepto.remunerativo!;
      }
      if (concepto.noRemunerativo != null) {
        totalNoRemunerativo += concepto.noRemunerativo!;
      }
      if (concepto.deducciones != null) {
        totalDeducciones += concepto.deducciones!;
      }
    }
    
    // Intentar encontrar el neto específicamente si no está calculado
    double sueldoNeto = totalRemunerativo + totalNoRemunerativo - totalDeducciones;
    if (conceptosEncontrados.containsKey('sueldo_neto')) {
      sueldoNeto = conceptosEncontrados['sueldo_neto']!;
    }
    
    return ReciboEscaneado(
      conceptos: conceptos,
      totalRemunerativo: totalRemunerativo,
      totalNoRemunerativo: totalNoRemunerativo,
      totalDeducciones: totalDeducciones,
      sueldoNeto: sueldoNeto,
    );
  }
  
  /// Método fallback para parsing por líneas si los patrones no funcionan
  Future<ReciboEscaneado> _parsearPorLineas(String textoCrudo) async {
    final conceptos = <ConceptoRecibo>[];
    final lineas = textoCrudo.split('\n');
    
    for (final linea in lineas) {
      final lineaLimpia = linea.trim();
      if (lineaLimpia.isEmpty) continue;
      
      // Intentar detectar patrones básicos por línea
      for (final entry in ReceiptOCRPatterns.patterns.entries) {
        final monto = ReceiptOCRPatterns.extraerMonto(lineaLimpia, entry.value);
        if (monto != null && monto > 0) {
          final tipoConcepto = entry.key;
          
          if (_esRemunerativo(tipoConcepto)) {
            conceptos.add(ConceptoRecibo(
              descripcion: _getDescripcionConcepto(tipoConcepto),
              remunerativo: monto,
            ));
          } else if (_esNoRemunerativo(tipoConcepto)) {
            conceptos.add(ConceptoRecibo(
              descripcion: _getDescripcionConcepto(tipoConcepto),
              noRemunerativo: monto,
            ));
          } else if (_esDeduccion(tipoConcepto)) {
            conceptos.add(ConceptoRecibo(
              descripcion: _getDescripcionConcepto(tipoConcepto),
              deducciones: monto,
            ));
          }
          break; // Pasar a la siguiente línea
        }
      }
    }
    
    // Calcular totales
    double totalRemunerativo = 0.0;
    double totalNoRemunerativo = 0.0;
    double totalDeducciones = 0.0;
    
    for (final concepto in conceptos) {
      if (concepto.remunerativo != null) {
        totalRemunerativo += concepto.remunerativo!;
      }
      if (concepto.noRemunerativo != null) {
        totalNoRemunerativo += concepto.noRemunerativo!;
      }
      if (concepto.deducciones != null) {
        totalDeducciones += concepto.deducciones!;
      }
    }
    
    return ReciboEscaneado(
      conceptos: conceptos,
      totalRemunerativo: totalRemunerativo,
      totalNoRemunerativo: totalNoRemunerativo,
      totalDeducciones: totalDeducciones,
      sueldoNeto: totalRemunerativo + totalNoRemunerativo - totalDeducciones,
    );
  }
  
  /// Determina si un concepto es remunerativo
  bool _esRemunerativo(String tipoConcepto) {
    final conceptosRemunerativos = {
      'sueldo_basico',
      'antiguedad',
      'presentismo',
      'horas_extras',
      'feriados',
      'vacaciones',
      'sac',
      'adicionales',
      'titulo',
      'funcion',
      'zona',
    };
    return conceptosRemunerativos.contains(tipoConcepto);
  }
  
  /// Determina si un concepto es no remunerativo
  bool _esNoRemunerativo(String tipoConcepto) {
    final conceptosNoRemunerativos = {
      'no_remunerativo',
      'ayuda_escolar',
    };
    return conceptosNoRemunerativos.contains(tipoConcepto);
  }
  
  /// Determina si un concepto es deducción
  bool _esDeduccion(String tipoConcepto) {
    final conceptosDeduccion = {
      'jubilacion',
      'ley_19032',
      'obra_social',
      'cuota_sindical',
      'ganancias',
    };
    return conceptosDeduccion.contains(tipoConcepto);
  }
  
  /// Obtiene descripción legible del concepto
  String _getDescripcionConcepto(String tipoConcepto) {
    final mapaDescripciones = {
      'sueldo_basico': 'Sueldo Básico',
      'antiguedad': 'Antigüedad',
      'presentismo': 'Presentismo',
      'horas_extras': 'Horas Extras',
      'feriados': 'Feriados',
      'vacaciones': 'Vacaciones',
      'sac': 'S.A.C. (Aguinaldo)',
      'adicionales': 'Adicionales',
      'titulo': 'Título/Habilitación',
      'funcion': 'Función',
      'zona': 'Zona',
      'no_remunerativo': 'Concepto No Remunerativo',
      'ayuda_escolar': 'Ayuda Escolar',
      'jubilacion': 'Jubilación (11%)',
      'ley_19032': 'Ley 19.032',
      'obra_social': 'Obra Social (3%)',
      'cuota_sindical': 'Cuota Sindical',
      'ganancias': 'Retención Ganancias',
    };
    return mapaDescripciones[tipoConcepto] ?? tipoConcepto;
  }
}