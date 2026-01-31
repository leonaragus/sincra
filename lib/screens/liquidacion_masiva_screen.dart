// ========================================================================
// PANTALLA DE LIQUIDACIÓN MASIVA
// Liquidar múltiples empleados con un click
// ========================================================================

import 'package:flutter/material.dart';
import '../models/empleado_completo.dart';
import '../services/empleados_service.dart';
import '../services/liquidacion_masiva_service.dart';
import '../theme/app_colors.dart';

class LiquidacionMasivaScreen extends StatefulWidget {
  final String? empresaCuit;
  final String? empresaNombre;
  
  const LiquidacionMasivaScreen({
    super.key,
    this.empresaCuit,
    this.empresaNombre,
  });
  
  @override
  State<LiquidacionMasivaScreen> createState() => _LiquidacionMasivaScreenState();
}

class _LiquidacionMasivaScreenState extends State<LiquidacionMasivaScreen> {
  // Configuración
  int _mes = DateTime.now().month;
  int _anio = DateTime.now().year;
  
  // Filtros
  String _filtroTodos = 'todos'; // todos, seleccionados
  String? _filtroProvincia;
  String? _filtroCategoria;
  String? _filtroSector;
  
  // Empleados
  List<EmpleadoCompleto> _empleadosDisponibles = [];
  List<EmpleadoCompleto> _empleadosSeleccionados = [];
  bool _cargandoEmpleados = true;
  
  // Opciones
  bool _aplicarConceptosRecurrentes = true;
  bool _generarRecibos = true;
  bool _generarF931 = false;
  
  // Progreso
  bool _liquidando = false;
  int _progreso = 0;
  int _total = 0;
  String _mensajeProgreso = '';
  
  // Resultado
  ResultadoLiquidacionMasiva? _resultado;
  
  @override
  void initState() {
    super.initState();
    _cargarEmpleados();
  }
  
  Future<void> _cargarEmpleados() async {
    setState(() => _cargandoEmpleados = true);
    
    try {
      _empleadosDisponibles = await EmpleadosService.obtenerEmpleadosActivos(
        empresaCuit: widget.empresaCuit,
      );
    } catch (e) {
      _mostrarError('Error cargando empleados: $e');
    }
    
    setState(() => _cargandoEmpleados = false);
  }
  
