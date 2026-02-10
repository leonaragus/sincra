
import '../services/teacher_omni_engine.dart';

class ResultadoRetroactivo {
  final double diferenciaNeto;
  final double diferenciaBruto;
  final double diferenciaNoRemunerativo;
  final List<DetalleDiferencia> detalles;
  final LiquidacionOmniResult liquidacionOriginal;
  final LiquidacionOmniResult liquidacionRecalculada;

  ResultadoRetroactivo({
    required this.diferenciaNeto,
    required this.diferenciaBruto,
    required this.diferenciaNoRemunerativo,
    required this.detalles,
    required this.liquidacionOriginal,
    required this.liquidacionRecalculada,
  });
}

class DetalleDiferencia {
  final String concepto;
  final double original;
  final double nuevo;
  final double diferencia;

  DetalleDiferencia(this.concepto, this.original, this.nuevo)
      : diferencia = nuevo - original;
}

class RetroactivoService {
  /// Calcula el retroactivo comparando una liquidación original con nuevos parámetros.
  static ResultadoRetroactivo calcularRetroactivo({
    required LiquidacionOmniResult original,
    required DocenteOmniInput nuevoInput,
  }) {
    // Recalcular con el nuevo input
    // Mantenemos la fecha de pago original para consistencia del cálculo histórico, 
    // aunque en la realidad se paga hoy.
    final recalculada = TeacherOmniEngine.liquidar(
      nuevoInput,
      periodo: original.periodo,
      fechaPago: original.fechaPago,
      cantidadCargos: nuevoInput.horasCatedra > 0 ? 0 : 1, // Estimación básica
      conceptosPropios: original.input.modoLiquidacion == nuevoInput.modoLiquidacion 
          ? original.conceptosPropios // Mantener conceptos si es el mismo modo
          : [],
    );

    final detalles = <DetalleDiferencia>[];

    // Comparar conceptos clave
    void comparar(String nombre, double vOrig, double vNuevo) {
      if ((vNuevo - vOrig).abs() > 0.01) {
        detalles.add(DetalleDiferencia(nombre, vOrig, vNuevo));
      }
    }

    comparar('Sueldo Básico', original.sueldoBasico, recalculada.sueldoBasico);
    comparar('Antigüedad', original.adicionalAntiguedad, recalculada.adicionalAntiguedad);
    comparar('Zona', original.adicionalZona, recalculada.adicionalZona);
    comparar('Estado Docente', original.estadoDocente, recalculada.estadoDocente);
    comparar('FONID', original.fonid, recalculada.fonid);
    comparar('Conectividad', original.conectividad, recalculada.conectividad);
    comparar('Material Didáctico', original.materialDidactico, recalculada.materialDidactico);
    comparar('Total Remunerativo', original.totalBrutoRemunerativo, recalculada.totalBrutoRemunerativo);
    comparar('Total No Remunerativo', original.totalNoRemunerativo, recalculada.totalNoRemunerativo);
    
    // Comparar totales finales
    final diffNeto = recalculada.netoACobrar - original.netoACobrar;
    final diffBruto = recalculada.totalBrutoRemunerativo - original.totalBrutoRemunerativo;
    final diffNoRem = recalculada.totalNoRemunerativo - original.totalNoRemunerativo;

    return ResultadoRetroactivo(
      diferenciaNeto: diffNeto,
      diferenciaBruto: diffBruto,
      diferenciaNoRemunerativo: diffNoRem,
      detalles: detalles,
      liquidacionOriginal: original,
      liquidacionRecalculada: recalculada,
    );
  }
}
