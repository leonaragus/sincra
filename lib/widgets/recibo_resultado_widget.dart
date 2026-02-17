import 'package:flutter/material.dart';
import 'package:syncra_arg/models/recibo_model.dart';
import 'package:syncra_arg/theme/app_colors.dart';
import 'package:syncra_arg/widgets/recibo_calculadoras_widget.dart';

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
                    ],
                  ),
                ),

                // 2. Detalle
                SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildDetalleLiquidacion(context),
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
                    ],
                  ),
                ),

                // 4. Herramientas (Calculadoras)
                ReciboCalculadorasWidget(recibo: recibo),
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
            ],
          ],
        ),
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
                    const Text('Haberes (Ingresos)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green)),
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
                    const Text('Retenciones (Descuentos)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.red)),
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
            _buildTotalRow('Total Haberes Remunerativos', recibo.totales.totalBruto),
            _buildTotalRow('Total No Remunerativo', recibo.totales.totalNoRemunerativo),
            _buildTotalRow('Total Descuentos', recibo.totales.totalRetenciones, isNegative: true),
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

  Widget _buildTotalRow(String label, double value, {bool isNegative = false}) {
    if (value == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade800, fontSize: 15)),
          Text(
            '${isNegative ? '-' : ''}\$${value.toStringAsFixed(2)}',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isNegative ? Colors.red : Colors.black87),
          ),
        ],
      ),
    );
  }
}
