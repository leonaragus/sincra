import 'package:flutter/material.dart';
import 'package:syncra_arg/services/conceptos_explicaciones_service.dart';
import 'package:syncra_arg/theme/app_colors.dart';

class ConceptosUtils {
  static Widget buildConceptoRow(String concepto, double monto, Color color) {
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
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (explicacion != null) ...[
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () => _mostrarExplicacionConcepto(explicacion, concepto, monto),
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
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  static void _mostrarExplicacionConcepto(Map<String, String> explicacion, String concepto, double monto) {
    // Esta función se implementará en el contexto de la pantalla principal
  }
}