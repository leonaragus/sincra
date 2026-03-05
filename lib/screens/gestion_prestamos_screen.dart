
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  List<Prestamo> _allPrestamos = [];
  List<Prestamo> _filteredPrestamos = [];
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
      if (widget.empresaCuit == null || widget.empresaCuit!.isEmpty) {
        throw Exception("El CUIT de la empresa no puede ser nulo.");
      }

      // 1. Cargar empleados (necesario para el dropdown y nombres)
      _empleados = await EmpleadosService.obtenerEmpleadosActivos(
        empresaCuit: widget.empresaCuit,
      );

      // 2. **LLAMADA ÚNICA Y OPTIMIZADA**
      // Obtenemos todos los préstamos de la empresa de una sola vez.
      _allPrestamos = await PrestamosService.obtenerPrestamosPorEmpresa(widget.empresaCuit!);
      
      // 3. Aplicar filtros iniciales en memoria
      _filtrarPrestamos();

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error cargando datos: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _cargando = false);
      }
    }
  }
  
  void _filtrarPrestamos() {
    List<Prestamo> temp = List.from(_allPrestamos);
    
    if (_filtroEmpleado != null) {
      temp = temp.where((p) => p.empleadoCuil == _filtroEmpleado).toList();
    }
    
    if (_soloActivos) {
      temp = temp.where((p) => p.estado == EstadoPrestamo.activo).toList();
    }
    
    setState(() {
      _filteredPrestamos = temp;
    });
  }
  
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;
    
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
                                if (widget.empleadoCuilFiltro == null) ...[
                                  _buildFiltros(),
                                  const SizedBox(height: 24),
                                ],
                                _buildEstadisticas(),
                                const SizedBox(height: 24),
                                _buildListaHeader(),
                                const SizedBox(height: 12),
                                if (_filteredPrestamos.isEmpty)
                                  _buildEmptyState()
                                else
                                  ..._filteredPrestamos.map((p) => _buildPrestamoCard(p)).toList(),
                              ]),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _agregarPrestamo,
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text('Nuevo Préstamo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          backgroundColor: AppColors.accentBlue,
          elevation: 8,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
              const Text(
                'Gestión de Préstamos',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh, color: AppColors.textSecondary),
                tooltip: 'Recargar Datos',
                onPressed: _cargarDatos,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFiltros() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.glassFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<String?>(
              value: _filtroEmpleado,
              dropdownColor: AppColors.backgroundCard,
              decoration: InputDecoration(
                labelText: 'Filtrar por Empleado',
                labelStyle: const TextStyle(color: AppColors.textSecondary),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.glassBorder)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.glassBorder)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.accentBlue)),
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('Mostrar Todos', style: TextStyle(color: AppColors.textPrimary))),
                ..._empleados.map((e) => DropdownMenuItem(
                  value: e.cuil,
                  child: Text(e.nombreCompleto, style: const TextStyle(color: AppColors.textPrimary)),
                )),
              ],
              onChanged: (v) {
                setState(() => _filtroEmpleado = v);
                _filtrarPrestamos();
              },
            ),
          ),
          const SizedBox(width: 16),
          FilterChip(
            label: const Text('Solo Activos'),
            selected: _soloActivos,
            onSelected: (v) {
              setState(() => _soloActivos = v);
              _filtrarPrestamos();
            },
            backgroundColor: AppColors.glassFillStrong,
            selectedColor: AppColors.accentBlue.withOpacity(0.5),
            labelStyle: TextStyle(color: _soloActivos ? Colors.white : AppColors.textSecondary),
            checkmarkColor: Colors.white,
          ),
        ],
      ),
    );
  }

  Widget _buildEstadisticas() {
    final montoTotal = _filteredPrestamos.fold(0.0, (sum, p) => sum + p.montoTotal);
    final montoRestante = _filteredPrestamos.fold(0.0, (sum, p) => sum + p.montoRestante);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: AppColors.glassFillStrong,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildEstadistica('Activos', _filteredPrestamos.where((p) => p.estado == EstadoPrestamo.activo).length.toString(), Icons.hourglass_top_rounded, AppColors.loanActive),
          _buildEstadistica('Completados', _filteredPrestamos.where((p) => p.estado == EstadoPrestamo.pagado).length.toString(), Icons.check_circle_rounded, AppColors.loanPaid),
          _buildEstadistica('Prestado', '\$${(montoTotal / 1000).toStringAsFixed(1)}K', Icons.arrow_circle_up_rounded, AppColors.accentBlue),
          _buildEstadistica('Restante', '\$${(montoRestante / 1000).toStringAsFixed(1)}K', Icons.arrow_circle_down_rounded, AppColors.accentPink),
        ],
      ),
    );
  }

  Widget _buildEstadistica(String label, String valor, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(valor, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      ],
    );
  }
  
  Widget _buildListaHeader() {
    return Row(
      children: [
        const Icon(Icons.account_balance_wallet_outlined, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        const Text(
          'Préstamos Registrados',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        const Spacer(),
        Text(
          '${_filteredPrestamos.length} Mostrados',
          style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 32),
      decoration: BoxDecoration(
        color: AppColors.glassFill,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.money_off_csred_outlined, size: 64, color: AppColors.textMuted),
          SizedBox(height: 24),
          Text(
            'No hay préstamos',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          SizedBox(height: 8),
          Text(
            'No se encontraron préstamos que coincidan con los filtros seleccionados. \nIntenta ajustar tu búsqueda o crea un nuevo préstamo.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildPrestamoCard(Prestamo prestamo) {
    final empleado = _empleados.firstWhere(
      (e) => e.cuil == prestamo.empleadoCuil,
      orElse: () => EmpleadoCompleto.empty(cuil: prestamo.empleadoCuil),
    );

    final Color color;
    switch (prestamo.estado) {
      case EstadoPrestamo.activo:
        color = AppColors.loanActive;
        break;
      case EstadoPrestamo.pagado:
        color = AppColors.loanPaid;
        break;
      default:
        color = AppColors.loanCancelled;
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.glassFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.15),
          child: Icon(Icons.receipt_long, color: color, size: 22),
        ),
        title: Text(
          empleado.nombreCompleto,
          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 16),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(
            'Resta: \$${prestamo.montoRestante.toStringAsFixed(2)}',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
        ),
        trailing: Chip(
          label: Text(prestamo.estado.name.toUpperCase(), style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold)),
          backgroundColor: color.withOpacity(0.2),
          side: BorderSide(color: color.withOpacity(0.4)),
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20, top: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: prestamo.montoTotal > 0 ? prestamo.montoPagado / prestamo.montoTotal : 0,
                          backgroundColor: AppColors.glassFillStrong,
                          valueColor: AlwaysStoppedAnimation<Color>(color),
                          minHeight: 10,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${(prestamo.porcentajePagado).toStringAsFixed(1)}%',
                       style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 14)
                    )
                  ],
                ),
                const SizedBox(height: 20),
                _buildDetalleFila('Monto Otorgado:', '\$${prestamo.montoTotal.toStringAsFixed(2)}'),
                _buildDetalleFila('Cuotas Pagadas:', '${prestamo.cuotasPagadas} de ${prestamo.cantidadCuotas}'),
                _buildDetalleFila('Valor Cuota:', '\$${prestamo.valorCuota.toStringAsFixed(2)}'),
                const Divider(color: AppColors.glassBorder, height: 24),
                _buildDetalleFila('Monto Restante:', '\$${prestamo.montoRestante.toStringAsFixed(2)}', destacado: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetalleFila(String label, String valor, {bool destacado = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          Text(
            valor,
            style: TextStyle(
              color: destacado ? AppColors.accentBlue : AppColors.textPrimary,
              fontSize: 14,
              fontWeight: destacado ? FontWeight.bold : FontWeight.normal,
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
          empleadosFiltro: _filtroEmpleado != null 
              ? [_filtroEmpleado!] 
              : _empleados.map((e) => e.cuil).toList(),
          empresaCuit: widget.empresaCuit ?? '',
        ),
      ),
    );

    if (resultado == true && mounted) {
      _cargarDatos();
    }
  }
}

// Añadido a EmpleadoCompleto para manejar casos borde
extension EmptyEmpleado on EmpleadoCompleto {
  static EmpleadoCompleto empty({String cuil = 'N/A'}) => EmpleadoCompleto(
    cuil: cuil,
    nombreCompleto: 'Empleado no encontrado',
    fechaIngreso: DateTime.now(),
    categoria: '',
    provincia: '',
  );
}
