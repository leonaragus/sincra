// Teacher Interface - Liquidación Docente Federal 2026
// Pantalla con 4 botones: Crear institución, Institución ya creada, Opciones de liquidación, Tutorial.

import 'package:flutter/material.dart';
import '../services/instituciones_service.dart';
import '../theme/app_colors.dart';
import '../utils/app_help.dart';
import 'institucion_form_screen.dart';
import 'lista_legajos_docente_screen.dart';
import 'liquidacion_docente_screen.dart';
import 'opciones_liquidacion_docente_screen.dart';
import 'profile_screen.dart';

class TeacherInterfaceScreen extends StatefulWidget {
  const TeacherInterfaceScreen({super.key});

  @override
  State<TeacherInterfaceScreen> createState() => _TeacherInterfaceScreenState();
}

class _TeacherInterfaceScreenState extends State<TeacherInterfaceScreen> {
  List<Map<String, dynamic>> _instituciones = [];
  /// CUIT (solo dígitos) -> cantidad de empleados/legajos
  Map<String, int> _empleadosPorInstitucion = {};
  
  /// Controlador para el menú hamburguesa
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _cargarInstituciones();
  }

  Future<void> _cargarInstituciones() async {
    final list = await InstitucionesService.getInstituciones();
    final counts = <String, int>{};
    for (final e in list) {
      final cuit = (e['cuit']?.toString() ?? '').replaceAll(RegExp(r'[^\d]'), '');
      if (cuit.isNotEmpty) {
        final legajos = await InstitucionesService.getLegajosDocente(cuit);
        counts[cuit] = legajos.length;
      }
    }
    if (mounted) setState(() {
      _instituciones = list;
      _empleadosPorInstitucion = counts;
    });
  }

  Future<void> _eliminarInstitucionPorCuit(String cuit) async {
    final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      title: const Text('Eliminar institución'),
      content: const Text('¿Eliminar esta institución? Los legajos asociados no se borran.'),
      actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')), TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Eliminar'))],
    ));
    if (ok != true || !mounted) return;
    await InstitucionesService.removeInstitucion(cuit);
    await _cargarInstituciones();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Institución eliminada')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.glassFillStrong, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.glassBorder)), child: const Icon(Icons.arrow_back, color: AppColors.textPrimary)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Liquidación Docente Federal 2026', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.glassFillStrong,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: const Icon(Icons.menu, color: AppColors.textPrimary, size: 22),
            ),
            onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
          ),
        ],
      ),
      endDrawer: _buildMenuHamburguesa(),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildBotonesPrincipales(),
        ],
      ),
    );
  }

  /// 4 botones: Crear institución, Institución ya creada, Opciones de liquidación, Tutorial.
  Widget _buildBotonesPrincipales() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.glassFillStrong,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.glassBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final r = await Navigator.push(context, MaterialPageRoute(builder: (c) => const InstitucionFormScreen()));
                    if (r == true && mounted) await _cargarInstituciones();
                  },
                  icon: const Icon(Icons.add, size: 22),
                  label: const Text('Crear institución'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: AppColors.glassBorder),
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _mostrarModalInstitucionesExistentes,
                  icon: const Icon(Icons.business, size: 22),
                  label: const Text('Institución ya creada'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: AppColors.glassBorder),
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildCartelResumen(),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _onOpcionesLiquidacionTap,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.pastelMint,
                foregroundColor: AppColors.background,
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 32),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              child: const Text('Opciones de liquidación'),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _onTutorialTap,
            icon: const Icon(Icons.menu_book, size: 22),
            label: const Text('Tutorial'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textPrimary,
              side: const BorderSide(color: AppColors.glassBorder),
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ],
      ),
    );
  }

  /// Cartel informativo: cantidad de instituciones y empleados por institución.
  /// Si no hay institución o no hay empleados, muestra botón Crear institución / Agregar empleados.
  Widget _buildCartelResumen() {
    final totalEmpleados = _instituciones.fold<int>(0, (s, e) => s + (_empleadosPorInstitucion[(e['cuit']?.toString() ?? '').replaceAll(RegExp(r'[^\d]'), '')] ?? 0));
    final faltaInstitucion = _instituciones.isEmpty;
    final faltaEmpleados = _instituciones.isNotEmpty && totalEmpleados < 1;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.pastelBlue.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.pastelBlue.withValues(alpha: 0.5), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  _instituciones.isEmpty
                      ? '0 instituciones cargadas'
                      : '${_instituciones.length} ${_instituciones.length == 1 ? 'institución cargada' : 'instituciones cargadas'}',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                ),
              ),
              if (faltaInstitucion)
                TextButton(
                  onPressed: () async {
                    final r = await Navigator.push(context, MaterialPageRoute(builder: (c) => const InstitucionFormScreen()));
                    if (r == true && mounted) await _cargarInstituciones();
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.pastelBlue,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Crear institución', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                )
              else if (faltaEmpleados && _instituciones.isNotEmpty) ...[
                TextButton(
                  onPressed: () async {
                    if (_instituciones.length > 1) {
                      _mostrarElegirInstitucionParaLegajo();
                    } else {
                      final e = _instituciones.first;
                      final cuit = (e['cuit']?.toString() ?? '').replaceAll(RegExp(r'[^\d]'), '');
                      final razon = e['razonSocial']?.toString() ?? cuit;
                      await Navigator.push(context, MaterialPageRoute(builder: (c) => ListaLegajosDocenteScreen(cuit: cuit, razonSocial: razon)));
                      if (mounted) await _cargarInstituciones();
                    }
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.pastelBlue,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Agregar empleados', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                ),
              ],
            ],
          ),
          if (_instituciones.isNotEmpty) ...[
            const SizedBox(height: 8),
            ..._instituciones.map((e) {
              final cuit = (e['cuit']?.toString() ?? '').replaceAll(RegExp(r'[^\d]'), '');
              final razon = e['razonSocial']?.toString() ?? cuit;
              final cant = _empleadosPorInstitucion[cuit] ?? 0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '• $razon: $cant ${cant == 1 ? 'empleado' : 'empleados'}',
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  void _onTutorialTap() {
    final helpContent = AppHelp.getHelpContent('teacher_interface');
    AppHelp.showHelpDialog(context, helpContent['title']!, helpContent['content']!);
  }

  /// Construye el menú hamburguesa lateral con todas las opciones
  Widget _buildMenuHamburguesa() {
    return Drawer(
      backgroundColor: AppColors.backgroundLight,
      surfaceTintColor: AppColors.backgroundLight,
      width: 300,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Encabezado del menú
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.glassFillStrong,
                border: Border(bottom: BorderSide(color: AppColors.glassBorder)),
              ),
              child: const Text(
                'Panel Docente',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ),

            // Sección de Navegación Principal
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                'NAVEGACIÓN',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                  letterSpacing: 1.2,
                ),
              ),
            ),

            // Botones principales
            _buildMenuItem(
              icon: Icons.add,
              label: 'Crear Nueva Institución',
              onTap: () async {
                Navigator.pop(context); // Cerrar menú
                final r = await Navigator.push(context, MaterialPageRoute(builder: (c) => const InstitucionFormScreen()));
                if (r == true && mounted) await _cargarInstituciones();
              },
            ),

            _buildMenuItem(
              icon: Icons.business,
              label: 'Gestionar Instituciones',
              onTap: () {
                Navigator.pop(context); // Cerrar menú
                _mostrarModalInstitucionesExistentes();
              },
            ),

            _buildMenuItem(
              icon: Icons.people,
              label: 'Gestión de Empleados',
              onTap: () {
                Navigator.pop(context); // Cerrar menú
                if (_instituciones.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Primero debe crear una institución')),
                  );
                } else if (_instituciones.length == 1) {
                  final e = _instituciones.first;
                  final cuit = (e['cuit']?.toString() ?? '').replaceAll(RegExp(r'[^\d]'), '');
                  final razon = e['razonSocial']?.toString() ?? cuit;
                  Navigator.push(context, MaterialPageRoute(builder: (c) => ListaLegajosDocenteScreen(cuit: cuit, razonSocial: razon)));
                } else {
                  _mostrarElegirInstitucionParaLegajo();
                }
              },
            ),

            _buildMenuItem(
              icon: Icons.calculate,
              label: 'Opciones de Liquidación',
              onTap: () {
                Navigator.pop(context); // Cerrar menú
                _onOpcionesLiquidacionTap();
              },
            ),

            const Divider(height: 24, color: AppColors.glassBorder),

            // Sección de Ayuda
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Text(
                'AYUDA',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                  letterSpacing: 1.2,
                ),
              ),
            ),

            _buildMenuItem(
              icon: Icons.help,
              label: 'Manual de Usuario',
              onTap: () {
                Navigator.pop(context); // Cerrar menú
                final helpContent = AppHelp.getHelpContent('teacher_interface');
                AppHelp.showHelpDialog(context, helpContent['title']!, helpContent['content']!);
              },
            ),

            _buildMenuItem(
              icon: Icons.info,
              label: 'Acerca del Sistema',
              onTap: () {
                Navigator.pop(context); // Cerrar menú
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Liquidación Docente Federal 2026'),
                    content: const Text('Sistema profesional para liquidación de haberes docentes según convenios nacionales vigentes.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cerrar'),
                      ),
                    ],
                  ),
                );
              },
            ),

            const Divider(height: 24, color: AppColors.glassBorder),

            // Sección de Cuenta
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Text(
                'CUENTA',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                  letterSpacing: 1.2,
                ),
              ),
            ),

            _buildMenuItem(
              icon: Icons.person,
              label: 'Mi Perfil y Suscripción',
              onTap: () {
                Navigator.pop(context); // Cerrar menú
                Navigator.push(context, MaterialPageRoute(builder: (c) => const ProfileScreen()));
              },
            ),

            // Espaciador final
            const Spacer(),

            // Footer con información
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.glassFillStrong,
                border: Border(top: BorderSide(color: AppColors.glassBorder)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_instituciones.length} Institución${_instituciones.length != 1 ? 'es' : ''}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_empleadosPorInstitucion.values.fold<int>(0, (sum, count) => sum + count)} Empleados',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
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

  /// Widget auxiliar para items del menú
  Widget _buildMenuItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.glassFillStrong,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Icon(icon, size: 20, color: AppColors.textPrimary),
      ),
      title: Text(
        label,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
        ),
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }

  void _mostrarElegirInstitucionParaLegajo() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.6),
        decoration: BoxDecoration(
          color: AppColors.backgroundLight,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text(
                        '¿A cuál institución deseas añadir el empleado?',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                    ),
                    IconButton(icon: const Icon(Icons.close, color: AppColors.textPrimary), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: _instituciones.length,
                  itemBuilder: (_, i) {
                    final e = _instituciones[i];
                    final cuit = (e['cuit']?.toString() ?? '').replaceAll(RegExp(r'[^\d]'), '');
                    final razon = e['razonSocial']?.toString() ?? cuit;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: AppColors.glassFill,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.glassBorder),
                      ),
                      child: ListTile(
                        leading: const CircleAvatar(backgroundColor: AppColors.glassFillStrong, child: Icon(Icons.business, color: AppColors.textSecondary)),
                        title: Text(razon, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
                        subtitle: Text('CUIT: ${e['cuit'] ?? ''}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                        trailing: const Text('Añadir empleado aquí', style: TextStyle(fontSize: 12, color: AppColors.pastelBlue)),
                        onTap: () async {
                          Navigator.pop(ctx);
                          await Navigator.push(context, MaterialPageRoute(builder: (c) => ListaLegajosDocenteScreen(cuit: cuit, razonSocial: razon)));
                          if (mounted) await _cargarInstituciones();
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _mostrarModalInstitucionesExistentes() {
    final parentContext = context;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.6),
        decoration: BoxDecoration(
          color: AppColors.backgroundLight,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Institución ya creada', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                    IconButton(icon: const Icon(Icons.close, color: AppColors.textPrimary), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
              ),
              Flexible(
                child: _instituciones.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.business_center, size: 48, color: AppColors.textMuted),
                            const SizedBox(height: 12),
                            const Text('No hay instituciones. Use "Crear institución" para agregar una.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        itemCount: _instituciones.length,
                        itemBuilder: (_, i) {
                          final e = _instituciones[i];
                          final cuit = (e['cuit']?.toString() ?? '').replaceAll(RegExp(r'[^\d]'), '');
                          final razon = e['razonSocial']?.toString() ?? cuit;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(color: AppColors.glassFill, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.glassBorder)),
                            child: ListTile(
                              leading: const CircleAvatar(backgroundColor: AppColors.glassFillStrong, child: Icon(Icons.business, color: AppColors.textSecondary)),
                              title: Text(razon, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
                              subtitle: Text('CUIT: ${e['cuit'] ?? ''}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                                TextButton.icon(
                                  onPressed: () async {
                                    final res = await Navigator.push(context, MaterialPageRoute(builder: (c) => ListaLegajosDocenteScreen(cuit: cuit, razonSocial: razon)));
                                    if (mounted) {
                                      if (res == 'ficha_creada') {
                                        Navigator.pop(ctx);
                                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ficha creada con éxito'), backgroundColor: AppColors.glassFillStrong, behavior: SnackBarBehavior.floating));
                                      }
                                      await _cargarInstituciones();
                                    }
                                  },
                                  icon: const Icon(Icons.people, color: AppColors.pastelBlue, size: 18),
                                  label: const Text('Ver legajos', style: TextStyle(fontSize: 12, color: AppColors.pastelBlue)),
                                  style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8), minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                                ),
                                TextButton.icon(
                                  onPressed: () async {
                                    Navigator.pop(ctx);
                                    final r = await Navigator.push(parentContext, MaterialPageRoute(builder: (c) => InstitucionFormScreen(institucion: e)));
                                    if (r == true && mounted) await _cargarInstituciones();
                                  },
                                  icon: const Icon(Icons.edit, color: AppColors.textPrimary, size: 18),
                                  label: const Text('Editar', style: TextStyle(fontSize: 12, color: AppColors.textPrimary)),
                                  style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8), minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                                ),
                                IconButton(icon: const Icon(Icons.delete, color: AppColors.textSecondary, size: 20), tooltip: 'Eliminar', onPressed: () async {
                                  await _eliminarInstitucionPorCuit(cuit);
                                  if (mounted) Navigator.pop(ctx);
                                }),
                              ]),
                              onTap: () {
                                Navigator.pop(ctx);
                                Navigator.push(context, MaterialPageRoute(
                                  builder: (c) => LiquidacionDocenteScreen(cuitInstitucion: cuit, razonSocial: razon),
                                ));
                              },
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onOpcionesLiquidacionTap() async {
    if (_instituciones.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor crear primero la ficha de la institución')),
      );
      return;
    }
    bool algunaTieneEmpleados = false;
    for (final inst in _instituciones) {
      final cuit = (inst['cuit']?.toString() ?? '').replaceAll(RegExp(r'[^\d]'), '');
      if (cuit.isEmpty) continue;
      final legajos = await InstitucionesService.getLegajosDocente(cuit);
      if (legajos.isNotEmpty) {
        algunaTieneEmpleados = true;
        break;
      }
    }
    if (!algunaTieneEmpleados) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Es necesario que agregue empleados a la institución')),
      );
      return;
    }
    if (!mounted) return;
    Navigator.push(context, MaterialPageRoute(
      builder: (c) => const OpcionesLiquidacionDocenteScreen(),
    ));
  }
}
