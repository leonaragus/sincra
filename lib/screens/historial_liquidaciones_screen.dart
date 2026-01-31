// ========================================================================
// PANTALLA DE HISTORIAL DE LIQUIDACIONES
// Ver historial completo de un empleado con validaciones
// ========================================================================

import 'package:flutter/material.dart';
import '../models/historial_liquidacion.dart';
import '../services/historial_liquidaciones_service.dart';
import '../theme/app_colors.dart';
import 'package:intl/intl.dart';

class HistorialLiquidacionesScreen extends StatefulWidget {
  final String empleadoCuil;
  final String empleadoNombre;
  
  const HistorialLiquidacionesScreen({
    super.key,
    required this.empleadoCuil,
    required this.empleadoNombre,
  });
  
  @override
  State<HistorialLiquidacionesScreen> createState() => _HistorialLiquidacionesScreenState();
}

class _HistorialLiquidacionesScreenState extends State<HistorialLiquidacionesScreen> {
  List<HistorialLiquidacion> _historial = [];
  EstadisticasHistorialEmpleado? _estadisticas;
  List<String> _variacionesInusuales = [];
  bool _cargando = true;
  
  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }
  
  Future<void> _cargarDatos() async {
    setState(() => _cargando = true);
    
    try {
      final historial = await HistorialLiquidacionesService.obtenerHistorialEmpleado(
        widget.empleadoCuil,
      );
      
      final estadisticas = await HistorialLiquidacionesService.obtenerEstadisticasEmpleado(
        widget.empleadoCuil,
      );
      
      final variaciones = await HistorialLiquidacionesService.detectarVariacionesInusuales(
        widget.empleadoCuil,
      );
      
      setState(() {
        _historial = historial;
        _estadisticas = estadisticas;
        _variacionesInusuales = variaciones;
        _cargando = false;
      });
    } catch (e) {
      print('Error cargando historial: $e');
      setState(() => _cargando = false);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Historial - ${widget.empleadoNombre}'),
        backgroundColor: AppColors.primary,
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _cargarDatos,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_estadisticas != null) _buildEstadisticas(_estadisticas!),
                  if (_variacionesInusuales.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildAlertasVariaciones(),
                  ],
                  const SizedBox(height: 16),
                  _buildListaHistorial(),
                ],
              ),
            ),
    );
  }
  
  Widget _buildEstadisticas(EstadisticasHistorialEmpleado stats) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Estadísticas',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildStatCard('Liquidaciones', stats.cantidadLiquidaciones.toString(), Icons.receipt)),
                Expanded(child: _buildStatCard('Promedio Neto', '\$${NumberFormat('#,###').format(stats.promedioNeto)}', Icons.attach_money)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _buildStatCard('Máximo', '\$${NumberFormat('#,###').format(stats.maximoNeto)}', Icons.trending_up)),
                Expanded(child: _buildStatCard('Mínimo', '\$${NumberFormat('#,###').format(stats.minimoNeto)}', Icons.trending_down)),
              ],
            ),
            if (stats.mejorRemuneracionUltimos6Meses != null) ...[
              const SizedBox(height: 8),
              Card(
                color: Colors.green[50],
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(Icons.star, color: Colors.green),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Mejor Remuneración (Últimos 6 meses):',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '\$${NumberFormat('#,###').format(stats.mejorRemuneracionUltimos6Meses)}',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green),
                          ),
                          const Text(
                            'Base para indemnizaciones (Art. 245 LCT)',
                            style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildStatCard(String label, String valor, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, size: 24, color: AppColors.primary),
            const SizedBox(height: 4),
            Text(
              valor,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(label, style: const TextStyle(fontSize: 11)),
          ],
        ),
      ),
    );
  }
  
  Widget _buildAlertasVariaciones() {
    return Card(
      color: Colors.amber[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.warning, color: Colors.orange),
                const SizedBox(width: 8),
                const Text(
                  'Variaciones Inusuales Detectadas',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(),
            ..._variacionesInusuales.map((alerta) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.arrow_right, size: 16, color: Colors.orange),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      alerta,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }
  
  Widget _buildListaHistorial() {
    if (_historial.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.history, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No hay liquidaciones registradas'),
              ],
            ),
          ),
        ),
      );
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Historial Completo',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ..._historial.map((liq) => _buildLiquidacionCard(liq)),
      ],
    );
  }
  
  Widget _buildLiquidacionCard(HistorialLiquidacion liq) {
    final Color colorEstado = liq.tieneErrores
        ? Colors.red
        : liq.tieneAdvertencias
            ? Colors.orange
            : Colors.green;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: colorEstado.withOpacity(0.2),
          child: Icon(
            liq.tieneErrores ? Icons.error : Icons.check_circle,
            color: colorEstado,
          ),
        ),
        title: Text(
          liq.periodo,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Neto: \$${NumberFormat('#,###').format(liq.netoACobrar)}'),
            Text('Bruto: \$${NumberFormat('#,###').format(liq.totalBrutoRemunerativo)}'),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              liq.tipo.toUpperCase(),
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
            ),
            if (liq.tieneAdvertencias || liq.tieneErrores)
              Icon(Icons.warning, size: 16, color: colorEstado),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetalleRow('Básico:', '\$${NumberFormat('#,###').format(liq.sueldoBasico)}'),
                _buildDetalleRow('Antigüedad:', '\$${NumberFormat('#,###').format(liq.adicionalAntiguedad)} (${liq.antiguedadAnios} años)'),
                if (liq.otrosHaberes > 0)
                  _buildDetalleRow('Otros haberes:', '\$${NumberFormat('#,###').format(liq.otrosHaberes)}'),
                const Divider(),
                _buildDetalleRow('Total Bruto:', '\$${NumberFormat('#,###').format(liq.totalBrutoRemunerativo)}', bold: true),
                _buildDetalleRow('Total Aportes:', '\$${NumberFormat('#,###').format(liq.totalAportes)}'),
                _buildDetalleRow('Total Descuentos:', '\$${NumberFormat('#,###').format(liq.totalDescuentos)}'),
                if (liq.embargosJudiciales > 0)
                  _buildDetalleRow('  └ Embargos:', '\$${NumberFormat('#,###').format(liq.embargosJudiciales)}', color: Colors.red),
                const Divider(),
                _buildDetalleRow('NETO A COBRAR:', '\$${NumberFormat('#,###').format(liq.netoACobrar)}', bold: true, color: Colors.green),
                const SizedBox(height: 8),
                _buildDetalleRow('% Neto/Bruto:', '${liq.porcentajeNeto.toStringAsFixed(1)}%'),
                _buildDetalleRow('Costo Empleador:', '\$${NumberFormat('#,###').format(liq.costoEmpleadorTotal)}'),
                const SizedBox(height: 8),
                Text(
                  'Liquidado: ${DateFormat('dd/MM/yyyy HH:mm').format(liq.fechaLiquidacion)}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
                
                // Advertencias
                if (liq.advertencias != null && liq.advertencias!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.warning, size: 16, color: Colors.orange),
                            SizedBox(width: 8),
                            Text('Advertencias:', style: TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...liq.advertencias!.map((adv) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text('• $adv', style: const TextStyle(fontSize: 12)),
                        )),
                      ],
                    ),
                  ),
                ],
                
                // Errores
                if (liq.errores != null && liq.errores!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.error, size: 16, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Errores:', style: TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...liq.errores!.map((err) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text('• $err', style: const TextStyle(fontSize: 12)),
                        )),
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
  
  Widget _buildDetalleRow(String label, String valor, {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: bold ? 14 : 12,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            valor,
            style: TextStyle(
              fontSize: bold ? 14 : 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