  List<EmpleadoCompleto> get _empleadosFiltrados {
    var empleados = _empleadosDisponibles;
    
    if (_filtroProvincia != null) {
      empleados = empleados.where((e) => e.provincia == _filtroProvincia).toList();
    }
    
    if (_filtroCategoria != null) {
      empleados = empleados.where((e) => e.categoria == _filtroCategoria).toList();
    }
    
    if (_filtroSector != null) {
      empleados = empleados.where((e) => e.sector == _filtroSector).toList();
    }
    
    return empleados;
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.empresaNombre != null
            ? 'Liquidación Masiva - ${widget.empresaNombre}'
            : 'Liquidación Masiva'),
        backgroundColor: AppColors.primary,
      ),
      body: _cargandoEmpleados
          ? const Center(child: CircularProgressIndicator())
          : _liquidando
              ? _buildPantallaProgreso()
              : _resultado != null
                  ? _buildPantallaResultado()
                  : _buildPantallaConfiguracion(),
    );
  }
  
  Widget _buildPantallaConfiguracion() {
    final empleadosALiquidar = _filtroTodos == 'todos' 
        ? _empleadosFiltrados 
        : _empleadosSeleccionados;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSeccionPeriodo(),
          const SizedBox(height: 24),
          _buildSeccionEmpleados(),
          const SizedBox(height: 24),
          _buildSeccionOpciones(),
          const SizedBox(height: 24),
          _buildSeccionResumen(empleadosALiquidar.length),
          const SizedBox(height: 32),
          _buildBotonLiquidar(empleadosALiquidar),
        ],
      ),
    );
  }
  
  Widget _buildSeccionPeriodo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '📅 Período',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _mes,
                    decoration: const InputDecoration(
                      labelText: 'Mes',
                      border: OutlineInputBorder(),
                    ),
                    items: List.generate(12, (i) {
                      final mes = i + 1;
                      final nombres = ['Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
                                      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'];
                      return DropdownMenuItem(
                        value: mes,
                        child: Text('$mes - ${nombres[i]}'),
                      );
                    }).toList(),
                    onChanged: (v) => setState(() => _mes = v!),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _anio,
                    decoration: const InputDecoration(
                      labelText: 'Año',
                      border: OutlineInputBorder(),
                    ),
                    items: List.generate(5, (i) {
                      final anio = DateTime.now().year - 2 + i;
                      return DropdownMenuItem(value: anio, child: Text('$anio'));
                    }).toList(),
                    onChanged: (v) => setState(() => _anio = v!),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSeccionEmpleados() {
    final provincias = _empleadosDisponibles.map((e) => e.provincia).toSet().toList()..sort();
    final categorias = _empleadosDisponibles.map((e) => e.categoria).toSet().toList()..sort();
    final sectores = _empleadosDisponibles.map((e) => e.sector).whereType<String>().toSet().toList()..sort();
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '👥 Empleados',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            // Selector: Todos vs Seleccionados
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'todos', label: Text('Todos'), icon: Icon(Icons.people)),
                ButtonSegment(value: 'seleccionados', label: Text('Seleccionados'), icon: Icon(Icons.checklist)),
              ],
              selected: {_filtroTodos},
              onSelectionChanged: (Set<String> selection) {
                setState(() => _filtroTodos = selection.first);
              },
            ),
            
            const SizedBox(height: 16),
            
            // Filtros
            if (_filtroTodos == 'todos') ...[
              const Text('Filtros:', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              
              DropdownButtonFormField<String?>(
                value: _filtroProvincia,
                decoration: const InputDecoration(
                  labelText: 'Provincia',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Todas')),
                  ...provincias.map((p) => DropdownMenuItem(value: p, child: Text(p))),
                ],
                onChanged: (v) => setState(() => _filtroProvincia = v),
              ),
              
              const SizedBox(height: 8),
              
              DropdownButtonFormField<String?>(
                value: _filtroCategoria,
                decoration: const InputDecoration(
                  labelText: 'Categoría',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Todas')),
                  ...categorias.map((c) => DropdownMenuItem(value: c, child: Text(c))),
                ],
                onChanged: (v) => setState(() => _filtroCategoria = v),
              ),
              
              const SizedBox(height: 8),
              
              DropdownButtonFormField<String?>(
                value: _filtroSector,
                decoration: const InputDecoration(
                  labelText: 'Sector',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Todos')),
                  ...sectores.map((s) => DropdownMenuItem(value: s, child: Text(s))),
                ],
                onChanged: (v) => setState(() => _filtroSector = v),
              ),
            ] else ...[
              const Text('Selecciona empleados:', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              
              SizedBox(
                height: 200,
                child: ListView.builder(
                  itemCount: _empleadosFiltrados.length,
                  itemBuilder: (context, index) {
                    final emp = _empleadosFiltrados[index];
                    final seleccionado = _empleadosSeleccionados.any((e) => e.cuil == emp.cuil);
                    
                    return CheckboxListTile(
                      title: Text(emp.nombreCompleto),
                      subtitle: Text('${emp.categoria} - ${emp.provincia}'),
                      value: seleccionado,
                      onChanged: (value) {
                        setState(() {
                          if (value == true) {
                            _empleadosSeleccionados.add(emp);
                          } else {
                            _empleadosSeleccionados.removeWhere((e) => e.cuil == emp.cuil);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildSeccionOpciones() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '⚙️ Opciones',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            CheckboxListTile(
              title: const Text('Aplicar conceptos recurrentes automáticamente'),
              subtitle: const Text('Vale comida, embargos, etc.'),
              value: _aplicarConceptosRecurrentes,
              onChanged: (v) => setState(() => _aplicarConceptosRecurrentes = v!),
            ),
            
            CheckboxListTile(
              title: const Text('Generar recibos PDF'),
              subtitle: const Text('Un PDF por empleado'),
              value: _generarRecibos,
              onChanged: (v) => setState(() => _generarRecibos = v!),
            ),
            
            CheckboxListTile(
              title: const Text('Generar F931 (SICOSS) al finalizar'),
              subtitle: const Text('Archivo para AFIP'),
              value: _generarF931,
              onChanged: (v) => setState(() => _generarF931 = v!),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSeccionResumen(int cantidad) {
    return Card(
      color: Colors.blue[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.blue, size: 40),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Se liquidarán $cantidad empleados',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Período: $_mes/$_anio',
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildBotonLiquidar(List<EmpleadoCompleto> empleados) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: empleados.isEmpty ? null : () => _iniciarLiquidacion(empleados),
        icon: const Icon(Icons.bolt, size: 28),
        label: Text(
          'LIQUIDAR ${empleados.length} EMPLEADOS',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
        ),
      ),
    );
  }
  
  Widget _buildPantallaProgreso() {
    final porcentaje = _total > 0 ? (_progreso / _total) * 100 : 0.0;
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.sync, size: 80, color: AppColors.primary),
            const SizedBox(height: 24),
            
            const Text(
              'Liquidando empleados...',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 32),
            
            LinearProgressIndicator(
              value: _total > 0 ? _progreso / _total : 0.0,
              minHeight: 12,
              backgroundColor: Colors.grey[300],
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
            const SizedBox(height: 16),
            
            Text(
              '$_progreso / $_total (${porcentaje.toStringAsFixed(1)}%)',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            
            Text(
              _mensajeProgreso,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildPantallaResultado() {
    if (_resultado == null) return const SizedBox();
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Ícono y título
          Icon(
            _resultado!.fallidos == 0 ? Icons.check_circle : Icons.warning,
            size: 80,
            color: _resultado!.fallidos == 0 ? Colors.green : Colors.orange,
          ),
          const SizedBox(height: 16),
          
          Text(
            _resultado!.fallidos == 0 
                ? '¡Liquidación Completada!' 
                : 'Liquidación Completada con Advertencias',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 32),
          
          // Estadísticas
          _buildCardEstadistica('Total Procesados', '${_resultado!.totalEmpleados}', Icons.people, Colors.blue),
          _buildCardEstadistica('Exitosos', '${_resultado!.exitosos}', Icons.check_circle, Colors.green),
          if (_resultado!.fallidos > 0)
            _buildCardEstadistica('Fallidos', '${_resultado!.fallidos}', Icons.error, Colors.red),
          _buildCardEstadistica('Tiempo', '${_resultado!.duracion.inSeconds}s', Icons.timer, Colors.purple),
          
          const SizedBox(height: 24),
          
          // Totales financieros
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Text('💰 Totales Financieros', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Divider(),
                  _buildFilaTotalFinanciero('Masa Salarial:', _resultado!.masaSalarialTotal),
                  _buildFilaTotalFinanciero('Aportes:', _resultado!.aportesTotal),
                  _buildFilaTotalFinanciero('Contribuciones:', _resultado!.contribucionesTotal),
                  const Divider(),
                  _buildFilaTotalFinanciero(
                    'Costo Empleador Total:',
                    _resultado!.masaSalarialTotal + _resultado!.contribucionesTotal,
                    destacado: true,
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Botones
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _resultado = null;
                      _progreso = 0;
                      _total = 0;
                    });
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Nueva Liquidación'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context, true);
                  },
                  icon: const Icon(Icons.check),
                  label: const Text('Finalizar'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildCardEstadistica(String label, String valor, IconData icon, Color color) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon, color: color, size: 32),
        title: Text(valor, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
        subtitle: Text(label),
      ),
    );
  }
  
  Widget _buildFilaTotalFinanciero(String label, double monto, {bool destacado = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: destacado ? 16 : 14,
              fontWeight: destacado ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            '\$${monto.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: destacado ? 18 : 14,
              fontWeight: destacado ? FontWeight.bold : FontWeight.w600,
              color: destacado ? AppColors.primary : null,
            ),
          ),
        ],
      ),
    );
  }
  
  Future<void> _iniciarLiquidacion(List<EmpleadoCompleto> empleados) async {
    setState(() {
      _liquidando = true;
      _progreso = 0;
      _total = empleados.length;
      _mensajeProgreso = 'Iniciando...';
    });
    
    try {
      final config = ConfiguracionLiquidacionMasiva(
        mes: _mes,
        anio: _anio,
        empresaCuit: widget.empresaCuit,
        empleadosCuilsFiltro: empleados.map((e) => e.cuil).toList(),
        aplicarConceptosRecurrentes: _aplicarConceptosRecurrentes,
        generarRecibos: _generarRecibos,
        generarF931AlFinal: _generarF931,
      );
      
      final resultado = await LiquidacionMasivaService.liquidarMasivo(
        config: config,
        onProgress: (actual, total, mensaje) {
          setState(() {
            _progreso = actual;
            _total = total;
            _mensajeProgreso = mensaje;
          });
        },
      );
      
      setState(() {
        _resultado = resultado;
        _liquidando = false;
      });
      
    } catch (e) {
      setState(() => _liquidando = false);
      _mostrarError('Error en liquidación masiva: $e');
    }
  }
  
  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: Colors.red,
      ),
    );
  }
}
