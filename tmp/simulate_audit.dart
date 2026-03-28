
import 'dart:convert';
import 'package:syncra_arg/models/recibo_model.dart';
import 'package:syncra_arg/services/claude_vision_service.dart';
import 'package:syncra_arg/services/cct_database_service.dart';

void main() {
  final simulatedJson = '''
  {
    "cabecera": {
      "empresa_nombre": "TELECOM ARGENTINA S.A.",
      "empresa_cuit": "30-63945373-8",
      "empresa_domicilio": "Alicia Moreau de Justo 50, CABA",
      "empleado_nombre": "GARCIA, ALBERTO",
      "empleado_cuil": "20-25234567-8",
      "fecha_ingreso": "01/03/2015",
      "categoria": "Analista Senior",
      "periodo": "Mayo 2024"
    },
    "liquidacion": {
      "haberes": [
        {"codigo": "100", "descripcion": "SUELDO BASICO", "cantidad": "30", "monto": 950000.00, "es_remunerativo": true},
        {"codigo": "150", "descripcion": "ANTIGÜEDAD", "cantidad": "9", "monto": 85500.00, "es_remunerativo": true},
        {"codigo": "200", "descripcion": "PRESENTISMO", "cantidad": "", "monto": 79166.00, "es_remunerativo": true},
        {"codigo": "800", "descripcion": "BONO NO REMUNERATIVO", "cantidad": "", "monto": 120000.00, "es_remunerativo": false}
      ],
      "retenciones": [
        {"codigo": "400", "descripcion": "JUBILACION 11%", "cantidad": "", "monto": 122613.26},
        {"codigo": "401", "descripcion": "LEY 19032 3%", "cantidad": "", "monto": 33439.98},
        {"codigo": "402", "descripcion": "OBRA SOCIAL 3%", "cantidad": "", "monto": 33439.98},
        {"codigo": "500", "descripcion": "CUOTA SINDICAL", "cantidad": "2%", "monto": 22293.32}
      ]
    },
    "totales": {
      "bruto": 1114666.00,
      "retenciones": 211786.54,
      "neto": 1022879.46
    },
    "inferencias": {
      "convenio": "FATEL (Telecomunicaciones)",
      "confianza": "Alta"
    }
  }
  ''';

  print('--- SIMULACIÓN DE PROCESAMIENTO IA ---');
  
  // 1. Simular parseo
  // Nota: Accedemos via reflexión o simplemente instanciamos para el test si los métodos son estáticos
  // Como no podemos ejecutar el código real de la app directamente con dependencias de Flutter, 
  // replicamos la lógica de parseo aquí para validar el resultado.
  
  final data = jsonDecode(simulatedJson);
  final cab = data['cabecera'];
  final liq = data['liquidacion'];
  final tot = data['totales'];
  final inf = data['inferencias'];

  final model = ReciboModel(
    textoCrudo: simulatedJson,
    cabecera: CabeceraRecibo(
      empleadoCuil: cab['empleado_cuil'],
      empleadoNombre: cab['empleado_nombre'],
      empresaCuit: cab['empresa_cuit'],
      empresaNombre: cab['empresa_nombre'],
      fechaIngreso: cab['fecha_ingreso'],
      categoriaProfesional: cab['categoria'],
      periodoAbonado: cab['periodo'],
    ),
    liquidacionDetallada: LiquidacionDetallada(
      haberes: (liq['haberes'] as List).map((h) => ConceptoRecibo(
        descripcion: h['descripcion'],
        monto: h['monto'].toDouble(),
        esRemunerativo: h['es_remunerativo'],
      )).toList(),
      retenciones: (liq['retenciones'] as List).map((r) => ConceptoRecibo(
        descripcion: r['descripcion'],
        monto: r['monto'].toDouble(),
        esRemunerativo: false,
      )).toList(),
    ),
    totales: TotalesRecibo(
      totalBruto: tot['bruto'].toDouble(),
      totalRetenciones: tot['retenciones'].toDouble(),
      netoACobrar: tot['neto'].toDouble(),
    ),
    inferencias: InferenciasRecibo(
      convenioSugerido: inf['convenio'],
      confianza: inf['confianza'],
    ),
    auditoriaIa: AuditoriaIa(analisisGeneral: '', alertas: [], explicacionesItems: []),
  );

  print('Modelo extraído correctamente: ${model.cabecera.empleadoNombre} (${model.inferencias.convenioSugerido})');

  // 2. Aquí llamaríamos a la lógica de auditoría (que requiere CctDatabaseService)
  // Como es un script de consola, imprimimos lo que la auditoría detectaría.
  
  print('\n--- RESULTADOS DE AUDITORÍA IA ---');
  print('Convenio detectado: ${model.inferencias.convenioSugerido}');
  print('Total Bruto (Base de aportes): \$${model.totales.totalBruto}');
  
  final jubilacion = model.liquidacionDetallada.retenciones.firstWhere((r) => r.descripcion.contains('JUBILACION'));
  final pctReal = (jubilacion.monto / model.totales.totalBruto) * 100;
  
  print('Verificación de Jubilación: ${pctReal.toStringAsFixed(2)}% (Esperado: 11%)');
  
  if (pctReal > 10.9 && pctReal < 11.1) {
    print('STATUS: OK');
  } else {
    print('STATUS: ALERTA (Posible error de cálculo)');
  }

  print('\nConceptos detectados para explicación:');
  for (var h in model.liquidacionDetallada.haberes) {
    print('- ${h.descripcion}: \$${h.monto} (Remunerativo: ${h.esRemunerativo})');
  }
}
