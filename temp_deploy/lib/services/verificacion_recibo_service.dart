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

class VerificacionReciboService {
  /// Parsea el texto crudo del OCR y lo convierte en un objeto [ReciboEscaneado].
  ///
  /// **Esta es la parte más compleja y requiere un ajuste fino.**
  /// Deberás usar expresiones regulares (RegEx) para identificar patrones
  /// en el texto del recibo y extraer los conceptos y montos.
  Future<ReciboEscaneado> parsearTextoOcr(String textoCrudo) async {
    // Lógica de parsing (ejemplo muy básico)
    // Deberás reemplazar esto con RegEx robustas.
    final conceptos = <ConceptoRecibo>[];
    final lineas = textoCrudo.split('\n');

    // Ejemplo de RegEx para buscar "Sueldo Básico" y un monto
    final regExSueldo = RegExp(r'sueldo basico\s+([\d.,]+)', caseSensitive: false);

    for (final linea in lineas) {
      // Aquí iría la lógica para identificar cada concepto
      if (regExSueldo.hasMatch(linea)) {
        final match = regExSueldo.firstMatch(linea);
        final montoStr = match?.group(1)?.replaceAll('.', '').replaceAll(',', '.');
        final monto = double.tryParse(montoStr ?? '0') ?? 0.0;
        conceptos.add(ConceptoRecibo(descripcion: 'Sueldo Básico', remunerativo: monto));
      }
      // ... más RegEx para otros conceptos (antigüedad, presentismo, jubilación, etc.)
    }

    // Calcular totales (esto también debería salir del parsing)
    final totalRemunerativo = conceptos.where((c) => c.remunerativo != null).fold(0.0, (sum, c) => sum + c.remunerativo!);
    // ... calcular otros totales

    return ReciboEscaneado(
      conceptos: conceptos,
      totalRemunerativo: totalRemunerativo,
    );
  }

  /// Compara un [ReciboEscaneado] con las reglas de un [CctSimplificado].
  Future<ResultadoVerificacion> verificarRecibo(
      ReciboEscaneado recibo, CctSimplificado cct) async {
    final inconsistencias = <String>[];
    final sugerencias = <String>[];

    // 1. Encontrar el sueldo bruto del recibo escaneado
    final sueldoBrutoEscaneado = recibo.totalRemunerativo;
    if (sueldoBrutoEscaneado <= 0) {
      inconsistencias.add("No se pudo determinar el Sueldo Bruto del recibo.");
      return ResultadoVerificacion(esCorrecto: false, inconsistencias: inconsistencias);
    }

    // 2. Recalcular las deducciones según el CCT
    final jubilacionCalculada = sueldoBrutoEscaneado * (cct.jubilacionPct / 100);
    final ley19032Calculada = sueldoBrutoEscaneado * (cct.ley19032Pct / 100);
    final obraSocialCalculada = sueldoBrutoEscaneado * (cct.obraSocialPct / 100);

    // 3. Comparar con los valores escaneados
    _compararConcepto(
      recibo: recibo,
      descripcionConcepto: 'Jubilación', // O como aparezca en el recibo
      valorCalculado: jubilacionCalculada,
      inconsistencias: inconsistencias,
    );
    // ... (Repetir para Ley 19.032 y Obra Social)

    // 4. Verificar el sueldo básico contra la categoría del CCT (lógica más avanzada)
    sugerencias.add("Verifica que tu sueldo básico coincida con la categoría de tu convenio.");

    return ResultadoVerificacion(
      esCorrecto: inconsistencias.isEmpty,
      inconsistencias: inconsistencias,
      sugerencias: sugerencias,
    );
  }

  void _compararConcepto({
    required ReciboEscaneado recibo,
    required String descripcionConcepto,
    required double valorCalculado,
    required List<String> inconsistencias,
  }) {
    // ... (Lógica de comparación como en el plan)
  }
}