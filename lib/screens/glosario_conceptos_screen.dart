import 'package:flutter/material.dart';
import 'package:syncra_arg/services/conceptos_explicaciones_service.dart';
import 'package:syncra_arg/theme/app_colors.dart';

class GlosarioConceptosScreen extends StatelessWidget {
  const GlosarioConceptosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final todasExplicaciones = ConceptosExplicacionesService.obtenerTodasExplicaciones();
    final remunerativos = ConceptosExplicacionesService.obtenerExplicacionesPorCategoria('remunerativo');
    final noRemunerativos = ConceptosExplicacionesService.obtenerExplicacionesPorCategoria('no remunerativo');
    final deducciones = ConceptosExplicacionesService.obtenerExplicacionesPorCategoria('deduccion');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundLight,
        surfaceTintColor: AppColors.backgroundLight,
        title: const Text('Glosario de Conceptos'),
        centerTitle: true,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
      ),
      body: DefaultTabController(
        length: 4,
        child: Column(
          children: [
            Container(
              color: AppColors.backgroundLight,
              child: TabBar(
                isScrollable: true,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textSecondary,
                indicatorColor: AppColors.primary,
                indicatorSize: TabBarIndicatorSize.tab,
                tabs: const [
                  Tab(text: 'Todos'),
                  Tab(text: 'Remunerativos'),
                  Tab(text: 'No Remunerativos'),
                  Tab(text: 'Deducciones'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildListaConceptos(todasExplicaciones),
                  _buildListaConceptos(remunerativos),
                  _buildListaConceptos(noRemunerativos),
                  _buildListaConceptos(deducciones),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListaConceptos(Map<String, Map<String, String>> conceptos) {
    if (conceptos.isEmpty) {
      return Center(
        child: Text(
          'No hay conceptos en esta categoría',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 16,
          ),
        ),
      );
    }

    final listaOrdenada = conceptos.entries.toList()
      ..sort((a, b) => a.value['titulo']!.compareTo(b.value['titulo']!));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: listaOrdenada.length,
      itemBuilder: (context, index) {
        final entry = listaOrdenada[index];
        final concepto = entry.value;
        
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          color: AppColors.backgroundLight,
          surfaceTintColor: AppColors.backgroundLight,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: AppColors.glassBorder, width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header con título y categoría
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        concepto['titulo'] ?? entry.key,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getColorCategoria(concepto['categoria']).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _getLabelCategoria(concepto['categoria']),
                        style: TextStyle(
                          color: _getColorCategoria(concepto['categoria']),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                // Explicación
                Text(
                  concepto['explicacion'] ?? 'No hay explicación disponible.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                
                const SizedBox(height: 8),
                
                // Palabras clave relacionadas
                Text(
                  'También conocido como: ${entry.key}',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _getColorCategoria(String? categoria) {
    switch (categoria) {
      case 'remunerativo':
        return AppColors.accentGreen;
      case 'no remunerativo':
        return AppColors.accentBlue;
      case 'deduccion':
        return AppColors.accentRed;
      default:
        return AppColors.textSecondary;
    }
  }

  String _getLabelCategoria(String? categoria) {
    switch (categoria) {
      case 'remunerativo':
        return 'REMUNERATIVO';
      case 'no remunerativo':
        return 'NO REMUNERATIVO';
      case 'deduccion':
        return 'DEDUCCIÓN';
      default:
        return 'OTRO';
    }
  }
}