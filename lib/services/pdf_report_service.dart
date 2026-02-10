import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:syncra_arg/models/recibo_escaneado.dart';
import 'package:flutter/services.dart';

class PdfReportService {
  static Future<void> generateAndDownloadReport({
    required ReciboEscaneado recibo,
    required List<String> detalles,
    required List<String> itemsRevisar,
    required List<String> alertasGraves,
    required String convenio,
  }) async {
    final doc = pw.Document();

    // Intentar cargar logo si existe (opcional)
    // final logo = await imageFromAssetBundle('assets/logo.png');

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Elevar Formación Técnica',
                            style: pw.TextStyle(
                                fontSize: 24, fontWeight: pw.FontWeight.bold)),
                        pw.Text('Expertos en Liquidación de Sueldos',
                            style: pw.TextStyle(
                                fontSize: 14, color: PdfColors.grey700)),
                      ],
                    ),
                    pw.Text('INFORME DE VERIFICACIÓN',
                        style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColor.fromInt(0xFF3b82f6))), // AppColors.accentBlue
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // Info General
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey400),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Resumen del Análisis',
                        style: pw.TextStyle(
                            fontSize: 16, fontWeight: pw.FontWeight.bold)),
                    pw.Divider(),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Convenio Aplicado: $convenio'),
                        pw.Text(
                            'Fecha: ${DateTime.now().toIso8601String().substring(0, 10)}'),
                      ],
                    ),
                    pw.SizedBox(height: 5),
                    pw.Text(
                        'Total Neto Detectado: \$${recibo.sueldoNeto.toStringAsFixed(2)}'),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // Alertas Graves
              if (alertasGraves.isNotEmpty) ...[
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  color: PdfColors.red50,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('⚠️ ALERTAS CRÍTICAS',
                          style: pw.TextStyle(
                              color: PdfColors.red900,
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 14)),
                      pw.SizedBox(height: 5),
                      ...alertasGraves.map((e) => pw.Bullet(
                          text: e,
                          style: pw.TextStyle(color: PdfColors.red900))),
                    ],
                  ),
                ),
                pw.SizedBox(height: 15),
              ],

              // Items a Revisar
              if (itemsRevisar.isNotEmpty) ...[
                pw.Text('Sugerencias de Revisión',
                    style: pw.TextStyle(
                        color: PdfColors.orange800,
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 14)),
                ...itemsRevisar.map((e) => pw.Bullet(text: e)),
                pw.SizedBox(height: 15),
              ],

              // Detalles
              pw.Text('Detalles Técnicos',
                  style: pw.TextStyle(
                      fontSize: 14, fontWeight: pw.FontWeight.bold)),
              ...detalles.map((e) => pw.Bullet(text: e, bulletSize: 2)),

              pw.Spacer(),

              // Footer / Promo
              pw.Divider(color: PdfColors.blue800, thickness: 2),
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text('¿Querés aprender a liquidar sueldos como un experto?',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Text('Sumate a Elevar Formación Técnica'),
                    pw.Text('Capacitación profesional para el mundo real',
                        style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: 'informe_liquidacion_elevar.pdf',
    );
  }
}
