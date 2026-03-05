
import 'package:flutter/material.dart';
import '../models/module_info.dart';
import '../theme/app_colors.dart';

// Importa todas las pantallas que se usarán en los módulos.
import '../screens/empresa_screen.dart';
import '../screens/validador_lsd_screen.dart';
import '../screens/verificador_recibo_screen.dart';
import '../screens/centro_liquidacion_screen.dart'; // ¡NUEVA PANTALLA!
import '../screens/convenios_screen.dart';
import '../screens/teacher_interface_screen.dart';
import '../screens/sanidad_interface_screen.dart';
import '../screens/gestion_empleados_screen.dart';
import '../screens/liquidacion_masiva_screen.dart';
import '../screens/dashboard_gerencial_screen.dart';
import '../screens/gestion_conceptos_screen.dart';
import '../screens/gestion_ausencias_screen.dart';
import '../screens/gestion_prestamos_screen.dart';
import '../screens/biblioteca_cct_screen.dart';
import '../screens/buscador_categorias_screen.dart';
import '../screens/dashboard_riesgos_screen.dart';

/// Lista centralizada de todos los módulos disponibles en la aplicación.
final List<ModuleInfo> appModules = [
  ModuleInfo(
    title: 'Tu Empresa',
    subtitle: 'Configura los datos de tu empresa',
    icon: Icons.business_center,
    iconColor: AppColors.accentBlue,
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
    buildRoute: (context) => const CentroLiquidacionScreen(), // ¡CAMBIO REALIZADO!
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
    buildRoute: (context) => const TeacherInterfaceScreen(),
  ),
  ModuleInfo(
    title: 'Liquidación Sanidad 2026',
    subtitle: 'Sistema de liquidación para sanidad',
    icon: Icons.local_hospital,
    iconColor: AppColors.accentPink,
    isPremium: true,
    buildRoute: (context) => const SanidadInterfaceScreen(),
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
    buildRoute: (context) => const LiquidacionMasivaScreen(),
  ),
  ModuleInfo(
    title: 'Dashboard Gerencial',
    subtitle: 'Reportes y gráficos ejecutivos',
    icon: Icons.dashboard,
    iconColor: const Color(0xFF9333EA),
    isPremium: true,
    buildRoute: (context) => const DashboardGerencialScreen(),
  ),
  ModuleInfo(
    title: 'Conceptos Recurrentes',
    subtitle: 'Vales, sindicato, embargos automáticos',
    icon: Icons.receipt_long,
    iconColor: AppColors.accentEmerald,
    isPremium: true,
    buildRoute: (context) => const GestionConceptosScreen(),
  ),
  ModuleInfo(
    title: 'Ausencias y Licencias',
    subtitle: 'Gestión de ausencias con aprobación',
    icon: Icons.event_busy,
    iconColor: const Color(0xFF14B8A6),
    isPremium: true,
    buildRoute: (context) => const GestionAusenciasScreen(),
  ),
  ModuleInfo(
    title: 'Préstamos',
    subtitle: 'Préstamos con cuotas automáticas',
    icon: Icons.attach_money,
    iconColor: const Color(0xFF6366F1),
    isPremium: true,
    buildRoute: (context) => const GestionPrestamosScreen(),
  ),
  ModuleInfo(
    title: 'Biblioteca CCT',
    subtitle: 'Convenios actualizados vía robot BAT',
    icon: Icons.library_books,
    iconColor: const Color(0xFF92400E),
    isPremium: true,
    buildRoute: (context) => const BibliotecaCCTScreen(),
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
