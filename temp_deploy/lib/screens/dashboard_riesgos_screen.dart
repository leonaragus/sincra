// ========================================================================
// DASHBOARD DE RIESGOS Y ADVERTENCIAS
// Panel centralizado de todas las alertas del sistema
// ========================================================================

import 'package:flutter/material.dart';
import '../services/alertas_proactivas_service.dart';
import '../services/empleados_service.dart';
import '../models/prestamo.dart';
import '../models/ausencia.dart';
import '../theme/app_colors.dart';

class DashboardRiesgosScreen extends StatefulWidget {
  const DashboardRiesgosScreen({super.key});
  
  @override
  State<DashboardRiesgosScreen> createState() => _DashboardRiesgosScreenState();
}

class _DashboardRiesgosScreenState extends State<DashboardRiesgosScreen> {
  ResumenAlertas? _resumen;
  bool _cargando = true;
  String? _filtroCategoria;
  String? _filtroTipo;
  
  @override
  void initState() {
    super.initState();
    _cargarAlertas();
  }
  
  Future<void> _cargarAlertas() async {
    setState(() => _cargando = true);
    
    try {
      // Cargar datos
      final empleados = await EmpleadosService.obtenerEmpleados();
      // TODO: Agregar métodos obtenerTodos() en los servicios
      final prestamos = <Prestamo>[];
      final ausencias = <Ausencia>[];
      
      // Generar alertas
      final resumen = await AlertasProactivasService.generarAlertasCompletas(
        empleados: empleados,
        prestamos: prestamos,
        ausencias: ausencias,
        fechaUltimaActualizacionParitarias: DateTime.now().subtract(const Duration(days: 45)),
        fechaUltimaActualizacionCCT: DateTime.now().subtract(const Duration(days: 30)),
      );
      
      setState(() {
        _resumen = resumen;
        _cargando = false;
      });
    } catch (e) {
      print('Error cargando alertas: $e');
      setState(() => _cargando = false);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard de Riesgos'),
        backgroundColor: AppColors.primary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargarAlertas,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _resumen == null || _resumen!.totalAlertas == 0
              ? _buildSinAlertas()
              : _buildConAlertas(),
    );
  }
  
  Widget _buildSinAlertas() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 100,
            color: Colors.green[300],
          ),
          const SizedBox(height: 24),
          const Text(
            '¡Todo en orden!',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'No hay alertas pendientes',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildConAlertas() {
    final alertasFiltradas = _resumen!.alertas.where((alerta) {
      if (_filtroCategoria != null && alerta.categoria != _filtroCategoria) {
        return false;
      }
      if (_filtroTipo != null && alerta.tipo != _filtroTipo) {
        return false;
      }
      return true;
    }).toList();
    
    return Column(
      children: [
        _buildResumen(),
        _buildFiltros(),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: alertasFiltradas.length,
            itemBuilder: (context, index) {
              return _buildAlertaCard(alertasFiltradas[index]);
            },
          ),
        ),
      ],
    );
  }
  
  Widget _buildResumen() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: AppColors.backgroundLight,
        border: Border(
          bottom: BorderSide(color: AppColors.glassBorder, width: 1),
        ),
      ),
      child: Column(
        children: [
          const Text(
            'Resumen de Alertas',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildResumenCard('Críticas', _resumen!.criticas, Colors.red)),
              Expanded(child: _buildResumenCard('Altas', _resumen!.altas, Colors.orange)),
              Expanded(child: _buildResumenCard('Medias', _resumen!.medias, Colors.yellow[700]!)),
              Expanded(child: _buildResumenCard('Bajas', _resumen!.bajas, Colors.blue)),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildResumenCard(String label, int cantidad, Color color) {
    return Card(
      color: color.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text(
              cantidad.toString(),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildFiltros() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: AppColors.backgroundLight,
        border: Border(
          bottom: BorderSide(color: AppColors.glassBorder, width: 1),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _filtroTipo,
              decoration: const InputDecoration(
                labelText: 'Filtrar por tipo',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: const [
                DropdownMenuItem(value: null, child: Text('Todos')),
                DropdownMenuItem(value: 'critica', child: Text('Críticas')),
                DropdownMenuItem(value: 'alta', child: Text('Altas')),
                DropdownMenuItem(value: 'media', child: Text('Medias')),
                DropdownMenuItem(value: 'baja', child: Text('Bajas')),
              ],
              onChanged: (valor) {
                setState(() => _filtroTipo = valor);
              },
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _filtroCategoria,
              decoration: const InputDecoration(
                labelText: 'Filtrar por categoría',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: const [
                DropdownMenuItem(value: null, child: Text('Todas')),
                DropdownMenuItem(value: 'empleado', child: Text('Empleados')),
                DropdownMenuItem(value: 'prestamo', child: Text('Préstamos')),
                DropdownMenuItem(value: 'ausencia', child: Text('Ausencias')),
                DropdownMenuItem(value: 'paritarias', child: Text('Paritarias')),
                DropdownMenuItem(value: 'cct', child: Text('CCT')),
              ],
              onChanged: (valor) {
                setState(() => _filtroCategoria = valor);
              },
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildAlertaCard(AlertaProactiva alerta) {
    final Color color = _getColorPorTipo(alerta.tipo);
    final IconData icon = _getIconPorCategoria(alerta.categoria);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.2),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(
          alerta.titulo,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    alerta.tipo.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  alerta.categoria,
                  style: const TextStyle(fontSize: 11),
                ),
              ],
            ),
            if (alerta.entidadNombre != null) ...[
              const SizedBox(height: 4),
              Text(
                alerta.entidadNombre!,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Descripción:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  alerta.descripcion,
                  style: const TextStyle(fontSize: 12),
                ),
                if (alerta.accionRecomendada != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.lightbulb_outline,
                          color: Colors.blue,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Acción recomendada:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                  color: Colors.blue,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                alerta.accionRecomendada!,
                                style: const TextStyle(fontSize: 11),
                              ),
                            ],
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
    );
  }
  
  Color _getColorPorTipo(String tipo) {
    switch (tipo) {
      case 'critica':
        return Colors.red;
      case 'alta':
        return Colors.orange;
      case 'media':
        return Colors.yellow[700]!;
      case 'baja':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
  
  IconData _getIconPorCategoria(String categoria) {
    switch (categoria) {
      case 'empleado':
        return Icons.person;
      case 'prestamo':
        return Icons.attach_money;
      case 'ausencia':
        return Icons.event_busy;
      case 'paritarias':
        return Icons.trending_up;
      case 'cct':
        return Icons.description;
      default:
        return Icons.warning;
    }
  }
}
