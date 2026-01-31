// ========================================================================
// SERVICIO DE EXPORTACIÓN A EXCEL
// Genera reportes profesionales en formato .xlsx
// ========================================================================

import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import '../models/empleado_completo.dart';
import 'empleados_service.dart';

class ExcelExportService {
  /// Genera Excel de libro de sueldos mensual
  static Future<String> generarLibroSueldos({
    required int mes,
    required int anio,
    required List<Map<String, dynamic>> liquidaciones,
    String? empresaNombre,
  }) async {
    final excel = Excel.createExcel();
    final sheet = excel['Libro de Sueldos'];
    
    // Estilo de encabezado
    final headerStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString('#1F4788'),
      fontColorHex: ExcelColor.white,
    );
    
    // Título
    sheet.merge(CellIndex.indexByString('A1'), CellIndex.indexByString('L1'));
    var titleCell = sheet.cell(CellIndex.indexByString('A1'));
    titleCell.value = TextCellValue('LIBRO DE SUELDOS - ${_nombreMes(mes)} $anio');
    titleCell.cellStyle = CellStyle(bold: true, fontSize: 16);
    
    if (empresaNombre != null) {
      sheet.merge(CellIndex.indexByString('A2'), CellIndex.indexByString('L2'));
      var empresaCell = sheet.cell(CellIndex.indexByString('A2'));
      empresaCell.value = TextCellValue(empresaNombre);
    }
    
    // Encabezados (fila 4)
    final headers = [
      'CUIL', 'Nombre', 'Categoría', 'Básico', 'Antigüedad', 
      'Otros Rem.', 'Total Bruto', 'Aportes', 'Descuentos', 
      'No Rem.', 'Neto', 'Contribuciones',
    ];
    
