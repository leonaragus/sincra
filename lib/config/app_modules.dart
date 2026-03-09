
import 'package:flutter/material.dart';
import '../models/module_info.dart';
import '../theme/app_colors.dart';

// Importa todas las pantallas que se usarán en los módulos.
import '../screens/empresa_screen.dart';
import '../screens/validador_lsd_screen.dart';
import '../screens/verificador_recibo_screen.dart';
import '../screens/centro_liquidacion_screen.dart' deferred as centro; // ¡NUEVA PANTALLA!
import '../screens/convenios_screen.dart';
import '../screens/teacher_interface_screen.dart' deferred as teacher;
import '../screens/sanidad_interface_screen.dart' deferred as sanidad;
import '../screens/gestion_empleados_screen.dart';
import '../screens/liquidacion_masiva_screen.dart' deferred as masiva;
import '../screens/dashboard_gerencial_screen.dart' deferred as dashboard;
import '../screens/gestion_conceptos_screen.dart';
import '../screens/gestion_ausencias_screen.dart';
import '../screens/gestion_prestamos_screen.dart';
import '../screens/cct_scan_screen.dart';
import '../screens/buscador_categorias_screen.dart';
import '../screens/dashboard_riesgos_screen.dart';
import '../services/hybrid_store.dart';

/// Lista centralizada de todos los módulos disponibles en la aplicación.
class _DeferredRoute extends StatelessWidget {
  final Future<void> Function() loader;
  final Widget Function() builder;
  const _DeferredRoute({required this.loader, required this.builder});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: loader(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return builder();
      },
    );
  }
}
final List<ModuleInfo> appModules = [
  ModuleInfo(
    title: 'Tu Empresa',
    subtitle: 'Configura los datos de tu empresa',
    icon: Icons.business_center,
    iconColor: AppColors.accentBlue,
    isPremium: true,
    buildRoute: (context) => const EmpresaScreen(),
  ),
  ModuleInfo(
    title: 'Validador LSD ARCA',
    subtitle: 'Validador previo de archivos LSD 2026',
    icon: Icons.fact_check,
    iconColor: AppColors.accentBlue,
    isPremium: true,
    buildRoute: (context) => const ValidadorLSDScreen(),
  ),
  ModuleInfo(
    title: 'Verificador de Recibo',
    subtitle: 'Escaneá y verificá tu liquidación',
    icon: Icons.document_scanner_outlined,
    iconColor: AppColors.accentPink,
    buildRoute: (context) => const VerificadorReciboScreen(),
  ),
  ModuleInfo(
    title: 'Centro de Liquidación',
    subtitle: 'Genera las liquidaciones de empleados',
    icon: Icons.calculate,
    iconColor: AppColors.primary,
    isPremium: true,
    isHighlighted: true,
    buildRoute: (context) => _DeferredRoute(
      loader: centro.loadLibrary,
      builder: () => centro.CentroLiquidacionScreen(),
    ),
  ),
  ModuleInfo(
    title: 'Convenios',
    subtitle: 'Gestiona los convenios laborales',
    icon: Icons.description,
    iconColor: AppColors.accentYellow,
    isPremium: true,
    buildRoute: (context) => const ConveniosScreen(),
  ),
  ModuleInfo(
    title: 'Liquidación Docente 2026',
    subtitle: 'Sistema federal de liquidación docente',
    icon: Icons.school,
    iconColor: AppColors.accentEmerald,
    isPremium: true,
    buildRoute: (context) => _DeferredRoute(
      loader: teacher.loadLibrary,
      builder: () => teacher.TeacherInterfaceScreen(),
    ),
  ),
  ModuleInfo(
    title: 'Liquidación Sanidad 2026',
    subtitle: 'Sistema de liquidación para sanidad',
    icon: Icons.local_hospital,
    iconColor: AppColors.accentPink,
    isPremium: true,
    buildRoute: (context) => _DeferredRoute(
      loader: sanidad.loadLibrary,
      builder: () => sanidad.SanidadInterfaceScreen(),
    ),
  ),
  ModuleInfo(
    title: 'Gestión de Empleados',
    subtitle: 'Base de datos completa de empleados',
    icon: Icons.people,
    iconColor: AppColors.accentBlue,
    isPremium: true,
    buildRoute: (context) => const GestionEmpleadosScreen(),
  ),
  ModuleInfo(
    title: 'Liquidación Masiva',
    subtitle: 'Procesa múltiples empleados en paralelo',
    icon: Icons.bolt,
    iconColor: AppColors.accentOrange,
    isPremium: true,
    isHighlighted: true,
    buildRoute: (context) => _DeferredRoute(
      loader: masiva.loadLibrary,
      builder: () => masiva.LiquidacionMasivaScreen(),
    ),
  ),
  ModuleInfo(
    title: 'Dashboard Gerencial',
    subtitle: 'Reportes y gráficos ejecutivos',
    icon: Icons.dashboard,
    iconColor: const Color(0xFF9333EA),
    isPremium: true,
    buildRoute: (context) => _DeferredRoute(
      loader: dashboard.loadLibrary,
      builder: () => dashboard.DashboardGerencialScreen(),
    ),
  ),
  ModuleInfo(
    title: 'Conceptos Recurrentes',
    subtitle: 'Vales, sindicato, embargos automáticos',
    icon: Icons.receipt_long,
    iconColor: AppColors.accentEmerald,
    isPremium: true,
    buildRoute: (context) => _EmpresaAwareRoute(
      builder: (cuit) => GestionConceptosScreen(empresaCuit: cuit),
    ),
  ),
  ModuleInfo(
    title: 'Ausencias y Licencias',
    subtitle: 'Gestión de ausencias con aprobación',
    icon: Icons.event_busy,
    iconColor: const Color(0xFF14B8A6),
    isPremium: true,
    buildRoute: (context) => _EmpresaAwareRoute(
      builder: (cuit) => GestionAusenciasScreen(empresaCuit: cuit),
    ),
  ),
  ModuleInfo(
    title: 'Préstamos',
    subtitle: 'Préstamos con cuotas automáticas',
    icon: Icons.attach_money,
    iconColor: const Color(0xFF6366F1),
    isPremium: true,
    buildRoute: (context) => _EmpresaAwareRoute(
      builder: (cuit) => GestionPrestamosScreen(empresaCuit: cuit),
    ),
  ),
  ModuleInfo(
    title: 'Biblioteca CCT',
    subtitle: 'Convenios actualizados vía robot BAT',
    icon: Icons.library_books,
    iconColor: const Color(0xFF92400E),
    isPremium: true,
    buildRoute: (context) => const CctScanScreen(),
  ),
  ModuleInfo(
    title: 'Buscador de Categorías',
    subtitle: 'Encontrá tu categoría por tareas',
    icon: Icons.search,
    iconColor: AppColors.accentBlue,
    isHighlighted: true,
    buildRoute: (context) => const BuscadorCategoriasScreen(),
  ),
  ModuleInfo(
    title: 'Dashboard de Riesgos',
    subtitle: 'Alertas y advertencias del sistema',
    icon: Icons.warning_amber,
    iconColor: Colors.red[700]!,
    isPremium: true,
    isHighlighted: true,
    buildRoute: (context) => const DashboardRiesgosScreen(),
  ),
];

class _EmpresaAwareRoute extends StatelessWidget {
  final Widget Function(String empresaCuit) builder;
  const _EmpresaAwareRoute({required this.builder});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, String>>>(
      future: HybridStore.getEmpresas(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final empresas = snapshot.data ?? const [];
        if (empresas.isEmpty) {
          return const EmpresaScreen();
        }
        final cuit = (empresas.first['cuit'] ?? '').replaceAll(RegExp(r'[^\d]'), '');
        return builder(cuit);
      },
    );
  }
}
