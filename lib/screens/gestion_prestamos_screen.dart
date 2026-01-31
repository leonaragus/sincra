// ========================================================================
// PANTALLA DE GESTIÓN DE PRÉSTAMOS
// Préstamos a empleados con cuotas automáticas
// ========================================================================

import 'package:flutter/material.dart';
import '../models/prestamo.dart';
import '../models/empleado_completo.dart';
import '../services/prestamos_service.dart';
import '../services/empleados_service.dart';
import '../theme/app_colors.dart';
import 'prestamo_form_screen.dart';

class GestionPrestamosScreen extends StatefulWidget {
  final String? empresaCuit;
  final String? empleadoCuilFiltro;
  
  const GestionPrestamosScreen({
    super.key,
    this.empresaCuit,
    this.empleadoCuilFiltro,
  });
  
  @override
  State<GestionPrestamosScreen> createState() => _GestionPrestamosScreenState();
}

class _GestionPrestamosScreenState extends State<GestionPrestamosScreen> {
  List<Prestamo> _prestamos = [];
  List<EmpleadoCompleto> _empleados = [];
  bool _cargando = true;
  
  String? _filtroEmpleado;
  bool _soloActivos = true;
  
  @override
  void initState() {
    super.initState();
    _filtroEmpleado = widget.empleadoCuilFiltro;
    _cargarDatos();
  }
  
