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
                  color: Colors.black.withOpacity(0.05),
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
                  onChanged: (value) {
                    setState(() {
                      _filtroTexto = value;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Buscar por puesto, tarea o convenio...',
                    prefixIcon: const Icon(Icons.search, color: AppColors.primary),
                    suffixIcon: _filtroTexto.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _filtroTexto = '';
                              });
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _filtroConvenioId,
                  decoration: InputDecoration(
                    labelText: 'Filtrar por Convenio (Opcional)',
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
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
                        Icon(Icons.search_off, size: 64, color: Colors.grey.shade300),
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
                        margin: const EdgeInsets.only(bottom: 16),
                        elevation: 2,
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
                                        color: AppColors.primary.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        cct.numeroCCT,
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primary,
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
                                    color: Colors.green.shade700,
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
    final concept = EducationalConceptsService.getConceptByTitle(conceptTitle);
    if (concept == null) {
      // Fallback for concepts not yet in the service
       if (conceptTitle == 'Sueldo Neto') {
         showDialog(
           context: context,
           builder: (context) => AlertDialog(
             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
             title: Row(
               children: [
                 Icon(Icons.help_outline, color: AppColors.primary.withOpacity(0.8)),
                 const SizedBox(width: 10),
                 Expanded(child: Text('Sueldo Neto o "de Bolsillo"', style: GoogleFonts.inter(fontWeight: FontWeight.bold))),
               ],
             ),
             content: Text(
               'Es la suma de dinero que efectivamente recibís en tu cuenta bancaria o en mano. Se calcula tomando tu sueldo bruto y restándole los descuentos obligatorios por ley, como los aportes a la jubilación, la obra social y el PAMI (Ley 19.032).',
                style: GoogleFonts.inter(height: 1.4)
              ),
             actions: [
               TextButton(
                 onPressed: () => Navigator.of(context).pop(),
                 child: const Text('Entendido'),
               ),
             ],
           ),
         );
       }
       return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.help_outline, color: AppColors.primary.withOpacity(0.8)),
            const SizedBox(width: 10),
            Expanded(child: Text(concept.titulo, style: GoogleFonts.inter(fontWeight: FontWeight.bold))),
          ],
        ),
        content: Text(concept.explicacionDetallada, style: GoogleFonts.inter(height: 1.4)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Entendido'),
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
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
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
                    color: Colors.grey.shade300,
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
                  Icon(Icons.business, size: 16, color: AppColors.textSecondary),
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
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 20, color: Colors.blue.shade700),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Este valor refleja la escala salarial vigente más reciente. Es la base sobre la que se calculan tus descuentos y adicionales.',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.blue.shade900,
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
              const Divider(),
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
              
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Entendido'),
                ),
              ),
            ],
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
        const Divider(),
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
            InkWell(
              onTap: () => _showHelpDialog(context, 'Sueldo Neto'),
              borderRadius: BorderRadius.circular(30),
              child: const Icon(Icons.help_outline, size: 18, color: AppColors.textMuted),
            ),
          ],
        ),
        const SizedBox(height: 16),

        _buildCalculationRow('Sueldo Básico', cat.salarioBase, currencyFormat, isPositive: true),
        _buildCalculationRow('Descuentos de Ley ($descuentosDesc)', montoDescuentos, currencyFormat, isPositive: false),
        
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          child: Divider(thickness: 1.5),
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
              style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
          ],
        ),

        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.amber.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.amber.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.warning_amber_rounded, size: 20, color: Colors.amber.shade800),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Cálculo aproximado sólo sobre el básico. No incluye adicionales (antigüedad, presentismo), horas extras, ni el impuesto a las ganancias.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.amber.shade900,
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
              color: isPositive ? Colors.green.shade700 : Colors.red.shade600,
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
              InkWell(
                onTap: () => _showHelpDialog(context, helpTopic),
                borderRadius: BorderRadius.circular(30),
                child: const Icon(Icons.help_outline, size: 18, color: AppColors.textMuted),
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Text(
          content,
          style: GoogleFonts.inter(
            fontSize: isPrice ? 24 : 16,
            fontWeight: isPrice ? FontWeight.bold : FontWeight.normal,
            color: isPrice ? Colors.green.shade700 : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildAdicionalRow(String label, String value, {String? helpTopic}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: AppColors.textPrimary,
                ),
              ),
              if (helpTopic != null) ...[
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => _showHelpDialog(context, helpTopic),
                  borderRadius: BorderRadius.circular(30),
                  child: const Icon(Icons.help_outline, size: 18, color: AppColors.textMuted),
                ),
              ],
            ],
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
