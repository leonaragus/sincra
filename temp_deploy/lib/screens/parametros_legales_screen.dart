import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/parametros_legales.dart';
import '../utils/formatters.dart';
import '../services/parametros_legales_service.dart';
import '../theme/app_colors.dart';

/// Pantalla de administración para gestionar parámetros legales
/// Permite actualizar valores legales sin necesidad de reprogramar la aplicación
class ParametrosLegalesScreen extends StatefulWidget {
  const ParametrosLegalesScreen({super.key});

  @override
  State<ParametrosLegalesScreen> createState() => _ParametrosLegalesScreenState();
}

class _ParametrosLegalesScreenState extends State<ParametrosLegalesScreen> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _baseImponibleMaximaController;
  late TextEditingController _baseImponibleMinimaController;
  late TextEditingController _smvmController;
  late TextEditingController _asignacionHijoController;
  late TextEditingController _topeMovilidadF931Controller;
  late TextEditingController _vigenciaDesdeController;
  late TextEditingController _vigenciaHastaController;
  
  ParametrosLegales? _parametrosActuales;
  bool _cargando = true;
  bool _guardando = false;
  DateTime? _fechaUltimaActualizacion;

  @override
  void initState() {
    super.initState();
    _inicializarControladores();
    _cargarParametros();
  }

  void _inicializarControladores() {
    _baseImponibleMaximaController = TextEditingController();
    _baseImponibleMinimaController = TextEditingController();
    _smvmController = TextEditingController();
    _asignacionHijoController = TextEditingController();
    _topeMovilidadF931Controller = TextEditingController();
    _vigenciaDesdeController = TextEditingController();
    _vigenciaHastaController = TextEditingController();
  }

  Future<void> _cargarParametros() async {
    setState(() => _cargando = true);
    
    try {
      final parametros = await ParametrosLegalesService.cargarParametros();
      final fechaActualizacion = await ParametrosLegalesService.obtenerFechaUltimaActualizacion();
      
      setState(() {
        _parametrosActuales = parametros;
        _fechaUltimaActualizacion = fechaActualizacion;
        
        // Llenar controladores con valores actuales
        _baseImponibleMaximaController.text = parametros.baseImponibleMaxima.toStringAsFixed(2);
        _baseImponibleMinimaController.text = parametros.baseImponibleMinima.toStringAsFixed(2);
        _smvmController.text = parametros.smvm.toStringAsFixed(2);
        _asignacionHijoController.text = parametros.asignacionHijo.toStringAsFixed(2);
        _topeMovilidadF931Controller.text = parametros.topeMovilidadF931.toStringAsFixed(2);
        _vigenciaDesdeController.text = DateFormat('dd/MM/yyyy').format(parametros.vigenciaDesde);
        _vigenciaHastaController.text = DateFormat('dd/MM/yyyy').format(parametros.vigenciaHasta);
        
        _cargando = false;
      });
    } catch (e) {
      setState(() => _cargando = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar parámetros: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _guardarParametros() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _guardando = true);
    
    try {
      final baseImponibleMaxima = double.parse(_baseImponibleMaximaController.text);
      final baseImponibleMinima = double.parse(_baseImponibleMinimaController.text);
      final smvm = double.parse(_smvmController.text);
      final asignacionHijo = double.parse(_asignacionHijoController.text);
      final topeMovilidadF931 = double.parse(_topeMovilidadF931Controller.text);
      
      // Parsear fechas
      final vigenciaDesde = DateFormat('dd/MM/yyyy').parse(_vigenciaDesdeController.text);
      final vigenciaHasta = DateFormat('dd/MM/yyyy').parse(_vigenciaHastaController.text);
      
      // Validar que la fecha desde sea anterior a la fecha hasta
      if (vigenciaDesde.isAfter(vigenciaHasta)) {
        throw ArgumentError('La fecha de inicio debe ser anterior a la fecha de fin');
      }
      
      // Validar que base mínima sea menor que base máxima
      if (baseImponibleMinima >= baseImponibleMaxima) {
        throw ArgumentError('La base imponible mínima debe ser menor que la máxima');
      }
      
      final parametrosActualizados = _parametrosActuales!.copyWith(
        baseImponibleMaxima: baseImponibleMaxima,
        baseImponibleMinima: baseImponibleMinima,
        smvm: smvm,
        asignacionHijo: asignacionHijo,
        topeMovilidadF931: topeMovilidadF931,
        vigenciaDesde: vigenciaDesde,
        vigenciaHasta: vigenciaHasta,
        usuarioActualizacion: 'Usuario', // En producción, usar el usuario real
      );
      
      final exito = await ParametrosLegalesService.guardarParametros(parametrosActualizados);
      
      setState(() => _guardando = false);
      
      if (mounted) {
        if (exito) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Parámetros legales actualizados correctamente'),
              backgroundColor: Colors.green,
            ),
          );
          await _cargarParametros();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error al guardar parámetros'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _guardando = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _resetearAPorDefecto() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.backgroundLight,
        title: const Text('Resetear a valores por defecto'),
        content: const Text(
          '¿Está seguro de que desea resetear los parámetros a los valores por defecto del Q1 2026? '
          'Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Resetear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    
    if (confirmar == true) {
      setState(() => _guardando = true);
      
      try {
        final exito = await ParametrosLegalesService.resetearAPorDefecto();
        
        setState(() => _guardando = false);
        
        if (mounted) {
          if (exito) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Parámetros reseteados a valores por defecto'),
                backgroundColor: Colors.green,
              ),
            );
            await _cargarParametros();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Error al resetear parámetros'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } catch (e) {
        setState(() => _guardando = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _seleccionarFecha(TextEditingController controller) async {
    final fechaActual = controller.text.isNotEmpty
        ? DateFormat('dd/MM/yyyy').tryParse(controller.text)
        : DateTime.now();
    
    final fechaSeleccionada = await showDatePicker(
      context: context,
      initialDate: fechaActual ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      locale: const Locale('es', 'AR'),
    );
    
    if (fechaSeleccionada != null) {
      controller.text = DateFormat('dd/MM/yyyy').format(fechaSeleccionada);
    }
  }

  @override
  void dispose() {
    _baseImponibleMaximaController.dispose();
    _baseImponibleMinimaController.dispose();
    _smvmController.dispose();
    _asignacionHijoController.dispose();
    _topeMovilidadF931Controller.dispose();
    _vigenciaDesdeController.dispose();
    _vigenciaHastaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Configuración Legal'),
        backgroundColor: AppColors.backgroundLight,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Información de última actualización
                    if (_fechaUltimaActualizacion != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: AppColors.glassFill,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.glassBorder),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, color: AppColors.textSecondary, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Última actualización: ${DateFormat('dd/MM/yyyy HH:mm').format(_fechaUltimaActualizacion!)}',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    
                    // Título de sección
                    const Text(
                      'Parámetros Legales Vigentes',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Estos valores se utilizan para calcular las bases imponibles y validaciones legales.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Base Imponible Máxima
                    _buildTextField(
                      label: 'Base Imponible Máxima',
                      controller: _baseImponibleMaximaController,
                      hint: '2.500.000,00',
                      icon: Icons.trending_up,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Este campo es obligatorio';
                        }
                        final valor = double.tryParse(value);
                        if (valor == null || valor <= 0) {
                          return 'Debe ser un número positivo';
                        }
                        return null;
                      },
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Base Imponible Mínima
                    _buildTextField(
                      label: 'Base Imponible Mínima',
                      controller: _baseImponibleMinimaController,
                      hint: '85.000,00',
                      icon: Icons.trending_down,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Este campo es obligatorio';
                        }
                        final valor = double.tryParse(value);
                        if (valor == null || valor <= 0) {
                          return 'Debe ser un número positivo';
                        }
                        return null;
                      },
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // SMVM
                    _buildTextField(
                      label: 'Sueldo Mínimo Vital y Móvil (SMVM)',
                      controller: _smvmController,
                      hint: '750.000,00',
                      icon: Icons.attach_money,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Este campo es obligatorio';
                        }
                        final valor = double.tryParse(value);
                        if (valor == null || valor <= 0) {
                          return 'Debe ser un número positivo';
                        }
                        return null;
                      },
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Valor Asignación Familiar
                    _buildTextField(
                      label: 'Valor Asignación Familiar',
                      controller: _asignacionHijoController,
                      hint: '55.000,00',
                      icon: Icons.child_care,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Este campo es obligatorio';
                        }
                        final valor = double.tryParse(value);
                        if (valor == null || valor <= 0) {
                          return 'Debe ser un número positivo';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),
                    // Botón informativo para consultar valores oficiales
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.glassFill,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.glassBorder),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: AppColors.pastelBlue, size: 20),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Para consultar valores oficiales actualizados, visite el sitio de AFIP',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: () async {
                              final url = Uri.parse('https://www.afip.gob.ar');
                              if (await canLaunchUrl(url)) {
                                await launchUrl(url, mode: LaunchMode.externalApplication);
                                return;
                              }
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('No se pudo abrir el enlace'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            },
                            icon: const Icon(Icons.open_in_new, size: 16),
                            label: const Text(
                              'Consultar valores oficiales en ARCA',
                              style: TextStyle(fontSize: 12),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.pastelBlue,
                              foregroundColor: AppColors.background,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Tope Movilidad F.931
                    _buildTextField(
                      label: 'Tope Movilidad F.931',
                      controller: _topeMovilidadF931Controller,
                      hint: '2.500.000,00',
                      icon: Icons.account_balance,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Este campo es obligatorio';
                        }
                        final valor = double.tryParse(value);
                        if (valor == null || valor <= 0) {
                          return 'Debe ser un número positivo';
                        }
                        return null;
                      },
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Fechas de vigencia
                    const Text(
                      'Período de Vigencia',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Vigencia Desde
                    _buildDateField(
                      label: 'Vigencia Desde',
                      controller: _vigenciaDesdeController,
                      icon: Icons.calendar_today,
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Vigencia Hasta
                    _buildDateField(
                      label: 'Vigencia Hasta',
                      controller: _vigenciaHastaController,
                      icon: Icons.event,
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Botones de acción
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _guardando ? null : _resetearAPorDefecto,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              side: const BorderSide(color: AppColors.glassBorder),
                            ),
                            child: const Text('Resetear a Por Defecto'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _guardando ? null : _guardarParametros,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              backgroundColor: AppColors.pastelBlue,
                            ),
                            child: _guardando
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Text('Guardar Cambios'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.glassFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: TextFormField(
        controller: controller,
        style: const TextStyle(color: AppColors.textPrimary),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, color: AppColors.textSecondary),
          border: InputBorder.none,
          labelStyle: const TextStyle(color: AppColors.textSecondary),
          hintStyle: const TextStyle(color: AppColors.textMuted),
        ),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: inputFormatters ?? [AppNumberFormatter.inputFormatter(valorIndice: false)],
        validator: (v) => validator != null ? validator(v?.replaceAll(',', '.')) : null,
      ),
    );
  }

  Widget _buildDateField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.glassFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: TextFormField(
        controller: controller,
        style: const TextStyle(color: AppColors.textPrimary),
        readOnly: true,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: AppColors.textSecondary),
          border: InputBorder.none,
          labelStyle: const TextStyle(color: AppColors.textSecondary),
          suffixIcon: IconButton(
            icon: const Icon(Icons.calendar_today, color: AppColors.textSecondary),
            onPressed: () => _seleccionarFecha(controller),
          ),
        ),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Este campo es obligatorio';
          }
          final fecha = DateFormat('dd/MM/yyyy').tryParse(value);
          if (fecha == null) {
            return 'Fecha inválida';
          }
          return null;
        },
      ),
    );
  }
}
