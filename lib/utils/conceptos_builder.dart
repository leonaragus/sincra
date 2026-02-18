import 'package:flutter/material.dart';
import 'package:syncra_arg/models/recibo_escaneado.dart';
import 'package:syncra_arg/services/conceptos_explicaciones_service.dart';
import 'package:syncra_arg/theme/app_colors.dart';

class ConceptosBuilder {
  static Widget buildResumenConceptos(ReciboEscaneado? recibo, BuildContext context) {
    if (recibo == null || recibo.conceptos.isEmpty) return const SizedBox.shrink();
    
    // Separar conceptos por tipo
    final conceptosRemunerativos = <String, double>{};
    final conceptosNoRemunerativos = <String, double>{};
    final conceptosDeducciones = <String, double>{};
    
    for (final concepto in recibo.conceptos) {
      if (concepto.remunerativo != null && concepto.remunerativo! > 0) {
        conceptosRemunerativos[concepto.descripcion] = (conceptosRemunerativos[concepto.descripcion] ?? 0) + concepto.remunerativo!;
      }
      if (concepto.noRemunerativo != null && concepto.noRemunerativo! > 0) {
        conceptosNoRemunerativos[concepto.descripcion] = (conceptosNoRemunerativos[concepto.descripcion] ?? 0) + concepto.noRemunerativo!;
      }
      if (concepto.deducciones != null && concepto.deducciones! > 0) {
        conceptosDeducciones[concepto.descripcion] = (conceptosDeducciones[concepto.descripcion] ?? 0) + concepto.deducciones!;
      }
    }

    final totalRemunerativos = conceptosRemunerativos.values.fold(0.0, (sum, value) => sum + value);
    final totalNoRemunerativos = conceptosNoRemunerativos.values.fold(0.0, (sum, value) => sum + value);
    final totalDeducciones = conceptosDeducciones.values.fold(0.0, (sum, value) => sum + value);
    final totalBruto = totalRemunerativos + totalNoRemunerativos;
    final totalNeto = recibo.sueldoNeto;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.glassBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header con estadísticas
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.list_alt, size: 18, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Conceptos detectados',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${conceptosRemunerativos.length + conceptosNoRemunerativos.length + conceptosDeducciones.length} items',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Resumen de totales
          _buildTotalRow('💰 Total Bruto', totalBruto, AppColors.accentGreen),
          _buildTotalRow('📉 Deducciones', totalDeducciones, AppColors.accentRed),
          _buildTotalRow('💵 Total Neto', totalNeto, AppColors.primary, isBold: true),
          
          const SizedBox(height: 16),
          const Divider(height: 1, color: AppColors.glassBorder),
          const SizedBox(height: 12),

          // Conceptos remunerativos
          if (conceptosRemunerativos.isNotEmpty) ...[
            _buildConceptosSection('📈 Remunerativos', conceptosRemunerativos, AppColors.accentGreen, context),
            const SizedBox(height: 12),
          ],

          // Conceptos no remunerativos
          if (conceptosNoRemunerativos.isNotEmpty) ...[
            _buildConceptosSection('🎁 No Remunerativos', conceptosNoRemunerativos, AppColors.accentBlue, context),
            const SizedBox(height: 12),
          ],

          // Deducciones
          if (conceptosDeducciones.isNotEmpty) ...[
            _buildConceptosSection('📉 Deducciones', conceptosDeducciones, AppColors.accentRed, context),
          ],
        ],
      ),
    );
  }

  static Widget _buildTotalRow(String label, double value, Color color, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            '\${value.toStringAsFixed(2)}',
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildConceptosSection(String title, Map<String, double> conceptos, Color color, BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              title,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                conceptos.length.toString(),
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...conceptos.entries.map((entry) => _buildConceptoRow(entry.key, entry.value, color, context)),
      ],
    );
  }

  static Widget _buildConceptoRow(String concepto, double monto, Color color, BuildContext context) {
    final explicacion = ConceptosExplicacionesService.obtenerExplicacion(concepto);
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    concepto,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (explicacion != null) ...[
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () => _mostrarExplicacionConcepto(explicacion, concepto, monto, context),
                    child: Icon(
                      Icons.info_outline,
                      color: color,
                      size: 16,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Text(
            '\${monto.toStringAsFixed(2)}',
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  static void _mostrarExplicacionConcepto(Map<String, String> explicacion, String concepto, double monto, BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.backgroundLight,
        surfaceTintColor: AppColors.backgroundLight,
        title: Row(
          children: [
            Icon(Icons.lightbulb_outline, color: AppColors.primary, size: 24),
            const SizedBox(width: 8),
            Text(
              explicacion['titulo'] ?? concepto,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(
          explicacion['explicacion'] ?? 'No hay explicación disponible para este concepto.',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Entendido',
              style: TextStyle(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}