import 'package:flutter/material.dart';
import 'package:syncra_arg/services/conceptos_explicaciones_service.dart';
import 'package:syncra_arg/theme/app_colors.dart';

class TooltipUtils {
  static Widget buildConceptoWithTooltip(String concepto, double monto, Color color) {
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
                    onTap: () => _mostrarExplicacionTooltip(concepto, monto, explicacion),
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

  static void _mostrarExplicacionTooltip(String concepto, double monto, Map<String, String> explicacion) {
    // Esta función se implementará en el contexto de la pantalla principal
    // usando un GlobalKey o pasando el contexto
    print('Mostrar tooltip para: $concepto - \${monto.toStringAsFixed(2)}');
    print('Explicación: ${explicacion['titulo']}');
  }
}