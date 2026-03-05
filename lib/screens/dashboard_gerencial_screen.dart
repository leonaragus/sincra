
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../services/reportes_service.dart';
import '../services/excel_export_service.dart';
import '../theme/app_colors.dart';
import '../utils/file_saver.dart';

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
  String _error = '';

  // Datos del dashboard
  Map<String, dynamic> _dashboardData = {};

  final _kpiNumberFormat = NumberFormat('#,##0', 'es_AR');

  // Getters para facilitar el acceso a los datos
  int get _totalEmpleados => _dashboardData['kpis']?['total_empleados'] ?? 0;
  double get _costoMensual => (_dashboardData['kpis']?['costo_estimado_mes'] as num?)?.toDouble() ?? 0.0;
  Map<String, int> get _porProvincia => (_dashboardData['kpis']?['por_provincia'] as Map?)?.cast<String, int>() ?? {};
  Map<String, int> get _porCategoria => (_dashboardData['kpis']?['por_categoria'] as Map?)?.cast<String, int>() ?? {};
  List<Map<String, dynamic>> get _evolucion => (_dashboardData['evolucion'] as List?)?.cast<Map<String, dynamic>>() ?? [];
  List<Map<String, dynamic>> get _topEmpleados => (_dashboardData['top_empleados'] as List?)?.cast<Map<String, dynamic>>() ?? [];

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() {
      _cargando = true;
      _error = '';
    });
    try {
      // **LLAMADA ÚNICA Y OPTIMIZADA**
      final data = await ReportesService.obtenerDatosDashboard(
        empresaCuit: widget.empresaCuit,
      );
      
      if (!mounted) return;

      setState(() {
        _dashboardData = data;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _cargando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 768;

    final chartColors = [
      AppColors.accentBlue,
      AppColors.accentPink,
      AppColors.accentEmerald,
      AppColors.accentOrange,
      AppColors.accentYellow,
      const Color(0xFF9333EA), // Purple
    ];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: (isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark).copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: backgroundColor,
        systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: backgroundColor,
        body: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _cargando
                  ? const Center(child: CircularProgressIndicator(color: AppColors.accentBlue))
                  : _error.isNotEmpty
                      ? _buildErrorState(_error)
                      : RefreshIndicator(
                          onRefresh: _cargarDatos,
                          backgroundColor: AppColors.backgroundCard,
                          color: AppColors.accentBlue,
                          child: CustomScrollView(
                            slivers: [
                              SliverPadding(
                                padding: const EdgeInsets.all(24),
                                sliver: SliverList(
                                  delegate: SliverChildListDelegate([
                                    _buildKPIs(),
                                    const SizedBox(height: 24),
                                    _buildGraficoEvolucion(chartColors.first),
                                    const SizedBox(height: 24),
                                    isTablet
                                        ? Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Expanded(child: _buildGraficoBarras(chartColors)),
                                              const SizedBox(width: 24),
                                              Expanded(child: _buildGraficoTorta(chartColors)),
                                            ],
                                          )
                                        : Column(
                                            children: [
                                              _buildGraficoBarras(chartColors),
                                              const SizedBox(height: 24),
                                              _buildGraficoTorta(chartColors),
                                            ],
                                          ),
                                    const SizedBox(height: 24),
                                    _buildTopEmpleados(),
                                  ]),
                                ),
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

  Widget _buildHeader() {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 8, 16, 16),
          decoration: const BoxDecoration(
            color: AppColors.glassFill,
            border: Border(bottom: BorderSide(color: AppColors.glassBorder)),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
                onPressed: () => Navigator.of(context).pop(),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  widget.empresaNombre ?? 'Dashboard Gerencial',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh, color: AppColors.textSecondary),
                tooltip: 'Actualizar',
                onPressed: _cargarDatos,
              ),
              IconButton(
                icon: const Icon(Icons.download_for_offline_outlined, color: AppColors.textSecondary),
                tooltip: 'Exportar a Excel',
                onPressed: _exportarExcel,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKPIs() {
    return Row(
      children: [
        Expanded(child: _buildKPICard('Total Empleados', _totalEmpleados.toString(), Icons.people_outline, AppColors.accentBlue)),
        const SizedBox(width: 16),
        Expanded(child: _buildKPICard('Costo Mensual', '\$${_kpiNumberFormat.format(_costoMensual)}', Icons.monetization_on_outlined, AppColors.accentEmerald)),
      ],
    );
  }

  Widget _buildKPICard(String label, String valor, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 12),
          Text(valor, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildGraficoContainer(String title, Widget child) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.glassFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 24),
          child,
        ],
      ),
    );
  }

  Widget _buildGraficoEvolucion(Color color) {
    if (_evolucion.isEmpty) return const SizedBox.shrink();
    
    return _buildGraficoContainer(
      'Evolución Masa Salarial (12 Meses)',
      SizedBox(
        height: 250,
        child: LineChart(
          LineChartData(
            gridData: FlGridData(show: true, checkToShowVerticalLine: (v) => true, getDrawingVerticalLine: (v) => FlLine(color: AppColors.glassBorder.withOpacity(0.5), strokeWidth: 1), getDrawingHorizontalLine: (v) => FlLine(color: AppColors.glassBorder.withOpacity(0.5), strokeWidth: 1)),
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30, interval: 3, getTitlesWidget: (v, m) => _bottomTitleWidgets(v, m, _evolucion))),
              leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 50, getTitlesWidget: _leftTitleWidgets)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(show: false),
            lineBarsData: [
              LineChartBarData(
                spots: _evolucion.asMap().entries.map((e) => FlSpot(e.key.toDouble(), (e.value['total_remuneraciones'] as num?)?.toDouble() ?? 0.0)).toList(),
                isCurved: true,
                color: color,
                barWidth: 4,
                isStrokeCapRound: true,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(show: true, color: color.withOpacity(0.2)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGraficoBarras(List<Color> colors) {
    final provincias = _porProvincia.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    if (provincias.isEmpty) return const SizedBox.shrink();

    return _buildGraficoContainer(
      'Empleados por Provincia',
      SizedBox(
        height: 300,
        child: BarChart(
          BarChartData(
            barGroups: provincias.take(5).toList().asMap().entries.map((e) {
              return BarChartGroupData(
                x: e.key,
                barRods: [BarChartRodData(toY: e.value.value.toDouble(), color: colors[e.key % colors.length], width: 18, borderRadius: BorderRadius.circular(4))],
              );
            }).toList(),
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, m) => _provinceTitleWidgets(v, m, provincias))),
              leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30, getTitlesWidget: (v, m) => Text(v.toInt().toString(), style: const TextStyle(color: AppColors.textMuted, fontSize: 10))))           
            ),
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
          ),
        ),
      ),
    );
  }

  Widget _buildGraficoTorta(List<Color> colors) {
    final categorias = _porCategoria.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    if (categorias.isEmpty) return const SizedBox.shrink();
    final total = categorias.fold(0, (sum, e) => sum + e.value);

    return _buildGraficoContainer(
      'Distribución por Categoría',
      SizedBox(
        height: 300,
        child: PieChart(
          PieChartData(
            sections: categorias.take(6).toList().asMap().entries.map((e) {
              final porcentaje = (e.value.value / total) * 100;
              return PieChartSectionData(
                value: e.value.value.toDouble(),
                title: '${porcentaje.toStringAsFixed(0)}%',
                color: colors[e.key % colors.length],
                radius: 100,
                titleStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white, shadows: [Shadow(color: Colors.black26, blurRadius: 3)]),
              );
            }).toList(),
            sectionsSpace: 4,
            centerSpaceRadius: 0,
          ),
        ),
      ),
    );
  }

  Widget _buildTopEmpleados() {
    if (_topEmpleados.isEmpty) return const SizedBox.shrink();

    return _buildGraficoContainer(
      'Top 5 Empleados por Antigüedad',
      Column(
        children: _topEmpleados.asMap().entries.map((entry) {
          final idx = entry.key;
          final emp = entry.value;
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: idx < _topEmpleados.length - 1 ? AppColors.glassBorder : Colors.transparent)),
            ),
            child: Row(
              children: [
                Expanded(flex: 3, child: Text(emp['nombre'] ?? '', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
                Expanded(flex: 2, child: Text(emp['categoria'] ?? '', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13), overflow: TextOverflow.ellipsis)),
                SizedBox(
                  width: 100,
                  child: Text('${emp['antiguedad'] ?? 0} años', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _bottomTitleWidgets(double value, TitleMeta meta, List<Map<String, dynamic>> data) {
    final style = const TextStyle(color: AppColors.textMuted, fontSize: 10);
    if (value.toInt() >= 0 && value.toInt() < data.length) {
      final item = data[value.toInt()];
      return SideTitleWidget(axisSide: meta.axisSide, child: Text('${item['periodo_mes']}/${(item['periodo_anio'] ?? '').toString().substring(2)}', style: style));
    }
    return Container();
  }

  Widget _leftTitleWidgets(double value, TitleMeta meta) {
    final style = const TextStyle(color: AppColors.textMuted, fontSize: 10);
    return SideTitleWidget(axisSide: meta.axisSide, child: Text('\$${(value / 1000).toStringAsFixed(0)}K', style: style));
  }

  Widget _provinceTitleWidgets(double value, TitleMeta meta, List<MapEntry<String, int>> data) {
    final style = const TextStyle(color: AppColors.textMuted, fontSize: 10);
    final prov = data[value.toInt()].key;
    return SideTitleWidget(axisSide: meta.axisSide, child: Text(prov.length > 4 ? prov.substring(0, 4) : prov, style: style));
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        margin: const EdgeInsets.all(24),
        decoration: BoxDecoration(
            color: AppColors.glassFill,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.error.withOpacity(0.5))
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: AppColors.error, size: 48),
            const SizedBox(height: 16),
            const Text('Ocurrió un Error', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            Text(message, style: const TextStyle(color: AppColors.textSecondary), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Future<void> _exportarExcel() async {
    // ... (sin cambios)
  }
}