    for (int i = 0; i < headers.length; i++) {
      var cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 3));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = headerStyle;
    }
    
    // Datos
    int row = 4;
    double totalBruto = 0;
    double totalAportes = 0;
    double totalNeto = 0;
    double totalContribuciones = 0;
    
    for (final liq in liquidaciones) {
      final basico = (liq['basico'] as num?)?.toDouble() ?? 0.0;
      final antiguedad = (liq['antiguedad'] as num?)?.toDouble() ?? 0.0;
      final conceptosRem = (liq['conceptosRemunerativos'] as num?)?.toDouble() ?? 0.0;
      final bruto = (liq['totalBruto'] as num?)?.toDouble() ?? 0.0;
      final aportes = (liq['totalAportes'] as num?)?.toDouble() ?? 0.0;
      final descuentos = (liq['descuentos'] as num?)?.toDouble() ?? 0.0;
      final noRem = (liq['conceptosNoRemunerativos'] as num?)?.toDouble() ?? 0.0;
      final neto = (liq['neto'] as num?)?.toDouble() ?? 0.0;
      final contribuciones = (liq['totalContribuciones'] as num?)?.toDouble() ?? 0.0;
      
      totalBruto += bruto;
      totalAportes += aportes;
      totalNeto += neto;
      totalContribuciones += contribuciones;
      
      final values = [
        liq['cuil'] ?? '',
        liq['nombre'] ?? '',
        liq['categoria'] ?? '',
        basico,
        antiguedad,
        conceptosRem,
        bruto,
        aportes,
        descuentos,
        noRem,
        neto,
        contribuciones,
      ];
      
      for (int i = 0; i < values.length; i++) {
        var cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: row));
        if (values[i] is num) {
          cell.value = DoubleCellValue((values[i] as num).toDouble());
          cell.cellStyle = CellStyle(numberFormat: NumFormat.standard_2);
        } else {
          cell.value = TextCellValue(values[i].toString());
        }
      }
      
      row++;
    }
    
    // Totales
    row++;
    var totalLabel = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row));
    totalLabel.value = TextCellValue('TOTALES:');
    totalLabel.cellStyle = CellStyle(bold: true);
    
    final totalesValues = [null, null, null, null, null, null, totalBruto, totalAportes, null, null, totalNeto, totalContribuciones];
    for (int i = 0; i < totalesValues.length; i++) {
      if (totalesValues[i] != null) {
        var cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: row));
        cell.value = DoubleCellValue(totalesValues[i] as double);
        cell.cellStyle = CellStyle(bold: true, numberFormat: NumFormat.standard_2);
      }
    }
    
    // Guardar archivo
    final dir = await getApplicationDocumentsDirectory();
    final fileName = 'LibroSueldos_${mes}_${anio}_${DateTime.now().millisecondsSinceEpoch}.xlsx';
    final filePath = '${dir.path}/$fileName';
    
    final fileBytes = excel.encode();
    if (fileBytes != null) {
      File(filePath)
        ..createSync(recursive: true)
        ..writeAsBytesSync(fileBytes);
    }
    
    return filePath;
  }
  
  /// Genera Excel de evolución salarial (12 meses)
  static Future<String> generarEvolucionSalarial({
    String? empresaCuit,
  }) async {
    final excel = Excel.createExcel();
    final sheet = excel['Evolución Salarial'];
    
    // Título
    sheet.merge(CellIndex.indexByString('A1'), CellIndex.indexByString('F1'));
    var titleCell = sheet.cell(CellIndex.indexByString('A1'));
    titleCell.value = TextCellValue('EVOLUCIÓN SALARIAL - ÚLTIMOS 12 MESES');
    titleCell.cellStyle = CellStyle(bold: true, fontSize: 16);
    
    // Headers
    final headers = ['Mes', 'Año', 'Total Remuneraciones', 'Total Aportes', 'Total Contribuciones', 'Costo Empleador'];
    final headerStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString('#1F4788'),
      fontColorHex: ExcelColor.white,
    );
    
    for (int i = 0; i < headers.length; i++) {
      var cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 2));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = headerStyle;
    }
    
    // Datos (placeholder - debería venir de f931_historial)
    int row = 3;
    final ahora = DateTime.now();
    
    for (int i = 11; i >= 0; i--) {
      final fecha = DateTime(ahora.year, ahora.month - i, 1);
      final mes = fecha.month;
      final anio = fecha.year;
      
      // Placeholder - reemplazar con datos reales de f931_historial
      final values = [
        _nombreMes(mes),
        anio,
        1500000.0, // Placeholder
        255000.0,  // Placeholder
        345000.0,  // Placeholder
        1845000.0, // Placeholder
      ];
      
      for (int j = 0; j < values.length; j++) {
        var cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: j, rowIndex: row));
        if (values[j] is num) {
          cell.value = DoubleCellValue((values[j] as num).toDouble());
          cell.cellStyle = CellStyle(numberFormat: NumFormat.standard_2);
        } else {
          cell.value = TextCellValue(values[j].toString());
        }
      }
      
      row++;
    }
    
    // Guardar
    final dir = await getApplicationDocumentsDirectory();
    final fileName = 'EvolucionSalarial_${DateTime.now().millisecondsSinceEpoch}.xlsx';
    final filePath = '${dir.path}/$fileName';
    
    final fileBytes = excel.encode();
    if (fileBytes != null) {
      File(filePath)
        ..createSync(recursive: true)
        ..writeAsBytesSync(fileBytes);
    }
    
    return filePath;
  }
  
  /// Genera Excel de resumen por provincia/categoría
  static Future<String> generarResumenPorProvincia({
    String? empresaCuit,
  }) async {
    final excel = Excel.createExcel();
    final sheet = excel['Resumen Provincial'];
    
    // Obtener empleados
    final empleados = await EmpleadosService.obtenerEmpleadosActivos(
      empresaCuit: empresaCuit,
    );
    
    // Agrupar por provincia
    final porProvincia = <String, List<EmpleadoCompleto>>{};
    for (final emp in empleados) {
      porProvincia.putIfAbsent(emp.provincia, () => []).add(emp);
    }
    
    // Título
    sheet.merge(CellIndex.indexByString('A1'), CellIndex.indexByString('E1'));
    var titleCell = sheet.cell(CellIndex.indexByString('A1'));
    titleCell.value = TextCellValue('RESUMEN POR PROVINCIA');
    titleCell.cellStyle = CellStyle(bold: true, fontSize: 16);
    
    // Headers
    final headers = ['Provincia', 'Cantidad Empleados', 'Costo Estimado', 'Promedio Antigüedad', 'Principal Categoría'];
    final headerStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString('#1F4788'),
      fontColorHex: ExcelColor.white,
    );
    
    for (int i = 0; i < headers.length; i++) {
      var cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 2));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = headerStyle;
    }
    
    // Datos
    int row = 3;
    final provinciasOrdenadas = porProvincia.keys.toList()..sort();
    
    for (final prov in provinciasOrdenadas) {
      final emps = porProvincia[prov]!;
      final cantidad = emps.length;
      final costoEstimado = cantidad * 500000.0; // Placeholder
      final promedioAntiguedad = emps.fold(0, (sum, e) => sum + e.antiguedadAnios) / cantidad;
      
      // Categoría más común
      final categorias = <String, int>{};
      for (final emp in emps) {
        categorias[emp.categoria] = (categorias[emp.categoria] ?? 0) + 1;
      }
      final categoriaPrincipal = categorias.entries.reduce((a, b) => a.value > b.value ? a : b).key;
      
      final values = [prov, cantidad, costoEstimado, promedioAntiguedad, categoriaPrincipal];
      
      for (int i = 0; i < values.length; i++) {
        var cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: row));
        if (values[i] is num) {
          cell.value = DoubleCellValue((values[i] as num).toDouble());
          cell.cellStyle = CellStyle(numberFormat: NumFormat.standard_2);
        } else {
          cell.value = TextCellValue(values[i].toString());
        }
      }
      
      row++;
    }
    
    // Guardar
    final dir = await getApplicationDocumentsDirectory();
    final fileName = 'ResumenProvincial_${DateTime.now().millisecondsSinceEpoch}.xlsx';
    final filePath = '${dir.path}/$fileName';
    
    final fileBytes = excel.encode();
    if (fileBytes != null) {
      File(filePath)
        ..createSync(recursive: true)
        ..writeAsBytesSync(fileBytes);
    }
    
    return filePath;
  }
  
  static String _nombreMes(int mes) {
    const meses = ['Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
                   'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'];
    return meses[mes - 1];
  }
}
