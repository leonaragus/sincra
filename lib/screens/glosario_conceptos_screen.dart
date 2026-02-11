import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/educational_concepts_service.dart';
import '../theme/app_colors.dart';

class GlosarioConceptosScreen extends StatefulWidget {
  const GlosarioConceptosScreen({super.key});

  @override
  State<GlosarioConceptosScreen> createState() => _GlosarioConceptosScreenState();
}

class _GlosarioConceptosScreenState extends State<GlosarioConceptosScreen> {
  String _query = '';
  String? _filtroCategoria;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // Filtrar conceptos
    var resultados = EducationalConceptsService.conceptos;
    
    if (_query.isNotEmpty) {
      resultados = EducationalConceptsService.buscar(_query);
    }
    
    if (_filtroCategoria != null) {
      resultados = resultados.where((c) => c.categoria == _filtroCategoria).toList();
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Glosario Interactivo', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Banner Promocional Academia
          _buildAcademyBanner(context),

          // Buscador y Filtros
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(
                  onChanged: (val) => setState(() => _query = val),
                  decoration: InputDecoration(
                    hintText: 'Buscar concepto (ej: Jubilación, Básico...)',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: theme.cardColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('Todos', null),
                      const SizedBox(width: 8),
                      _buildFilterChip('Remunerativos', 'Remunerativo'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Descuentos', 'Descuento'),
                      const SizedBox(width: 8),
                      _buildFilterChip('No Remunerativos', 'No Remunerativo'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Lista de Conceptos
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: resultados.length,
              itemBuilder: (context, index) {
                final c = resultados[index];
                return _buildConceptoCard(c, theme);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String? categoria) {
    final isSelected = _filtroCategoria == categoria;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (bool selected) {
        setState(() {
          _filtroCategoria = selected ? categoria : null;
        });
      },
      backgroundColor: Theme.of(context).cardColor,
      selectedColor: AppColors.accentBlue.withOpacity(0.2),
      labelStyle: TextStyle(
        color: isSelected ? AppColors.accentBlue : AppColors.textSecondary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? AppColors.accentBlue : Colors.transparent,
        ),
      ),
    );
  }

  Widget _buildConceptoCard(ConceptoEducativo c, ThemeData theme) {
    Color cardColor;
    IconData icon;
    
    switch (c.categoria) {
      case 'Remunerativo':
        cardColor = Colors.green.shade900.withOpacity(0.2);
        icon = Icons.add_circle_outline;
        break;
      case 'Descuento':
        cardColor = Colors.red.shade900.withOpacity(0.2);
        icon = Icons.remove_circle_outline;
        break;
      default:
        cardColor = Colors.orange.shade900.withOpacity(0.2);
        icon = Icons.info_outline;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: theme.cardColor,
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: _getIconColor(c.categoria)),
          ),
          title: Text(
            c.titulo,
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          subtitle: Text(
            c.definicionCorta,
            style: TextStyle(color: theme.hintColor, fontSize: 13),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(),
                  Text(
                    c.explicacionDetallada,
                    style: TextStyle(height: 1.5, color: theme.textTheme.bodyLarge?.color),
                  ),
                  if (c.ejemplo != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.accentBlue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.accentBlue.withOpacity(0.3)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.lightbulb, size: 16, color: AppColors.accentBlue),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Ejemplo: ${c.ejemplo}',
                              style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getIconColor(String categoria) {
    switch (categoria) {
      case 'Remunerativo': return Colors.green;
      case 'Descuento': return Colors.red;
      default: return Colors.orange;
    }
  }

  Widget _buildAcademyBanner(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.secondary, AppColors.secondary.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.secondary.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.school, color: Colors.white, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '¿Querés aprender más?',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Convertite en un experto en liquidación de sueldos con nuestros cursos especializados.',
            style: TextStyle(color: Colors.white, fontSize: 14),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.business, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Text(
                  EducationalConceptsService.nombreAcademia,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
