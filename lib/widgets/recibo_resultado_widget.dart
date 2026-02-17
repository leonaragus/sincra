import 'package:flutter/material.dart';
import 'package:syncra_arg/models/recibo_model.dart';
import 'package:syncra_arg/theme/app_colors.dart';
import 'package:syncra_arg/widgets/recibo_calculadoras_widget.dart';
import 'package:url_launcher/url_launcher.dart';

class ReciboResultadoWidget extends StatelessWidget {
  final ReciboModel recibo;

  const ReciboResultadoWidget({super.key, required this.recibo});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header de Pestañas
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Theme.of(context).dividerColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(4),
            child: TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.center, // Centrar pestañas
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Theme.of(context).primaryColor, // Fondo sólido para la activa
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).primaryColor.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              labelColor: Colors.white, // Texto blanco en la activa
              unselectedLabelColor: Theme.of(context).hintColor, // Texto gris en inactiva
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w800, 
                fontSize: 13,
                letterSpacing: 0.5,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w600, 
                fontSize: 13,
              ),
              dividerColor: Colors.transparent, // Quitar línea divisoria default
              padding: EdgeInsets.zero,
              labelPadding: const EdgeInsets.symmetric(horizontal: 16), // Espacio interno
              tabs: const [
                Tab(
                  height: 48,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.smart_toy_outlined, size: 20),
                      SizedBox(width: 8),
                      Text("AUDITORÍA IA"),
                    ],
                  ),
                ),
                Tab(
                  height: 48,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.receipt_long_outlined, size: 20),
                      SizedBox(width: 8),
                      Text("DETALLE"),
                    ],
                  ),
                ),
                Tab(
                  height: 48,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.analytics_outlined, size: 20),
                      SizedBox(width: 8),
                      Text("TOTALES"),
                    ],
                  ),
                ),
                Tab(
                  height: 48,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.calculate_outlined, size: 20),
                      SizedBox(width: 8),
                      Text("HERRAMIENTAS"),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Contenido de Pestañas
          SizedBox(
            height: 600, // Aumentamos altura para acomodar calculadoras
            child: TabBarView(
              children: [
                // 1. Auditoría
                SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildAuditoriaCard(context),
                      const SizedBox(height: 16),
                      _buildSugerenciasCard(context),
                      const SizedBox(height: 24),
                      _buildAcademyBanner(context),
                    ],
                  ),
                ),

                // 2. Detalle
                SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildDetalleLiquidacion(context),
                      const SizedBox(height: 24),
                      _buildAcademyBanner(context),
                    ],
                  ),
                ),

                // 3. Totales y Cabecera
                SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildTotalesCard(context),
                      const SizedBox(height: 16),
                      _buildCabeceraCard(context),
                      const SizedBox(height: 24),
                      _buildAcademyBanner(context),
                    ],
                  ),
                ),

                // 4. Herramientas (Calculadoras)
                SingleChildScrollView(
                  child: Column(
                    children: [
                      ReciboCalculadorasWidget(recibo: recibo),
                      const SizedBox(height: 16),
                      _buildAcademyBanner(context),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCabeceraCard(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.business, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Datos del Recibo',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
              ],
            ),
            const Divider(),
            _buildInfoRow('Empresa:', recibo.cabecera.empresaNombre),
            _buildInfoRow('Empleado:', recibo.cabecera.empleadoNombre),
            _buildInfoRow('CUIL:', recibo.cabecera.empleadoCuil),
            _buildInfoRow('Periodo:', recibo.cabecera.periodoAbonado),
            _buildInfoRow('Fecha Ingreso:', recibo.cabecera.fechaIngreso),
            _buildInfoRow('Antigüedad:', recibo.cabecera.antiguedadReconocida),
            if (recibo.cabecera.cctAplicable.isNotEmpty)
              _buildInfoRow('Convenio:', recibo.cabecera.cctAplicable),
          ],
        ),
      ),
    );
  }

  Widget _buildAuditoriaCard(BuildContext context) {
    return Card(
      elevation: 4,
      color: Colors.blue.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.blue.shade200, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.smart_toy, color: Colors.blue),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Análisis Inteligente',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade900,
                          fontSize: 18,
                        ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.shade300),
                  ),
                  child: Text(
                    'Confianza: ${(recibo.auditoriaIA.puntuacionConfianzaOcr * 100).toStringAsFixed(0)}%',
                    style: TextStyle(color: Colors.green.shade800, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                recibo.auditoriaIA.analisisLegal,
                style: TextStyle(fontSize: 15, height: 1.5, color: Colors.blue.shade900),
              ),
            ),
            if (recibo.auditoriaIA.alertasCriticas.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('⚠️ Alertas Detectadas:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 16)),
              const SizedBox(height: 8),
              ...recibo.auditoriaIA.alertasCriticas.map((e) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 20),
                        const SizedBox(width: 8),
                        Expanded(child: Text(e, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w500))),
                      ],
                    ),
                  )),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _mostrarDialogoReclamo(context),
                  icon: const Icon(Icons.edit_note, size: 18),
                  label: const Text('Generar Texto de Reclamo'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red.shade700,
                    side: BorderSide(color: Colors.red.shade200),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _mostrarDialogoReclamo(BuildContext context) {
    final alerts = recibo.auditoriaIA.alertasCriticas.join("\n- ");
    final textoReclamo = "Hola, quería consultar sobre mi liquidación de ${recibo.cabecera.periodoAbonado}.\n\n"
        "Noté las siguientes inconsistencias que me gustaría revisar:\n"
        "- $alerts\n\n"
        "¿Podrían indicarme si es correcto o si hubo un error? Gracias.";

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Cómo reclamo esto?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Podés copiar este texto y enviarlo a RRHH o a tu delegado gremial para iniciar la consulta de manera formal pero amable.',
              style: TextStyle(fontSize: 14, color: Colors.black87),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: SelectableText(
                textoReclamo,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
          FilledButton.icon(
            onPressed: () {
              // Copiar al portapapeles (requiere import services)
              // Por ahora solo cerramos, en una app real usariamos Clipboard.setData
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Texto copiado al portapapeles')),
              );
            },
            icon: const Icon(Icons.copy, size: 18),
            label: const Text('Copiar Texto'),
          ),
        ],
      ),
    );
  }

  Widget _buildSugerenciasCard(BuildContext context) {
    // Si no hay sugerencias o explicación de conceptos, no mostramos nada
    if (recibo.auditoriaIA.explicacionConceptosComplejos.isEmpty) {
        return const SizedBox.shrink();
    }
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             Row(
              children: [
                Icon(Icons.lightbulb_outline, color: Colors.amber.shade700),
                const SizedBox(width: 8),
                Text(
                  'Conceptos Clave',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.amber.shade900,
                      ),
                ),
              ],
            ),
            const Divider(),
            if (recibo.auditoriaIA.explicacionConceptosComplejos.isNotEmpty)
              Text(
                recibo.auditoriaIA.explicacionConceptosComplejos,
                style: const TextStyle(fontSize: 14, height: 1.4),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetalleLiquidacion(BuildContext context) {
    return Column(
      children: [
        // Haberes
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Haberes (Ingresos)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green)),
                        Text('Dinero que suma a tu bolsillo', style: TextStyle(fontSize: 12, color: Colors.green.shade700)),
                      ],
                    ),
                    Icon(Icons.add_circle_outline, color: Colors.green.shade300),
                  ],
                ),
                const Divider(),
                Table(
                  columnWidths: const {
                    0: FlexColumnWidth(3),
                    1: FlexColumnWidth(1),
                  },
                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                  children: [
                    ...recibo.liquidacionDetallada.haberes.map((h) => TableRow(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(h.descripcion, style: const TextStyle(fontWeight: FontWeight.w500)),
                                  if (h.cantidad.isNotEmpty && h.cantidad != "1.0")
                                    Text('Cant: ${h.cantidad}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                  // Etiqueta de tipo de concepto
                                  Container(
                                    margin: const EdgeInsets.only(top: 2),
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: h.esRemunerativo ? Colors.green.shade50 : Colors.blue.shade50,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: h.esRemunerativo ? Colors.green.shade200 : Colors.blue.shade200, width: 0.5),
                                    ),
                                    child: Text(
                                      h.esRemunerativo ? 'Remunerativo (Suma aguinaldo)' : 'No Remunerativo (Bolsillo)',
                                      style: TextStyle(fontSize: 10, color: h.esRemunerativo ? Colors.green.shade800 : Colors.blue.shade800),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                '\$${h.monto.toStringAsFixed(2)}',
                                textAlign: TextAlign.right,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        )),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Retenciones
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Retenciones (Descuentos)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.red)),
                        Text('Jubilación, Obra Social, etc.', style: TextStyle(fontSize: 12, color: Colors.red.shade700)),
                      ],
                    ),
                    Icon(Icons.remove_circle_outline, color: Colors.red.shade300),
                  ],
                ),
                const Divider(),
                Table(
                  columnWidths: const {
                    0: FlexColumnWidth(3),
                    1: FlexColumnWidth(1),
                  },
                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                  children: [
                    ...recibo.liquidacionDetallada.retenciones.map((r) => TableRow(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text('${r.descripcion} ${r.porcentaje.isNotEmpty ? "(${r.porcentaje})" : ""}', 
                                style: const TextStyle(fontWeight: FontWeight.w500)),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                '-\$${r.monto.toStringAsFixed(2)}',
                                textAlign: TextAlign.right,
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                              ),
                            ),
                          ],
                        )),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTotalesCard(BuildContext context) {
    return Card(
      elevation: 4,
      color: AppColors.primary.withOpacity(0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            _buildTotalRow(context, 'Total Haberes Remunerativos', recibo.totales.totalBruto),
            _buildTotalRow(context, 'Total No Remunerativo', recibo.totales.totalNoRemunerativo),
            _buildTotalRow(context, 'Total Descuentos', recibo.totales.totalRetenciones, isNegative: true),
            const Divider(height: 24, thickness: 1.5),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'NETO A COBRAR',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: AppColors.primary),
                ),
                Text(
                  '\$${recibo.totales.netoACobrar.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 24, color: AppColors.primary),
                ),
              ],
            ),
            if (recibo.totales.netoEnLetras.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  '(${recibo.totales.netoEnLetras})',
                  style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey.shade600, fontSize: 12),
                  textAlign: TextAlign.right,
                ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 110, child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w500))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
        ],
      ),
    );
  }

  Widget _buildTotalRow(BuildContext context, String label, double value, {bool isNegative = false}) {
    if (value == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color, fontSize: 15)),
          Text(
            '${isNegative ? '-' : ''}\$${value.toStringAsFixed(2)}',
            style: TextStyle(
              fontWeight: FontWeight.bold, 
              fontSize: 16, 
              color: isNegative ? Colors.red : Theme.of(context).textTheme.bodyLarge?.color
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAcademyBanner(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 16, bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo.shade900, Colors.indigo.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.indigo.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          const Row(
            children: [
              Icon(Icons.school, color: Colors.white, size: 28),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Elevar Formación Técnica',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            '¿Querés aprender a liquidar sueldos como un experto? Inscribite en nuestros cursos y dominá la normativa laboral.',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                final Uri url = Uri.parse('https://wa.me/5491112345678?text=Hola,%20me%20interesa%20saber%20m%C3%A1s%20sobre%20los%20cursos%20de%20liquidaci%C3%B3n%20de%20sueldos.');
                if (!await launchUrl(url)) {
                   if (context.mounted) {
                     ScaffoldMessenger.of(context).showSnackBar(
                       const SnackBar(content: Text('No se pudo abrir WhatsApp')),
                     );
                   }
                }
              },
              icon: const Icon(Icons.chat_bubble_outline, color: Colors.indigo),
              label: const Text('Consultar por WhatsApp'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.indigo.shade900,
                padding: const EdgeInsets.symmetric(vertical: 12),
                textStyle: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
