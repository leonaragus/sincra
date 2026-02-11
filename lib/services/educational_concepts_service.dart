// SERVICIO DE EXPLICACIONES EDUCATIVAS - SYNCRA ACADEMY
// Base de conocimiento local sobre conceptos de liquidación de sueldos en Argentina.

class ConceptoEducativo {
  final String titulo;
  final String definicionCorta;
  final String explicacionDetallada;
  final String? ejemplo;
  final String categoria; // Remunerativo, No Remunerativo, Descuento, Legales

  const ConceptoEducativo({
    required this.titulo,
    required this.definicionCorta,
    required this.explicacionDetallada,
    this.ejemplo,
    required this.categoria,
  });
}

class EducationalConceptsService {
  static const String contactoAcademia = "381666666"; // Placeholder, se actualizará
  static const String nombreAcademia = "Elevar Formación Técnica";

  static const List<ConceptoEducativo> conceptos = [
    // --- REMUNERATIVOS ---
    ConceptoEducativo(
      titulo: "Sueldo Básico",
      definicionCorta: "Es la remuneración base establecida por tu convenio colectivo.",
      explicacionDetallada: "Es el punto de partida de tu sueldo. Este monto se define en las paritarias de tu gremio (Comercio, Sanidad, UOCRA, etc.) y varía según tu categoría y antigüedad. Sobre este monto se calculan la mayoría de los adicionales y los descuentos.",
      categoria: "Remunerativo",
      ejemplo: "Si sos Empleado de Comercio Maestranza A, tu básico hoy ronda los \$500.000 (aprox).",
    ),
    ConceptoEducativo(
      titulo: "Antigüedad",
      definicionCorta: "Un plus por cada año que llevas trabajando en la empresa.",
      explicacionDetallada: "Es un porcentaje que se suma a tu básico por cada año de servicio. El porcentaje varía según el convenio: en Comercio es 1% por año, en Sanidad 2%, en Docentes varía mucho más. Es un derecho adquirido que premia tu permanencia.",
      categoria: "Remunerativo",
    ),
    ConceptoEducativo(
      titulo: "Presentismo / Asistencia",
      definicionCorta: "Premio por no faltar ni llegar tarde.",
      explicacionDetallada: "Es un incentivo para cumplir con el horario y la asistencia. Ojo: en muchos convenios, con una sola falta injustificada podés perder el total de este premio. En Comercio es la doceava parte del básico (8.33%).",
      categoria: "Remunerativo",
    ),
    ConceptoEducativo(
      titulo: "Horas Extras 50% y 100%",
      definicionCorta: "Pago adicional por trabajar fuera de tu horario habitual.",
      explicacionDetallada: "Las horas al 50% se pagan cuando te quedas más tiempo de lunes a viernes (o sábados hasta las 13hs). Las del 100% (dobles) son para sábados después de las 13hs, domingos y feriados.",
      categoria: "Remunerativo",
    ),

    // --- DESCUENTOS DE LEY ---
    ConceptoEducativo(
      titulo: "Jubilación (SIPA)",
      definicionCorta: "Aporte para tu futuro retiro (11%).",
      explicacionDetallada: "Es un descuento obligatorio del 11% sobre todos tus conceptos remunerativos. Va destinado al Sistema Integrado Previsional Argentino para financiar las jubilaciones actuales y futuras.",
      categoria: "Descuento",
    ),
    ConceptoEducativo(
      titulo: "Obra Social",
      definicionCorta: "Aporte para tu cobertura de salud (3%).",
      explicacionDetallada: "Es el 3% de tu sueldo bruto destinado a la Obra Social de tu actividad (OSECAC, OSPRERA, etc.) para que tengas cobertura médica. Vos ponés el 3% y tu empleador pone otro 6%.",
      categoria: "Descuento",
    ),
    ConceptoEducativo(
      titulo: "Ley 19.032 (PAMI)",
      definicionCorta: "Aporte al Instituto de Jubilados (3%).",
      explicacionDetallada: "Es otro 3% obligatorio que financia al PAMI. Aunque tengas obra social privada o prepaga, este aporte es solidario y obligatorio para todos los trabajadores registrados.",
      categoria: "Descuento",
    ),
    ConceptoEducativo(
      titulo: "Cuota Sindical / Aporte Solidario",
      definicionCorta: "Aporte al gremio que te representa.",
      explicacionDetallada: "Varía según el gremio (generalmente entre 2% y 2.5%). Si estás afiliado es obligatorio. Si no lo estás, a veces existe el 'Aporte Solidario' por el uso del convenio colectivo.",
      categoria: "Descuento",
    ),

    // --- NO REMUNERATIVOS ---
    ConceptoEducativo(
      titulo: "Conceptos No Remunerativos",
      definicionCorta: "Pagos que van 'al bolsillo' pero no suman para jubilación.",
      explicacionDetallada: "Son sumas acordadas en paritarias que el empleador te paga pero sobre las cuales NO se hacen descuentos de jubilación (aunque sí suelen pagar Obra Social). Importante: generalmente NO se toman en cuenta para calcular el aguinaldo ni indemnizaciones, salvo excepciones.",
      categoria: "No Remunerativo",
    ),
  ];

  static List<ConceptoEducativo> buscar(String query) {
    return conceptos.where((c) => 
      c.titulo.toLowerCase().contains(query.toLowerCase()) || 
      c.definicionCorta.toLowerCase().contains(query.toLowerCase())
    ).toList();
  }
}
