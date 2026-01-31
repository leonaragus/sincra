import 'package:flutter/material.dart';
import 'dart:ui';
import '../models/cct_completo.dart';
import '../theme/app_colors.dart';

class CCTDetailDialog extends StatefulWidget {
  final CCTCompleto convenio;
  final Function(CCTCompleto)? onUpdate;
  final bool esNuevo;

  const CCTDetailDialog({
    super.key,
    required this.convenio,
    this.onUpdate,
    this.esNuevo = false,
  });

  @override
  State<CCTDetailDialog> createState() => _CCTDetailDialogState();
}

class _CCTDetailDialogState extends State<CCTDetailDialog> {
  late CCTCompleto _convenioEditado;
  bool _modoEdicion = false;
  
  // Controllers para campos editables
  late TextEditingController _nombreController;
  late TextEditingController _numeroCCTController;
  late TextEditingController _descripcionController;
  late TextEditingController _actividadController;
  late TextEditingController _presentismoController;
  late TextEditingController _antiguedadController;
  late TextEditingController _porcentajeAntiguedadAnualController;

  @override
  void initState() {
    super.initState();
    _convenioEditado = widget.convenio;
    _modoEdicion = widget.esNuevo;
    _inicializarControllers();
  }

  void _inicializarControllers() {
    _nombreController = TextEditingController(text: _convenioEditado.nombre);
    _numeroCCTController = TextEditingController(text: _convenioEditado.numeroCCT);
    _descripcionController = TextEditingController(text: _convenioEditado.descripcion);
    _actividadController = TextEditingController(text: _convenioEditado.actividad ?? '');
    _presentismoController = TextEditingController(text: _convenioEditado.adicionalPresentismo.toStringAsFixed(2));
    _antiguedadController = TextEditingController(text: _convenioEditado.adicionalAntiguedad.toStringAsFixed(2));
    _porcentajeAntiguedadAnualController = TextEditingController(text: _convenioEditado.porcentajeAntiguedadAnual.toStringAsFixed(2));
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _numeroCCTController.dispose();
    _descripcionController.dispose();
    _actividadController.dispose();
    _presentismoController.dispose();
    _antiguedadController.dispose();
    _porcentajeAntiguedadAnualController.dispose();
    super.dispose();
  }

  void _activarEdicion() {
    setState(() {
      _modoEdicion = true;
    });
  }

