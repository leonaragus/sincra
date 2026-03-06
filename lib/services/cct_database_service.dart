
/// Base de datos y lógica para identificar Convenios Colectivos de Trabajo (CCT).
/// v3.0 - Simplificado para tener una única responsabilidad: IDENTIFICAR.
/// La lógica de explicaciones fue migrada a EducationalConceptsService.
class CctDatabaseService {

  // --- BASE DE DATOS DE IDENTIFICACIÓN DE CCTs ---
  static final Map<List<String>, InfoCCT> _cctDb = {
    ['uocra', 'construccion', 'i.e.r.i.c', 'ley 22.250']: InfoCCT(id: "uocra", nombre: "UOCRA (Construcción)", confianza: "Alta"),
    ['comercio', 'faecys', 'osecac', 'cct130/75', 'cct 130/75']: InfoCCT(id: "comercio", nombre: "Empleados de Comercio", confianza: "Alta"),
    ['gastronomico', 'uthgra', 'cct 389/2004']: InfoCCT(id: "gastronomico", nombre: "Gastronómicos (UTHGRA)", confianza: "Alta"),
    ['sanidad', 'atsa', 'cct 122/75']: InfoCCT(id: "sanidad", nombre: "Sanidad (ATSA)", confianza: "Alta"),
    ['metalurgico', 'uom', 'cct 260/75']: InfoCCT(id: "metalurgico", nombre: "Metalúrgicos (UOM)", confianza: "Alta"),
    ['camioneros', 'cct 40/89', 'cct40/89', 'sichoca']: InfoCCT(id: "camioneros", nombre: "Camioneros (CCT 40/89)", confianza: "Alta"),
    ['petroleros', 'cct 637/11', 'cct637']: InfoCCT(id: "petroleros", nombre: "Petroleros Jerárquicos", confianza: "Alta")
  };

  InfoCCT identificarCCT(String descripciones, String? categoria) {
    final texto = "$descripciones ${categoria ?? ''}".toLowerCase();
    for (var entry in _cctDb.entries) {
      for (var keyword in entry.key) {
        if (texto.contains(keyword)) {
          return entry.value;
        }
      }
    }
    return InfoCCT(id: "unknown", nombre: "No identificado", confianza: "Baja");
  }

  // --- La lógica de reglas de retención y topes sigue aquí, ya que es específica del CCT ---
  ReglaRetencion obtenerReglasRetencion(String cctId, String retencionKey) {
      // Aquí iría la lógica específica de cada CCT para los porcentajes
      if (retencionKey == 'jubilaci') return ReglaRetencion(min: 11.0, max: 12.0);
      if (retencionKey == 'obra social') return ReglaRetencion(min: 3.0, max: 3.5);
      return ReglaRetencion(min: 0, max: 100); 
  }

  double obtenerTopePrevisional(String? periodo) {
    // Lógica existente para obtener topes previsionales...
    return 1128755.6; // Ejemplo de tope para el cálculo
  }
}
