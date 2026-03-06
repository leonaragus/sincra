
import '../models/recibo_model.dart';
import 'claude_vision_service.dart';

/// Implementación real del servicio de CCT que consume una "base de datos" local.
/// En una app real, los `_cctData` y `_topesSalariales` provendrían de un archivo 
/// JSON, una base de datos local (Isar, Drift) o se cargarían desde `cct_argentina_completo.dart`.
class CctDatabaseService implements CctService {

  // Simulación de la base de datos de convenios que mencionaste.
  // Contiene palabras clave y reglas específicas.
  final List<Map<String, dynamic>> _cctData = [
    {
      "id": "cct130/75",
      "nombre": "Empleados de Comercio",
      "palabras_clave": ["osecac", "faecys", "sec", "130/75"],
      "reglas_retencion": {
        "jubilaci": {"min": 10.5, "max": 11.5},
        "obra_social": {"min": 2.8, "max": 3.2},
        "sindicato": {"min": 2.0, "max": 2.0}
      }
    },
    {
      "id": "fatsa",
      "nombre": "Trabajadores de Sanidad (FATSA)",
      "palabras_clave": ["fatsa", "sanidad", "cct 122/75", "cct 108/75"],
      "reglas_retencion": {
        "jubilaci": {"min": 10.5, "max": 11.5},
        "obra_social": {"min": 2.8, "max": 3.2}
      }
    },
    {
      "id": "docentes",
      "nombre": "Docentes",
      "palabras_clave": ["docente", "incentivo docente", "fonid", "material didactico"],
      "reglas_retencion": {
        // Las reglas de los docentes son muy variables y provinciales. 
        // Se usan rangos más amplios para evitar falsos positivos.
        "jubilaci": {"min": 10.5, "max": 18.0}, // IPS, etc., pueden tener aportes mayores.
        "obra_social": {"min": 3.0, "max": 6.0} // IOMA, etc., suelen tener aportes mayores.
      }
    },
    {
      "id": "cct637/11",
      "nombre": "Petroleros Jerárquicos (CCT 637/11)",
      "palabras_clave": ["cct 637", "sjpj"],
       "reglas_retencion": {
        "jubilaci": {"min": 11.0, "max": 19.0},
        "obra_social": {"min": 3.0, "max": 4.5}
      }
    }
  ];

  // Simulación de una tabla de topes previsionales históricos.
  final Map<String, double> _topesSalariales = {
    "2017-11": 72289.33,
    "2023-09": 875355.99,
    "2024-03": 1570000.0, // Ejemplo
  };
  
  @override
  InfoCCT identificarCCT(String descripciones, String? categoria) {
    for (var cct in _cctData) {
      List<String> keywords = List<String>.from(cct['palabras_clave']);
      if (keywords.any((keyword) => descripciones.contains(keyword))) {
        return InfoCCT(id: cct['id'], nombre: cct['nombre'], confianza: "Alta");
      }
    }
    if (categoria != null && (categoria.contains('gerente') || categoria.contains('jefe'))) {
      return InfoCCT(id: 'fuera_convenio', nombre: 'Personal Fuera de Convenio', confianza: 'Alta');
    }
    return InfoCCT(id: 'desconocido', nombre: 'No identificado', confianza: 'Baja');
  }

  @override
  ReglaRetencion obtenerReglasRetencion(String cctId, String retencionKey) {
    final cct = _cctData.firstWhere((c) => c['id'] == cctId, orElse: () => {});
    if (cct.isNotEmpty && cct.containsKey('reglas_retencion')) {
      final reglas = cct['reglas_retencion'][retencionKey];
      if (reglas != null) {
        return ReglaRetencion(min: reglas['min'], max: reglas['max']);
      }
    }
    // Reglas por defecto si el CCT o la regla no están en nuestra BD.
    if (retencionKey == 'jubilaci') return ReglaRetencion(min: 10.5, max: 11.5);
    if (retencionKey == 'obra_social') return ReglaRetencion(min: 2.8, max: 3.2);
    return ReglaRetencion(min: 0, max: 100);
  }

  @override
  double obtenerTopePrevisional(String? periodo) {
    // En una implementación real, esto parsearía el mes y año del período
    // para buscar en la tabla de topes. Por ahora, mantiene la lógica simple.
    if (periodo?.toLowerCase().contains('noviembre 2017') ?? false) {
      return _topesSalariales["2017-11"] ?? 72289.33;
    }
    // Devuelve el último tope conocido como default
    return _topesSalariales.values.last;
  }

  @override
  String? obtenerExplicacionAmigable(String descripcion, String cctId) {
    // Aquí iría la lógica para buscar en la base de datos una explicación 
    // específica para un concepto de un convenio (ej: "Adicional por Turno Noche" 
    // en Petroleros). Por ahora, devolvemos null para que el motor use la lógica genérica.
    return null;
  }
}
