import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/ocr_cct_service.dart';
import '../theme/app_colors.dart';

class CctOcrReviewScreen extends StatefulWidget {
  final ResultadoOCRCCT result;

  const CctOcrReviewScreen({super.key, required this.result});

  @override
  State<CctOcrReviewScreen> createState() => _CctOcrReviewScreenState();
}

class _CctOcrReviewScreenState extends State<CctOcrReviewScreen> {
  late TextEditingController _nombreCtr;
  late TextEditingController _codigoCtr;
  late List<EscalaSalarialExtraida> _escalas;

  @override
  void initState() {
    super.initState();
    _nombreCtr = TextEditingController(text: widget.result.nombreCCT);
    _codigoCtr = TextEditingController(text: widget.result.codigoCCT);
    _escalas = List.from(widget.result.escalas);
  }

  @override
  void dispose() {
    _nombreCtr.dispose();
    _codigoCtr.dispose();
    super.dispose();
  }

  void _guardar() {
    // Aquí se implementaría la lógica de guardado real
    // Por ahora solo retornamos true para indicar éxito
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('CCT guardado correctamente (Simulado)'), backgroundColor: Colors.green),
    );
    Navigator.pop(context, true);
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
        title: const Text('Revisar CCT Extraído', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        actions: [
          TextButton(
            onPressed: _guardar,
            child: const Text('Confirmar', style: TextStyle(color: AppColors.pastelMint, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderSection(),
            const SizedBox(height: 24),
            const Text('Escalas Detectadas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: 12),
            if (_escalas.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('No se detectaron escalas salariales.', style: TextStyle(color: AppColors.textMuted)),
              )
            else
              ..._escalas.map((e) => _buildEscalaItem(e)),
            
            const SizedBox(height: 30),
            Center(
              child: FilledButton.icon(
                onPressed: _guardar,
                icon: const Icon(Icons.check),
                label: const Text('Guardar CCT'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.pastelMint,
                  foregroundColor: Colors.black87,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.glassFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Datos del Convenio', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 16),
          TextField(
            controller: _nombreCtr,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: const InputDecoration(
              labelText: 'Nombre del CCT / Sindicato',
              labelStyle: TextStyle(color: AppColors.textSecondary),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.glassBorder)),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _codigoCtr,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: const InputDecoration(
              labelText: 'Código (ej: 130/75)',
              labelStyle: TextStyle(color: AppColors.textSecondary),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.glassBorder)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEscalaItem(EscalaSalarialExtraida escala) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.glassBorder.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(escala.categoria, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: AppColors.textPrimary)),
                if (escala.observaciones != null && escala.observaciones!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(escala.observaciones!, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.pastelMint.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              escala.basico != null 
                  ? '\$${NumberFormat("#,##0.00", "es_AR").format(escala.basico)}' 
                  : '-',
              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.pastelMint),
            ),
          ),
        ],
      ),
    );
  }
}
