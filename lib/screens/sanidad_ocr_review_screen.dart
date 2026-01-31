// SanidadOcrReviewScreen - Validación de datos extraídos por OCR
// Cards editables para revisar y corregir datos antes de cargar en la liquidación

import 'package:flutter/material.dart';
import '../services/sanidad_omni_engine.dart';
import '../services/sanidad_receipt_scan_service.dart';
import '../theme/app_colors.dart';

class SanidadOcrReviewScreen extends StatefulWidget {
  final SanidadOcrExtractResult extract;

  const SanidadOcrReviewScreen({super.key, required this.extract});

  @override
  State<SanidadOcrReviewScreen> createState() => _SanidadOcrReviewScreenState();
}

class _SanidadOcrReviewScreenState extends State<SanidadOcrReviewScreen> {
  late TextEditingController _cuilCtr;
  late TextEditingController _nombreCtr;
  late TextEditingController _sueldoBasicoCtr;
  late TextEditingController _antiguedadPctCtr;
  late TextEditingController _horasNocturnasCtr;

  CategoriaSanidad _categoria = CategoriaSanidad.profesional;
  NivelTituloSanidad _nivelTitulo = NivelTituloSanidad.sinTitulo;

  @override
  void initState() {
    super.initState();
    _cuilCtr = TextEditingController(text: widget.extract.cuil ?? '');
    _nombreCtr = TextEditingController(text: widget.extract.nombre ?? '');
    _sueldoBasicoCtr = TextEditingController(
      text: widget.extract.sueldoBasico != null ? _fmtNum(widget.extract.sueldoBasico!) : '',
    );
    _antiguedadPctCtr = TextEditingController(
      text: widget.extract.antiguedadPct != null ? _fmtNum(widget.extract.antiguedadPct!) : '',
    );
    _horasNocturnasCtr = TextEditingController(
      text: widget.extract.horasNocturnas?.toString() ?? '0',
    );

    // Intentar parsear categoría del OCR
    if (widget.extract.categoriaRaw != null) {
      final cat = _parseCategoria(widget.extract.categoriaRaw!);
      if (cat != null) _categoria = cat;
    }
  }

  CategoriaSanidad? _parseCategoria(String s) {
    final low = s.toLowerCase();
    if (low.contains('profesional')) return CategoriaSanidad.profesional;
    if (low.contains('tecnico') || low.contains('técnico')) return CategoriaSanidad.tecnico;
    if (low.contains('servicios')) return CategoriaSanidad.servicios;
    if (low.contains('administrativo') || low.contains('administrativa')) return CategoriaSanidad.administrativo;
    if (low.contains('maestranza')) return CategoriaSanidad.maestranza;
    return null;
  }

  String _fmtNum(double n) => n.toStringAsFixed(2).replaceAll('.', ',');

  double? _parseNumFromField(String s) {
    if (s.trim().isEmpty) return null;
    return double.tryParse(s.replaceAll(',', '.'));
  }

  int? _parseIntFromField(String s) {
    if (s.trim().isEmpty) return null;
    return int.tryParse(s);
  }

  @override
  void dispose() {
    _cuilCtr.dispose();
    _nombreCtr.dispose();
    _sueldoBasicoCtr.dispose();
    _antiguedadPctCtr.dispose();
    _horasNocturnasCtr.dispose();
    super.dispose();
  }

  /// True si el OCR no detectó al menos un dato principal
  bool get _hasMissingOcrFields {
    final e = widget.extract;
    return (e.cuil == null || e.cuil!.trim().isEmpty) ||
        (e.sueldoBasico == null) ||
        (e.antiguedadPct == null);
  }

