import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import '../models/empresa.dart';
import '../data/cct_argentina_completo.dart';
import '../models/cct_completo.dart';
import '../theme/app_colors.dart';
import '../utils/validadores.dart';
import '../data/rnos_docentes_data.dart';
import 'dart:ui';

class EmpleadoScreen extends StatefulWidget {
  final Empresa empresa;
  final Map<String, dynamic>? empleadoExistente; // Para edición

  const EmpleadoScreen({
    super.key,
    required this.empresa,
    this.empleadoExistente,
  });

  @override
  State<EmpleadoScreen> createState() => _EmpleadoScreenState();
}

class _EmpleadoScreenState extends State<EmpleadoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _apellidoController = TextEditingController();
  final _cuilController = TextEditingController();
  final _fechaIngresoController = TextEditingController();
  final _cargoController = TextEditingController();
  final _codigoRnosController = TextEditingController();
  final _cantidadFamiliaresController = TextEditingController();

  String? _convenioSeleccionadoId; // Convenio del empleado
  String? _categoriaSeleccionadaId;
  List<CCTCompleto> _conveniosEmpresa = [];
  List<CategoriaCCT> _categoriasDisponibles = [];
  bool _fueraDeConvenio = false;
  bool _inicializando = true; // Flag para evitar que el listener se ejecute durante initState

  @override
  void initState() {
    super.initState();
    
    // Cargar convenios primero
    _cargarConveniosEmpresa().then((_) {
      // Después de cargar convenios, cargar datos del empleado si estamos editando
      if (widget.empleadoExistente != null && mounted) {
        _cargarDatosEmpleado();
      }
      
      // Agregar listener para formatear CUIL después de la inicialización completa
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _inicializando = false;
        // Formatear CUIL inicial si existe (sin listener activo)
        if (_cuilController.text.isNotEmpty) {
          final text = _cuilController.text;
          final digitsOnly = text.replaceAll(RegExp(r'[^\d]'), '');
          if (digitsOnly.isNotEmpty && digitsOnly.length == 11) {
            final formatted = _formatearCUILTexto(digitsOnly);
            if (formatted != text) {
              _cuilController.value = TextEditingValue(
                text: formatted,
                selection: TextSelection.collapsed(offset: formatted.length),
              );
            }
          }
        }
        _cuilController.addListener(_formatearCUIL);
      });
    });
  }

  void _cargarDatosEmpleado() {
    if (widget.empleadoExistente == null) return;
    
    final empleado = widget.empleadoExistente!;
    final nombreCompleto = empleado['nombre']?.toString() ?? '';
    final partesNombre = nombreCompleto.split(' ');
    
    _nombreController.text = partesNombre.isNotEmpty ? partesNombre.first : '';
    _apellidoController.text = partesNombre.length > 1 
        ? partesNombre.sublist(1).join(' ') 
        : '';
    
    final cuil = empleado['cuil']?.toString() ?? '';
    if (cuil.isNotEmpty) {
      final digitsOnly = cuil.replaceAll(RegExp(r'[^\d]'), '');
      if (digitsOnly.length == 11) {
        _cuilController.text = _formatearCUILTexto(digitsOnly);
        
        // Validar CUIL al cargar y mostrar advertencia si es inválido
        if (!validarCUITCUIL(cuil)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('CUIL inválido: Verifique los dígitos'),
                  backgroundColor: Colors.red,
                  duration: Duration(seconds: 5),
                ),
              );
            }
          });
        }
      } else {
        _cuilController.text = cuil;
      }
    }
    
    final fechaIngreso = empleado['fechaIngreso']?.toString() ?? '';
    if (fechaIngreso.isNotEmpty) {
      try {
        // Intentar parsear la fecha en formato DD/MM/YYYY
        final fecha = DateFormat('dd/MM/yyyy').parse(fechaIngreso);
        _fechaIngresoController.text = DateFormat('dd/MM/yyyy').format(fecha);
      } catch (e) {
        _fechaIngresoController.text = fechaIngreso;
      }
    }
    _cargoController.text = empleado['cargo']?.toString() ?? '';
    _codigoRnosController.text = empleado['codigoRnos']?.toString() ?? '';
    _cantidadFamiliaresController.text = empleado['cantidadFamiliares']?.toString() ?? '0';
    
    final convenioId = empleado['convenioId']?.toString();
    if (convenioId != null && convenioId.isNotEmpty && convenioId != 'fuera_convenio') {
      // Cargar convenio y categoría después de que los convenios estén disponibles
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _cargarConvenioYCategoria(convenioId, empleado['categoriaId']?.toString());
      });
    } else {
      _convenioSeleccionadoId = null;
      _fueraDeConvenio = true;
    }
  }

  void _cargarConvenioYCategoria(String convenioId, String? categoriaId) {
    if (!mounted) return;
    
    try {
      CCTCompleto? convenio;
      
      // Buscar en convenios de la empresa primero
      try {
        convenio = _conveniosEmpresa.firstWhere((c) => c.id == convenioId);
      } catch (e) {
        // Si no está en los convenios de la empresa, buscar en todos
        try {
          convenio = cctArgentinaCompleto.firstWhere((c) => c.id == convenioId);
        } catch (e2) {
          // Convenio no encontrado
          convenio = null;
        }
      }
      
      if (convenio != null) {
        final categoriasConvenio = convenio.categorias;
        setState(() {
          _convenioSeleccionadoId = convenioId;
          _fueraDeConvenio = false;
          _categoriasDisponibles = categoriasConvenio;
          
          // Cargar categoría si existe
          if (categoriaId != null && categoriaId.isNotEmpty) {
            final categoriaExiste = categoriasConvenio.any((c) => c.id == categoriaId);
            if (categoriaExiste) {
              _categoriaSeleccionadaId = categoriaId;
            }
          }
        });
      } else {
        setState(() {
          _convenioSeleccionadoId = null;
          _fueraDeConvenio = true;
          _categoriasDisponibles = [];
        });
      }
    } catch (e) {
      // En caso de error, establecer valores por defecto
      if (mounted) {
        setState(() {
          _convenioSeleccionadoId = null;
          _fueraDeConvenio = true;
          _categoriasDisponibles = [];
        });
      }
    }
  }

  Future<void> _cargarConveniosEmpresa() async {
    final prefs = await SharedPreferences.getInstance();
    final razonSocial = widget.empresa.razonSocial;
    
    // Cargar convenios de la empresa
    final conveniosJson = prefs.getString('empresa_convenios_$razonSocial');
    List<String> conveniosIds = [];
    
    if (conveniosJson != null && conveniosJson.isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(conveniosJson);
        conveniosIds = List<String>.from(decoded)
            .where((id) => id != 'fuera_convenio')
            .toList();
      } catch (e) {
        // Formato antiguo: un solo convenio
        if (widget.empresa.convenioId.isNotEmpty && 
            widget.empresa.convenioId != 'No seleccionado') {
          conveniosIds = [widget.empresa.convenioId];
        }
      }
    } else if (widget.empresa.convenioId.isNotEmpty && 
               widget.empresa.convenioId != 'No seleccionado') {
      conveniosIds = [widget.empresa.convenioId];
    }
    
    setState(() {
      _conveniosEmpresa = cctArgentinaCompleto
          .where((c) => conveniosIds.contains(c.id))
          .toList();
    });
  }


  String _formatearCUILTexto(String cuil) {
    final digitsOnly = cuil.replaceAll(RegExp(r'[^\d]'), '');
    if (digitsOnly.length != 11) return cuil;
    return '${digitsOnly.substring(0, 2)}-${digitsOnly.substring(2, 10)}-${digitsOnly.substring(10)}';
  }

  void _formatearCUIL() {
    if (_inicializando) return;
    
    final text = _cuilController.text;
    final digitsOnly = text.replaceAll(RegExp(r'[^\d]'), '');
    
    if (digitsOnly.isEmpty) {
      _cuilController.value = const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
      return;
    }

    String formatted = '';
    if (digitsOnly.length <= 2) {
      formatted = digitsOnly;
    } else if (digitsOnly.length <= 10) {
      formatted = '${digitsOnly.substring(0, 2)}-${digitsOnly.substring(2)}';
    } else {
      formatted = '${digitsOnly.substring(0, 2)}-${digitsOnly.substring(2, 10)}-${digitsOnly.substring(10)}';
    }

    if (formatted != text) {
      final selectionOffset = formatted.length;
      _cuilController.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: selectionOffset),
      );
    }
  }

  void _mostrarBuscadorRNOS() {
    showDialog(
      context: context,
      builder: (context) {
        String query = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtered = CatalogoRNOS2026.lista.where((e) {
              final search = query.toLowerCase();
              return e.nombreCompleto.toLowerCase().contains(search) ||
                  e.sigla.toLowerCase().contains(search) ||
                  e.codigoArca.contains(search) ||
                  e.jurisdiccion.toLowerCase().contains(search);
            }).toList();

            return AlertDialog(
              backgroundColor: AppColors.backgroundLight,
              title: const Text('Buscador RNOS 2026', style: TextStyle(color: AppColors.textPrimary)),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      autofocus: true,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Buscar por nombre, sigla o provincia...',
                        hintStyle: const TextStyle(color: AppColors.textMuted),
                        prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
                        filled: true,
                        fillColor: AppColors.glassFill,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onChanged: (v) => setModalState(() => query = v),
                    ),
                    const SizedBox(height: 16),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: filtered.length,
                        itemBuilder: (context, i) {
                          final os = filtered[i];
                          return ListTile(
                            title: Text(os.nombreCompleto, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14)),
                            subtitle: Text('${os.sigla} | Código: ${os.codigoArca} | Aporte: ${os.porcentajeAporte}%', 
                              style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                            trailing: Text(os.jurisdiccion, style: const TextStyle(color: AppColors.pastelBlue, fontSize: 11)),
                            onTap: () {
                              setState(() {
                                _codigoRnosController.text = os.codigoArca;
                              });
                              Navigator.pop(context);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar')),
              ],
            );
          },
        );
      },
    );
  }

  void _onConvenioChanged(String? convenioId) {
    if (!mounted || _inicializando) return;
    
    setState(() {
      _convenioSeleccionadoId = convenioId;
      _categoriaSeleccionadaId = null;
      _fueraDeConvenio = convenioId == null;
      
      if (convenioId != null && !_fueraDeConvenio) {
        try {
          CCTCompleto? convenio;
          try {
            convenio = _conveniosEmpresa.firstWhere((c) => c.id == convenioId);
          } catch (e) {
            try {
              convenio = cctArgentinaCompleto.firstWhere((c) => c.id == convenioId);
            } catch (e2) {
              convenio = null;
            }
          }
          
          if (convenio != null) {
            _categoriasDisponibles = convenio.categorias;
          } else {
            _categoriasDisponibles = [];
          }
        } catch (e) {
          _categoriasDisponibles = [];
        }
      } else {
        _categoriasDisponibles = [];
      }
    });
  }

  Future<void> _guardarEmpleado() async {
    if (!_formKey.currentState!.validate()) return;

    String convenioNombre = 'Fuera de Convenio';
    if (!_fueraDeConvenio && _convenioSeleccionadoId != null) {
      try {
        final convenio = _conveniosEmpresa.firstWhere(
          (c) => c.id == _convenioSeleccionadoId,
        );
        convenioNombre = convenio.nombre;
      } catch (e) {
        try {
          final convenio = cctArgentinaCompleto.firstWhere(
            (c) => c.id == _convenioSeleccionadoId,
          );
          convenioNombre = convenio.nombre;
        } catch (e2) {
          convenioNombre = 'Fuera de Convenio';
        }
      }
    }
    
    String categoriaNombre = '';
    if (_categoriaSeleccionadaId != null && _categoriasDisponibles.isNotEmpty) {
      try {
        categoriaNombre = _categoriasDisponibles
            .firstWhere((c) => c.id == _categoriaSeleccionadaId)
            .nombre;
      } catch (e) {
        categoriaNombre = '';
      }
    }
    
    // Validar y obtener código RNOS (usar predeterminado si está vacío)
    String codigoRnos = _codigoRnosController.text.trim();
    bool mostrarAdvertenciaRnos = false;
    if (codigoRnos.isEmpty) {
      codigoRnos = '126205'; // OSECAC por defecto
      mostrarAdvertenciaRnos = true;
    }
    
    // Validar formato de código RNOS (6 dígitos)
    if (codigoRnos.length != 6 || !RegExp(r'^\d+$').hasMatch(codigoRnos)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('El código RNOS debe tener 6 dígitos numéricos'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }
    
    final cantidadFamiliares = int.tryParse(_cantidadFamiliaresController.text.trim()) ?? 0;
    
    // Validar CUIL matemáticamente antes de guardar
    final cuilLimpio = _cuilController.text.replaceAll('-', '').trim();
    if (!validarCUITCUIL(_cuilController.text)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('CUIL inválido: Verifique los dígitos. No se puede guardar el empleado.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
      }
      return; // No permitir guardar si el CUIL es inválido
    }
    
    final empleado = {
      'nombre': '${_nombreController.text.trim()} ${_apellidoController.text.trim()}',
      'apellido': _apellidoController.text.trim(),
      'cuil': cuilLimpio,
      'fechaIngreso': _fechaIngresoController.text.trim(),
      'cargo': _cargoController.text.trim(),
      'convenioId': _convenioSeleccionadoId ?? 'fuera_convenio',
      'convenioNombre': convenioNombre,
      'categoriaId': _categoriaSeleccionadaId ?? '',
      'categoriaNombre': categoriaNombre,
      'codigoRnos': codigoRnos,
      'cantidadFamiliares': cantidadFamiliares,
    };
    
    // Mostrar advertencia si se usó código predeterminado
    if (mostrarAdvertenciaRnos && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Se usó código RNOS predeterminado (126205 - OSECAC). Puede cambiarlo editando el empleado.'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 4),
        ),
      );
    }

    final prefs = await SharedPreferences.getInstance();
    final empleadosJson = prefs.getString('empleados_${widget.empresa.razonSocial}');
    List<dynamic> empleados = [];
    
    if (empleadosJson != null && empleadosJson.isNotEmpty) {
      try {
        empleados = jsonDecode(empleadosJson);
      } catch (e) {
        empleados = [];
      }
    }
    
    if (widget.empleadoExistente != null) {
      // Editar empleado existente
      final cuilOriginal = widget.empleadoExistente!['cuil']?.toString() ?? '';
      final index = empleados.indexWhere(
        (e) => e['cuil']?.toString() == cuilOriginal,
      );
      if (index != -1) {
        empleados[index] = empleado;
      }
    } else {
      // Agregar nuevo empleado
      empleados.add(empleado);
    }
    
    await prefs.setString(
      'empleados_${widget.empresa.razonSocial}',
      jsonEncode(empleados),
    );

    if (!mounted) return;
    
    // Preguntar si desea agregar más empleados
    final agregarMas = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.backgroundLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          widget.empleadoExistente != null 
              ? 'Empleado actualizado' 
              : 'Empleado guardado',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          widget.empleadoExistente != null
              ? 'El empleado ha sido actualizado correctamente.'
              : '¿Desea agregar otro empleado?',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'No',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.pastelBlue,
              foregroundColor: AppColors.background,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Sí'),
          ),
        ],
      ),
    );
    
    if (agregarMas == true) {
      // Limpiar formulario para agregar otro
      _formKey.currentState!.reset();
      _nombreController.clear();
      _apellidoController.clear();
      _cuilController.clear();
      _fechaIngresoController.clear();
      _cargoController.clear();
      setState(() {
        _convenioSeleccionadoId = null;
        _categoriaSeleccionadaId = null;
        _fueraDeConvenio = false;
        _categoriasDisponibles = [];
      });
    } else {
      // Volver a la pantalla anterior
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  @override
  @override
  void dispose() {
    _nombreController.dispose();
    _apellidoController.dispose();
    _cuilController.dispose();
    _fechaIngresoController.dispose();
    _cargoController.dispose();
    _codigoRnosController.dispose();
    _cantidadFamiliaresController.dispose();
    super.dispose();
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
          widget.empleadoExistente != null
              ? 'Editar Empleado'
              : widget.empresa.razonSocial,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.disabled,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _buildSeccion(
              'Datos del Empleado',
              Icons.person,
              [
                _buildTextField(
                  controller: _nombreController,
                  label: 'Nombre',
                  icon: Icons.person_outline,
                  validator: (value) =>
                      value == null || value.trim().isEmpty
                          ? 'Ingrese el nombre'
                          : null,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _apellidoController,
                  label: 'Apellido',
                  icon: Icons.person_outline,
                  validator: (value) =>
                      value == null || value.trim().isEmpty
                          ? 'Ingrese el apellido'
                          : null,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _cuilController,
                  label: 'CUIL',
                  icon: Icons.badge,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(13), // 11 dígitos + 2 guiones
                  ],
                  validator: (value) {
                    // Usar la función de validación matemática
                    return validarCUITCUILConMensaje(value);
                  },
                ),
                const SizedBox(height: 16),
                _buildDateField(
                  controller: _fechaIngresoController,
                  label: 'Fecha de Ingreso',
                  icon: Icons.calendar_today,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Ingrese la fecha de ingreso';
                    }
                    try {
                      final fecha = DateFormat('dd/MM/yyyy').parse(value);
                      final hoy = DateTime.now();
                      final edadMinima = DateTime(hoy.year - 18, hoy.month, hoy.day);
                      if (fecha.isAfter(edadMinima)) {
                        return 'El empleado debe ser mayor de 18 años';
                      }
                      return null;
                    } catch (e) {
                      return 'Fecha inválida (DD/MM/YYYY)';
                    }
                  },
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _cargoController,
                  label: 'Cargo',
                  icon: Icons.work_outline,
                  validator: (value) =>
                      value == null || value.trim().isEmpty
                          ? 'Ingrese el cargo'
                          : null,
                ),
                const SizedBox(height: 16),
                // Campo Código RNOS con buscador nacional
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildTextField(
                        controller: _codigoRnosController,
                        label: 'Código RNOS (6 dígitos)',
                        icon: Icons.local_hospital,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(6),
                        ],
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Ingrese el código RNOS';
                          }
                          if (value.trim().length != 6 || !RegExp(r'^\d+$').hasMatch(value.trim())) {
                            return 'Debe tener 6 dígitos numéricos';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: IconButton.filledTonal(
                        onPressed: _mostrarBuscadorRNOS,
                        icon: const Icon(Icons.search),
                        tooltip: 'Buscar en catálogo nacional',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Padding(
                  padding: EdgeInsets.only(left: 16),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: AppColors.textMuted),
                      SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Si no se especifica, se usará 126205 (OSECAC) por defecto',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _cantidadFamiliaresController,
                  label: 'Cantidad de Familiares a Cargo',
                  icon: Icons.family_restroom,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(2),
                  ],
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Ingrese la cantidad (0 si no tiene)';
                    }
                    final cantidad = int.tryParse(value.trim());
                    if (cantidad == null || cantidad < 0) {
                      return 'Debe ser un número mayor o igual a 0';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.pastelBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.pastelBlue.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: AppColors.pastelBlue, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '¿No encuentra el convenio que necesita? Puede añadirlo desde la ventana de Convenios.',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildSeccion(
              'Convenio y Categoría',
              Icons.work,
              [
                DropdownButtonFormField<String>(
                  key: ValueKey('convenio_${_convenioSeleccionadoId ?? 'null'}'),
                  initialValue: _convenioSeleccionadoId,
                  hint: const Text(
                    'Seleccionar convenio',
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                  dropdownColor: AppColors.backgroundLight,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.description, color: AppColors.textMuted),
                  ),
                  style: const TextStyle(color: AppColors.textPrimary),
                  onChanged: _onConvenioChanged,
                  items: [
                    // Opción "Fuera de Convenio"
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text(
                        'Fuera de Convenio',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    // Convenios de la empresa
                    ..._conveniosEmpresa.map((convenio) {
                      return DropdownMenuItem<String>(
                        value: convenio.id,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              convenio.nombre,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              'CCT ${convenio.numeroCCT}',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                  selectedItemBuilder: (BuildContext context) {
                    return [
                      const Text(
                        'Fuera de Convenio',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      ..._conveniosEmpresa.map<Widget>((convenio) {
                        return Text(
                          convenio.nombre,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        );
                      }),
                    ];
                  },
                ),
                if (_categoriasDisponibles.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    key: ValueKey('categoria_${_categoriaSeleccionadaId ?? 'null'}'),
                    initialValue: _categoriaSeleccionadaId,
                    hint: const Text(
                      'Seleccionar categoría',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                    dropdownColor: AppColors.backgroundLight,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.category, color: AppColors.textMuted),
                    ),
                    style: const TextStyle(color: AppColors.textPrimary),
                    onChanged: (String? newValue) {
                      setState(() {
                        _categoriaSeleccionadaId = newValue;
                      });
                    },
                    selectedItemBuilder: (BuildContext context) {
                      return _categoriasDisponibles.map<Widget>((categoria) {
                        return Text(
                          categoria.nombre,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        );
                      }).toList();
                    },
                    items: _categoriasDisponibles.map((categoria) {
                      return DropdownMenuItem<String>(
                        value: categoria.id,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              categoria.nombre,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (categoria.descripcion != null && categoria.descripcion!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  categoria.descripcion!,
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 11,
                                    fontStyle: FontStyle.italic,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            Text(
                              '\$${categoria.salarioBase.toStringAsFixed(0)}',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    validator: (value) =>
                        !_fueraDeConvenio && (value == null || value.isEmpty)
                            ? 'Seleccione una categoría'
                            : null,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _guardarEmpleado,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.pastelBlue,
                foregroundColor: AppColors.background,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.save, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    widget.empleadoExistente != null
                        ? 'Actualizar Empleado'
                        : 'Guardar Empleado',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeccion(String titulo, IconData icono, List<Widget> children) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.glassFillStrong,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.pastelBlue.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icono, color: AppColors.pastelBlue, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    titulo,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ...children,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.textMuted),
        prefixIcon: Icon(icon, color: AppColors.textMuted),
        filled: true,
        fillColor: AppColors.glassFill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.glassBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.pastelBlue, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.red.shade300),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.red.shade300, width: 2),
        ),
      ),
      validator: validator,
    );
  }
  
  Widget _buildDateField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.textMuted),
        prefixIcon: Icon(icon, color: AppColors.textMuted),
        suffixIcon: const Icon(Icons.calendar_today, color: AppColors.textMuted),
        filled: true,
        fillColor: AppColors.glassFill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.glassBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.pastelBlue, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.red.shade300),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.red.shade300, width: 2),
        ),
      ),
      validator: validator,
      onTap: () async {
        final hoy = DateTime.now();
        final fechaMaxima = DateTime(hoy.year - 18, hoy.month, hoy.day);
        
        final fechaSeleccionada = await showDatePicker(
          context: context,
          initialDate: fechaMaxima,
          firstDate: DateTime(1950),
          lastDate: fechaMaxima,
          locale: const Locale('es'),
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: const ColorScheme.light(
                  primary: AppColors.pastelBlue,
                  onPrimary: AppColors.background,
                  surface: AppColors.backgroundLight,
                  onSurface: AppColors.textPrimary,
                ),
              ),
              child: child!,
            );
          },
        );
        
        if (fechaSeleccionada != null) {
          controller.text = DateFormat('dd/MM/yyyy').format(fechaSeleccionada);
        }
      },
    );
  }
}
