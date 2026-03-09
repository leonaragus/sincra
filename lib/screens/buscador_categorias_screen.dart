import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../data/cct_argentina_completo.dart';
import '../models/cct_completo.dart';
import '../services/educational_concepts_service.dart';
import '../theme/app_colors.dart';

class BuscadorCategoriasScreen extends StatefulWidget {
  const BuscadorCategoriasScreen({super.key});

  @override
  State<BuscadorCategoriasScreen> createState() => _BuscadorCategoriasScreenState();
}

class _BuscadorCategoriasScreenState extends State<BuscadorCategoriasScreen> {
  String _filtroTexto = '';
  String? _filtroConvenioId;
  final TextEditingController _searchController = TextEditingController();

  List<CCTCompleto> get _conveniosDisponibles => cctArgentinaCompleto;

  List<Map<String, dynamic>> _obtenerResultados() {
    List<Map<String, dynamic>> resultados = [];

    for (var cct in cctArgentinaCompleto) {
      if (_filtroConvenioId != null && cct.id != _filtroConvenioId) {
        continue;
      }

      for (var cat in cct.categorias) {
        if (_filtroTexto.isNotEmpty) {
          final texto = _filtroTexto.toLowerCase();
          final coincideNombre = cat.nombre.toLowerCase().contains(texto);
          final coincideDesc = cat.descripcion?.toLowerCase().contains(texto) ?? false;
          final coincideCCT = cct.nombre.toLowerCase().contains(texto);
          final coincideActividad = cct.actividad?.toLowerCase().contains(texto) ?? false;

          if (!coincideNombre && !coincideDesc && !coincideCCT && !coincideActividad) {
            continue;
          }
        }

        resultados.add({
          'cct': cct,
          'categoria': cat,
        });
      }
    }
    return resultados;
  }

