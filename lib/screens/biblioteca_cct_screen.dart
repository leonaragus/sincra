// ========================================================================
// BIBLIOTECA CCT EN LA NUBE
// Convenios actualizados por robot BAT con banner de sincronización
// Misma metodología que Docentes y Sanidad
// ========================================================================

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/cct_cloud_service.dart';
import '../services/educational_concepts_service.dart';
import '../theme/app_colors.dart';
import 'glosario_conceptos_screen.dart';

class BibliotecaCCTScreen extends StatefulWidget {
  const BibliotecaCCTScreen({super.key});
  
  @override
  State<BibliotecaCCTScreen> createState() => _BibliotecaCCTScreenState();
}

class _BibliotecaCCTScreenState extends State<BibliotecaCCTScreen> {
  List<CCTMaster> _ccts = [];
  bool _sincronizando = false;
  
  Map<String, dynamic>? _infoSincronizacion;
  
  String _filtroSector = 'todos'; // todos, sanidad, docente, comercio
  
  @override
  void initState() {
    super.initState();
    _cargarCCTs();
  }
  
  Future<void> _cargarCCTs() async {
    try {
      final res = await CCTCloudService.sincronizarCCT();
      
      setState(() {
        _infoSincronizacion = res;
        final data = res['data'] as List? ?? [];
        _ccts = data.map((m) => CCTMaster.fromMap(m)).toList();
      });
    } catch (e) {
      _mostrarError('Error cargando CCT: $e');
    }
  }
  
