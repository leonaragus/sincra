// ========================================================================
// DASHBOARD DE RIESGOS Y ADVERTENCIAS
// Widget que muestra un resumen de situaciones que requieren atención
// ========================================================================

import 'package:flutter/material.dart';
import '../services/alertas_proactivas_service.dart';
import '../services/auditoria_service.dart';
import '../models/empleado_completo.dart';

class DashboardRiesgosWidget extends StatefulWidget {
  const DashboardRiesgosWidget({super.key});
  
  @override
  State<DashboardRiesgosWidget> createState() => _DashboardRiesgosWidgetState();
}

class _DashboardRiesgosWidgetState extends State<DashboardRiesgosWidget> {
  bool _cargando = true;
  List<AlertaProactiva> _alertas = [];
  int _cantidadCambiosRecientes = 0;
  
  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }
  
  Future<void> _cargarDatos() async {
    setState(() => _cargando = true);
    
    try {
      // Cargar alertas
      final resumen = await AlertasProactivasService.generarAlertasCompletas(
        empleados: [],
      );
      _alertas = resumen.alertas;
      
      // Cargar cambios recientes en auditoría
      final cambiosRecientes = await AuditoriaService.obtenerHistorial();
        _cantidadCambiosRecientes = cambiosRecientes.length;
    } catch (e) {
        // Error cargando dashboard
      }
    
    if (mounted) {
      setState(() => _cargando = false);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
                const SizedBox(width: 12),
                const Text(
                  'Dashboard de Riesgos y Advertencias',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _cargarDatos,
                  tooltip: 'Actualizar',
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 12),
            
            // Resumen de alertas
            _buildResumenAlertas(),
            
            const SizedBox(height: 16),
            
            // Lista de alertas
            if (_alertas.isNotEmpty) ...[
              const Text(
                'Alertas Activas:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              ..._alertas.take(5).map((alerta) => _buildAlertaItem(alerta)),
              
              if (_alertas.length > 5)
                TextButton(
                  onPressed: () {
                    // Mostrar todas las alertas
                    _mostrarTodasAlertas();
                  },
                  child: Text('Ver todas (${_alertas.length})'),
                ),
            ] else ...[
              const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green),
                  SizedBox(width: 8),
                  Text('No hay alertas activas'),
                ],
              ),
            ],
            
            const SizedBox(height: 16),
            
            // Cambios recientes
            _buildCambiosRecientes(),
          ],
        ),
      ),
    );
  }
  
  Widget _buildResumenAlertas() {
    final porTipo = <String, int>{};
    for (final alerta in _alertas) {
      porTipo[alerta.tipo] = (porTipo[alerta.tipo] ?? 0) + 1;
    }
    
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        _buildBadge(
          'Total Alertas',
          _alertas.length.toString(),
          _alertas.isEmpty ? Colors.green : Colors.orange,
        ),
        if (porTipo['critica'] != null)
          _buildBadge(
            'Alertas Críticas',
            porTipo['critica'].toString(),
            Colors.red,
          ),
        if (porTipo['alta'] != null)
          _buildBadge(
            'Alertas Altas',
            porTipo['alta'].toString(),
            Colors.orange,
          ),
        if (porTipo['media'] != null)
          _buildBadge(
            'Alertas Medias',
            porTipo['media'].toString(),
            Colors.blue,
          ),
      ],
    );
  }
  
  Widget _buildBadge(String label, String valor, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            valor,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color.withOpacity(0.8),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildAlertaItem(AlertaProactiva alerta) {
    IconData icono;
    Color color;
    
    switch (alerta.tipo) {
      case 'critica':
        icono = Icons.error;
        color = Colors.red;
        break;
      case 'alta':
        icono = Icons.warning;
        color = Colors.orange;
        break;
      case 'media':
        icono = Icons.info;
        color = Colors.blue;
        break;
      case 'baja':
        icono = Icons.lightbulb;
        color = Colors.green;
        break;
      default:
        icono = Icons.info;
        color = Colors.grey;
        break;
    }
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icono, color: color),
        title: Text(
          alerta.titulo,
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
        ),
        subtitle: Text(
          alerta.descripcion,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11),
        ),
        trailing: alerta.entidadNombre != null
            ? Text(
                alerta.entidadNombre!,
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              )
            : null,
      ),
    );
  }
  
  Widget _buildCambiosRecientes() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.history, color: Colors.blue, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$_cantidadCambiosRecientes cambios en las últimas 24 horas',
              style: const TextStyle(fontSize: 12),
            ),
          ),
          TextButton(
            onPressed: () {
              // Ver auditoría completa
              _mostrarAuditoria();
            },
            child: const Text('Ver auditoría', style: TextStyle(fontSize: 11)),
          ),
        ],
      ),
    );
  }
  
  void _mostrarTodasAlertas() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Todas las Alertas'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _alertas.length,
            itemBuilder: (context, index) {
              return _buildAlertaItem(_alertas[index]);
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
  
  void _mostrarAuditoria() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Auditoría de Cambios'),
        content: const Text('Ver log completo de auditoría...'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }
}
