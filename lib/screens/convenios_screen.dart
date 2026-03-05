
import 'package:flutter/material.dart';
import 'dart:ui';
import '../models/cct_completo.dart';
import '../services/convenios_service.dart'; // <- NUEVO
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../widgets/cct_detail_dialog.dart';
import '../utils/app_help.dart';

// =======================================================================
// GESTOR DE CONVENIOS COLECTIVOS
// Pantalla rediseñada para ser un centro de gestión de CCTs, utilizando
// ConveniosService para una persistencia de datos real.
// =======================================================================

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
    _cargarConveniosDesdeServicio();
    _searchController.addListener(_filtrarConvenios);
  }

  /// Carga los convenios utilizando el nuevo ConveniosService.
  /// Ahora los datos son persistentes.
  Future<void> _cargarConveniosDesdeServicio() async {
    setState(() => _isLoading = true);
    final convenios = await ConveniosService.getConvenios();
    if (mounted) {
      setState(() {
        _convenios = convenios;
        _conveniosFiltrados = convenios;
        _isLoading = false;
      });
    }
  }

  void _filtrarConvenios() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _conveniosFiltrados = _convenios.where((cct) {
        return cct.nombre.toLowerCase().contains(query) ||
            cct.numeroCCT.toLowerCase().contains(query) ||
            (cct.actividad?.toLowerCase().contains(query) ?? false);
      }).toList();
    });
  }

  /// Guarda los cambios utilizando el servicio, asegurando la persistencia.
  Future<void> _guardarCambios(CCTCompleto convenioActualizado, bool esNuevo) async {
    CCTCompleto convenioFinal = convenioActualizado;

    if (esNuevo) {
      convenioFinal = convenioActualizado.copyWith(
        id: 'cct_pers_${DateTime.now().millisecondsSinceEpoch}', 
        esPersonalizado: true,
      );
    } else {
      // Si estamos editando, nos aseguramos de marcarlo como personalizado.
      convenioFinal = convenioActualizado.copyWith(esPersonalizado: true);
    }

    await ConveniosService.saveConvenio(convenioFinal);
    // Recargamos desde la fuente de la verdad para reflejar los cambios.
    await _cargarConveniosDesdeServicio();
  }

  void _abrirDetalle(CCTCompleto convenio) {
    showDialog(
      context: context,
      barrierColor: const Color.fromRGBO(0, 0, 0, 0.5),
      builder: (context) => CCTDetailDialog(
        convenio: convenio,
        // Pasamos el callback de guardado al diálogo.
        onUpdate: (cct) => _guardarCambios(cct, false),
      ),
    );
  }

  void _agregarConvenio() {
    // Creamos un convenio vacío para el formulario.
    final nuevoConvenio = CCTCompleto(
      id: 'temp_id', // ID temporal
      numeroCCT: '',
      nombre: '',
      descripcion: '',
      categorias: [],
      descuentos: [],
      zonas: [],
      fechaVigencia: DateTime.now(),
      esPersonalizado: true,
    );

    showDialog(
      context: context,
      barrierColor: const Color.fromRGBO(0, 0, 0, 0.5),
      builder: (context) => CCTDetailDialog(
        convenio: nuevoConvenio,
        onUpdate: (cct) => _guardarCambios(cct, true),
        esNuevo: true,
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
        title: const Text('Gestor de Convenios', // Título actualizado
            style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          AppHelp.buildHelpButton(context, 'ConveniosScreen'),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _agregarConvenio,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Nuevo Personalizado'),
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildSearchBar(),
            const SizedBox(height: 12),
            _buildSyncStatusIndicator(),
            const SizedBox(height: 16),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    )
                  : _conveniosFiltrados.isEmpty
                      ? _buildEmptyState()
                      : _buildConveniosList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
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
              border: Border.all(color: AppColors.glassBorder, width: 1),
            ),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                hintText: 'Buscar por nombre, CCT o actividad...',
                hintStyle: TextStyle(color: AppColors.textMuted),
                border: InputBorder.none,
                icon: Icon(Icons.search, color: AppColors.textSecondary),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 64, color: AppColors.textMuted),
          SizedBox(height: 16),
          Text(
            'No se encontraron convenios',
            style: TextStyle(fontSize: 18, color: AppColors.textSecondary),
          ),
          SizedBox(height: 8),
          Text(
            'Prueba con otro término de búsqueda o crea uno nuevo.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMuted, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildConveniosList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: _conveniosFiltrados.length,
      itemBuilder: (context, index) {
        final convenio = _conveniosFiltrados[index];
        return _buildConvenioCard(convenio);
      },
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
                color: convenio.esPersonalizado ? AppColors.primary.withOpacity(0.5) : AppColors.glassBorder,
                width: convenio.esPersonalizado ? 1.5 : 1.0,
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
                      _buildCardHeader(convenio),
                      const SizedBox(height: 16),
                      Text(
                        convenio.descripcion,
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (convenio.categorias.isNotEmpty || convenio.descuentos.isNotEmpty || convenio.zonas.isNotEmpty)
                        const SizedBox(height: 16),
                      _buildInfoChips(convenio),
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
  
  Widget _buildCardHeader(CCTCompleto convenio) {
    return Row(
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
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'CCT ${convenio.numeroCCT}',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  if (convenio.esPersonalizado) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.accentEmerald.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'PERSONALIZADO',
                        style: TextStyle(
                          color: AppColors.accentEmerald,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        const Icon(Icons.arrow_forward_ios, color: AppColors.textSecondary, size: 20),
      ],
    );
  }

  Widget _buildInfoChips(CCTCompleto convenio) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        if (convenio.categorias.isNotEmpty) _buildInfoChip(Icons.people, '${convenio.categorias.length} categorías'),
        if (convenio.descuentos.isNotEmpty) _buildInfoChip(Icons.percent, '${convenio.descuentos.length} descuentos'),
        if (convenio.zonas.isNotEmpty) _buildInfoChip(Icons.map, '${convenio.zonas.length} zonas'),
      ],
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
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }

  // El widget de Sync Status se mantiene igual, ya que su lógica es independiente.
  Widget _buildSyncStatusIndicator() {
    // ... (código del método original sin cambios)
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
}