  Widget _buildCard({
    required String label,
    required String valorDetectado,
    required TextEditingController ctr,
    bool isNumero = false,
    String? hint,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: AppColors.glassFill,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.glassBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 12)),
                  if (hint != null)
                    Text(hint, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                valorDetectado.isNotEmpty ? valorDetectado : '—',
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
            ),
            Expanded(
              flex: 3,
              child: TextFormField(
                controller: ctr,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Corregir',
                  hintStyle: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                ),
                keyboardType: isNumero 
                  ? const TextInputType.numberWithOptions(decimal: true) 
                  : TextInputType.text,
                onChanged: (_) => setState(() {}),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownCard({
    required String label,
    required String valorDetectado,
    required List<DropdownMenuItem<String>> items,
    required String currentValue,
    required void Function(String?) onChanged,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: AppColors.glassFill,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.glassBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 12)),
            ),
            Expanded(
              flex: 2,
              child: Text(
                valorDetectado.isNotEmpty ? valorDetectado : '—',
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
            ),
            Expanded(
              flex: 3,
              child: DropdownButtonFormField<String>(
                value: currentValue,
                decoration: InputDecoration(
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                ),
                dropdownColor: AppColors.backgroundLight,
                style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                items: items,
                onChanged: onChanged,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmar() {
    // Validaciones básicas
    final cuil = _cuilCtr.text.trim();
    if (cuil.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('CUIL es obligatorio')),
      );
      return;
    }

    final nombre = _nombreCtr.text.trim();
    if (nombre.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nombre es obligatorio')),
      );
      return;
    }

    // Crear resultado para devolver a la pantalla de sanidad
    final result = {
      'cuil': cuil,
      'nombre': nombre,
      'sueldoBasico': _parseNumFromField(_sueldoBasicoCtr.text),
      'antiguedadPct': _parseNumFromField(_antiguedadPctCtr.text),
      'categoria': _categoria.name,
      'nivelTitulo': _nivelTitulo.name,
      'horasNocturnas': _parseIntFromField(_horasNocturnasCtr.text) ?? 0,
    };

    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Revisar datos del recibo',
          style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          if (widget.extract.urlDetectada != null && widget.extract.urlDetectada!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.shade900.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.link, color: AppColors.pastelBlue, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'URL: ${widget.extract.urlDetectada}',
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (_hasMissingOcrFields)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade900.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.shade700, width: 1),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, color: Colors.amber.shade700, size: 22),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Si falta algún dato, complételo a mano en los campos o escanee una foto con mejor resolución.',
                        style: TextStyle(fontSize: 13, color: AppColors.textPrimary, height: 1.3),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 12),
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    'DATOS EXTRAÍDOS',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.pastelMint),
                  ),
                ),
                _buildCard(
                  label: 'CUIL',
                  valorDetectado: widget.extract.cuil ?? '',
                  ctr: _cuilCtr,
                  hint: 'Formato: 20-12345678-9',
                ),
                _buildCard(
                  label: 'Nombre',
                  valorDetectado: widget.extract.nombre ?? '',
                  ctr: _nombreCtr,
                ),
                _buildCard(
                  label: 'Sueldo Básico',
                  valorDetectado: widget.extract.sueldoBasico != null ? '\$${_fmtNum(widget.extract.sueldoBasico!)}' : '',
                  ctr: _sueldoBasicoCtr,
                  isNumero: true,
                ),
                _buildCard(
                  label: 'Antigüedad %',
                  valorDetectado: widget.extract.antiguedadPct != null ? '${widget.extract.antiguedadPct!.toInt()}%' : '',
                  ctr: _antiguedadPctCtr,
                  isNumero: true,
                ),
                _buildCard(
                  label: 'Horas Nocturnas',
                  valorDetectado: widget.extract.horasNocturnas?.toString() ?? '',
                  ctr: _horasNocturnasCtr,
                  isNumero: true,
                ),
                const SizedBox(height: 16),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    'CLASIFICACIÓN',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.pastelMint),
                  ),
                ),
                _buildDropdownCard(
                  label: 'Categoría',
                  valorDetectado: widget.extract.categoriaRaw ?? '',
                  currentValue: _categoria.name,
                  items: CategoriaSanidad.values.map((c) {
                    final nombre = c == CategoriaSanidad.profesional ? 'Profesional'
                      : c == CategoriaSanidad.tecnico ? 'Técnico'
                      : c == CategoriaSanidad.servicios ? 'Servicios'
                      : c == CategoriaSanidad.administrativo ? 'Administrativo'
                      : 'Maestranza';
                    return DropdownMenuItem(value: c.name, child: Text(nombre));
                  }).toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setState(() {
                        _categoria = CategoriaSanidad.values.firstWhere((e) => e.name == v);
                      });
                    }
                  },
                ),
                _buildDropdownCard(
                  label: 'Nivel Título',
                  valorDetectado: '',
                  currentValue: _nivelTitulo.name,
                  items: NivelTituloSanidad.values.map((n) {
                    final nombre = n == NivelTituloSanidad.sinTitulo ? 'Sin Título'
                      : n == NivelTituloSanidad.auxiliar ? 'Auxiliar (+5%)'
                      : n == NivelTituloSanidad.tecnico ? 'Técnico (+7%)'
                      : 'Universitario (+10%)';
                    return DropdownMenuItem(value: n.name, child: Text(nombre));
                  }).toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setState(() {
                        _nivelTitulo = NivelTituloSanidad.values.firstWhere((e) => e.name == v);
                      });
                    }
                  },
                ),
                if (widget.extract.rawTextOcr != null && widget.extract.rawTextOcr!.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  ExpansionTile(
                    title: const Text('Ver texto OCR completo', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    children: [
                      Container(
                        margin: const EdgeInsets.all(12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          widget.extract.rawTextOcr!,
                          style: const TextStyle(fontSize: 10, color: AppColors.textSecondary, fontFamily: 'monospace'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.backgroundLight,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: FilledButton.icon(
                onPressed: _confirmar,
                icon: const Icon(Icons.check_circle),
                label: const Text('Confirmar y cargar datos'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  backgroundColor: AppColors.pastelMint,
                  foregroundColor: Colors.black87,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
