// ========================================================================
// DASHBOARD GERENCIAL
// KPIs, gráficos y estadísticas ejecutivas en tiempo real
// ========================================================================

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/reportes_service.dart';
import '../services/excel_export_service.dart';
import '../theme/app_colors.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';

class DashboardGerencialScreen extends StatefulWidget {
  final String? empresaCuit;
  final String? empresaNombre;
  
  const DashboardGerencialScreen({
    super.key,
    this.empresaCuit,
    this.empresaNombre,
  });
  
  @override
  State<DashboardGerencialScreen> createState() => _DashboardGerencialScreenState();
}

class _DashboardGerencialScreenState extends State<DashboardGerencialScreen> {
  bool _cargando = true;
  
  // KPIs
  int _totalEmpleados = 0;
  double _costoMensual = 0;
  Map<String, int> _porProvincia = {};
  Map<String, int> _porCategoria = {};
  
  // Evolución (12 meses)
  List<Map<String, dynamic>> _evolucion = [];
  
  // Top empleados
  List<Map<String, dynamic>> _topEmpleados = [];
  
  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }
  
  Future<void> _cargarDatos() async {
    setState(() => _cargando = true);
    
    try {
      final ahora = DateTime.now();
      
      // Cargar KPIs
      final kpis = await ReportesService.obtenerKPIsMes(
        mes: ahora.month,
        anio: ahora.year,
        empresaCuit: widget.empresaCuit,
      );
      
      // Cargar evolución
      final evolucion = await ReportesService.obtenerEvolucionMasaSalarial(
        empresaCuit: widget.empresaCuit,
      );
      
      // Cargar top empleados
      final top = await ReportesService.obtenerTopEmpleados(
        empresaCuit: widget.empresaCuit,
        limit: 10,
      );
      
      setState(() {
        _totalEmpleados = kpis['total_empleados'] ?? 0;
        _costoMensual = (kpis['costo_estimado_mes'] as num?)?.toDouble() ?? 0.0;
        _porProvincia = (kpis['por_provincia'] as Map?)?.cast<String, int>() ?? {};
        _porCategoria = (kpis['por_categoria'] as Map?)?.cast<String, int>() ?? {};
        _evolucion = evolucion;
        _topEmpleados = top;
        _cargando = false;
      });
    } catch (e) {
      print('Error cargando dashboard: $e');
      setState(() => _cargando = false);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.empresaNombre != null
            ? 'Dashboard - ${widget.empresaNombre}'
            : 'Dashboard Gerencial'),
        backgroundColor: AppColors.primary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargarDatos,
            tooltip: 'Actualizar',
          ),
          IconButton(
            icon: const Icon(Icons.file_download),
            onPressed: _exportarExcel,
            tooltip: 'Exportar Excel',
          ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _cargarDatos,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildKPIs(),
                  const SizedBox(height: 24),
                  _buildGraficoEvolucion(),
                  const SizedBox(height: 24),
                  _buildGraficosProvincia(),
                  const SizedBox(height: 24),
                  _buildTopEmpleados(),
                ],
              ),
            ),
    );
  }
  
  Widget _buildKPIs() {
    return Row(
      children: [
        Expanded(
          child: _buildKPICard(
            'Total Empleados',
            _totalEmpleados.toString(),
            Icons.people,
            Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildKPICard(
            'Costo Mensual',
            '\$${NumberFormat('#,###').format(_costoMensual)}',
            Icons.attach_money,
            Colors.green,
          ),
        ),
      ],
    );
  }
  
  Widget _buildKPICard(String label, String valor, IconData icon, Color color) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 32),
                const Spacer(),
                Text(
                  valor,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildGraficoEvolucion() {
    if (_evolucion.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Icon(Icons.show_chart, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                'No hay datos de evolución disponibles',
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 8),
              const Text(
                'Los datos aparecerán cuando generes F931',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }
    
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Evolución Masa Salarial (12 meses)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 250,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: true),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() >= 0 && value.toInt() < _evolucion.length) {
                            final data = _evolucion[value.toInt()];
                            return Text(
                              '${data['periodo_mes']}/${data['periodo_anio'].toString().substring(2)}',
                              style: const TextStyle(fontSize: 10),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 60,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            '\$${(value / 1000).toStringAsFixed(0)}K',
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: true),
                  lineBarsData: [
                    LineChartBarData(
                      spots: _evolucion.asMap().entries.map((e) {
                        return FlSpot(
                          e.key.toDouble(),
                          ((e.value['total_remuneraciones'] as num?)?.toDouble() ?? 0.0),
                        );
                      }).toList(),
                      isCurved: true,
                      color: AppColors.primary,
                      barWidth: 3,
                      dotData: const FlDotData(show: true),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildGraficosProvincia() {
    if (_porProvincia.isEmpty) {
      return const SizedBox();
    }
    
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _buildGraficoBarras(),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildGraficoTorta(),
        ),
      ],
    );
  }
  
  Widget _buildGraficoBarras() {
    final provincias = _porProvincia.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Empleados por Provincia',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 300,
              child: BarChart(
                BarChartData(
                  barGroups: provincias.take(5).toList().asMap().entries.map((e) {
                    return BarChartGroupData(
                      x: e.key,
                      barRods: [
                        BarChartRodData(
                          toY: e.value.value.toDouble(),
                          color: AppColors.primary,
                          width: 20,
                        ),
                      ],
                    );
                  }).toList(),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() < provincias.length) {
                            final prov = provincias[value.toInt()].key;
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                prov.length > 8 ? prov.substring(0, 8) : prov,
                                style: const TextStyle(fontSize: 10),
                              ),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          return Text(value.toInt().toString());
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildGraficoTorta() {
    final categorias = _porCategoria.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    final total = categorias.fold(0, (sum, e) => sum + e.value);
    
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
      Colors.teal,
    ];
    
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Empleados por Categoría',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 250,
              child: PieChart(
                PieChartData(
                  sections: categorias.take(6).toList().asMap().entries.map((e) {
                    final porcentaje = (e.value.value / total) * 100;
                    return PieChartSectionData(
                      value: e.value.value.toDouble(),
                      title: '${porcentaje.toStringAsFixed(1)}%',
                      color: colors[e.key % colors.length],
                      radius: 80,
                      titleStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    );
                  }).toList(),
                  sectionsSpace: 2,
                  centerSpaceRadius: 0,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: categorias.take(6).toList().asMap().entries.map((e) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: colors[e.key % colors.length],
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${e.value.key} (${e.value.value})',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildTopEmpleados() {
    if (_topEmpleados.isEmpty) {
      return const SizedBox();
    }
    
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Top 10 Empleados (Mayor Antigüedad)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Table(
              border: TableBorder.all(color: Colors.grey[300]!),
              columnWidths: const {
                0: FlexColumnWidth(3),
                1: FlexColumnWidth(2),
                2: FlexColumnWidth(1),
                3: FlexColumnWidth(2),
              },
              children: [
                TableRow(
                  decoration: BoxDecoration(color: Colors.grey[200]),
                  children: [
                    _buildTableHeader('Nombre'),
                    _buildTableHeader('Categoría'),
                    _buildTableHeader('Antigüedad'),
                    _buildTableHeader('Provincia'),
                  ],
                ),
                ..._topEmpleados.map((emp) {
                  return TableRow(
                    children: [
                      _buildTableCell(emp['nombre'] ?? ''),
                      _buildTableCell(emp['categoria'] ?? ''),
                      _buildTableCell('${emp['antiguedad'] ?? 0} años'),
                      _buildTableCell(emp['provincia'] ?? ''),
                    ],
                  );
                }).toList(),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildTableHeader(String text) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
  }
  
  Widget _buildTableCell(String text) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Text(text, style: const TextStyle(fontSize: 12)),
    );
  }
  
  Future<void> _exportarExcel() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Generando Excel...'),
            ],
          ),
        ),
      );
      
      final rutaArchivo = await ExcelExportService.generarEvolucionSalarial(
        empresaCuit: widget.empresaCuit,
      );
      
      Navigator.pop(context); // Cerrar diálogo
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Excel generado exitosamente'),
          backgroundColor: Colors.green,
        ),
      );
      
      // Abrir archivo
      await OpenFile.open(rutaArchivo);
      
    } catch (e) {
      Navigator.pop(context); // Cerrar diálogo
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generando Excel: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