  @override
  Widget build(BuildContext context) {
    final resultados = _obtenerResultados();
    final currencyFormat = NumberFormat.currency(locale: 'es_AR', symbol: '\$');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Buscador de Categorías', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Encontrá tu categoría laboral',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Si no sabés tu categoría, escribí las tareas que realizás (ej: "soldar", "limpiar", "atención").',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _searchController,
                  style: const TextStyle(color: AppColors.textPrimary), // FIX: Letras visibles al escribir
                  onChanged: (value) {
                    setState(() {
                      _filtroTexto = value;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Buscar por puesto, tarea o convenio...',
                    hintStyle: TextStyle(color: AppColors.textMuted),
                    prefixIcon: const Icon(Icons.search, color: AppColors.accentBlue),
                    suffixIcon: _filtroTexto.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: AppColors.textSecondary),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _filtroTexto = '';
                              });
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: AppColors.backgroundLight, // FIX: Fondo que combine con el sistema
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.border.withOpacity(0.5)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.accentBlue, width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _filtroConvenioId,
                  dropdownColor: AppColors.backgroundLight,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Filtrar por Convenio (Opcional)',
                    labelStyle: TextStyle(color: AppColors.textSecondary),
                    filled: true,
                    fillColor: AppColors.backgroundLight,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.border.withOpacity(0.5)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('Todos los Convenios'),
                    ),
                    ..._conveniosDisponibles.map((cct) {
                      return DropdownMenuItem<String>(
                        value: cct.id,
                        child: Text(
                          cct.nombre.length > 35 ? '${cct.nombre.substring(0, 32)}...' : cct.nombre,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _filtroConvenioId = value;
                    });
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: resultados.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, size: 64, color: AppColors.textMuted.withOpacity(0.3)),
                        const SizedBox(height: 16),
                        Text(
                          'No se encontraron categorías',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          'Intenta con otras palabras clave',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: resultados.length,
                    itemBuilder: (context, index) {
                      final item = resultados[index];
                      final CCTCompleto cct = item['cct'];
                      final CategoriaCCT cat = item['categoria'];
                      
                      return Card(
                        color: AppColors.backgroundCard,
                        margin: const EdgeInsets.only(bottom: 16),
                        elevation: 4,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: InkWell(
                          onTap: () {
                            _mostrarDetalleCategoria(context, cct, cat);
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppColors.accentBlue.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        cct.numeroCCT,
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.accentBlue,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        cct.nombre,
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          color: AppColors.textSecondary,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  cat.nombre,
                                  style: GoogleFonts.inter(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  currencyFormat.format(cat.salarioBase),
                                  style: GoogleFonts.inter(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.success,
                                  ),
                                ),
                                if (cat.descripcion != null) ...[
                                  const SizedBox(height: 12),
                                  Text(
                                    cat.descripcion!,
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      color: AppColors.textSecondary,
                                      height: 1.4,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showHelpDialog(BuildContext context, String conceptTitle) {
    final concept = EducationalConceptsService.findExplanation(conceptTitle);
    
    // Contenido de ayuda específico si no se encuentra en el servicio
    String title = conceptTitle;
    String explanation = 'No hay información disponible para este concepto.';

    if (concept != null) {
      title = concept.title;
      explanation = concept.explanation;
    } else if (conceptTitle == 'Sueldo Neto') {
      title = 'Sueldo Neto o "de Bolsillo"';
      explanation = 'Es la suma de dinero que efectivamente recibís en tu cuenta bancaria o en mano. Se calcula tomando tu sueldo bruto y restándole los descuentos obligatorios por ley, como los aportes a la jubilación, la obra social y el PAMI (Ley 19.032).';
    } else if (conceptTitle == 'Sueldo Básico') {
      title = 'Sueldo Básico';
      explanation = 'Es el salario mínimo fijado por convenio para tu categoría. Sobre este valor se calculan todos los adicionales (antigüedad, presentismo, etc.) y los descuentos de ley.';
    } else if (conceptTitle == 'Adicional por Antigüedad') {
      title = 'Adicional por Antigüedad';
      explanation = 'Es un extra que se paga por cada año de servicio en la empresa. El porcentaje varía según cada convenio colectivo (CCT).';
    } else if (conceptTitle == 'Adicional por Presentismo') {
      title = 'Adicional por Presentismo';
      explanation = 'Es un premio económico para los trabajadores que no tienen inasistencias injustificadas durante el mes.';
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.backgroundCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.help_outline, color: AppColors.accentBlue, size: 28),
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppColors.textPrimary))),
          ],
        ),
        content: Text(explanation, style: GoogleFonts.inter(height: 1.5, color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Entendido', style: TextStyle(color: AppColors.accentBlue, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _mostrarDetalleCategoria(BuildContext context, CCTCompleto cct, CategoriaCCT cat) {
    final currencyFormat = NumberFormat.currency(locale: 'es_AR', symbol: '\$');
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent, // FIX: Para usar el diseño de la app
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.textMuted.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  cat.nombre,
                  style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.business, size: 16, color: AppColors.textSecondary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${cct.nombre} (CCT ${cct.numeroCCT})',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _buildInfoSection(
                  'Sueldo Básico Estimado',
                  currencyFormat.format(cat.salarioBase),
                  isPrice: true,
                  helpTopic: 'Sueldo Básico',
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.accentBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.accentBlue.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, size: 20, color: AppColors.accentBlue),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Este valor refleja la escala salarial vigente más reciente. Es la base sobre la que se calculan tus descuentos y adicionales.',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // --- SECCIÓN DE CÁLCULO NETO ---
                _buildNetoEstimadoSection(cat, cct),
                // --------------------------------

                const SizedBox(height: 16),
                if (cat.descripcion != null)
                  _buildInfoSection('Descripción de Tareas', cat.descripcion!),
                const SizedBox(height: 16),
                _buildInfoSection('Actividad', cct.actividad ?? 'No especificada'),
                const SizedBox(height: 16),
                _buildInfoSection('Fecha de Vigencia', DateFormat('MMMM yyyy', 'es_AR').format(cct.fechaVigencia)),
                
                const SizedBox(height: 24),
                const Divider(color: AppColors.border),
                const SizedBox(height: 16),
                Text(
                  'Adicionales del Convenio',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                if (cct.adicionalAntiguedad > 0 || cct.porcentajeAntiguedadAnual > 0)
                  _buildAdicionalRow(
                    'Antigüedad', 
                    '${cct.porcentajeAntiguedadAnual}% por año',
                    helpTopic: 'Adicional por Antigüedad',
                  ),
                if (cct.adicionalPresentismo > 0)
                  _buildAdicionalRow(
                    'Presentismo',
                    '${cct.adicionalPresentismo}%',
                    helpTopic: 'Adicional por Presentismo',
                  ),
                
                if (cct.zonas.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Zonas Geográficas',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...cct.zonas.map((z) => _buildAdicionalRow(
                    z.nombre, 
                    '+${z.adicionalPorcentaje}%${z.descripcion != null ? " (${z.descripcion})" : ""}'
                  )).toList(),
                ],
                
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Entendido', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNetoEstimadoSection(CategoriaCCT cat, CCTCompleto cct) {
    final currencyFormat = NumberFormat.currency(locale: 'es_AR', symbol: '\$');
    
    final descuentosDeLey = cct.descuentos.where((d) {
      final nombre = d.nombre.toLowerCase();
      return nombre.contains('jubilación') || nombre.contains('obra social') || nombre.contains('ley 19.032');
    }).toList();

    if (descuentosDeLey.isEmpty) {
      descuentosDeLey.addAll([
          const DescuentoCCT(id: 'jubilacion', nombre: 'Jubilación', porcentaje: 11.0),
          const DescuentoCCT(id: 'ley_19032', nombre: 'Ley 19.032', porcentaje: 3.0),
          const DescuentoCCT(id: 'obra_social', nombre: 'Obra Social', porcentaje: 3.0),
      ]);
    }

    final totalPorcentaje = descuentosDeLey.fold<double>(0.0, (sum, item) => sum + item.porcentaje);
    final montoDescuentos = cat.salarioBase * (totalPorcentaje / 100);
    final netoEstimado = cat.salarioBase - montoDescuentos;

    final descuentosDesc = descuentosDeLey.map((d) => '${d.porcentaje}%').join(' + ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const Divider(color: AppColors.border),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Estimación "de Bolsillo"',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 8),
            _buildHelpIcon('Sueldo Neto'),
          ],
        ),
        const SizedBox(height: 16),

        _buildCalculationRow('Sueldo Básico', cat.salarioBase, currencyFormat, isPositive: true),
        _buildCalculationRow('Descuentos de Ley ($descuentosDesc)', montoDescuentos, currencyFormat, isPositive: false),
        
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          child: Divider(thickness: 1.5, color: AppColors.border),
        ),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Neto Estimado',
              style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            Text(
              currencyFormat.format(netoEstimado),
              style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.success),
            ),
          ],
        ),

        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.warning.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.warning.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, size: 20, color: AppColors.warning),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Cálculo aproximado sólo sobre el básico. No incluye adicionales (antigüedad, presentismo), horas extras, ni el impuesto a las ganancias.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCalculationRow(String label, double amount, NumberFormat format, {required bool isPositive}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary),
          ),
          Text(
            '${isPositive ? '' : '- '}${format.format(amount)}',
            style: GoogleFonts.inter(
              fontSize: 14, 
              color: isPositive ? AppColors.success : AppColors.error,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(String title, String content, {bool isPrice = false, String? helpTopic}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
            if (helpTopic != null) ...[
              const SizedBox(width: 8),
              _buildHelpIcon(helpTopic),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Text(
          content,
          style: GoogleFonts.inter(
            fontSize: isPrice ? 28 : 16,
            fontWeight: isPrice ? FontWeight.bold : FontWeight.normal,
            color: isPrice ? AppColors.success : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildAdicionalRow(String label, String value, {String? helpTopic}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(color: AppColors.textSecondary),
                ),
                if (helpTopic != null) ...[
                  const SizedBox(width: 8),
                  _buildHelpIcon(helpTopic),
                ],
              ],
            ),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpIcon(String topic) {
    return InkWell(
      onTap: () => _showHelpDialog(context, topic),
      borderRadius: BorderRadius.circular(20),
      child: const Icon(
        Icons.help_outline,
        size: 18,
        color: AppColors.accentBlue, // FIX: Color de ayuda estandarizado
      ),
    );
  }
}
