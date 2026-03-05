
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:ui';

import '../viewmodels/liquidacion_view_model.dart';
import '../services/sanidad_omni_engine.dart';
import '../theme/app_colors.dart';
import '../utils/pdf_recibo.dart'; // Importado para la clase ConceptoParaPDF

class CentroLiquidacionScreen extends StatelessWidget {
  const CentroLiquidacionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => LiquidacionViewModel(),
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Consumer<LiquidacionViewModel>(
          builder: (context, viewModel, child) {
            return SafeArea(
              child: Column(
                children: [
                  _buildHeader(context),
                  Expanded(
                    child: Stack(
                      children: [
                        SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: _buildContent(context, viewModel),
                        ),
                        if (viewModel.isLoading)
                          Container(
                            color: Colors.black.withOpacity(0.5),
                            child: const Center(child: CircularProgressIndicator()),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    // ... sin cambios ...
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
          const Expanded(
            child: Text(
              'Centro de Liquidación',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, LiquidacionViewModel viewModel) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (viewModel.errorMessage != null && !viewModel.isLoading)
          _buildStatusMessage(viewModel.errorMessage!, isError: true),
        if (viewModel.successMessage != null && !viewModel.isLoading)
          _buildStatusMessage(viewModel.successMessage!, isError: false),

        _buildSeleccionEmpresa(context, viewModel),
        const SizedBox(height: 24),
        if (viewModel.empresaSeleccionada != null) ...[
          _buildSeleccionEmpleado(context, viewModel),
          const SizedBox(height: 24),
        ],
        if (viewModel.empleadoSeleccionado != null) ...[
          _buildDatosLiquidacion(context, viewModel),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: viewModel.isLoading ? null : viewModel.calcularLiquidacion,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.pastelBlue, foregroundColor: AppColors.background, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('Calcular Liquidación', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 24),
        ],
        if (viewModel.liquidacion != null) ...[
          _buildResultadosLiquidacion(context, viewModel),
        ],
      ],
    );
  }

  Widget _buildStatusMessage(String message, {required bool isError}) {
    // ... sin cambios ...
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: isError ? Colors.red.shade100 : Colors.green.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isError ? Colors.red.shade300 : Colors.green.shade300),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(color: isError ? Colors.red.shade900 : Colors.green.shade900, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildSeleccionEmpresa(BuildContext context, LiquidacionViewModel viewModel) {
    // ... sin cambios ...
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Empresa', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 12),
          DropdownButtonFormField<Map<String, dynamic>>(
            value: viewModel.empresaSeleccionada,
            decoration: _buildDropdownDecoration(),
            items: viewModel.empresas.map((empresa) {
              return DropdownMenuItem<Map<String, dynamic>>(
                value: empresa,
                child: Text(empresa['razonSocial'] ?? ''),
              );
            }).toList(),
            onChanged: (empresa) {
              if (empresa != null) viewModel.onEmpresaSeleccionada(empresa);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSeleccionEmpleado(BuildContext context, LiquidacionViewModel viewModel) {
    // ... sin cambios ...
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Empleado', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 12),
          DropdownButtonFormField<Map<String, dynamic>>(
            value: viewModel.empleadoSeleccionado,
            decoration: _buildDropdownDecoration(),
            items: viewModel.empleados.map((empleado) {
              return DropdownMenuItem<Map<String, dynamic>>(
                value: empleado,
                child: Text(empleado['nombre'] ?? ''),
              );
            }).toList(),
            onChanged: (empleado) {
              if (empleado != null) viewModel.onEmpleadoSeleccionado(empleado);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDatosLiquidacion(BuildContext context, LiquidacionViewModel viewModel) {
    // ... sin cambios ...
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Datos de Liquidación', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 16),
          _buildTextField(label: 'Sueldo Básico', initialValue: viewModel.sueldoBasico, onChanged: (v) => viewModel.sueldoBasico = v),
          const SizedBox(height: 16),
          _buildTextField(label: 'Período', initialValue: viewModel.periodo, onChanged: (v) => viewModel.periodo = v),
        ],
      ),
    );
  }

  Widget _buildResultadosLiquidacion(BuildContext context, LiquidacionViewModel viewModel) {
    final liquidacion = viewModel.liquidacion;

    if (liquidacion is! LiquidacionSanidadResult) {
      return const _GlassCard(child: Text('Resultado no compatible.'));
    }

    final conceptos = _mapearLiquidacionParaTabla(liquidacion);

    final totalRemunerativo = conceptos.fold<double>(0, (sum, c) => sum + c.remunerativo);
    final totalNoRemunerativo = conceptos.fold<double>(0, (sum, c) => sum + c.noRemunerativo);
    final totalDeducciones = conceptos.fold<double>(0, (sum, c) => sum + c.descuento);
    final sueldoNeto = liquidacion.netoACobrar;

    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Resultados de la Liquidación', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 16),
          // --- TABLA DE RESULTADOS MEJORADA ---
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Concepto', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Remunerativo', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                DataColumn(label: Text('No Remun.', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                DataColumn(label: Text('Deducción', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
              ],
              rows: [
                ...conceptos.map((c) => DataRow(
                  cells: [
                    DataCell(Text(c.descripcion)),
                    DataCell(Text(c.remunerativo > 0 ? c.remunerativo.toStringAsFixed(2) : '-')),
                    DataCell(Text(c.noRemunerativo > 0 ? c.noRemunerativo.toStringAsFixed(2) : '-')),
                    DataCell(Text(c.descuento > 0 ? c.descuento.toStringAsFixed(2) : '-')),
                  ]
                )),
                // --- FILA DE TOTALES ---
                DataRow(
                  cells: [
                    const DataCell(Text('TOTALES', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataCell(Text(totalRemunerativo.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.bold))),
                    DataCell(Text(totalNoRemunerativo.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.bold))),
                    DataCell(Text(totalDeducciones.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.bold))),
                  ]
                )
              ],
            ),
          ),
          const Divider(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Sueldo Neto a Cobrar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text('\$${sueldoNeto.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.pastelBlue)),
            ]
          ),
          const SizedBox(height: 24),
          // --- BOTONES DE EXPORTACIÓN FLEXIBLES ---
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              _buildExportButton(
                label: 'Recibo (PDF)',
                icon: Icons.picture_as_pdf,
                onPressed: viewModel.isLoading ? null : viewModel.exportarReciboPDF,
                color: AppColors.pastelOrange,
              ),
              _buildExportButton(
                label: 'LSD (.txt)',
                icon: Icons.description_outlined,
                onPressed: viewModel.isLoading ? null : viewModel.exportarLsdTxt,
                color: AppColors.pastelMint,
              ),
              _buildExportButton(
                label: 'Pack Completo (.zip)',
                icon: Icons.archive_outlined,
                onPressed: viewModel.isLoading ? null : viewModel.exportarPackARCA,
                color: AppColors.pastelGreen,
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildExportButton({required String label, required IconData icon, required VoidCallback? onPressed, required Color color}) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: AppColors.background,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  List<ConceptoParaPDF> _mapearLiquidacionParaTabla(LiquidacionSanidadResult liq) {
    final List<ConceptoParaPDF> conceptos = [];
    if (liq.sueldoBasico > 0) conceptos.add(ConceptoParaPDF(descripcion: 'Sueldo Básico', remunerativo: liq.sueldoBasico, noRemunerativo: 0, descuento: 0));
    if (liq.adicionalAntiguedad > 0) conceptos.add(ConceptoParaPDF(descripcion: 'Ad. Antigüedad', remunerativo: liq.adicionalAntiguedad, noRemunerativo: 0, descuento: 0));
    if (liq.adicionalTitulo > 0) conceptos.add(ConceptoParaPDF(descripcion: 'Ad. Título', remunerativo: liq.adicionalTitulo, noRemunerativo: 0, descuento: 0));
    if (liq.aporteJubilacion > 0) conceptos.add(ConceptoParaPDF(descripcion: 'Jubilación (11%)', remunerativo: 0, noRemunerativo: 0, descuento: liq.aporteJubilacion));
    if (liq.aporteLey19032 > 0) conceptos.add(ConceptoParaPDF(descripcion: 'Ley 19.032 (3%)', remunerativo: 0, noRemunerativo: 0, descuento: liq.aporteLey19032));
    if (liq.aporteObraSocial > 0) conceptos.add(ConceptoParaPDF(descripcion: 'Obra Social (3%)', remunerativo: 0, noRemunerativo: 0, descuento: liq.aporteObraSocial));
    if (liq.cuotaSindicalAtsa > 0) conceptos.add(ConceptoParaPDF(descripcion: 'Cuota Sindical', remunerativo: 0, noRemunerativo: 0, descuento: liq.cuotaSindicalAtsa));
    return conceptos;
  }

  Widget _buildTextField({required String label, required String initialValue, required ValueChanged<String> onChanged}) {
    // ... sin cambios ...
    return TextFormField(
      initialValue: initialValue,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: AppColors.glassFill,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  InputDecoration _buildDropdownDecoration() {
    // ... sin cambios ...
    return InputDecoration(
      filled: true,
      fillColor: AppColors.glassFill,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
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
          child: child,
        ),
      ),
    );
  }
}
