// Formulario Crear/Editar legajo sanidad — mismo formato que LegajoDocenteFormScreen / EmpleadoScreen

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../services/instituciones_service.dart';
import '../data/rnos_docentes_data.dart';
import '../services/sanidad_omni_engine.dart';
import '../theme/app_colors.dart';

class LegajoSanidadFormScreen extends StatefulWidget {
  final String cuitInstitucion;
  final Map<String, dynamic>? legajoExistente;

  const LegajoSanidadFormScreen({super.key, required this.cuitInstitucion, this.legajoExistente});

  @override
  State<LegajoSanidadFormScreen> createState() => _LegajoSanidadFormScreenState();
}

class _LegajoSanidadFormScreenState extends State<LegajoSanidadFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _cuilController = TextEditingController();
  final _puestoController = TextEditingController(); // Puesto/Cargo específico
  final _cantidadFamiliaresController = TextEditingController(text: '0');
  final _horasNocturnasController = TextEditingController(text: '0');
  final _codigoRnosController = TextEditingController();

  CategoriaSanidad _categoria = CategoriaSanidad.profesional;
  NivelTituloSanidad _nivelTitulo = NivelTituloSanidad.sinTitulo;
  bool _tareaCriticaRiesgo = false;
  bool _cuotaSindicalAtsa = false;
  bool _manejoEfectivoCaja = false;
  DateTime _fechaIngreso = DateTime.now().subtract(const Duration(days: 365 * 5));

  @override
  void initState() {
    super.initState();
    if (widget.legajoExistente != null) {
      final l = widget.legajoExistente!;
      _nombreController.text = l['nombre']?.toString() ?? '';
      _cuilController.text = l['cuil']?.toString() ?? '';
      _puestoController.text = l['puesto']?.toString() ?? ''; // Cargar puesto
      _cantidadFamiliaresController.text = (l['cantidadFamiliares'] is int ? l['cantidadFamiliares'] as int : int.tryParse(l['cantidadFamiliares']?.toString() ?? '') ?? 0).toString();
      _horasNocturnasController.text = (l['horasNocturnas'] is int ? l['horasNocturnas'] as int : int.tryParse(l['horasNocturnas']?.toString() ?? '') ?? 0).toString();
      _codigoRnosController.text = l['codigoRnos']?.toString() ?? '';
      final fi = l['fechaIngreso']?.toString();
      if (fi != null && fi.isNotEmpty) {
        final d = DateTime.tryParse(fi);
        if (d != null) _fechaIngreso = d;
      }
      final cat = l['categoria']?.toString();
      if (cat != null) _categoria = CategoriaSanidad.values.cast<CategoriaSanidad?>().firstWhere((e) => e?.name == cat, orElse: () => CategoriaSanidad.profesional) ?? CategoriaSanidad.profesional;
      final nt = l['nivelTitulo']?.toString();
      if (nt != null) _nivelTitulo = NivelTituloSanidad.values.cast<NivelTituloSanidad?>().firstWhere((e) => e?.name == nt, orElse: () => NivelTituloSanidad.sinTitulo) ?? NivelTituloSanidad.sinTitulo;
      _tareaCriticaRiesgo = l['tareaCriticaRiesgo'] == true;
      _cuotaSindicalAtsa = l['cuotaSindicalAtsa'] == true;
      _manejoEfectivoCaja = l['manejoEfectivoCaja'] == true;
    }
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _cuilController.dispose();
    _puestoController.dispose();
    _cantidadFamiliaresController.dispose();
    _horasNocturnasController.dispose();
    _codigoRnosController.dispose();
    super.dispose();
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

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    final cuil = _cuilController.text.replaceAll(RegExp(r'[^\d]'), '');
    if (cuil.length != 11) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('CUIL debe tener 11 dígitos')));
      return;
    }
    try {
      await InstitucionesService.saveLegajoSanidad(widget.cuitInstitucion, {
        'nombre': _nombreController.text.trim(),
        'cuil': _cuilController.text.trim(),
        'fechaIngreso': DateFormat('yyyy-MM-dd').format(_fechaIngreso),
        'categoria': _categoria.name,
        'nivelTitulo': _nivelTitulo.name,
        'tareaCriticaRiesgo': _tareaCriticaRiesgo,
        'cuotaSindicalAtsa': _cuotaSindicalAtsa,
        'manejoEfectivoCaja': _manejoEfectivoCaja,
        'horasNocturnas': int.tryParse(_horasNocturnasController.text) ?? 0,
        'cantidadFamiliares': int.tryParse(_cantidadFamiliaresController.text) ?? 0,
        'codigoRnos': _codigoRnosController.text.trim().isEmpty ? null : _codigoRnosController.text.trim(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(widget.legajoExistente != null ? 'Legajo actualizado' : 'Legajo guardado'),
        backgroundColor: AppColors.glassFillStrong,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ));
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  InputDecoration _dropdownDecoration(String label, IconData icon) => InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.textMuted),
        prefixIcon: Icon(icon, color: AppColors.textMuted),
        filled: true,
        fillColor: AppColors.glassFill,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.glassBorder)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.pastelBlue, width: 2)),
      );

  @override
  Widget build(BuildContext context) {
    final esEdicion = widget.legajoExistente != null;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.glassFillStrong, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.glassBorder)), child: const Icon(Icons.arrow_back, color: AppColors.textPrimary)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(esEdicion ? 'Editar Legajo' : 'Nuevo Legajo', style: const TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _buildSeccion('Datos personales', Icons.person, [
              _buildTextField(controller: _nombreController, label: 'Nombre y Apellido', icon: Icons.person, validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingrese el nombre' : null),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _cuilController,
                label: 'CUIL',
                icon: Icons.badge,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(11)],
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Ingrese el CUIL';
                  return (v.replaceAll(RegExp(r'[^\d]'), '').length != 11) ? '11 dígitos' : null;
                },
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _puestoController, 
                label: 'Puesto / Cargo (ej: Enfermero, Camillero...)', 
                icon: Icons.work_outline,
              ),
              const Padding(
                padding: EdgeInsets.only(left: 16, top: 4),
                child: Text(
                  'El puesto aparece en el recibo de sueldo',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                ),
              ),
            ]),
            const SizedBox(height: 24),
            _buildSeccion('Categoría y título', Icons.work, [
              DropdownButtonFormField<CategoriaSanidad>(
                initialValue: _categoria,
                decoration: _dropdownDecoration('Categoría', Icons.medical_services),
                dropdownColor: AppColors.backgroundLight,
                style: const TextStyle(color: AppColors.textPrimary),
                items: SanidadNomenclador2026.items.map((e) => DropdownMenuItem(value: e.categoria, child: Text('${e.descripcion} (\$${e.basico.toStringAsFixed(0)})'))).toList(),
                onChanged: (v) { if (v != null) setState(() => _categoria = v); },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<NivelTituloSanidad>(
                initialValue: _nivelTitulo,
                decoration: _dropdownDecoration('Nivel de Título', Icons.school),
                dropdownColor: AppColors.backgroundLight,
                style: const TextStyle(color: AppColors.textPrimary),
                items: const [
                  DropdownMenuItem(value: NivelTituloSanidad.sinTitulo, child: Text('Sin título (0%)')),
                  DropdownMenuItem(value: NivelTituloSanidad.auxiliar, child: Text('Auxiliar (5%)')),
                  DropdownMenuItem(value: NivelTituloSanidad.tecnico, child: Text('Técnico (7%)')),
                  DropdownMenuItem(value: NivelTituloSanidad.universitario, child: Text('Universitario (10%)')),
                ],
                onChanged: (v) { if (v != null) setState(() => _nivelTitulo = v); },
              ),
            ]),
            const SizedBox(height: 24),
            _buildSeccion('Otros datos', Icons.tune, [
              ListTile(
                title: const Text('Fecha ingreso', style: TextStyle(color: AppColors.textPrimary)),
                subtitle: Text(DateFormat('dd/MM/yyyy').format(_fechaIngreso), style: const TextStyle(color: AppColors.textSecondary)),
                trailing: const Icon(Icons.calendar_today, color: AppColors.pastelBlue),
                onTap: () async {
                  final d = await showDatePicker(context: context, initialDate: _fechaIngreso, firstDate: DateTime(1950), lastDate: DateTime.now());
                  if (d != null) setState(() => _fechaIngreso = d);
                },
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                tileColor: AppColors.glassFill,
              ),
              const SizedBox(height: 16),
              _buildTextField(controller: _horasNocturnasController, label: 'Horas nocturnas', icon: Icons.nightlight_round, keyboardType: TextInputType.number),
              const SizedBox(height: 16),
              _buildTextField(controller: _cantidadFamiliaresController, label: 'Cantidad de familiares a cargo', icon: Icons.family_restroom, keyboardType: TextInputType.number),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _codigoRnosController,
                      label: 'Código RNOS (Obra Social)',
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
              SwitchListTile(
                title: const Text('Tarea Crítica / Riesgo (10%)', style: TextStyle(color: AppColors.textPrimary)),
                value: _tareaCriticaRiesgo,
                onChanged: (v) => setState(() => _tareaCriticaRiesgo = v),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                tileColor: AppColors.glassFill,
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                title: const Text('Cuota Sindical ATSA (2%)', style: TextStyle(color: AppColors.textPrimary)),
                value: _cuotaSindicalAtsa,
                onChanged: (v) => setState(() => _cuotaSindicalAtsa = v),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                tileColor: AppColors.glassFill,
              ),
              if (_categoria == CategoriaSanidad.administrativo) ...[
                const SizedBox(height: 8),
                SwitchListTile(
                  title: Text('Manejo efectivo / Cobranzas (Fallo Caja \$${montoFalloCaja2026.toStringAsFixed(0)})', style: const TextStyle(color: AppColors.textPrimary)),
                  value: _manejoEfectivoCaja,
                  onChanged: (v) => setState(() => _manejoEfectivoCaja = v),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  tileColor: AppColors.glassFill,
                ),
              ],
            ]),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _guardar,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.pastelBlue, foregroundColor: AppColors.background, padding: const EdgeInsets.symmetric(vertical: 18), shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))), elevation: 0),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.save, size: 22), const SizedBox(width: 8), Text(esEdicion ? 'Actualizar Legajo' : 'Guardar Legajo', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))]),
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
          decoration: BoxDecoration(color: AppColors.glassFillStrong, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.glassBorder)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.pastelBlue.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)), child: Icon(icono, color: AppColors.pastelBlue, size: 20)), const SizedBox(width: 12), Text(titulo, style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold))]),
              const SizedBox(height: 16),
              ...children,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({required TextEditingController controller, required String label, required IconData icon, TextInputType? keyboardType, List<TextInputFormatter>? inputFormatters, String? Function(String?)? validator}) {
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
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.glassBorder)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.pastelBlue, width: 2)),
      ),
      validator: validator,
    );
  }
}
