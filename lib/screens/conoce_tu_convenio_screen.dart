import 'package:flutter/material.dart';
import 'package:syncra_arg/services/api_service.dart';
import 'package:syncra_arg/theme/app_colors.dart';
import 'package:syncra_arg/models/cct_completo.dart';
import 'package:syncra_arg/models/convenio_model.dart';
import 'package:syncra_arg/data/cct_argentina_completo.dart';
import 'package:syncra_arg/widgets/cct_detail_dialog.dart';
import 'package:url_launcher/url_launcher.dart';

class ConoceTuConvenioScreen extends StatefulWidget {
  final String? convenioId;
  final String? categoriaId;
  
  const ConoceTuConvenioScreen({
    super.key,
    this.convenioId,
    this.categoriaId,
  });

  @override
  State<ConoceTuConvenioScreen> createState() => _ConoceTuConvenioScreenState();
}

class _ConoceTuConvenioScreenState extends State<ConoceTuConvenioScreen> {
  CCTCompleto? _convenioSeleccionado;
  String? _categoriaSeleccionada;
  bool _isLoading = true;
  final List<CCTCompleto> _todosConvenios = [];

  @override
  void initState() {
    super.initState();
    _cargarConvenios();
  }

  /// Convierte ConvenioModel a CCTCompleto para compatibilidad
  CCTCompleto _convertirConvenioModelACCTCompleto(ConvenioModel convenioModel) {
    return CCTCompleto(
      id: convenioModel.id,
      numeroCCT: convenioModel.id, // Usar ID como número CCT temporal
      nombre: convenioModel.nombreCCT,
      descripcion: 'Convenio cargado desde sincronización',
      actividad: null,
      categorias: [
        CategoriaCCT(
          id: convenioModel.categoria,
          nombre: convenioModel.categoria,
          salarioBase: convenioModel.sueldoBasico,
          descripcion: 'Categoría ${convenioModel.categoria}',
        ),
      ],
      descuentos: [],
      zonas: [],
      adicionalPresentismo: convenioModel.adicionales['presentismo'] ?? 0.0,
      adicionalAntiguedad: convenioModel.adicionales['antiguedad'] ?? 0.0,
      porcentajeAntiguedadAnual: 1.0,
      horasMensualesDivisor: 192.0, // Valor por defecto
      esDivisorDias: false,
      fechaVigencia: convenioModel.ultimaActualizacion,
      activo: true,
      pdfUrl: convenioModel.pdfUrl,
    );
  }

  Future<void> _cargarConvenios() async {
    setState(() { _isLoading = true; });
    
    // Cargar convenios desde la base de datos
    try {
      final convenios = await ApiService.syncOrLoadLocal();
      final conveniosConvertidos = convenios.map(_convertirConvenioModelACCTCompleto).toList();
      setState(() {
        _todosConvenios.addAll(conveniosConvertidos);
        _isLoading = false;
      });
      
      // Si viene con convenio específico, cargarlo
      if (widget.convenioId != null) {
        _cargarConvenioEspecifico(widget.convenioId!);
      }
    } catch (e) {
      // Fallback a datos locales
      setState(() {
        _todosConvenios.addAll(cctArgentinaCompleto);
        _isLoading = false;
      });
      if (widget.convenioId != null) {
        _cargarConvenioEspecifico(widget.convenioId!);
      }
    }
  }

  void _cargarConvenioEspecifico(String convenioId) {
    final convenio = _todosConvenios.firstWhere(
      (c) => c.id == convenioId,
      orElse: () => cctArgentinaCompleto.firstWhere(
        (c) => c.id == convenioId,
        orElse: () => _todosConvenios.first,
      ),
    );
    
    setState(() {
      _convenioSeleccionado = convenio;
      _categoriaSeleccionada = widget.categoriaId ?? 
          (convenio.categorias.isNotEmpty ? convenio.categorias.first.id : null);
    });
  }

  void _seleccionarConvenio(CCTCompleto convenio) {
    setState(() {
      _convenioSeleccionado = convenio;
      _categoriaSeleccionada = convenio.categorias.isNotEmpty ? 
          convenio.categorias.first.id : null;
    });
  }

