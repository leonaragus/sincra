import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui';
import 'dart:convert';
import 'empresa_screen.dart';
import '../services/hybrid_store.dart';
import 'convenios_screen.dart';
import '../models/empresa.dart';
import '../services/api_service.dart';
import '../services/subscription_service.dart';
import '../theme/app_colors.dart';
import 'empleado_screen.dart';
import 'lista_empleados_screen.dart';
import 'liquidador_final_screen.dart';
import 'parametros_legales_screen.dart';
import 'teacher_interface_screen.dart';
import 'sanidad_interface_screen.dart';
import '../utils/logo_avatar.dart';
import '../utils/app_help.dart';

// Sprint 1 + 2 + 3 + 4 + 5
import 'gestion_empleados_screen.dart';
import 'liquidacion_masiva_screen.dart';
import 'dashboard_gerencial_screen.dart';
import 'gestion_conceptos_screen.dart';
import 'gestion_ausencias_screen.dart';
import 'gestion_prestamos_screen.dart';
import 'biblioteca_cct_screen.dart';
import 'dashboard_riesgos_screen.dart';
import 'verificador_recibo_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  List<Map<String, String>> _empresas = [];

  @override
  void initState() {
    super.initState();
    _cargarEmpresas();
    _maybeShowUpdateSnackBar();
  }

  Future<void> _maybeShowUpdateSnackBar() async {
    final should = await ApiService.shouldShowUpdateSnackBar();
    if (!should || !mounted) return;
    final date = await ApiService.getUpdateSnackBarDate();
    await ApiService.clearShowUpdateSnackBar();
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _showUpdateSnackBar(date ?? '');
    });
  }

  void _showUpdateSnackBar(String date) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          date.isNotEmpty
              ? 'Convenios actualizados al $date'
              : 'Convenios actualizados',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.glassFillStrong,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.glassBorder, width: 1),
        ),
      ),
    );
  }

  Future<void> _cargarEmpresas() async {
    final list = await HybridStore.getEmpresas();
    if (mounted) setState(() => _empresas = list);
  }

  Future<void> _navegarAEmpresa(Map<String, String>? empresa) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EmpresaScreen(
          razonSocial: empresa?['razonSocial'],
          cuit: empresa?['cuit'],
          domicilio: empresa?['domicilio'],
          convenio: empresa?['convenio'],
          logoPath: empresa?['logoPath'],
          firmaPath: empresa?['firmaPath'],
        ),
      ),
    );
    if (result == true || empresa == null) {
      _cargarEmpresas();
    }
  }

  Future<void> _eliminarEmpresa(int index) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar eliminación'),
        content: Text(
          '¿Está seguro de eliminar ${_empresas[index]['razonSocial']}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmado == true) {
      final nueva = List<Map<String, String>>.from(_empresas)..removeAt(index);
      await HybridStore.saveEmpresas(nueva);
      _cargarEmpresas();
    }
  }

  Future<Empresa> _crearEmpresaDesdeMap(Map<String, String> empresaMap) async {
    final prefs = await SharedPreferences.getInstance();
    final razonSocial = empresaMap['razonSocial'] ?? '';
    final conveniosJson = prefs.getString('empresa_convenios_$razonSocial');
    
    String convenioId = empresaMap['convenio'] ?? '';
    String convenioNombre = empresaMap['convenio'] ?? '';
    
    if (conveniosJson != null && conveniosJson.isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(conveniosJson);
        if (decoded.isNotEmpty) {
          convenioId = decoded.first.toString();
          convenioNombre = decoded.first.toString();
        }
      } catch (e) {
        // Usar valor por defecto
      }
    }
    
    return Empresa(
      razonSocial: razonSocial,
      cuit: empresaMap['cuit'] ?? '',
      domicilio: empresaMap['domicilio'] ?? '',
      convenioId: convenioId,
      convenioNombre: convenioNombre,
      convenioPersonalizado: false,
      logoPath: empresaMap['logoPath'] == 'No disponible'
          ? null
          : empresaMap['logoPath'],
      categorias: [],
      parametros: [],
    );
  }

  void _mostrarAyuda() {
    final helpContent = AppHelp.getHelpContent('home');
    AppHelp.showHelpDialog(
      context,
      helpContent['title']!,
      helpContent['content']!,
    );
  }

  void _irALiquidador() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const LiquidadorFinalScreen(),
      ),
    );
  }

  void _navegarVerificadorRecibo() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const VerificadorReciboScreen(),
      ),
    );
  }

  // NUEVO: módulos filtrados por plan, sin scroll, arriba
  Future<List<Widget>> _buildModuleList() async {
    final plan = await SubscriptionService.getCurrentUserPlan();
    final planType = (plan?['plan_type'] ?? 'free').toString();
    final isFree = planType == 'free';

    if (isFree) {
      // Plan free: solo Verificador de Recibo, arriba, grande
      return [
        _buildModernCard(
          title: 'Verificador de Recibo',
          subtitle: 'Escaneá y verificá tu liquidación',
          icon: Icons.document_scanner_outlined,
          iconColor: AppColors.accentPink,
          isHighlighted: true,
          onTap: _navegarVerificadorRecibo,
        ),
      ];
    } else {
      // Planes de pago: todos menos Verificador, apilados arriba
      return [
        _buildModernCard(
          title: 'Tu Empresa',
          subtitle: 'Configura los datos de tu empresa',
          icon: Icons.business_center,
          iconColor: AppColors.accentBlue,
          onTap: () => _navegarAEmpresa(null),
        ),
        _buildModernCard(
          title: 'Liquidador Final',
          subtitle: 'Genera las liquidaciones de empleados',
          icon: Icons.calculate,
          iconColor: AppColors.primary,
          isHighlighted: true,
          onTap: _irALiquidador,
        ),
        _buildModernCard(
          title: 'Convenios',
          subtitle: 'Gestiona los convenios laborales',
          icon: Icons.description,
          iconColor: AppColors.accentYellow,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ConveniosScreen())),
        ),
        _buildModernCard(
          title: 'Liquidación Docente 2026',
          subtitle: 'Sistema federal de liquidación docente',
          icon: Icons.school,
          iconColor: AppColors.accentEmerald,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TeacherInterfaceScreen())),
        ),
        _buildModernCard(
          title: 'Liquidación Sanidad 2026',
          subtitle: 'Sistema de liquidación para sanidad',
          icon: Icons.local_hospital,
          iconColor: AppColors.accentPink,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SanidadInterfaceScreen())),
        ),
        _buildModernCard(
          title: 'Gestión de Empleados',
          subtitle: 'Base de datos completa de empleados',
          icon: Icons.people,
          iconColor: AppColors.accentBlue,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GestionEmpleadosScreen())),
        ),
        _buildModernCard(
          title: 'Liquidación Masiva',
          subtitle: 'Procesa múltiples empleados en paralelo',
          icon: Icons.bolt,
          iconColor: AppColors.accentOrange,
          isHighlighted: true,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LiquidacionMasivaScreen())),
        ),
        _buildModernCard(
          title: 'Dashboard Gerencial',
          subtitle: 'Reportes y gráficos ejecutivos',
          icon: Icons.dashboard,
          iconColor: const Color(0xFF9333EA),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DashboardGerencialScreen())),
        ),
        _buildModernCard(
          title: 'Conceptos Recurrentes',
          subtitle: 'Vales, sindicato, embargos automáticos',
          icon: Icons.receipt_long,
          iconColor: AppColors.accentEmerald,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GestionConceptosScreen())),
        ),
        _buildModernCard(
          title: 'Ausencias y Licencias',
          subtitle: 'Gestión de ausencias con aprobación',
          icon: Icons.event_busy,
          iconColor: const Color(0xFF14B8A6),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GestionAusenciasScreen())),
        ),
        _buildModernCard(
          title: 'Préstamos',
          subtitle: 'Préstamos con cuotas automáticas',
          icon: Icons.attach_money,
          iconColor: const Color(0xFF6366F1),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GestionPrestamosScreen())),
        ),
        _buildModernCard(
          title: 'Biblioteca CCT',
          subtitle: 'Convenios actualizados vía robot BAT',
          icon: Icons.library_books,
          iconColor: const Color(0xFF92400E),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BibliotecaCCTScreen())),
        ),
        _buildModernCard(
          title: 'Dashboard de Riesgos',
          subtitle: 'Alertas y advertencias del sistema',
          icon: Icons.warning_amber,
          iconColor: Colors.red[700]!,
          isHighlighted: true,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DashboardRiesgosScreen())),
        ),
      ];
    }
  }

  // Módulos arriba, sin scroll
  Widget _buildMainButtons() {
    return FutureBuilder<List<Widget>>(
      future: _buildModuleList(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final modules = snapshot.data!;
        if (modules.isEmpty) {
          return const Center(child: Text('No hay módulos disponibles para tu plan.'));
        }
        // Sin GridView: tarjetas apiladas arriba, visibles sin scroll
        return Column(
          children: modules,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light.copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: AppColors.background,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            color: AppColors.background,
          ),
          child: SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                // Módulos arriba, sin scroll
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: _buildMainButtons(),
                ),
                // Empresas debajo (si hay)
                if (_empresas.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: _buildEmpresasSection(),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          final helpContent = AppHelp.getHelpContent('HomeScreen');
          AppHelp.showHelpDialog(
            context,
            helpContent['title']!,
            helpContent['content']!,
          );
        },
        backgroundColor: const Color(0xFF6366F1),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 8,
        child: const Icon(
          Icons.help_outline,
          size: 28,
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  // Resto de métodos sin cambios
  Widget _buildHeader() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.backgroundLight.withOpacity(0.5),
        border: Border(
          bottom: BorderSide(
            color: AppColors.glassBorder,
            width: 1,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.glassFill,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.glassBorder, width: 1),
              ),
              child: const Icon(
                Icons.account_balance_wallet,
                color: AppColors.textPrimary,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Syncra Arg',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
                letterSpacing: 0.5,
              ),
            ),
            const Spacer(),
            IconButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ParametrosLegalesScreen(),
                  ),
                );
              },
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.glassFill,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.glassBorder, width: 1),
                ),
                child: const Icon(
                  Icons.settings,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
              ),
              tooltip: 'Parámetros Legales',
            ),
            IconButton(
              onPressed: _mostrarAyuda,
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.glassFill,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.glassBorder, width: 1),
                ),
                child: const Icon(
                  Icons.help_outline,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpresasSection() {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isTablet = screenWidth > 600;
    final crossAxisCount = isTablet ? 2 : 1;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.glassFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Empresas Guardadas',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.glassFillStrong,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.glassBorder, width: 1),
                  ),
                  child: const Icon(
                    Icons.add,
                    color: AppColors.textPrimary,
                    size: 20,
                  ),
                ),
                onPressed: () => _navegarAEmpresa(null),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 2.5,
            ),
            itemCount: _empresas.length,
            itemBuilder: (context, index) {
              final empresa = _empresas[index];
              return _buildEmpresaCard(empresa, index);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmpresaCard(Map<String, String> empresa, int index) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          final empresaObj = await _crearEmpresaDesdeMap(empresa);
          if (!mounted) return;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EmpleadoScreen(
                empresa: empresaObj,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.glassFillStrong,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.glassBorder, width: 1),
          ),
          child: Row(
            children: [
              empresa['logoPath'] != null &&
                      empresa['logoPath'] != 'No disponible' &&
                      empresa['logoPath']!.isNotEmpty
                  ? buildLogoAvatar(empresa['logoPath']!)
                  : Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.glassFill,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.glassBorder, width: 1),
                      ),
                      child: const Icon(
                        Icons.business,
                        color: AppColors.textSecondary,
                        size: 20,
                      ),
                    ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      empresa['razonSocial'] ?? '',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'CUIT: ${empresa['cuit'] ?? ''}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.people,
                      color: AppColors.accentBlue,
                      size: 18,
                    ),
                    tooltip: 'Ver empleados',
                    onPressed: () async {
                      final empresaObj = await _crearEmpresaDesdeMap(empresa);
                      if (!mounted) return;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ListaEmpleadosScreen(
                            empresa: empresaObj,
                          ),
                        ),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.edit,
                      color: AppColors.textPrimary,
                      size: 18,
                    ),
                    onPressed: () => _navegarAEmpresa(empresa),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.delete,
                      color: AppColors.textSecondary,
                      size: 18,
                    ),
                    onPressed: () => _eliminarEmpresa(index),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}