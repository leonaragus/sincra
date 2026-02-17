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
  // Cabecera
  late TextEditingController _empresaNombreCtr;
  late TextEditingController _empresaCuitCtr;
  late TextEditingController _empleadoNombreCtr;
  late TextEditingController _empleadoCuilCtr;
  late TextEditingController _legajoCtr;
  late TextEditingController _fechaIngresoCtr;
  late TextEditingController _antiguedadReconocidaCtr;
  late TextEditingController _cctAplicableCtr;
  late TextEditingController _periodoAbonadoCtr;
  late TextEditingController _lugarPagoCtr;

  // Totales
  late TextEditingController _totalBrutoCtr;
  late TextEditingController _totalRetencionesCtr;
  late TextEditingController _totalNoRemunerativoCtr;
  late TextEditingController _netoACobrarCtr;
  late TextEditingController _netoEnLetrasCtr;

  // Specific concepts not directly in Cabecera/Totales, but were in old model
  late TextEditingController _horasNocturnasCtr; // Keeping this for now

  CategoriaSanidad _categoria = CategoriaSanidad.profesional;
  NivelTituloSanidad _nivelTitulo = NivelTituloSanidad.sinTitulo;

  @override
  void initState() {
    super.initState();
    // Cabecera
    _empresaNombreCtr = TextEditingController(text: widget.extract.cabecera?.empresaNombre ?? '');
    _empresaCuitCtr = TextEditingController(text: widget.extract.cabecera?.empresaCuit ?? '');
    _empleadoNombreCtr = TextEditingController(text: widget.extract.cabecera?.empleadoNombre ?? '');
    _empleadoCuilCtr = TextEditingController(text: widget.extract.cabecera?.empleadoCuil ?? '');
    _legajoCtr = TextEditingController(text: widget.extract.cabecera?.legajo ?? '');
    _fechaIngresoCtr = TextEditingController(text: widget.extract.cabecera?.fechaIngreso ?? '');
    _antiguedadReconocidaCtr = TextEditingController(text: widget.extract.cabecera?.antiguedadReconocida ?? '');
    _cctAplicableCtr = TextEditingController(text: widget.extract.cabecera?.cctAplicable ?? '');
    _periodoAbonadoCtr = TextEditingController(text: widget.extract.cabecera?.periodoAbonado ?? '');
    _lugarPagoCtr = TextEditingController(text: widget.extract.cabecera?.lugarPago ?? '');

    // Totales
    _totalBrutoCtr = TextEditingController(
      text: widget.extract.totales?.totalBruto != null ? _fmtNum(widget.extract.totales!.totalBruto!) : '',
    );
    _totalRetencionesCtr = TextEditingController(
      text: widget.extract.totales?.totalRetenciones != null ? _fmtNum(widget.extract.totales!.totalRetenciones!) : '',
    );
    _totalNoRemunerativoCtr = TextEditingController(
      text: widget.extract.totales?.totalNoRemunerativo != null ? _fmtNum(widget.extract.totales!.totalNoRemunerativo!) : '',
    );
    _netoACobrarCtr = TextEditingController(
      text: widget.extract.totales?.netoACobrar != null ? _fmtNum(widget.extract.totales!.netoACobrar!) : '',
    );
    _netoEnLetrasCtr = TextEditingController(text: widget.extract.totales?.netoEnLetras ?? '');

    // Specific concepts
    _horasNocturnasCtr = TextEditingController(
      text: '', // No direct mapping in new model, will need to be handled if it's a specific concept.
    );

    // Intentar parsear categoría del OCR
    if (widget.extract.cabecera?.categoriaProfesional != null) {
      final cat = _parseCategoria(widget.extract.cabecera!.categoriaProfesional!);
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
    // Cabecera
    _empresaNombreCtr.dispose();
    _empresaCuitCtr.dispose();
    _empleadoNombreCtr.dispose();
    _empleadoCuilCtr.dispose();
    _legajoCtr.dispose();
    _fechaIngresoCtr.dispose();
    _antiguedadReconocidaCtr.dispose();
    _cctAplicableCtr.dispose();
    _periodoAbonadoCtr.dispose();
    _lugarPagoCtr.dispose();

    // Totales
    _totalBrutoCtr.dispose();
    _totalRetencionesCtr.dispose();
    _totalNoRemunerativoCtr.dispose();
    _netoACobrarCtr.dispose();
    _netoEnLetrasCtr.dispose();

    // Specific concepts
    _horasNocturnasCtr.dispose();

    super.dispose();
  }

  /// True si el OCR no detectó al menos un dato principal
  bool get _hasMissingOcrFields {
    final e = widget.extract;
    return (e.cabecera?.empleadoCuil == null || e.cabecera!.empleadoCuil!.trim().isEmpty) ||
        (e.cabecera?.empleadoNombre == null || e.cabecera!.empleadoNombre!.trim().isEmpty) ||
        (e.totales?.netoACobrar == null);
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
    final empleadoCuil = _empleadoCuilCtr.text.trim();
    if (empleadoCuil.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('CUIL del empleado es obligatorio')),
      );
      return;
    }

    final empleadoNombre = _empleadoNombreCtr.text.trim();
    if (empleadoNombre.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nombre del empleado es obligatorio')),
      );
      return;
    }

    final netoACobrar = _parseNumFromField(_netoACobrarCtr.text);
    if (netoACobrar == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Neto a Cobrar es obligatorio y debe ser un número válido')),
      );
      return;
    }

    // Crear resultado para devolver a la pantalla de sanidad
    final result = SanidadOcrExtractResult(
      cabecera: Cabecera(
        empresaNombre: _empresaNombreCtr.text.trim(),
        empresaCuit: _empresaCuitCtr.text.trim(),
        empleadoNombre: empleadoNombre,
        empleadoCuil: empleadoCuil,
        legajo: _legajoCtr.text.trim(),
        fechaIngreso: _fechaIngresoCtr.text.trim(),
        antiguedadReconocida: _antiguedadReconocidaCtr.text.trim(),
        cctAplicable: _cctAplicableCtr.text.trim(),
        periodoAbonado: _periodoAbonadoCtr.text.trim(),
        lugarPago: _lugarPagoCtr.text.trim(),
        categoriaProfesional: _categoria.name, // Usar la categoría seleccionada
      ),
      totales: Totales(
        totalBruto: _parseNumFromField(_totalBrutoCtr.text),
        totalRetenciones: _parseNumFromField(_totalRetencionesCtr.text),
        totalNoRemunerativo: _parseNumFromField(_totalNoRemunerativoCtr.text),
        netoACobrar: netoACobrar,
        netoEnLetras: _netoEnLetrasCtr.text.trim(),
      ),
      // Mantener otros campos si son relevantes o pasarlos como null si no se editan aquí
      urlDetectada: widget.extract.urlDetectada,
      source: widget.extract.source,
      rawTextOcr: widget.extract.rawTextOcr,
      error: widget.extract.error,
      liquidacionDetallada: widget.extract.liquidacionDetallada, // No se edita aquí
      auditoriaIa: widget.extract.auditoriaIa, // No se edita aquí
    );

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
                    'DATOS DE CABECERA',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.pastelMint),
                  ),
                ),
                _buildCard(
                  label: 'Empresa Nombre',
                  valorDetectado: widget.extract.cabecera?.empresaNombre ?? '',
                  ctr: _empresaNombreCtr,
                ),
                _buildCard(
                  label: 'Empresa CUIT',
                  valorDetectado: widget.extract.cabecera?.empresaCuit ?? '',
                  ctr: _empresaCuitCtr,
                  hint: 'Formato: 20-12345678-9',
                ),
                _buildCard(
                  label: 'Empleado Nombre',
                  valorDetectado: widget.extract.cabecera?.empleadoNombre ?? '',
                  ctr: _empleadoNombreCtr,
                ),
                _buildCard(
                  label: 'Empleado CUIL',
                  valorDetectado: widget.extract.cabecera?.empleadoCuil ?? '',
                  ctr: _empleadoCuilCtr,
                  hint: 'Formato: 20-12345678-9',
                ),
                _buildCard(
                  label: 'Legajo',
                  valorDetectado: widget.extract.cabecera?.legajo ?? '',
                  ctr: _legajoCtr,
                ),
                _buildCard(
                  label: 'Fecha Ingreso',
                  valorDetectado: widget.extract.cabecera?.fechaIngreso ?? '',
                  ctr: _fechaIngresoCtr,
                  hint: 'Formato: DD/MM/AAAA',
                ),
                _buildCard(
                  label: 'Antigüedad Reconocida',
                  valorDetectado: widget.extract.cabecera?.antiguedadReconocida ?? '',
                  ctr: _antiguedadReconocidaCtr,
                  hint: 'Ej: 10 años',
                ),
                _buildCard(
                  label: 'CCT Aplicable',
                  valorDetectado: widget.extract.cabecera?.cctAplicable ?? '',
                  ctr: _cctAplicableCtr,
                ),
                _buildCard(
                  label: 'Periodo Abonado',
                  valorDetectado: widget.extract.cabecera?.periodoAbonado ?? '',
                  ctr: _periodoAbonadoCtr,
                  hint: 'Ej: 01/2023',
                ),
                _buildCard(
                  label: 'Lugar de Pago',
                  valorDetectado: widget.extract.cabecera?.lugarPago ?? '',
                  ctr: _lugarPagoCtr,
                ),
                const SizedBox(height: 16),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    'TOTALES',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.pastelMint),
                  ),
                ),
                _buildCard(
                  label: 'Total Bruto',
                  valorDetectado: widget.extract.totales?.totalBruto != null ? '\$${_fmtNum(widget.extract.totales!.totalBruto!)}' : '',
                  ctr: _totalBrutoCtr,
                  isNumero: true,
                ),
                _buildCard(
                  label: 'Total Retenciones',
                  valorDetectado: widget.extract.totales?.totalRetenciones != null ? '\$${_fmtNum(widget.extract.totales!.totalRetenciones!)}' : '',
                  ctr: _totalRetencionesCtr,
                  isNumero: true,
                ),
                _buildCard(
                  label: 'Total No Remunerativo',
                  valorDetectado: widget.extract.totales?.totalNoRemunerativo != null ? '\$${_fmtNum(widget.extract.totales!.totalNoRemunerativo!)}' : '',
                  ctr: _totalNoRemunerativoCtr,
                  isNumero: true,
                ),
                _buildCard(
                  label: 'Neto a Cobrar',
                  valorDetectado: widget.extract.totales?.netoACobrar != null ? '\$${_fmtNum(widget.extract.totales!.netoACobrar!)}' : '',
                  ctr: _netoACobrarCtr,
                  isNumero: true,
                ),
                _buildCard(
                  label: 'Neto en Letras',
                  valorDetectado: widget.extract.totales?.netoEnLetras ?? '',
                  ctr: _netoEnLetrasCtr,
                ),
                // Specific concepts - keeping for now, but might need re-evaluation
                _buildCard(
                  label: 'Horas Nocturnas',
                  valorDetectado: '', // No direct mapping in new model, will need to be handled if it's a specific concept.
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
                  valorDetectado: widget.extract.cabecera?.categoriaProfesional ?? '',
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
