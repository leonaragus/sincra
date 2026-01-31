import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/concepto.dart';
import '../models/empresa.dart';
import '../models/empleado.dart';

// Clase auxiliar para conceptos del PDF
class ConceptoParaPDF {
  final String descripcion;
  final double remunerativo;
  final double noRemunerativo;
  final double descuento;
  
  ConceptoParaPDF({
    required this.descripcion,
    required this.remunerativo,
    required this.noRemunerativo,
    required this.descuento,
  });
}

class PdfRecibo {
  static Future<Uint8List> generar({
    required Empresa empresa,
    required Empleado empleado,
    required List<Concepto> conceptos,
  }) async {
    final pdf = pw.Document();

    final double bruto = empleado.sueldoBasico;

    double totalRem = 0;
    double totalNoRem = 0;
    double totalDesc = 0;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _encabezado(empresa, empleado),
              pw.SizedBox(height: 20),
              _tablaConceptos(
                conceptos,
                bruto,
                onSumar: (tipo, monto) {
                  switch (tipo) {
                    case TipoConcepto.remunerativo:
                      totalRem += monto;
                      break;
                    case TipoConcepto.noRemunerativo:
                      totalNoRem += monto;
                      break;
                    case TipoConcepto.descuento:
                      totalDesc += monto;
                      break;
                  }
                },
              ),
              pw.Divider(),
              _totales(totalRem, totalNoRem, totalDesc),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  // Método para generar PDF completo con los nuevos conceptos
  // ARCA 2026: Soporta logo y firma digital
  static Future<Uint8List> generarCompleto({
    required Empresa empresa,
    required Empleado empleado,
    required List<ConceptoParaPDF> conceptos,
    required double sueldoBruto,
    required double totalDeducciones,
    required double totalNoRemunerativo,
    required double sueldoNeto,
    double? baseImponibleTopeada, // Base de cálculo de aportes (con tope aplicado)
    String? bancoAcreditacion, // Banco de acreditación
    String? fechaUltimoDepositoAportes, // Fecha último depósito de aportes
    String? leyendaUltimoDepositoAportes, // Ej: "Período Junio 2025 - Banco [INSTITUCION]"
    int? diasTrabajadosSemestre, // Días trabajados en el semestre (SAC proporcional)
    int? divisorUsado, // Divisor del semestre (ej. 181, 184, 180) para SAC
    double? baseDeCalculo, // Base de cálculo SAC: 50% mayor remuneración
    double? sueldoBasico, // Sueldo básico para desglose de horas extras
    int? cantidadHorasExtras50, // Cantidad de horas extras 50%
    int? cantidadHorasExtras100, // Cantidad de horas extras 100%
    String? detallePuntosYValorIndice, // Puntos y Valor del Índice para auditoría del docente
    String? desgloseBaseBonificable, // Cascada A–G: Base Bonificable (auditoría docente)
    bool incluirBloqueFirmaLey25506 = false, // Espacio firma o referencia Firma Digital Ley 25.506
    Uint8List? logoBytes, // Logo de la empresa en bytes (PNG/JPG)
    Uint8List? firmaBytes, // Firma digital en bytes (PNG/JPG)
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _encabezado(empresa, empleado, logoBytes: logoBytes),
              if (diasTrabajadosSemestre != null) ...[
                pw.SizedBox(height: 6),
                pw.Text(
                  'Días trabajados en el semestre: $diasTrabajadosSemestre',
                  style: const pw.TextStyle(fontSize: 11),
                ),
              ],
              if (divisorUsado != null || (baseDeCalculo != null && baseDeCalculo > 0)) ...[
                pw.SizedBox(height: 4),
                if (divisorUsado != null)
                  pw.Text(
                    'Divisor usado: $divisorUsado',
                    style: const pw.TextStyle(fontSize: 11),
                  ),
                if (baseDeCalculo != null && baseDeCalculo > 0)
                  pw.Text(
                    'Base de cálculo (50% mayor remuneración): \$${baseDeCalculo.toStringAsFixed(2)}',
                    style: const pw.TextStyle(fontSize: 11),
                  ),
              ],
              pw.SizedBox(height: 20),
              _tablaConceptosCompleta(conceptos),
              pw.SizedBox(height: 20),
              if (detallePuntosYValorIndice != null && detallePuntosYValorIndice.isNotEmpty) ...[
                pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 12),
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    border: pw.Border.all(color: PdfColors.grey400),
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Text(
                    'Puntos y Valor del Índice (auditoría): $detallePuntosYValorIndice',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ),
              ],
              if (desgloseBaseBonificable != null && desgloseBaseBonificable.isNotEmpty) ...[
                pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 12),
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    border: pw.Border.all(color: PdfColors.grey400),
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Text(
                    'Desglose Base Bonificable (Cascada A–G): $desgloseBaseBonificable',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                ),
              ],
              _totalesCompleto(
                sueldoBruto,
                totalNoRemunerativo,
                totalDeducciones,
                sueldoNeto,
                empleado,
                empresa,
                baseImponibleTopeada: baseImponibleTopeada,
                bancoAcreditacion: bancoAcreditacion,
                fechaUltimoDepositoAportes: fechaUltimoDepositoAportes,
                leyendaUltimoDepositoAportes: leyendaUltimoDepositoAportes,
                sueldoBasico: sueldoBasico,
                cantidadHorasExtras50: cantidadHorasExtras50,
                cantidadHorasExtras100: cantidadHorasExtras100,
              ),
              pw.Spacer(),
              if (incluirBloqueFirmaLey25506 || firmaBytes != null) ...[
                pw.SizedBox(height: 16),
                _bloqueFirmaLey25506(firmaBytes: firmaBytes),
              ],
              _observacionesLegales(empresa),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Bloque al pie: espacio para firma o referencia a Firma Digital (Ley 25.506).
  /// ARCA 2026: Si se proporciona firmaBytes, muestra la imagen de la firma.
  static pw.Widget _bloqueFirmaLey25506({Uint8List? firmaBytes}) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 12),
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          // Espacio para firma del empleado
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.SizedBox(height: 40),
                pw.Container(
                  width: 180,
                  height: 1,
                  color: PdfColors.grey400,
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Firma del Empleado',
                  style: pw.TextStyle(
                    fontSize: 9,
                    color: PdfColors.grey600,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(width: 40),
          // Firma del empleador (imagen o espacio)
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                if (firmaBytes != null && firmaBytes.isNotEmpty)
                  pw.Container(
                    width: 120,
                    height: 50,
                    child: pw.Image(pw.MemoryImage(firmaBytes), fit: pw.BoxFit.contain),
                  )
                else
                  pw.SizedBox(height: 40),
                pw.Container(
                  width: 180,
                  height: 1,
                  color: PdfColors.grey400,
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Firma del Empleador',
                  style: pw.TextStyle(
                    fontSize: 9,
                    color: PdfColors.grey600,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Ley 25.506 - Firma Digital',
                  style: pw.TextStyle(
                    fontSize: 8,
                    color: PdfColors.grey500,
                    fontStyle: pw.FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _tablaConceptosCompleta(List<ConceptoParaPDF> conceptos) {
    return pw.Table(
      border: pw.TableBorder.all(),
      columnWidths: const {
        0: pw.FlexColumnWidth(3),
        1: pw.FlexColumnWidth(2),
        2: pw.FlexColumnWidth(2),
        3: pw.FlexColumnWidth(2),
      },
      children: [
        _filaHeader(),
        ...conceptos.map((c) {
          return pw.TableRow(
            children: [
              _celdaTexto(c.descripcion),
              _celdaMonto(c.remunerativo > 0 ? c.remunerativo : null),
              _celdaMonto(c.noRemunerativo > 0 ? c.noRemunerativo : null),
              _celdaMonto(c.descuento > 0 ? c.descuento : null),
            ],
          );
        }),
      ],
    );
  }

  static pw.Widget _totalesCompleto(
    double sueldoBruto,
    double totalNoRemunerativo,
    double totalDeducciones,
    double sueldoNeto,
    Empleado empleado,
    Empresa empresa, {
    double? baseImponibleTopeada,
    String? bancoAcreditacion,
    String? fechaUltimoDepositoAportes,
    String? leyendaUltimoDepositoAportes, // Ej: "Período Junio 2025 - Banco [INSTITUCION]"
    double? sueldoBasico,
    int? cantidadHorasExtras50,
    int? cantidadHorasExtras100,
  }) {
    final sueldoNetoEnLetras = _numeroALetras(sueldoNeto);
    
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.all(16),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey200,
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              // Total Haberes Remunerativos (BRUTO REAL sin topes)
              pw.Text(
                'Total Haberes Remunerativos: \$${sueldoBruto.toStringAsFixed(2)}',
                style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              // Base de Cálculo de Aportes (valor topeado) - línea pequeña
              if (baseImponibleTopeada != null && baseImponibleTopeada != sueldoBruto)
                pw.Text(
                  'Base de Cálculo de Aportes: \$${baseImponibleTopeada.toStringAsFixed(2)} (tope aplicado)',
                  style: pw.TextStyle(
                    fontSize: 9,
                    color: PdfColors.grey700,
                    fontStyle: pw.FontStyle.italic,
                  ),
                ),
              pw.SizedBox(height: 8),
              pw.Text(
                'Total No Remunerativo: \$${totalNoRemunerativo.toStringAsFixed(2)}',
                style: const pw.TextStyle(fontSize: 12),
              ),
              pw.Text(
                'Total Deducciones: \$${totalDeducciones.toStringAsFixed(2)}',
                style: const pw.TextStyle(fontSize: 12),
              ),
              pw.Divider(),
              pw.Text(
                'SUELDO NETO A COBRAR: \$${sueldoNeto.toStringAsFixed(2)}',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Text(
                  'Son: $sueldoNetoEnLetras',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    fontStyle: pw.FontStyle.italic,
                  ),
                  textAlign: pw.TextAlign.right,
                ),
              ),
            ],
          ),
        ),
        // Desglose de cálculo de horas extras (si aplica)
        if (sueldoBasico != null && sueldoBasico > 0 && (cantidadHorasExtras50 != null && cantidadHorasExtras50 > 0 || cantidadHorasExtras100 != null && cantidadHorasExtras100 > 0)) ...[
          pw.SizedBox(height: 12),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Desglose de Cálculo de Horas Extras:',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 4),
                if (cantidadHorasExtras50 != null && cantidadHorasExtras50 > 0) ...[
                  pw.Text(
                    'Valor hora normal: \$${(sueldoBasico / 173.0).toStringAsFixed(2)}',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                  pw.Text(
                    'Horas Extras 50% ($cantidadHorasExtras50 horas): \$${(sueldoBasico / 173.0 * 1.5 * cantidadHorasExtras50).toStringAsFixed(2)}',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                ],
                if (cantidadHorasExtras100 != null && cantidadHorasExtras100 > 0) ...[
                  if (cantidadHorasExtras50 == null || cantidadHorasExtras50 == 0)
                    pw.Text(
                      'Valor hora normal: \$${(sueldoBasico / 173.0).toStringAsFixed(2)}',
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  pw.Text(
                    'Horas Extras 100% ($cantidadHorasExtras100 horas): \$${(sueldoBasico / 173.0 * 2.0 * cantidadHorasExtras100).toStringAsFixed(2)}',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                ],
              ],
            ),
          ),
        ],
        pw.SizedBox(height: 16),
        // Campos obligatorios
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey400),
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                'Lugar y Fecha de Pago: ${empleado.lugarPago ?? empresa.domicilio}, ${empleado.fechaPago}',
                style: const pw.TextStyle(fontSize: 11),
                textAlign: pw.TextAlign.right,
              ),
              if (bancoAcreditacion != null && bancoAcreditacion.isNotEmpty) ...[
                pw.SizedBox(height: 4),
                pw.Text(
                  'Banco de Acreditación: $bancoAcreditacion',
                  style: const pw.TextStyle(fontSize: 11),
                  textAlign: pw.TextAlign.right,
                ),
              ],
              if (fechaUltimoDepositoAportes != null && fechaUltimoDepositoAportes.isNotEmpty) ...[
                pw.SizedBox(height: 4),
                pw.Text(
                  'Fecha último depósito de aportes: $fechaUltimoDepositoAportes',
                  style: const pw.TextStyle(fontSize: 11),
                  textAlign: pw.TextAlign.right,
                ),
              ],
              if (leyendaUltimoDepositoAportes != null && leyendaUltimoDepositoAportes.isNotEmpty) ...[
                pw.SizedBox(height: 4),
                pw.Text(
                  'Último depósito de aportes: $leyendaUltimoDepositoAportes',
                  style: const pw.TextStyle(fontSize: 11),
                  textAlign: pw.TextAlign.right,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ================= ENCABEZADO =================

  static pw.Widget _encabezado(Empresa empresa, Empleado empleado, {Uint8List? logoBytes}) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Logo de la empresa (si existe)
        if (logoBytes != null && logoBytes.isNotEmpty)
          pw.Container(
            width: 70,
            height: 70,
            margin: const pw.EdgeInsets.only(right: 16),
            child: pw.Image(pw.MemoryImage(logoBytes), fit: pw.BoxFit.contain),
          ),
        // Datos de la empresa y empleado
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                empresa.razonSocial,
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text('CUIT: ${empresa.cuit}'),
              pw.Text(empresa.domicilio),
              pw.SizedBox(height: 10),
              pw.Text(
                'Empleado: ${empleado.nombre}',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.Text('Categoría: ${empleado.categoria}'),
              if (empleado.fechaIngreso != null && empleado.fechaIngreso!.isNotEmpty)
                pw.Text('Fecha de Ingreso: ${empleado.fechaIngreso}'),
              pw.Text('Período Liquidado: ${empleado.periodo}'),
            ],
          ),
        ),
      ],
    );
  }

  // ================= TABLA =================

  static pw.Widget _tablaConceptos(
    List<Concepto> conceptos,
    double bruto, {
    required void Function(TipoConcepto, double) onSumar,
  }) {
    return pw.Table(
      border: pw.TableBorder.all(),
      columnWidths: const {
        0: pw.FlexColumnWidth(3),
        1: pw.FlexColumnWidth(2),
        2: pw.FlexColumnWidth(2),
        3: pw.FlexColumnWidth(2),
      },
      children: [
        _filaHeader(),
        ...conceptos.map((c) {
          final monto = c.calcular(bruto);
          onSumar(c.tipo, monto);

          return pw.TableRow(
            children: [
              _celdaTexto(c.descripcion),
              _celdaMonto(
                c.tipo == TipoConcepto.remunerativo ? monto : null,
              ),
              _celdaMonto(
                c.tipo == TipoConcepto.noRemunerativo ? monto : null,
              ),
              _celdaMonto(
                c.tipo == TipoConcepto.descuento ? monto : null,
              ),
            ],
          );
        }),
      ],
    );
  }

  static pw.TableRow _filaHeader() {
    return pw.TableRow(
      decoration: const pw.BoxDecoration(color: PdfColors.grey300),
      children: [
        _celdaTexto('Concepto', bold: true),
        _celdaTexto('Haberes Remunerativos', bold: true),
        _celdaTexto('Haberes No Remunerativos', bold: true),
        _celdaTexto('Deducciones', bold: true),
      ],
    );
  }

  static pw.Widget _celdaTexto(String texto, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        texto,
        style: pw.TextStyle(
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  static pw.Widget _celdaMonto(double? valor) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        valor == null ? '' : valor.toStringAsFixed(2),
        textAlign: pw.TextAlign.right,
      ),
    );
  }

  // ================= TOTALES =================

  static pw.Widget _totales(
    double rem,
    double noRem,
    double desc,
  ) {
    final neto = rem + noRem - desc;

    return pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Text('Total Remunerativo: \$${rem.toStringAsFixed(2)}'),
          pw.Text('Total No Remunerativo: \$${noRem.toStringAsFixed(2)}'),
          pw.Text('Descuentos: \$${desc.toStringAsFixed(2)}'),
          pw.Divider(),
          pw.Text(
            'NETO A COBRAR: \$${neto.toStringAsFixed(2)}',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ================= CONVERSIÓN NÚMERO A LETRAS =================
  
  /// Convierte un número a letras en español argentino
  static String _numeroALetras(double numero) {
    if (numero == 0) return 'cero pesos';
    
    final partes = numero.toStringAsFixed(2).split('.');
    final enteros = int.parse(partes[0]);
    final decimales = int.parse(partes[1]);
    
    String resultado = '';
    
    if (enteros > 0) {
      resultado = _convertirEnteros(enteros);
      if (enteros == 1) {
        resultado += ' peso';
      } else {
        resultado += ' pesos';
      }
    }
    
    if (decimales > 0) {
      if (enteros > 0) {
        resultado += ' con ';
      }
      resultado += _convertirEnteros(decimales);
      if (decimales == 1) {
        resultado += ' centavo';
      } else {
        resultado += ' centavos';
      }
    }
    
    return resultado.trim();
  }
  
  static String _convertirEnteros(int numero) {
    if (numero == 0) return 'cero';
    if (numero < 20) return _unidades[numero] ?? numero.toString();
    if (numero < 100) {
      final decenas = numero ~/ 10;
      final unidades = numero % 10;
      if (unidades == 0) {
        return _decenas[decenas] ?? numero.toString();
      }
      return '${_decenas[decenas] ?? decenas.toString()} y ${_unidades[unidades] ?? unidades.toString()}';
    }
    if (numero < 1000) {
      final centenas = numero ~/ 100;
      final resto = numero % 100;
      String resultado = '';
      if (centenas == 1) {
        if (resto == 0) {
          resultado = 'cien';
        } else {
          resultado = 'ciento';
        }
      } else if (centenas == 5) {
        resultado = 'quinientos';
      } else if (centenas == 7) {
        resultado = 'setecientos';
      } else if (centenas == 9) {
        resultado = 'novecientos';
      } else {
        resultado = '${_unidades[centenas] ?? centenas.toString()}cientos';
      }
      if (resto > 0) {
        resultado += ' ${_convertirEnteros(resto)}';
      }
      return resultado;
    }
    if (numero < 1000000) {
      final miles = numero ~/ 1000;
      final resto = numero % 1000;
      String resultado = '';
      if (miles == 1) {
        resultado = 'mil';
      } else {
        resultado = '${_convertirEnteros(miles)} mil';
      }
      if (resto > 0) {
        resultado += ' ${_convertirEnteros(resto)}';
      }
      return resultado;
    }
    if (numero < 1000000000) {
      final millones = numero ~/ 1000000;
      final resto = numero % 1000000;
      String resultado = '';
      if (millones == 1) {
        resultado = 'un millón';
      } else {
        resultado = '${_convertirEnteros(millones)} millones';
      }
      if (resto > 0) {
        resultado += ' ${_convertirEnteros(resto)}';
      }
      return resultado;
    }
    return numero.toString();
  }
  
  static const Map<int, String> _unidades = {
    1: 'uno',
    2: 'dos',
    3: 'tres',
    4: 'cuatro',
    5: 'cinco',
    6: 'seis',
    7: 'siete',
    8: 'ocho',
    9: 'nueve',
    10: 'diez',
    11: 'once',
    12: 'doce',
    13: 'trece',
    14: 'catorce',
    15: 'quince',
    16: 'dieciséis',
    17: 'diecisiete',
    18: 'dieciocho',
    19: 'diecinueve',
  };
  
  static const Map<int, String> _decenas = {
    2: 'veinte',
    3: 'treinta',
    4: 'cuarenta',
    5: 'cincuenta',
    6: 'sesenta',
    7: 'setenta',
    8: 'ochenta',
    9: 'noventa',
  };

  // ================= OBSERVACIONES LEGALES =================
  
  static pw.Widget _observacionesLegales(Empresa empresa) {
    final fechaActual = DateTime.now();
    final fechaFormateada = '${fechaActual.day.toString().padLeft(2, '0')}/${fechaActual.month.toString().padLeft(2, '0')}/${fechaActual.year}';
    
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 20),
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Observaciones Legales',
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'El empleador reconoce la autenticidad, autoría e integridad del presente documento. Último depósito de aportes realizado en Banco (Nombre del Banco) el día $fechaFormateada.',
            style: pw.TextStyle(
              fontSize: 9,
              fontStyle: pw.FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}
