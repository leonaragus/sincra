import 'package:flutter/material.dart';

/// v3.0 - EL CEREBRO CENTRAL DEL CONOCIMIENTO LABORAL
/// Unifica todas las explicaciones de conceptos, tanto generales como específicos de CCTs.
/// Esta es ahora la ÚNICA fuente de verdad para las "traducciones humanas".
class EducationalConceptsService {

  static final Map<String, ConceptExplanation> _explanationsDb = {
    // --- CONCEPTOS UNIVERSALES ---
    "jubilacion": ConceptExplanation(
      title: "Jubilación",
      icon: Icons.account_balance,
      explanation: "Es tu aporte mensual para construir tu futura jubilación. Por ley, generalmente es el 11% de tu sueldo bruto (remunerativo).",
    ),
    "obra social": ConceptExplanation(
      title: "Obra Social",
      icon: Icons.local_hospital,
      explanation: "Es tu aporte para garantizar tu cobertura de salud y la de tu familia. Usualmente es el 3% de tu sueldo bruto.",
    ),
    "ley 19032": ConceptExplanation(
      title: "Aporte al PAMI (Ley 19.032)",
      icon: Icons.health_and_safety,
      explanation: "Es un aporte solidario de todos los trabajadores al PAMI, la obra social de los jubilados. Equivale al 3% de tu sueldo bruto.",
    ),
    "antiguedad": ConceptExplanation(
      title: "Adicional por Antigüedad",
      icon: Icons.military_tech,
      explanation: "¡Un premio a tu lealtad! Es un porcentaje que se suma a tu sueldo por cada año que llevas en la empresa. El porcentaje exacto lo define tu convenio.",
    ),
    "presentismo": ConceptExplanation(
      title: "Presentismo o Asistencia Perfecta",
      icon: Icons.check_circle,
      explanation: "¡Felicitaciones! Es un premio económico por no haber faltado. Generalmente es un porcentaje fijo de tu básico o una suma fija, según tu convenio.",
    ),
    "feriado": ConceptExplanation(
      title: "Feriado Trabajado",
      icon: Icons.celebration,
      explanation: "¡Bien hecho! Si trabajaste un feriado, la ley dice que te lo deben pagar doble. Por eso ves este monto extra.",
    ),
    "horas extras": ConceptExplanation(
      title: "Horas Extras",
      icon: Icons.add_alarm,
      explanation: "Es el pago por el tiempo extra que trabajaste. Las que son al 50% valen una vez y media una hora normal, y las del 100% (fines de semana o feriados) valen el doble.",
    ),
    "aporte sindical": ConceptExplanation(
      title: "Cuota Sindical",
      icon: Icons.groups,
      explanation: "Si estás afiliado, este es tu aporte al sindicato que te representa y defiende tus derechos. El porcentaje lo define el gremio.",
    ),
    "seguro de sepelio": ConceptExplanation(
      title: "Seguro de Vida o Sepelio",
      icon: Icons.shield,
      explanation: "Es un pequeño aporte que muchos convenios incluyen para darte a vos y tu familia una cobertura esencial en los momentos más difíciles.",
    ),

    // --- CONCEPTOS DE EGRESO (LIQUIDACIÓN FINAL) ---
    "indemniz": ConceptExplanation(
      title: "Indemnización",
      icon: Icons.rocket_launch,
      explanation: "🌟 Este es el pago fuerte de tu salida. Entra 'limpia' a tu bolsillo, sin descuentos de jubilación ni obra social.",
    ),
     "vac no goz": ConceptExplanation(
      title: "Vacaciones No Gozadas",
      icon: Icons.beach_access,
      explanation: "🏖️ La ley es clara: las vacaciones que te quedaban pendientes y no te tomaste, te las tienen que pagar en efectivo al irte.",
    ),

    // --- CONCEPTOS ESPECÍFICOS DE CCTs ---
    // Camioneros (CCT 40/89)
    "pernoctada": ConceptExplanation(
        title: "Pernoctada",
        icon: Icons.hotel,
        explanation: "Es el pago por las noches que pasaste fuera de casa por tu trabajo. ¡Bien merecido!",
    ),
    "viatico": ConceptExplanation(
        title: "Viáticos",
        icon: Icons.restaurant_menu,
        explanation: "Cubre los gastos extra de comida que tenés mientras estás en ruta. Puede ser un monto fijo 'especial' o calculado por 'km recorrido'.",
    ),
    "km rec": ConceptExplanation(
        title: "Pago por Kilómetro Recorrido",
        icon: Icons.directions_car,
        explanation: "Es el corazón de tu sueldo de conductor. Notarás que puede aparecer dos veces: una parte suma a tu sueldo (remunerativo) y otra va directo a tu bolsillo (no remunerativo) para optimizar impuestos. Ambas suman.",
    ),
    // Gastronómicos (UTHGRA)
    "complemento de servicio": ConceptExplanation(
      title: "Complemento de Servicio",
      icon: Icons.room_service,
      explanation: "Es un adicional específico de tu convenio que busca compensar diferentes aspectos de tu tarea diaria."
    ),
    "alimentacion": ConceptExplanation(
      title: "Adicional por Alimentación",
      icon: Icons.fastfood,
      explanation: "Es un monto que te da el empleador para cubrir el costo de tu comida durante la jornada laboral."
    ),
  };

  static ConceptExplanation? findExplanation(String concepto) {
    final conceptoLower = concepto.toLowerCase();
    String? bestKey;
    int highestMatch = 0;

    // Lógica de búsqueda mejorada para encontrar la mejor coincidencia
    _explanationsDb.forEach((key, value) {
      if (conceptoLower.contains(key) && key.length > highestMatch) {
        bestKey = key;
        highestMatch = key.length;
      }
    });

    return bestKey != null ? _explanationsDb[bestKey] : null;
  }

  static List<ConceptExplanation> getAllConcepts() => _explanationsDb.values.toList();
}

class ConceptExplanation {
  final String title;
  final IconData icon;
  final String explanation;

  ConceptExplanation({required this.title, required this.icon, required this.explanation});
}
