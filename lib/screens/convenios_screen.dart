import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/cct_argentina_completo.dart';
import '../models/cct_completo.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../widgets/cct_detail_dialog.dart';
import '../utils/app_help.dart';

class ConveniosScreen extends StatefulWidget {
  const ConveniosScreen({super.key});

  @override
  State<ConveniosScreen> createState() => _ConveniosScreenState();
}

class _ConveniosScreenState extends State<ConveniosScreen> {
  List<CCTCompleto> _convenios = [];
  List<CCTCompleto> _conveniosFiltrados = [];
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargarConvenios();
    _searchController.addListener(_filtrarConvenios);
  }

  Future<void> _cargarConvenios() async {
    setState(() {
      _isLoading = true;
    });

    // Cargar desde SharedPreferences si hay cambios guardados
    final prefs = await SharedPreferences.getInstance();
    final String? conveniosJson = prefs.getString('cct_modificados');

    if (conveniosJson != null) {
      // Aquí podrías deserializar los convenios modificados
      // Por ahora usamos los de la base de datos
    }

    // Cargar convenios base
    setState(() {
      _convenios = List.from(cctArgentinaCompleto);
      _conveniosFiltrados = List.from(_convenios);
      _isLoading = false;
    });
  }

  void _filtrarConvenios() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _conveniosFiltrados = List.from(_convenios);
      } else {
        _conveniosFiltrados = _convenios.where((cct) {
          return cct.nombre.toLowerCase().contains(query) ||
              cct.numeroCCT.toLowerCase().contains(query) ||
              (cct.actividad != null &&
                  cct.actividad!.toLowerCase().contains(query));
        }).toList();
      }
    });
  }

  static const String _idConvenioNuevo = 'cct_nuevo';

  CCTCompleto _crearConvenioVacio() {
    return CCTCompleto(
      id: _idConvenioNuevo,
      numeroCCT: '',
      nombre: '',
      descripcion: '',
      actividad: null,
      categorias: [],
      descuentos: [],
      zonas: [],
      adicionalPresentismo: 8.33,
      adicionalAntiguedad: 1.0,
      fechaVigencia: DateTime.now(),
      activo: true,
    );
  }

  Future<void> _guardarCambios(CCTCompleto convenioActualizado) async {
    final esNuevo = convenioActualizado.id == _idConvenioNuevo;

    if (esNuevo) {
      final nuevoId = 'cct_${DateTime.now().millisecondsSinceEpoch}';
      final convenioConId = convenioActualizado.copyWith(id: nuevoId);
      setState(() {
        _convenios.insert(0, convenioConId);
        _filtrarConvenios();
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('cct_modificado_$nuevoId', true);
    } else {
      final index = _convenios.indexWhere((c) => c.id == convenioActualizado.id);
      if (index != -1) {
        setState(() {
          _convenios[index] = convenioActualizado;
          _filtrarConvenios();
        });
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('cct_modificado_${convenioActualizado.id}', true);
      }
    }
  }

  void _abrirDetalle(CCTCompleto convenio) {
    showDialog(
      context: context,
      barrierColor: const Color.fromRGBO(0, 0, 0, 0.5),
      builder: (context) => CCTDetailDialog(
        convenio: convenio,
        onUpdate: _guardarCambios,
      ),
    );
  }

  void _agregarConvenio() {
    showDialog(
      context: context,
      barrierColor: const Color.fromRGBO(0, 0, 0, 0.5),
      builder: (context) => CCTDetailDialog(
        convenio: _crearConvenioVacio(),
        onUpdate: _guardarCambios,
        esNuevo: true,
      ),
    );
  }

  void _mostrarAyuda() {
    final helpContent = AppHelp.getHelpContent('ConveniosScreen');
    AppHelp.showHelpDialog(
      context,
      helpContent['title']!,
      helpContent['content']!,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildSyncStatusIndicator() {
    final status = ApiService.lastSyncStatus;
    final actualizadoHoy = status.success && status.isActualizadoHoy;
    
    String text;
    String dateText = '';
    IconData icon;
    
    if (status.success) {
      if (actualizadoHoy) {
        text = 'Escalas actualizadas al día';
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
      padding: const EdgeInsets.symmetric(horizontal: 20),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.glassFillStrong,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Convenios Colectivos',
            style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
              ),
              child: const Icon(Icons.help_outline, color: AppColors.primary, size: 20),
            ),
            tooltip: 'Ayuda',
            onPressed: _mostrarAyuda,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _agregarConvenio,
        backgroundColor: AppColors.glassFillStrong,
        foregroundColor: AppColors.textPrimary,
        icon: const Icon(Icons.add),
        label: const Text('Nuevo convenio'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.glassFillStrong,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.glassBorder,
                          width: 1,
                        ),
                      ),
                      child: const Icon(
                        Icons.arrow_back,
                        color: AppColors.textPrimary,
                        size: 24,
                      ),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Convenios Colectivos',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppColors.glassFillStrong,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.glassBorder,
                        width: 1,
                      ),
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: const InputDecoration(
                        hintText: 'Buscar convenio...',
                        hintStyle: TextStyle(color: AppColors.textMuted),
                        border: InputBorder.none,
                        icon: Icon(
                          Icons.search,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _buildSyncStatusIndicator(),
            const SizedBox(height: 16),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.pastelBlue,
                      ),
                    )
                  : _conveniosFiltrados.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.search_off,
                                size: 64,
                                color: AppColors.textMuted,
                              ),
                              SizedBox(height: 16),
                              Text(
                                'No se encontraron convenios',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: _conveniosFiltrados.length,
                          itemBuilder: (context, index) {
                            final convenio = _conveniosFiltrados[index];
                            return _buildConvenioCard(convenio);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConvenioCard(CCTCompleto convenio) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.glassFillStrong,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: AppColors.glassBorder,
                width: 1.5,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _abrirDetalle(convenio),
                borderRadius: BorderRadius.circular(24),
                child: Padding(
                  padding: const EdgeInsets.all(20),
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
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.pastelBlue.withValues(alpha: 0.3),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        'CCT ${convenio.numeroCCT}',
                                        style: const TextStyle(
                                          color: AppColors.textPrimary,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                    if (convenio.actividad != null) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.glassFill,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          convenio.actividad!,
                                          style: const TextStyle(
                                            color: AppColors.textSecondary,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward_ios,
                            color: AppColors.textSecondary,
                            size: 20,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        convenio.descripcion,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          _buildInfoChip(
                            Icons.people,
                            '${convenio.categorias.length} categorías',
                          ),
                          const SizedBox(width: 12),
                          _buildInfoChip(
                            Icons.percent,
                            '${convenio.descuentos.length} descuentos',
                          ),
                          const SizedBox(width: 12),
                          _buildInfoChip(
                            Icons.map,
                            '${convenio.zonas.length} zonas',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.glassFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.glassBorder, width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
