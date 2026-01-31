import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'dart:io';
import '../models/empresa.dart';
import '../theme/app_colors.dart';
import 'empleado_screen.dart';

class ListaEmpleadosScreen extends StatefulWidget {
  final Empresa empresa;

  const ListaEmpleadosScreen({super.key, required this.empresa});

  @override
  State<ListaEmpleadosScreen> createState() => _ListaEmpleadosScreenState();
}

class _ListaEmpleadosScreenState extends State<ListaEmpleadosScreen> {
  List<Map<String, dynamic>> _empleados = [];

  @override
  void initState() {
    super.initState();
    _cargarEmpleados();
  }

  Future<void> _cargarEmpleados() async {
    final prefs = await SharedPreferences.getInstance();
    final empleadosJson = prefs.getString('empleados_${widget.empresa.razonSocial}');
    
    if (empleadosJson != null && empleadosJson.isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(empleadosJson);
        setState(() {
          _empleados = List<Map<String, dynamic>>.from(
            decoded.map((e) => Map<String, dynamic>.from(e)),
          );
        });
      } catch (e) {
        setState(() {
          _empleados = [];
        });
      }
    } else {
      setState(() {
        _empleados = [];
      });
    }
  }

  Future<void> _eliminarEmpleado(int index) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.backgroundLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text(
          'Confirmar eliminación',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          '¿Está seguro de eliminar a ${_empleados[index]['nombre']}?',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmado == true) {
      final prefs = await SharedPreferences.getInstance();
      _empleados.removeAt(index);
      await prefs.setString(
        'empleados_${widget.empresa.razonSocial}',
        jsonEncode(_empleados),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Empleado eliminado correctamente'),
          backgroundColor: AppColors.glassFillStrong,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      );
      _cargarEmpleados();
    }
  }

  String _formatearCUIL(String cuil) {
    final digitsOnly = cuil.replaceAll(RegExp(r'[^\d]'), '');
    if (digitsOnly.length != 11) return cuil;
    return '${digitsOnly.substring(0, 2)}-${digitsOnly.substring(2, 10)}-${digitsOnly.substring(10)}';
  }
  
  Future<void> _mostrarHistorialRecibos(Map<String, dynamic> empleado) async {
    final prefs = await SharedPreferences.getInstance();
    final cuil = empleado['cuil']?.toString() ?? '';
    final recibosJson = prefs.getString('recibos_$cuil');
    
    List<Map<String, dynamic>> recibos = [];
    if (recibosJson != null && recibosJson.isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(recibosJson);
        recibos = List<Map<String, dynamic>>.from(
          decoded.map((e) => Map<String, dynamic>.from(e)),
        );
        // Ordenar por fecha descendente
        recibos.sort((a, b) {
          final fechaA = a['fechaGeneracion']?.toString() ?? '';
          final fechaB = b['fechaGeneracion']?.toString() ?? '';
          return fechaB.compareTo(fechaA);
        });
      } catch (e) {
        recibos = [];
      }
    }
    
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.backgroundLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            const Icon(Icons.history, color: AppColors.pastelBlue),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Historial de Recibos - ${empleado['nombre'] ?? 'Empleado'}',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: recibos.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.receipt_long,
                          size: 48,
                          color: AppColors.textMuted,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No hay recibos generados',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: recibos.length,
                  itemBuilder: (context, index) {
                    final recibo = recibos[index];
                    String fechaFormateada = '';
                    try {
                      final fechaIso = recibo['fechaGeneracion']?.toString() ?? '';
                      if (fechaIso.isNotEmpty) {
                        final fecha = DateTime.parse(fechaIso);
                        fechaFormateada = DateFormat('dd/MM/yyyy HH:mm').format(fecha);
                      }
                    } catch (e) {
                      fechaFormateada = recibo['fechaGeneracion']?.toString() ?? '';
                    }
                    final periodo = recibo['periodo']?.toString() ?? '';
                    final ruta = recibo['ruta']?.toString() ?? '';
                    final sueldoNeto = recibo['sueldoNeto'] ?? 0.0;
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: AppColors.glassFill,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.glassBorder),
                      ),
                      child: ListTile(
                        leading: const Icon(
                          Icons.picture_as_pdf,
                          color: AppColors.pastelOrange,
                        ),
                        title: Text(
                          'Período: $periodo',
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Fecha: $fechaFormateada',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                            if (sueldoNeto > 0)
                              Text(
                                'Neto: \$${(sueldoNeto as num).toStringAsFixed(2)}',
                                style: const TextStyle(
                                  color: AppColors.pastelOrange,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(
                            Icons.download,
                            color: AppColors.pastelBlue,
                          ),
                          onPressed: () {
                            if (ruta.isNotEmpty && File(ruta).existsSync()) {
                              OpenFile.open(ruta);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('El archivo no existe'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          },
                        ),
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cerrar',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
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
        title: Text(
          'Empleados - ${widget.empresa.razonSocial}',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.pastelBlue.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.pastelBlue),
              ),
              child: const Icon(Icons.add, color: AppColors.pastelBlue),
            ),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EmpleadoScreen(
                    empresa: widget.empresa,
                  ),
                ),
              );
              if (result == true || result == null) {
                _cargarEmpleados();
              }
            },
          ),
        ],
      ),
      body: _empleados.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: const BoxDecoration(
                      color: AppColors.glassFillStrong,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.people_outline,
                      size: 64,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'No hay empleados cargados',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Toca el botón + para agregar empleados',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: _empleados.length,
              itemBuilder: (context, index) {
                final empleado = _empleados[index];
                final cuilFormateado = _formatearCUIL(empleado['cuil']?.toString() ?? '');
                
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppColors.glassFillStrong,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.glassBorder),
                  ),
                  child: InkWell(
                    onTap: () => _mostrarHistorialRecibos(empleado),
                    borderRadius: BorderRadius.circular(16),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      leading: CircleAvatar(
                        backgroundColor: AppColors.pastelBlue.withValues(alpha: 0.2),
                        child: Text(
                          empleado['nombre']?.toString().substring(0, 1).toUpperCase() ?? '?',
                          style: const TextStyle(
                            color: AppColors.pastelBlue,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        empleado['nombre']?.toString() ?? 'Sin nombre',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (cuilFormateado.isNotEmpty)
                            Text(
                              'CUIL: $cuilFormateado',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          if (empleado['cargo']?.toString().isNotEmpty ?? false)
                            Text(
                              'Cargo: ${empleado['cargo']}',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          if (empleado['convenioNombre']?.toString().isNotEmpty ?? false)
                            Text(
                              'Convenio: ${empleado['convenioNombre']}',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.history,
                              color: AppColors.pastelOrange,
                              size: 20,
                            ),
                            onPressed: () => _mostrarHistorialRecibos(empleado),
                            tooltip: 'Ver histórico de recibos',
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.edit,
                              color: AppColors.pastelBlue,
                              size: 20,
                            ),
                            onPressed: () async {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => EmpleadoScreen(
                                    empresa: widget.empresa,
                                    empleadoExistente: empleado,
                                  ),
                                ),
                              );
                              if (result == true || result == null) {
                                _cargarEmpleados();
                              }
                            },
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete,
                              color: Colors.red,
                              size: 20,
                            ),
                            onPressed: () => _eliminarEmpleado(index),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
