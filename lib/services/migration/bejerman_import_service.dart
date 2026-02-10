import 'dart:io';
import 'package:excel/excel.dart';
import 'package:syncra_arg/models/liquidacion.dart';

/// Servicio para importar y comparar liquidaciones desde Sistema Bejerman
/// Permite validar los cálculos de Syncra contra los resultados históricos de Bejerman
class BejermanImportService {
  
  /// Estructura de columnas típica de exportación Excel de Bejerman
  /// Puede variar según la configuración del reporte del usuario
  static const int COL_LEGAJO = 0;
  static const int COL_CUIL = 1; // A veces está en otra columna
  static const int COL_APELLIDO_NOMBRE = 2;
  static const int COL_CONCEPTO_COD = 3;
  static const int COL_CONCEPTO_DESC = 4;
  static const int COL_UNIDADES = 5;
  static const int COL_IMPORTE = 6; // Neto o Importe del concepto

  /// Importa un archivo Excel de Bejerman y lo convierte a una lista de comparativas
  Future<List<ComparativaBejerman>> importarYComparar(
    String filePath, 
    List<Liquidacion> liquidacionesLocales
  ) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception("El archivo no existe");
    }

    final bytes = await file.readAsBytes();
    final excel = Excel.decodeBytes(bytes);
    
    final Map<String, double> netosBejerman = {};

    // Asumimos que la primera hoja tiene los datos
    final table = excel.tables[excel.tables.keys.first];
    
    if (table == null) return [];

    // Recorrer filas (saltando cabecera si es necesario)
    for (var i = 1; i < table.maxRows; i++) {
      final row = table.rows[i];
      if (row.isEmpty) continue;

      // Lógica de extracción (simplificada para el ejemplo)
      // En una implementación real, esto debe ser configurable o detectar formato
      try {
        final cuilRaw = row[COL_CUIL]?.value?.toString();
        final importeRaw = row[COL_IMPORTE]?.value;
        
        if (cuilRaw != null && importeRaw != null) {
          final cuil = _limpiarCuil(cuilRaw);
          final importe = double.tryParse(importeRaw.toString()) ?? 0.0;
          
          // Asumimos que el Excel tiene una fila por empleado con el TOTAL NETO
          // O sumamos si viene desglosado
          netosBejerman.update(cuil, (value) => value + importe, ifAbsent: () => importe);
        }
      } catch (e) {
        // Ignorar filas con error de formato
        continue;
      }
    }

    // Realizar comparación
    final List<ComparativaBejerman> resultados = [];

    for (final local in liquidacionesLocales) {
      // Necesitamos el CUIL del empleado local. 
      // Asumimos que local.empleadoId es el CUIL o tenemos forma de obtenerlo.
      // Por ahora usamos empleadoId como proxy
      final cuilLocal = local.empleadoId; 
      
      final netoBejerman = netosBejerman[cuilLocal] ?? 0.0;
      // Recalcular neto local en el momento para asegurar frescura
      final netoLocal = local.calcularSueldoNeto(0.0); // TODO: Pasar básico real

      resultados.add(ComparativaBejerman(
        cuil: cuilLocal,
        netoSyncra: netoLocal,
        netoBejerman: netoBejerman,
      ));
    }

    return resultados;
  }

  String _limpiarCuil(String raw) {
    return raw.replaceAll(RegExp(r'[^0-9]'), '');
  }
}

class ComparativaBejerman {
  final String cuil;
  final double netoSyncra;
  final double netoBejerman;

  ComparativaBejerman({
    required this.cuil,
    required this.netoSyncra,
    required this.netoBejerman,
  });

  double get diferencia => netoSyncra - netoBejerman;
  bool get esCoincidente => diferencia.abs() < 10.0; // Tolerancia de $10
}