  Future<void> _sincronizarCCT() async {
    if (_sincronizando) return;
    
    setState(() => _sincronizando = true);
    
    final res = await CCTCloudService.sincronizarCCT();
    
    if (mounted) {
      setState(() {
        _infoSincronizacion = res;
        _sincronizando = false;
        
        final data = res['data'] as List? ?? [];
        _ccts = data.map((m) => CCTMaster.fromMap(m)).toList();
      });
      
      if (res['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('CCT sincronizados correctamente'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Biblioteca de Convenios', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _buildBannerSincronizacion(),
          _buildAcademyBanner(context),
          const SizedBox(height: 16),
          _buildInstruccionesRobot(),
          const SizedBox(height: 16),
          _buildFiltros(),
          const SizedBox(height: 16),
          _buildListaCCTs(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildAcademyBanner(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(bottom: 16),
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
              // Botón Glosario
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (c) => const GlosarioConceptosScreen()));
                  },
                  icon: const Icon(Icons.book, size: 18),
                  label: const Text('Glosario'),
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
  
  /// Banner de sincronización (misma metodología que Docentes y Sanidad)
  Widget _buildBannerSincronizacion() {
    if (_infoSincronizacion == null && !_sincronizando) {
      return const SizedBox.shrink();
    }
    
    final info = _infoSincronizacion;
    final bool success = info?['success'] ?? false;
    final bool isOffline = info?['modo'] == 'offline';
    final DateTime? fecha = info?['fecha'];
    final int cantidad = info?['cantidad'] ?? 0;
    final String fechaStr = fecha != null 
        ? DateFormat('dd/MM/yyyy HH:mm').format(fecha) 
        : 'Nunca';
    
    Color bgColor = success 
        ? Colors.green.withOpacity(0.1) 
        : Colors.amber.withOpacity(0.1);
    Color borderColor = success 
        ? Colors.green.withOpacity(0.3) 
        : Colors.amber.withOpacity(0.3);
    IconData icon = success 
        ? Icons.check_circle_outline 
        : (isOffline ? Icons.cloud_off : Icons.sync_problem);
    String mensajeBanner = success 
        ? 'CCT actualizados al $fechaStr ($cantidad convenios)' 
        : (isOffline ? 'Modo Offline: Última sync $fechaStr' : 'Error al sincronizar CCT');
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          if (_sincronizando)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
            )
          else
            Icon(icon, size: 16, color: success ? Colors.green : Colors.amber),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _sincronizando ? 'Sincronizando CCT desde la nube...' : mensajeBanner,
              style: TextStyle(
                fontSize: 12,
                color: success ? Colors.green.shade700 : Colors.amber.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (!_sincronizando)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.refresh, size: 14),
                  onPressed: _sincronizarCCT,
                  tooltip: 'Actualizar',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
        ],
      ),
    );
  }
  
  Widget _buildInstruccionesRobot() {
    return Card(
      color: Colors.blue[50],
      child: ExpansionTile(
        leading: const Icon(Icons.smart_toy, color: Colors.blue),
        title: const Text('¿Cómo actualizar CCT con el Robot BAT?'),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pasos para actualizar CCT:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text('1. Ejecutar el archivo actualizar_cct.bat desde tu PC'),
                const Text('2. El robot descargará los CCT actualizados de fuentes oficiales'),
                const Text('3. Guardará los resultados en cct_resultados.json'),
                const Text('4. La app detectará el archivo y subirá los CCT a Supabase'),
                const Text('5. Todos los usuarios se sincronizarán automáticamente'),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    // Aquí podrías abrir una pantalla para ver el log del robot
                    _mostrarHistorialRobot();
                  },
                  icon: const Icon(Icons.history),
                  label: const Text('Ver Historial de Actualizaciones'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildFiltros() {
    return SegmentedButton<String>(
      segments: const [
        ButtonSegment(value: 'todos', label: Text('Todos')),
        ButtonSegment(value: 'sanidad', label: Text('Sanidad')),
        ButtonSegment(value: 'docente', label: Text('Docente')),
        ButtonSegment(value: 'comercio', label: Text('Comercio')),
      ],
      selected: {_filtroSector},
      onSelectionChanged: (Set<String> selection) {
        setState(() => _filtroSector = selection.first);
      },
    );
  }
  
  Widget _buildListaCCTs() {
    var ccts = _ccts;
    
    if (_filtroSector != 'todos') {
      ccts = ccts.where((c) => c.sector == _filtroSector).toList();
    }
    
    if (ccts.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              const Icon(Icons.library_books, size: 80, color: Colors.grey),
              const SizedBox(height: 16),
              const Text('No hay CCT disponibles'),
              const SizedBox(height: 8),
              const Text(
                'Ejecuta el robot BAT para actualizar',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _sincronizarCCT,
                icon: const Icon(Icons.refresh),
                label: const Text('Sincronizar Ahora'),
              ),
            ],
          ),
        ),
      );
    }
    
    return Column(
      children: ccts.map((cct) => _buildCCTCard(cct)).toList(),
    );
  }
  
  Widget _buildCCTCard(CCTMaster cct) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withOpacity(0.2),
          child: Text(
            cct.codigo.split('/')[0],
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          '${cct.codigo} - ${cct.nombre}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sector: ${cct.sector ?? 'No especificado'}'),
            if (cct.fechaActualizacion != null)
              Text(
                'Última actualización: ${DateFormat('dd/MM/yyyy').format(cct.fechaActualizacion!)}',
                style: const TextStyle(fontSize: 11, color: Colors.green),
              ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 20),
            Text(
              'v${cct.versionActual}',
              style: const TextStyle(fontSize: 10),
            ),
          ],
        ),
        onTap: () => _verDetalleCCT(cct),
      ),
    );
  }
  
  void _verDetalleCCT(CCTMaster cct) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.glassBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.accentBlue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.assignment, color: AppColors.accentBlue, size: 32),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              cct.codigo,
                              style: const TextStyle(color: AppColors.accentBlue, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            Text(
                              cct.nombre,
                              style: GoogleFonts.poppins(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildDetalleRow('Sector', cct.sector ?? 'N/A', Icons.business),
                  _buildDetalleRow('Versión', 'v${cct.versionActual}', Icons.history),
                  if (cct.fechaActualizacion != null)
                    _buildDetalleRow('Actualizado', DateFormat('dd/MM/yyyy').format(cct.fechaActualizacion!), Icons.calendar_today),
                  
                  if (cct.descripcion != null) ...[
                    const SizedBox(height: 24),
                    const Text('Descripción', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 16)),
                    const SizedBox(height: 8),
                    Text(cct.descripcion!, style: const TextStyle(color: AppColors.textSecondary, height: 1.5)),
                  ],

                  // Sección de Categorías y Escalas
                  const SizedBox(height: 32),
                  const Text('Escalas y Categorías', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 18)),
                  const SizedBox(height: 16),
                  
                  if (cct.jsonEstructura != null && cct.jsonEstructura!['categorias'] != null)
                    ..._buildCategoriasList(cct.jsonEstructura!['categorias'])
                  else
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.glassFill,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.glassBorder),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline, color: AppColors.textMuted, size: 20),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Las escalas detalladas están siendo procesadas por el robot BAT. Pronto verás todas las categorías aquí.',
                              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.accentBlue,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text('Entendido'),
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

  List<Widget> _buildCategoriasList(dynamic categorias) {
    if (categorias is! List) return [];
    
    return categorias.map((cat) {
      final nombre = cat['nombre']?.toString() ?? 'Sin nombre';
      final basico = cat['basico']?.toString() ?? 'Consultar';
      
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.backgroundLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(nombre, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  if (cat['descripcion'] != null)
                    Text(cat['descripcion'].toString(), style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text('Básico', style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
                Text(basico.contains('\$') ? basico : '\$$basico', 
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.accentBlue, fontSize: 16)),
              ],
            ),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildDetalleRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textMuted),
          const SizedBox(width: 12),
          Text('$label:', style: const TextStyle(color: AppColors.textMuted)),
          const SizedBox(width: 8),
          Text(value, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  void _mostrarHistorialRobot() async {
    final historial = await CCTCloudService.obtenerHistorialRobot(limit: 20);
    
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Historial Robot BAT'),
        content: SizedBox(
          width: double.maxFinite,
          child: historial.isEmpty
              ? const Center(child: Text('No hay ejecuciones registradas'))
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: historial.length,
                  itemBuilder: (context, index) {
                    final ejecucion = historial[index];
                    final exitosa = ejecucion['exitosa'] ?? false;
                    final fecha = DateTime.parse(ejecucion['fecha_ejecucion']);
                    
                    return ListTile(
                      leading: Icon(
                        exitosa ? Icons.check_circle : Icons.error,
                        color: exitosa ? Colors.green : Colors.red,
                      ),
                      title: Text(DateFormat('dd/MM/yyyy HH:mm').format(fecha)),
                      subtitle: Text(
                        'Procesados: ${ejecucion['cct_procesados']} | '
                        'Actualizados: ${ejecucion['cct_actualizados']} | '
                        'Errores: ${ejecucion['cct_con_errores']}',
                        style: const TextStyle(fontSize: 11),
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }
  
  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), backgroundColor: Colors.red),
    );
  }
}