  Future<void> _cargarDatos() async {
    setState(() => _cargando = true);
    
    try {
      _empleados = await EmpleadosService.obtenerEmpleadosActivos(
        empresaCuit: widget.empresaCuit,
      );
      
      _prestamos = [];
      if (_filtroEmpleado != null) {
        _prestamos = await PrestamosService.obtenerPrestamosPorEmpleado(
          _filtroEmpleado!,
          soloActivos: _soloActivos,
        );
      } else {
        for (final emp in _empleados) {
          final prestamos = await PrestamosService.obtenerPrestamosPorEmpleado(
            emp.cuil,
            soloActivos: _soloActivos,
          );
          _prestamos.addAll(prestamos);
        }
      }
    } catch (e) {
      _mostrarError('Error cargando datos: $e');
    }
    
    setState(() => _cargando = false);
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Préstamos'),
        backgroundColor: AppColors.primary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargarDatos,
          ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildFiltros(),
                _buildEstadisticas(),
                Expanded(child: _buildListaPrestamos()),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _agregarPrestamo,
        icon: const Icon(Icons.attach_money),
        label: const Text('Nuevo Préstamo'),
        backgroundColor: AppColors.primary,
      ),
    );
  }
  
  Widget _buildFiltros() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (widget.empleadoCuilFiltro == null)
              DropdownButtonFormField<String?>(
                value: _filtroEmpleado,
                decoration: const InputDecoration(
                  labelText: 'Empleado',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Todos')),
                  ..._empleados.map((e) => DropdownMenuItem(
                    value: e.cuil,
                    child: Text(e.nombreCompleto),
                  )),
                ],
                onChanged: (v) {
                  setState(() => _filtroEmpleado = v);
                  _cargarDatos();
                },
              ),
            
            const SizedBox(height: 12),
            
            FilterChip(
              label: const Text('Solo activos'),
              selected: _soloActivos,
              onSelected: (v) {
                setState(() => _soloActivos = v);
                _cargarDatos();
              },
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildEstadisticas() {
    final totalPrestamos = _prestamos.length;
    final totalActivos = _prestamos.where((p) => p.estado == EstadoPrestamo.activo).length;
    final montoTotal = _prestamos.fold(0.0, (sum, p) => sum + p.montoTotal);
    final montoRestante = _prestamos.fold(0.0, (sum, p) => sum + p.montoRestante);
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildEstadistica('Total', totalPrestamos.toString(), Icons.list),
            _buildEstadistica('Activos', totalActivos.toString(), Icons.pending),
            _buildEstadistica('Prestado', '\$${(montoTotal / 1000).toStringAsFixed(0)}K', Icons.trending_up),
            _buildEstadistica('Restante', '\$${(montoRestante / 1000).toStringAsFixed(0)}K', Icons.trending_down),
          ],
        ),
      ),
    );
  }
  
  Widget _buildEstadistica(String label, String valor, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: AppColors.primary),
        const SizedBox(height: 4),
        Text(
          valor,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }
  
  Widget _buildListaPrestamos() {
    if (_prestamos.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.money_off, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text('No hay préstamos registrados'),
          ],
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _prestamos.length,
      itemBuilder: (context, index) {
        final prestamo = _prestamos[index];
        final empleado = _empleados.firstWhere(
          (e) => e.cuil == prestamo.empleadoCuil,
          orElse: () => EmpleadoCompleto(
            cuil: prestamo.empleadoCuil,
            nombreCompleto: 'Empleado no encontrado',
            fechaIngreso: DateTime.now(),
            categoria: '',
            provincia: '',
          ),
        );
        
        return _buildPrestamoCard(prestamo, empleado);
      },
    );
  }
  
  Widget _buildPrestamoCard(Prestamo prestamo, EmpleadoCompleto empleado) {
    final Color color = prestamo.estado == EstadoPrestamo.activo
        ? Colors.orange
        : prestamo.estado == EstadoPrestamo.pagado
            ? Colors.green
            : Colors.grey;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.2),
          child: Icon(Icons.attach_money, color: color),
        ),
        title: Text(
          empleado.nombreCompleto,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Monto: \$${prestamo.montoTotal.toStringAsFixed(2)}'),
            Text('Cuotas: ${prestamo.cuotasPagadas}/${prestamo.cantidadCuotas}'),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Chip(
              label: Text(prestamo.estado.name.toUpperCase(), style: const TextStyle(fontSize: 10)),
              backgroundColor: color.withOpacity(0.3),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LinearProgressIndicator(
                  value: prestamo.porcentajePagado / 100,
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  minHeight: 8,
                ),
                const SizedBox(height: 8),
                Text(
                  'Progreso: ${prestamo.porcentajePagado.toStringAsFixed(1)}%',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                
                _buildDetalleFila('Monto otorgado:', '\$${prestamo.montoTotal.toStringAsFixed(2)}'),
                _buildDetalleFila('Monto pagado:', '\$${prestamo.montoPagado.toStringAsFixed(2)}'),
                _buildDetalleFila('Monto restante:', '\$${prestamo.montoRestante.toStringAsFixed(2)}', destacado: true),
                _buildDetalleFila('Valor cuota:', '\$${prestamo.valorCuota.toStringAsFixed(2)}'),
                _buildDetalleFila('Tasa interés:', '${prestamo.tasaInteres}% anual'),
                _buildDetalleFila(
                  'Fecha otorgamiento:',
                  '${prestamo.fechaOtorgamiento.day}/${prestamo.fechaOtorgamiento.month}/${prestamo.fechaOtorgamiento.year}',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildDetalleFila(String label, String valor, {bool destacado = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: destacado ? 14 : 12,
              fontWeight: destacado ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            valor,
            style: TextStyle(
              fontSize: destacado ? 14 : 12,
              fontWeight: FontWeight.w600,
              color: destacado ? AppColors.primary : null,
            ),
          ),
        ],
      ),
    );
  }
  
  void _agregarPrestamo() async {
    final resultado = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PrestamoFormScreen(
          empleadosFiltro: widget.empleadoCuilFiltro != null 
              ? [widget.empleadoCuilFiltro!] 
              : _empleados.map((e) => e.cuil).toList(),
          empresaCuit: widget.empresaCuit ?? '',
        ),
      ),
    );
    
    if (resultado == true) {
      _cargarDatos();
    }
  }
  
  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), backgroundColor: Colors.red),
    );
  }
}
