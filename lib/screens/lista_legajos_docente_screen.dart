// Lista de legajos docentes de una institución — mismo formato que ListaEmpleadosScreen

import 'package:flutter/material.dart';
import '../services/instituciones_service.dart';
import '../theme/app_colors.dart';
import 'legajo_docente_form_screen.dart';

class ListaLegajosDocenteScreen extends StatefulWidget {
  final String cuit;
  final String? razonSocial;

  const ListaLegajosDocenteScreen({super.key, required this.cuit, this.razonSocial});

  @override
  State<ListaLegajosDocenteScreen> createState() => _ListaLegajosDocenteScreenState();
}

class _ListaLegajosDocenteScreenState extends State<ListaLegajosDocenteScreen> {
  List<Map<String, dynamic>> _legajos = [];

  @override
  void initState() {
    super.initState();
    _cargarLegajos();
  }

  Future<void> _cargarLegajos() async {
    final list = await InstitucionesService.getLegajosDocente(widget.cuit);
    if (mounted) setState(() => _legajos = list);
  }

  Future<void> _eliminarLegajo(int index) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: AppColors.backgroundLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Confirmar eliminación', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        content: Text('¿Eliminar a ${_legajos[index]['nombre']}?', style: const TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar', style: TextStyle(color: AppColors.textSecondary))),
          ElevatedButton(onPressed: () => Navigator.pop(c, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text('Eliminar')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final cuil = (_legajos[index]['cuil']?.toString() ?? '').replaceAll(RegExp(r'[^\d]'), '');
    await InstitucionesService.removeLegajoDocente(widget.cuit, cuil);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Legajo eliminado'), backgroundColor: AppColors.glassFillStrong, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))));
    _cargarLegajos();
  }

  String _formatearCUIL(String s) {
    final d = s.replaceAll(RegExp(r'[^\d]'), '');
    if (d.length != 11) return s;
    return '${d.substring(0, 2)}-${d.substring(2, 10)}-${d.substring(10)}';
  }

  Future<void> _irANuevoLegajo() async {
    final r = await Navigator.push(context, MaterialPageRoute(builder: (c) => LegajoDocenteFormScreen(cuitInstitucion: widget.cuit)));
    if (!mounted) return;
    if (r == 'ficha_creada') {
      Navigator.pop(context, 'ficha_creada');
      return;
    }
    if (r == true) _cargarLegajos();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.glassFillStrong, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.glassBorder)), child: const Icon(Icons.arrow_back, color: AppColors.textPrimary)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Legajos — ${widget.razonSocial ?? widget.cuit}', style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.pastelBlue.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.pastelBlue)), child: const Icon(Icons.add, color: AppColors.pastelBlue)),
            tooltip: 'Agregar legajo',
            onPressed: _irANuevoLegajo,
          ),
        ],
      ),
      body: _legajos.isEmpty
          ? Center(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Container(padding: const EdgeInsets.all(24), decoration: const BoxDecoration(color: AppColors.glassFillStrong, shape: BoxShape.circle), child: const Icon(Icons.people_outline, size: 64, color: AppColors.textMuted)),
                const SizedBox(height: 24),
                const Text('No hay legajos cargados', style: TextStyle(color: AppColors.textSecondary, fontSize: 18)),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _irANuevoLegajo,
                  icon: const Icon(Icons.add, size: 20),
                  label: const Text('Agregar legajo'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.pastelBlue,
                    foregroundColor: AppColors.background,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ]),
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 700;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.icon(
                          onPressed: _irANuevoLegajo,
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Agregar legajo'),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.pastelBlue,
                            foregroundColor: AppColors.background,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: isWide
                          ? SingleChildScrollView(
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              child: DataTable(
                      headingRowColor: MaterialStateProperty.all(AppColors.glassFillStrong),
                      columns: const [
                        DataColumn(label: Text('Nombre', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('CUIL', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Cargo', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('', style: TextStyle(color: AppColors.textPrimary))),
                      ],
                      rows: _legajos.asMap().entries.map((e) {
                        final l = e.value;
                        final i = e.key;
                        return DataRow(
                          cells: [
                            DataCell(Text(l['nombre']?.toString() ?? '—', style: const TextStyle(color: AppColors.textPrimary))),
                            DataCell(Text(_formatearCUIL(l['cuil']?.toString() ?? ''), style: const TextStyle(color: AppColors.textSecondary))),
                            DataCell(Text(l['cargo']?.toString() ?? '—', style: const TextStyle(color: AppColors.textSecondary))),
                            DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                              IconButton(icon: const Icon(Icons.edit, color: AppColors.pastelBlue, size: 20), onPressed: () async {
                                final r = await Navigator.push(context, MaterialPageRoute(builder: (c) => LegajoDocenteFormScreen(cuitInstitucion: widget.cuit, legajoExistente: l)));
                                if (r == true && mounted) _cargarLegajos();
                              }),
                              IconButton(icon: const Icon(Icons.delete, color: Colors.red, size: 20), onPressed: () => _eliminarLegajo(i)),
                            ])),
                          ],
                        );
                      }).toList(),
                            ),
                          )
                          : ListView.builder(
                              padding: const EdgeInsets.all(20),
                              itemCount: _legajos.length,
                              itemBuilder: (context, index) {
                                final l = _legajos[index];
                                final cuilF = _formatearCUIL(l['cuil']?.toString() ?? '');
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  decoration: BoxDecoration(color: AppColors.glassFillStrong, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.glassBorder)),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    leading: CircleAvatar(backgroundColor: AppColors.pastelBlue.withValues(alpha: 0.2), child: Text((l['nombre']?.toString().substring(0, 1) ?? '?').toUpperCase(), style: const TextStyle(color: AppColors.pastelBlue, fontWeight: FontWeight.bold))),
                                    title: Text(l['nombre']?.toString() ?? 'Sin nombre', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
                                    subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      if (cuilF.isNotEmpty) Text('CUIL: $cuilF', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                                      if (l['cargo']?.toString().isNotEmpty ?? false) Text('Cargo: ${l['cargo']}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                                    ]),
                                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                                      IconButton(icon: const Icon(Icons.edit, color: AppColors.pastelBlue, size: 20), onPressed: () async {
                                        final r = await Navigator.push(context, MaterialPageRoute(builder: (c) => LegajoDocenteFormScreen(cuitInstitucion: widget.cuit, legajoExistente: l)));
                                        if (r == true && mounted) _cargarLegajos();
                                      }),
                                      IconButton(icon: const Icon(Icons.delete, color: Colors.red, size: 20), onPressed: () => _eliminarLegajo(index)),
                                    ]),
                                    onTap: () async {
                                      final r = await Navigator.push(context, MaterialPageRoute(builder: (c) => LegajoDocenteFormScreen(cuitInstitucion: widget.cuit, legajoExistente: l)));
                                      if (r == true && mounted) _cargarLegajos();
                                    },
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}
