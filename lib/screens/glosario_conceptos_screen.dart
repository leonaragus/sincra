import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/educational_concepts_service.dart';
import '../theme/app_colors.dart';
import 'biblioteca_cct_screen.dart';

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
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.secondary, AppColors.secondary.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: AppColors.glassBorder.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.school, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Elevar Formación Técnica',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    Text(
                      'Academia de Liquidadores',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 12,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Convertite en un experto en liquidación de sueldos con nuestros cursos prácticos y actualizados.',
            style: TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              // Botón WhatsApp
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final phone = EducationalConceptsService.contactoAcademia;
                    final url = Uri.parse('https://wa.me/$phone?text=Hola! Me gustaría recibir información sobre los cursos de liquidación de sueldos.');
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url, mode: LaunchMode.externalApplication);
                    }
                  },
                  icon: const Icon(Icons.chat_bubble_outline, size: 18),
                  label: const Text('WhatsApp'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Botón Biblioteca
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (c) => const BibliotecaCCTScreen()));
                  },
                  icon: const Icon(Icons.menu_book, size: 18),
                  label: const Text('Convenios'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white24),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