  Future<void> _descargarPDF() async {
    if (_convenioSeleccionado == null) return;

    final url = _convenioSeleccionado!.pdfUrl;
    if (url != null && url.isNotEmpty) {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No se pudo abrir el enlace PDF'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'PDF no disponible para ${_convenioSeleccionado!.nombre}'),
            backgroundColor: AppColors.info,
          ),
        );
      }
    }
  }

  void _mostrarDetallesCompletos() {
    if (_convenioSeleccionado == null) return;
    
    showDialog(
      context: context,
      builder: (context) => CCTDetailDialog(
        convenio: _convenioSeleccionado!,
      ),
    );
  }

  Widget _buildSelectorConvenio() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Selecciona tu convenio:',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<CCTCompleto>(
            value: _convenioSeleccionado,
            items: _todosConvenios.map((convenio) {
              return DropdownMenuItem<CCTCompleto>(
                value: convenio,
                child: Text(
                  convenio.nombre,
                  style: const TextStyle(color: AppColors.textPrimary),
                ),
              );
            }).toList(),
            onChanged: (convenio) {
              if (convenio != null) {
                _seleccionarConvenio(convenio);
              }
            },
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              filled: true,
              fillColor: AppColors.backgroundLight,
            ),
            style: const TextStyle(color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoConvenio() {
    if (_convenioSeleccionado == null) {
      return const Center(
        child: Text(
          'Selecciona un convenio para ver su información',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    final convenio = _convenioSeleccionado!;
    // Si la categoría seleccionada no pertenece al convenio actual, usar la primera
    if (_categoriaSeleccionada != null && 
        !convenio.categorias.any((c) => c.id == _categoriaSeleccionada)) {
      _categoriaSeleccionada = convenio.categorias.isNotEmpty ? convenio.categorias.first.id : null;
    }
    
    final categoria = _categoriaSeleccionada != null
        ? convenio.categorias.firstWhere(
            (c) => c.id == _categoriaSeleccionada,
            orElse: () => convenio.categorias.first,
          )
        : (convenio.categorias.isNotEmpty ? convenio.categorias.first : null);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      convenio.nombre,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'CCT ${convenio.numeroCCT}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          Text(
            convenio.descripcion,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 15,
              height: 1.4,
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Sección de Descarga PDF Destacada
          if (convenio.pdfUrl != null && convenio.pdfUrl!.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withOpacity(0.2)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.description, color: AppColors.primary),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Documentación Oficial',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _descargarPDF,
                      icon: const Icon(Icons.download),
                      label: const Text('Descargar CCT Completo (PDF)'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'ℹ️ Se descargará el documento oficial completo del convenio',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const Divider(height: 32, color: AppColors.border),
          ],
          
          if (convenio.categorias.isNotEmpty) ...[
            Row(
              children: [
                const Icon(Icons.calculate_outlined, color: AppColors.textSecondary, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Escalas Salariales (Ejemplo)',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Seleccioná una categoría para ver el básico vigente:',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.backgroundLight,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _categoriaSeleccionada,
                  isExpanded: true,
                  dropdownColor: AppColors.backgroundCard,
                  style: const TextStyle(color: AppColors.textPrimary),
                  items: convenio.categorias.map((cat) {
                    return DropdownMenuItem<String>(
                      value: cat.id,
                      child: Text(
                        cat.nombre,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _categoriaSeleccionada = val;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],

          if (categoria != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.accentGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.accentGreen.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Salario Básico Vigente',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        '\$${categoria.salarioBase.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}',
                        style: const TextStyle(
                          color: AppColors.accentGreen,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  if (categoria.descripcion != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      categoria.descripcion!,
                      style: TextStyle(
                        color: AppColors.textSecondary.withOpacity(0.8),
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
          
          // Botón de PDF eliminado de aquí (movido arriba)
          const SizedBox(height: 16),
          Center(
            child: TextButton(
              onPressed: _mostrarDetallesCompletos,
              child: const Text('Ver detalles técnicos y adicionales'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Conoce tu Convenio',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Indicador de estado de sincronización
                  _buildSyncStatusIndicator(),
                  const SizedBox(height: 16),
                  _buildSelectorConvenio(),
                  const SizedBox(height: 20),
                  _buildInfoConvenio(),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.backgroundCard,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '¿Por qué conocer tu convenio?',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Conocer tu convenio colectivo te permite:\n'
                          '• Verificar que tu salario sea el correcto\n'
                          '• Entender tus derechos laborales\n'
                          '• Conocer los adicionales que te corresponden\n'
                          '• Comprender las deducciones aplicadas',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSyncStatusIndicator() {
    final status = ApiService.lastSyncStatus;
    final actualizadoHoy = status.success && status.isActualizadoHoy;
    
    String text;
    String dateText = '';
    IconData icon;
    
    if (status.success) {
      if (actualizadoHoy) {
        text = 'Convenios actualizados al día';
        if (status.lastSyncDate != null) {
          dateText = ' • ${_formatTime(status.lastSyncDate!)}';
        }
      } else {
        text = 'Usando datos locales';
        if (status.dataUpdateDate != null) {
          dateText = ' • Actualizado: ${_formatDate(status.dataUpdateDate!)}';
        }
      }
      icon = actualizadoHoy ? Icons.cloud_done : Icons.phone_android;
    } else {
      text = 'Sin conexión - Datos locales';
      if (status.dataUpdateDate != null) {
        dateText = ' • Actualizado: ${_formatDate(status.dataUpdateDate!)}';
      }
      icon = Icons.error_outline;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.glassFillStrong,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.glassBorder, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  text,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (dateText.isNotEmpty)
                  Text(
                    dateText,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}