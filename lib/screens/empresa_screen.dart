import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import '../theme/app_colors.dart';
import '../services/hybrid_store.dart';
import '../data/cct_argentina_completo.dart';
import '../models/cct_completo.dart';
import '../models/formato_recibo.dart';
import '../widgets/selector_formato_recibo_dialog.dart';
import '../utils/validadores.dart';
import '../data/rnos_docentes_data.dart';
import 'dart:ui';
import '../utils/app_help.dart';

class EmpresaScreen extends StatefulWidget {
  final String? razonSocial;
  final String? cuit;
  final String? domicilio;
  final String? convenio;
  final String? logoPath;
  final String? firmaPath;

  const EmpresaScreen({
    super.key,
    this.razonSocial,
    this.cuit,
    this.domicilio,
    this.convenio,
    this.logoPath,
    this.firmaPath,
  });

  @override
  State<EmpresaScreen> createState() => EmpresaScreenState();
}

class EmpresaScreenState extends State<EmpresaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _razonSocialController = TextEditingController();
  final _cuitController = TextEditingController();
  final _domicilioController = TextEditingController();
  final _codigoRnosController = TextEditingController();

  List<String> _conveniosSeleccionados = []; // Lista de IDs de convenios seleccionados
  String? _logoPath;
  String? _firmaPath;
  String? _formatoReciboId;
  List<CCTCompleto> _conveniosDisponibles = [];
  bool _inicializando = true; // Flag para evitar que el listener se ejecute durante initState

  @override
  void initState() {
    super.initState();
    
    // Cargar convenios primero, antes de cualquier otra cosa
    _conveniosDisponibles = List<CCTCompleto>.from(cctArgentinaCompleto);
    
    // Inicializar datos básicos
    if (widget.razonSocial != null) {
      _razonSocialController.text = widget.razonSocial!;
      _domicilioController.text = widget.domicilio ?? '';
      _logoPath = widget.logoPath == 'No disponible' ? null : widget.logoPath;
      _firmaPath = widget.firmaPath == 'No disponible' ? null : widget.firmaPath;
      
      // Establecer CUIT sin formato primero para evitar problemas con el listener
      final cuitSinFormato = widget.cuit?.replaceAll('-', '') ?? '';
      if (cuitSinFormato.isNotEmpty) {
        _cuitController.text = cuitSinFormato;
      }
      
      // Cargar convenios seleccionados guardados
      _cargarConveniosSeleccionados();
    } else {
      _formatoReciboId = 'clasico_lct';
    }
    
    // Cargar formato de recibo de forma asíncrona
    _cargarFormatoRecibo();
    
    // Agregar listener después del primer frame para evitar problemas
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _inicializando = false;
      // Formatear CUIT una vez después de la inicialización, pero sin listener activo
      if (_cuitController.text.isNotEmpty && widget.razonSocial != null) {
        final text = _cuitController.text;
        final digitsOnly = text.replaceAll(RegExp(r'[^\d]'), '');
        if (digitsOnly.isNotEmpty && digitsOnly.length >= 2) {
          String formatted = '';
          if (digitsOnly.length <= 2) {
            formatted = digitsOnly;
          } else if (digitsOnly.length <= 10) {
            formatted = '${digitsOnly.substring(0, 2)}-${digitsOnly.substring(2)}';
          } else {
            formatted = '${digitsOnly.substring(0, 2)}-${digitsOnly.substring(2, 10)}-${digitsOnly.substring(10)}';
          }
          if (formatted != text) {
            _cuitController.value = TextEditingValue(
              text: formatted,
              selection: TextSelection.collapsed(offset: formatted.length),
            );
          }
        }
      }
      // Agregar listener después de formatear
      _cuitController.addListener(_formatearCUIT);
    });
  }

  Future<void> _cargarCodigoRnos() async {
    if (widget.razonSocial == null) return;
    try {
      final empresas = await HybridStore.getEmpresas();
      for (final emp in empresas) {
        if (emp['razonSocial'] == widget.razonSocial) {
          final codigo = emp['codigo_rnos']?.toString();
          if (codigo != null && codigo.isNotEmpty) {
            _codigoRnosController.text = codigo;
          }
          break;
        }
      }
    } catch (_) {}
  }

  Future<void> _cargarConveniosSeleccionados() async {
    if (widget.razonSocial == null) return;
    
    final prefs = await SharedPreferences.getInstance();
    final conveniosJson = prefs.getString('empresa_convenios_${widget.razonSocial}');
    
    if (conveniosJson != null && conveniosJson.isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(conveniosJson);
        setState(() {
          _conveniosSeleccionados = List<String>.from(decoded);
        });
        return;
      } catch (e) {
        // Si falla el JSON, intentar formato antiguo (string simple)
      }
    }
    
    // Formato antiguo: un solo convenio
    if (widget.convenio != null && 
        widget.convenio!.isNotEmpty && 
        widget.convenio! != 'No seleccionado' &&
        widget.convenio! != 'No disponible') {
      for (final convenio in _conveniosDisponibles) {
        if (convenio.id == widget.convenio || convenio.nombre == widget.convenio) {
          setState(() {
            _conveniosSeleccionados = [convenio.id];
          });
          break;
        }
      }
    }
  }

  Future<void> _cargarFormatoRecibo() async {
    if (widget.razonSocial == null) {
      _formatoReciboId = 'clasico_lct';
      return;
    }
    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    // Intentar cargar desde la key específica
    final formatoId = prefs.getString('empresa_formato_${widget.razonSocial}');
    if (formatoId != null && formatoId.isNotEmpty) {
      if (mounted) {
        setState(() {
          _formatoReciboId = formatoId;
        });
      }
      return;
    }
    final empresas = await HybridStore.getEmpresas();
    final idx = empresas.indexWhere((e) => e['razonSocial'] == widget.razonSocial);
    if (idx >= 0) {
      final fr = empresas[idx]['formatoRecibo'] ?? '';
      if (fr.isNotEmpty && fr != 'No disponible' && mounted) {
        setState(() => _formatoReciboId = fr);
      } else {
        _formatoReciboId = 'clasico_lct';
      }
    } else {
      _formatoReciboId = 'clasico_lct';
    }
  }


  void _formatearCUIT() {
    // No formatear durante la inicialización
    if (_inicializando) return;
    
    final text = _cuitController.text;
    final digitsOnly = text.replaceAll(RegExp(r'[^\d]'), '');
    
    if (digitsOnly.length > 11) {
      _cuitController.value = TextEditingValue(
        text: digitsOnly.substring(0, 11),
        selection: const TextSelection.collapsed(offset: 13),
      );
      return;
    }

    String formatted = '';
    if (digitsOnly.isNotEmpty) {
      if (digitsOnly.length <= 2) {
        formatted = digitsOnly;
      } else if (digitsOnly.length <= 10) {
        formatted = '${digitsOnly.substring(0, 2)}-${digitsOnly.substring(2)}';
      } else {
        formatted =
            '${digitsOnly.substring(0, 2)}-${digitsOnly.substring(2, 10)}-${digitsOnly.substring(10)}';
      }
    }

    if (formatted != text) {
      final selectionOffset = formatted.length;
      _cuitController.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: selectionOffset),
      );
    }
  }

  void _mostrarAyuda() {
    final helpContent = AppHelp.getHelpContent('EmpresaScreen');
    AppHelp.showHelpDialog(
      context,
      helpContent['title']!,
      helpContent['content']!,
    );
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

  Future<void> _guardarEmpresa() async {
    if (!_formKey.currentState!.validate()) return;

    final prefs = await SharedPreferences.getInstance();
    final List<Map<String, String>> empresas = await HybridStore.getEmpresas();

    final primerConvenio = _conveniosSeleccionados.isNotEmpty
        ? _conveniosSeleccionados.first
        : 'No seleccionado';

    final mapa = <String, String>{
      'razonSocial': _razonSocialController.text.trim(),
      'cuit': _cuitController.text.trim(),
      'domicilio': _domicilioController.text.trim(),
      'codigo_rnos': _codigoRnosController.text.trim().isEmpty ? '' : _codigoRnosController.text.trim(),
      'convenio': primerConvenio,
      'logoPath': _logoPath ?? 'No disponible',
      'firmaPath': _firmaPath ?? 'No disponible',
      'formatoRecibo': _formatoReciboId ?? 'clasico_lct',
    };

    final i = empresas.indexWhere((e) => e['razonSocial'] == widget.razonSocial);
    if (i >= 0) {
      empresas[i] = mapa;
    } else {
      empresas.add(mapa);
    }
    await HybridStore.saveEmpresas(empresas);

    // Guardar lista de convenios seleccionados (excluyendo 'fuera_convenio' del formato antiguo)
    final razonSocial = _razonSocialController.text.trim();
    final conveniosParaGuardar = _conveniosSeleccionados
        .where((id) => id != 'fuera_convenio')
        .toList();
    
    if (conveniosParaGuardar.isNotEmpty || _conveniosSeleccionados.contains('fuera_convenio')) {
      await prefs.setString(
        'empresa_convenios_$razonSocial',
        jsonEncode(_conveniosSeleccionados),
      );
    } else {
      await prefs.remove('empresa_convenios_$razonSocial');
    }

    // Guardar formato de recibo por separado para fácil acceso
    if (_formatoReciboId != null) {
      await prefs.setString(
        'empresa_formato_$razonSocial',
        _formatoReciboId!,
      );
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.razonSocial != null
              ? 'Empresa actualizada correctamente'
              : 'Empresa creada correctamente',
        ),
        backgroundColor: AppColors.glassFillStrong,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  Future<void> _elegirImagen(bool esFirma) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.backgroundLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: AppColors.textMuted,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: AppColors.pastelBlue),
              title: const Text(
                'Galería',
                style: TextStyle(color: AppColors.textPrimary),
              ),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: AppColors.pastelOrange),
              title: const Text(
                'Cámara',
                style: TextStyle(color: AppColors.textPrimary),
              ),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    final picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(source: source);

    if (pickedFile != null) {
      setState(() {
        if (esFirma) {
          _firmaPath = pickedFile.path;
        } else {
          _logoPath = pickedFile.path;
        }
      });
    }
  }

  void _eliminarImagen(bool esFirma) {
    setState(() {
      if (esFirma) {
        _firmaPath = null;
      } else {
        _logoPath = null;
      }
    });
  }

  Future<void> _abrirSelectorFormato() async {
    final formatoSeleccionado = await showDialog<String>(
      context: context,
      barrierColor: const Color.fromRGBO(0, 0, 0, 0.5),
      builder: (context) => SelectorFormatoReciboDialog(
        formatoActual: _formatoReciboId,
      ),
    );

    if (formatoSeleccionado != null) {
      setState(() {
        _formatoReciboId = formatoSeleccionado;
      });
    }
  }

  @override
  void dispose() {
    _razonSocialController.dispose();
    _cuitController.removeListener(_formatearCUIT);
    _cuitController.dispose();
    _domicilioController.dispose();
    _codigoRnosController.dispose();
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
          widget.razonSocial != null ? 'Editar Empresa' : 'Nueva Empresa',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
              ),
              child: const Icon(Icons.help_outline, color: AppColors.primary, size: 20),
            ),
            tooltip: 'Ayuda',
            onPressed: _mostrarAyuda,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.disabled, // Deshabilitar validación automática
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _buildSeccion(
              'Información Básica',
              Icons.business_center,
              [
                _buildTextField(
                  controller: _razonSocialController,
                  label: 'Razón Social',
                  icon: Icons.business,
                  validator: (value) =>
                      value == null || value.trim().isEmpty
                          ? 'Ingrese la razón social'
                          : null,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _cuitController,
                  label: 'CUIT',
                  icon: Icons.badge,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(11),
                  ],
                  validator: (value) {
                    // Usar la función de validación matemática
                    return validarCUITCUILConMensaje(value);
                  },
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _domicilioController,
                  label: 'Domicilio legal (calle/numero/ciudad)',
                  icon: Icons.location_on,
                  validator: (value) =>
                      value == null || value.trim().isEmpty
                          ? 'Ingrese el domicilio legal en formato: calle/numero/ciudad'
                          : null,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        controller: _codigoRnosController,
                        label: 'Código RNOS (obra social)',
                        icon: Icons.medical_services,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      onPressed: _mostrarBuscadorRNOS,
                      icon: const Icon(Icons.search),
                      tooltip: 'Buscar en catálogo nacional',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.pastelBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.pastelBlue.withOpacity(0.3),
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
              'Convenios Colectivos',
              Icons.description,
              [
                const Text(
                  'Selecciona los convenios que aplican en tu empresa (puedes elegir varios)',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 12),
                // Opción "Fuera de Convenio"
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: _conveniosSeleccionados.contains('fuera_convenio')
                        ? AppColors.pastelBlue.withValues(alpha: 0.15)
                        : AppColors.glassFill,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _conveniosSeleccionados.contains('fuera_convenio')
                          ? AppColors.pastelBlue
                          : AppColors.glassBorder,
                      width: _conveniosSeleccionados.contains('fuera_convenio') ? 2 : 1,
                    ),
                  ),
                  child: CheckboxListTile(
                    value: _conveniosSeleccionados.contains('fuera_convenio'),
                    onChanged: (bool? value) {
                      setState(() {
                        if (value == true) {
                          if (!_conveniosSeleccionados.contains('fuera_convenio')) {
                            _conveniosSeleccionados.add('fuera_convenio');
                          }
                        } else {
                          _conveniosSeleccionados.remove('fuera_convenio');
                        }
                      });
                    },
                    title: const Text(
                      'Fuera de Convenio',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: const Text(
                      'Para empleados sin convenio colectivo',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    activeColor: AppColors.pastelBlue,
                    checkColor: AppColors.background,
                  ),
                ),
                Container(
                  constraints: const BoxConstraints(maxHeight: 300),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _conveniosDisponibles.length,
                    itemBuilder: (context, index) {
                      final convenio = _conveniosDisponibles[index];
                      final estaSeleccionado = _conveniosSeleccionados.contains(convenio.id);
                      
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: estaSeleccionado 
                              ? AppColors.pastelBlue.withValues(alpha: 0.15)
                              : AppColors.glassFill,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: estaSeleccionado 
                                ? AppColors.pastelBlue 
                                : AppColors.glassBorder,
                            width: estaSeleccionado ? 2 : 1,
                          ),
                        ),
                        child: CheckboxListTile(
                          value: estaSeleccionado,
                          onChanged: (bool? value) {
                            setState(() {
                              if (value == true) {
                                if (!_conveniosSeleccionados.contains(convenio.id)) {
                                  _conveniosSeleccionados.add(convenio.id);
                                }
                              } else {
                                _conveniosSeleccionados.remove(convenio.id);
                              }
                            });
                          },
                          title: Text(
                            convenio.nombre,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            'CCT ${convenio.numeroCCT}',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          activeColor: AppColors.pastelBlue,
                          checkColor: AppColors.background,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildSeccion(
              'Logo de la Empresa',
              Icons.image,
              [
                _buildImageSelector(
                  path: _logoPath,
                  onTap: () => _elegirImagen(false),
                  onDelete: () => _eliminarImagen(false),
                  hintText: 'Toca para seleccionar logo',
                  subText: 'Galería o Cámara',
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildSeccion(
              'Firma Digital / Sello',
              Icons.draw,
              [
                _buildImageSelector(
                  path: _firmaPath,
                  onTap: () => _elegirImagen(true),
                  onDelete: () => _eliminarImagen(true),
                  hintText: 'Toca para seleccionar firma o sello',
                  subText: 'Galería o Cámara',
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildSeccion(
              'Formato de Recibo',
              Icons.receipt_long,
              [
                GestureDetector(
                  onTap: _abrirSelectorFormato,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.glassFillStrong,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.glassBorder),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.pastelBlue.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.receipt_long,
                                color: AppColors.pastelBlue,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _formatoReciboId != null
                                        ? FormatoRecibo.obtenerPorId(_formatoReciboId!)?.nombre ?? 'No seleccionado'
                                        : 'No seleccionado',
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _formatoReciboId != null
                                        ? FormatoRecibo.obtenerPorId(_formatoReciboId!)?.descripcion ?? 'Selecciona un formato'
                                        : 'Toca para seleccionar formato de recibo',
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 13,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.arrow_forward_ios,
                              color: AppColors.textSecondary,
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _guardarEmpresa,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.pastelBlue,
                foregroundColor: AppColors.background,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(16)),
                ),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.save, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    widget.razonSocial != null ? 'Actualizar Empresa' : 'Crear Empresa',
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

  Widget _buildImageSelector({
    required String? path,
    required VoidCallback onTap,
    required VoidCallback onDelete,
    required String hintText,
    required String subText,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.glassFillStrong,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: path == null
                ? Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: const BoxDecoration(
                          color: AppColors.glassFill,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.add_photo_alternate,
                          color: AppColors.pastelBlue,
                          size: 48,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        hintText,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subText,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  )
                : Stack(
                    children: [
                      Center(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: _buildSafeImageFile(path, height: 150),
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: GestureDetector(
                          onTap: onDelete,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.background.withValues(alpha: 0.8),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              color: AppColors.textPrimary,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
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

  Widget _buildSafeImageFile(String path, {double? height}) {
    final file = File(path);
    if (!file.existsSync()) {
      return Container(
        height: height ?? 150,
        decoration: BoxDecoration(
          color: AppColors.glassFill,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Icon(
            Icons.broken_image,
            color: AppColors.textSecondary,
            size: 48,
          ),
        ),
      );
    }
    
    return Image.file(
      file,
      height: height,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          height: height ?? 150,
          decoration: BoxDecoration(
            color: AppColors.glassFill,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Center(
            child: Icon(
              Icons.broken_image,
              color: AppColors.textSecondary,
              size: 48,
            ),
          ),
        );
      },
    );
  }
}