  void _guardarCambios() {
    final nombre = _nombreController.text.trim();
    final numeroCCT = _numeroCCTController.text.trim();

    if (nombre.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingrese el nombre del convenio')),
      );
      return;
    }
    if (numeroCCT.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingrese el número de CCT')),
      );
      return;
    }

    _convenioEditado = _convenioEditado.copyWith(
      nombre: nombre,
      numeroCCT: numeroCCT,
      descripcion: _descripcionController.text.trim(),
      actividad: _actividadController.text.isEmpty ? null : _actividadController.text.trim(),
      adicionalPresentismo: double.tryParse(_presentismoController.text) ?? _convenioEditado.adicionalPresentismo,
      adicionalAntiguedad: double.tryParse(_antiguedadController.text) ?? _convenioEditado.adicionalAntiguedad,
      porcentajeAntiguedadAnual: double.tryParse(_porcentajeAntiguedadAnualController.text) ?? _convenioEditado.porcentajeAntiguedadAnual,
    );

    if (widget.onUpdate != null) {
      widget.onUpdate!(_convenioEditado);
    }
    setState(() {
      _modoEdicion = false;
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.esNuevo ? 'Convenio creado correctamente' : 'Convenio actualizado correctamente',
        ),
      ),
    );
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  void _cancelarEdicion() {
    if (widget.esNuevo) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _convenioEditado = widget.convenio;
      _inicializarControllers();
      _modoEdicion = false;
    });
  }

  void _editarCategoria(CategoriaCCT categoria, int index) {
    final nombreController = TextEditingController(text: categoria.nombre);
    final salarioController = TextEditingController(text: categoria.salarioBase.toStringAsFixed(0));
    final descripcionController = TextEditingController(text: categoria.descripcion ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar Categoría'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nombreController,
                decoration: const InputDecoration(labelText: 'Nombre'),
              ),
              TextField(
                controller: salarioController,
                decoration: const InputDecoration(labelText: 'Salario Base'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: descripcionController,
                decoration: const InputDecoration(labelText: 'Descripción'),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final nuevasCategorias = List<CategoriaCCT>.from(_convenioEditado.categorias);
              nuevasCategorias[index] = CategoriaCCT(
                id: categoria.id,
                nombre: nombreController.text,
                salarioBase: double.tryParse(salarioController.text) ?? categoria.salarioBase,
                descripcion: descripcionController.text.isEmpty ? null : descripcionController.text,
              );
              setState(() {
                _convenioEditado = _convenioEditado.copyWith(categorias: nuevasCategorias);
              });
              Navigator.pop(context);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _agregarCategoria() {
    final nombreController = TextEditingController();
    final salarioController = TextEditingController();
    final descripcionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Agregar Categoría'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nombreController,
                decoration: const InputDecoration(labelText: 'Nombre'),
              ),
              TextField(
                controller: salarioController,
                decoration: const InputDecoration(labelText: 'Salario Base'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: descripcionController,
                decoration: const InputDecoration(labelText: 'Descripción'),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nombreController.text.isNotEmpty && salarioController.text.isNotEmpty) {
                final nuevaCategoria = CategoriaCCT(
                  id: 'cat_${DateTime.now().millisecondsSinceEpoch}',
                  nombre: nombreController.text,
                  salarioBase: double.tryParse(salarioController.text) ?? 0.0,
                  descripcion: descripcionController.text.isEmpty ? null : descripcionController.text,
                );
                setState(() {
                  _convenioEditado = _convenioEditado.copyWith(
                    categorias: [..._convenioEditado.categorias, nuevaCategoria],
                  );
                });
                Navigator.pop(context);
              }
            },
            child: const Text('Agregar'),
          ),
        ],
      ),
    );
  }

  void _eliminarCategoria(int index) {
    setState(() {
      final nuevasCategorias = List<CategoriaCCT>.from(_convenioEditado.categorias);
      nuevasCategorias.removeAt(index);
      _convenioEditado = _convenioEditado.copyWith(categorias: nuevasCategorias);
    });
  }

  void _editarDescuento(DescuentoCCT descuento, int index) {
    final nombreController = TextEditingController(text: descuento.nombre);
    final porcentajeController = TextEditingController(text: descuento.porcentaje.toStringAsFixed(2));
    final descripcionController = TextEditingController(text: descuento.descripcion ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar Descuento'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nombreController,
                decoration: const InputDecoration(labelText: 'Nombre'),
              ),
              TextField(
                controller: porcentajeController,
                decoration: const InputDecoration(labelText: 'Porcentaje'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: descripcionController,
                decoration: const InputDecoration(labelText: 'Descripción'),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final nuevosDescuentos = List<DescuentoCCT>.from(_convenioEditado.descuentos);
              nuevosDescuentos[index] = DescuentoCCT(
                id: descuento.id,
                nombre: nombreController.text,
                porcentaje: double.tryParse(porcentajeController.text) ?? descuento.porcentaje,
                descripcion: descripcionController.text.isEmpty ? null : descripcionController.text,
              );
              setState(() {
                _convenioEditado = _convenioEditado.copyWith(descuentos: nuevosDescuentos);
              });
              Navigator.pop(context);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _agregarDescuento() {
    final nombreController = TextEditingController();
    final porcentajeController = TextEditingController();
    final descripcionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Agregar Descuento'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nombreController,
                decoration: const InputDecoration(labelText: 'Nombre'),
              ),
              TextField(
                controller: porcentajeController,
                decoration: const InputDecoration(labelText: 'Porcentaje'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: descripcionController,
                decoration: const InputDecoration(labelText: 'Descripción'),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nombreController.text.isNotEmpty && porcentajeController.text.isNotEmpty) {
                final nuevoDescuento = DescuentoCCT(
                  id: 'desc_${DateTime.now().millisecondsSinceEpoch}',
                  nombre: nombreController.text,
                  porcentaje: double.tryParse(porcentajeController.text) ?? 0.0,
                  descripcion: descripcionController.text.isEmpty ? null : descripcionController.text,
                );
                setState(() {
                  _convenioEditado = _convenioEditado.copyWith(
                    descuentos: [..._convenioEditado.descuentos, nuevoDescuento],
                  );
                });
                Navigator.pop(context);
              }
            },
            child: const Text('Agregar'),
          ),
        ],
      ),
    );
  }

  void _eliminarDescuento(int index) {
    setState(() {
      final nuevosDescuentos = List<DescuentoCCT>.from(_convenioEditado.descuentos);
      nuevosDescuentos.removeAt(index);
      _convenioEditado = _convenioEditado.copyWith(descuentos: nuevosDescuentos);
    });
  }

  void _editarZona(ZonaCCT zona, int index) {
    final nombreController = TextEditingController(text: zona.nombre);
    final porcentajeController = TextEditingController(text: zona.adicionalPorcentaje.toStringAsFixed(2));
    final descripcionController = TextEditingController(text: zona.descripcion ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar Zona'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nombreController,
                decoration: const InputDecoration(labelText: 'Nombre'),
              ),
              TextField(
                controller: porcentajeController,
                decoration: const InputDecoration(labelText: 'Adicional Porcentaje'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: descripcionController,
                decoration: const InputDecoration(labelText: 'Descripción'),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final nuevasZonas = List<ZonaCCT>.from(_convenioEditado.zonas);
              nuevasZonas[index] = ZonaCCT(
                id: zona.id,
                nombre: nombreController.text,
                adicionalPorcentaje: double.tryParse(porcentajeController.text) ?? zona.adicionalPorcentaje,
                descripcion: descripcionController.text.isEmpty ? null : descripcionController.text,
              );
              setState(() {
                _convenioEditado = _convenioEditado.copyWith(zonas: nuevasZonas);
              });
              Navigator.pop(context);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _agregarZona() {
    final nombreController = TextEditingController();
    final porcentajeController = TextEditingController();
    final descripcionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Agregar Zona'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nombreController,
                decoration: const InputDecoration(labelText: 'Nombre'),
              ),
              TextField(
                controller: porcentajeController,
                decoration: const InputDecoration(labelText: 'Adicional Porcentaje'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: descripcionController,
                decoration: const InputDecoration(labelText: 'Descripción'),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nombreController.text.isNotEmpty && porcentajeController.text.isNotEmpty) {
                final nuevaZona = ZonaCCT(
                  id: 'zona_${DateTime.now().millisecondsSinceEpoch}',
                  nombre: nombreController.text,
                  adicionalPorcentaje: double.tryParse(porcentajeController.text) ?? 0.0,
                  descripcion: descripcionController.text.isEmpty ? null : descripcionController.text,
                );
                setState(() {
                  _convenioEditado = _convenioEditado.copyWith(
                    zonas: [..._convenioEditado.zonas, nuevaZona],
                  );
                });
                Navigator.pop(context);
              }
            },
            child: const Text('Agregar'),
          ),
        ],
      ),
    );
  }

  void _eliminarZona(int index) {
    setState(() {
      final nuevasZonas = List<ZonaCCT>.from(_convenioEditado.zonas);
      nuevasZonas.removeAt(index);
      _convenioEditado = _convenioEditado.copyWith(zonas: nuevasZonas);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.9,
              maxWidth: 600,
            ),
            decoration: BoxDecoration(
              color: AppColors.backgroundLight,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: AppColors.glassBorder,
                width: 2,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: AppColors.glassFillStrong,
                    border: Border(
                      bottom: BorderSide(color: AppColors.glassBorder, width: 1),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (widget.esNuevo)
                              const Padding(
                                padding: EdgeInsets.only(bottom: 4),
                                child: Text(
                                  'Nuevo convenio',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            _modoEdicion
                                ? TextField(
                                    controller: _nombreController,
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                    decoration: const InputDecoration(
                                      border: InputBorder.none,
                                      hintText: 'Nombre del convenio',
                                      hintStyle: TextStyle(color: AppColors.textMuted),
                                    ),
                                  )
                                : Text(
                                    _convenioEditado.nombre,
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                            const SizedBox(height: 4),
                            _modoEdicion
                                ? TextField(
                                    controller: _numeroCCTController,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: AppColors.textSecondary,
                                    ),
                                    decoration: const InputDecoration(
                                      border: InputBorder.none,
                                      hintText: 'CCT',
                                      hintStyle: TextStyle(color: AppColors.textMuted),
                                    ),
                                  )
                                : Text(
                                    'CCT ${_convenioEditado.numeroCCT}',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                          ],
                        ),
                      ),
                      if (!_modoEdicion)
                        IconButton(
                          icon: const Icon(Icons.edit, color: AppColors.textPrimary),
                          onPressed: _activarEdicion,
                        )
                      else
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.check, color: AppColors.pastelMint),
                              onPressed: _guardarCambios,
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: AppColors.textSecondary),
                              onPressed: _cancelarEdicion,
                            ),
                          ],
                        ),
                      IconButton(
                        icon: const Icon(Icons.close, color: AppColors.textSecondary),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),

                // Contenido
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Descripción y Actividad
                        _buildCampoEditable(
                          'Descripción',
                          _descripcionController,
                          _modoEdicion,
                        ),
                        const SizedBox(height: 16),
                        _buildCampoEditable(
                          'Actividad',
                          _actividadController,
                          _modoEdicion,
                        ),

                        const SizedBox(height: 20),

                        // Adicionales
                        _buildAdicionalesSection(),

                        const SizedBox(height: 20),

                        // Categorías
                        _buildCategoriasSection(),

                        const SizedBox(height: 20),

                        // Descuentos
                        _buildDescuentosSection(),

                        const SizedBox(height: 20),

                        // Zonas
                        _buildZonasSection(),
                      ],
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

  Widget _buildCampoEditable(
    String label,
    TextEditingController controller,
    bool editable,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        editable
            ? TextField(
                controller: controller,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.glassFillStrong,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.glassBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.pastelBlue, width: 2),
                  ),
                ),
              )
            : Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.glassFillStrong,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.glassBorder),
                ),
                child: Text(
                  controller.text.isEmpty ? 'No especificado' : controller.text,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ),
      ],
    );
  }

  Widget _buildAdicionalesSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.glassFillStrong,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Adicionales',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            'Presentismo',
            _presentismoController,
            '%',
            _modoEdicion,
          ),
          const SizedBox(height: 8),
          _buildInfoRow(
            'Antigüedad (fijo)',
            _antiguedadController,
            '%',
            _modoEdicion,
          ),
          const SizedBox(height: 8),
          _buildInfoRow(
            '% Antigüedad Anual',
            _porcentajeAntiguedadAnualController,
            '%',
            _modoEdicion,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    String label,
    TextEditingController controller,
    String suffix,
    bool editable,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        editable
            ? SizedBox(
                width: 120,
                child: TextField(
                  controller: controller,
                  style: const TextStyle(color: AppColors.textPrimary),
                  textAlign: TextAlign.right,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppColors.glassFillStrong,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    suffixText: suffix,
                    suffixStyle: const TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              )
            : Text(
                '${controller.text}$suffix',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ],
    );
  }

  Widget _buildCategoriasSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Categorías',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            Row(
              children: [
                Text(
                  '${_convenioEditado.categorias.length} categorías',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                if (_modoEdicion) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.add_circle, color: AppColors.textPrimary),
                    onPressed: _agregarCategoria,
                    tooltip: 'Agregar categoría',
                  ),
                ],
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._convenioEditado.categorias.asMap().entries.map((entry) {
          final index = entry.key;
          final categoria = entry.value;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.glassFillStrong,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        categoria.nombre,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (categoria.descripcion != null)
                        Text(
                          categoria.descripcion!,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                Text(
                  '\$${categoria.salarioBase.toStringAsFixed(0)}',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                if (_modoEdicion) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.edit, color: AppColors.textSecondary, size: 20),
                    onPressed: () => _editarCategoria(categoria, index),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
                    onPressed: () => _eliminarCategoria(index),
                  ),
                ],
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildDescuentosSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Descuentos',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            Row(
              children: [
                Text(
                  '${_convenioEditado.descuentos.length} descuentos',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                if (_modoEdicion) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.add_circle, color: AppColors.textPrimary),
                    onPressed: _agregarDescuento,
                    tooltip: 'Agregar descuento',
                  ),
                ],
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._convenioEditado.descuentos.asMap().entries.map((entry) {
          final index = entry.key;
          final descuento = entry.value;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.glassFillStrong,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        descuento.nombre,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (descuento.descripcion != null)
                        Text(
                          descuento.descripcion!,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                Text(
                  '${descuento.porcentaje.toStringAsFixed(2)}%',
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                if (_modoEdicion) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.edit, color: AppColors.textSecondary, size: 20),
                    onPressed: () => _editarDescuento(descuento, index),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
                    onPressed: () => _eliminarDescuento(index),
                  ),
                ],
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildZonasSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Zonas',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            Row(
              children: [
                Text(
                  '${_convenioEditado.zonas.length} zonas',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                if (_modoEdicion) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.add_circle, color: AppColors.textPrimary),
                    onPressed: _agregarZona,
                    tooltip: 'Agregar zona',
                  ),
                ],
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._convenioEditado.zonas.asMap().entries.map((entry) {
          final index = entry.key;
          final zona = entry.value;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.glassFillStrong,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        zona.nombre,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (zona.descripcion != null)
                        Text(
                          zona.descripcion!,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                Text(
                  zona.adicionalPorcentaje > 0
                      ? '+${zona.adicionalPorcentaje.toStringAsFixed(0)}%'
                      : '0%',
                  style: TextStyle(
                    color: zona.adicionalPorcentaje > 0
                        ? Colors.greenAccent
                        : AppColors.textSecondary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                if (_modoEdicion) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.edit, color: AppColors.textSecondary, size: 20),
                    onPressed: () => _editarZona(zona, index),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
                    onPressed: () => _eliminarZona(index),
                  ),
                ],
              ],
            ),
          );
        }),
      ],
    );
  }
}
