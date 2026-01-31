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
    // Cargar convenios de la empresa si existen
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 24),
                        _buildMainButtons(),
                        if (_empresas.isNotEmpty) ...[
                          const SizedBox(height: 32),
                          _buildEmpresasSection(),
                        ],
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

  Widget _buildMainButtons() {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isTablet = screenWidth > 600;
    final isDesktop = screenWidth > 900;
    
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = isDesktop ? 3 : (isTablet ? 2 : 1);
        final childAspectRatio = isDesktop ? 1.2 : (isTablet ? 1.1 : 1.0);
        
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: childAspectRatio,
          children: [
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
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ConveniosScreen(),
                  ),
                );
              },
            ),
            _buildModernCard(
              title: 'Liquidación Docente 2026',
              subtitle: 'Sistema federal de liquidación docente',
              icon: Icons.school,
              iconColor: AppColors.accentEmerald,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const TeacherInterfaceScreen(),
                  ),
                );
              },
            ),
            _buildModernCard(
              title: 'Liquidación Sanidad 2026',
              subtitle: 'Sistema de liquidación para sanidad',
              icon: Icons.local_hospital,
              iconColor: AppColors.accentPink,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SanidadInterfaceScreen(),
                  ),
                );
              },
            ),
            
            // === SPRINT 2 + 3: NUEVAS FUNCIONALIDADES ===
            
            _buildModernCard(
              title: 'Gestión de Empleados',
              subtitle: 'Base de datos completa de empleados',
              icon: Icons.people,
              iconColor: AppColors.accentBlue,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const GestionEmpleadosScreen(),
                  ),
                );
              },
            ),
            _buildModernCard(
              title: 'Liquidación Masiva',
              subtitle: 'Procesa múltiples empleados en paralelo',
              icon: Icons.bolt,
              iconColor: AppColors.accentOrange,
              isHighlighted: true,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const LiquidacionMasivaScreen(),
                  ),
                );
              },
            ),
            _buildModernCard(
              title: 'Dashboard Gerencial',
              subtitle: 'Reportes y gráficos ejecutivos',
              icon: Icons.dashboard,
              iconColor: Color(0xFF9333EA), // Purple
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DashboardGerencialScreen(),
                  ),
                );
              },
            ),
            _buildModernCard(
              title: 'Conceptos Recurrentes',
              subtitle: 'Vales, sindicato, embargos automáticos',
              icon: Icons.receipt_long,
              iconColor: AppColors.accentEmerald,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const GestionConceptosScreen(),
                  ),
                );
              },
            ),
            _buildModernCard(
              title: 'Ausencias y Licencias',
              subtitle: 'Gestión de ausencias con aprobación',
              icon: Icons.event_busy,
              iconColor: Color(0xFF14B8A6), // Teal
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const GestionAusenciasScreen(),
                  ),
                );
              },
            ),
            _buildModernCard(
              title: 'Préstamos',
              subtitle: 'Préstamos con cuotas automáticas',
              icon: Icons.attach_money,
              iconColor: Color(0xFF6366F1), // Indigo
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const GestionPrestamosScreen(),
                  ),
                );
              },
            ),
            _buildModernCard(
              title: 'Biblioteca CCT',
              subtitle: 'Convenios actualizados vía robot BAT',
              icon: Icons.library_books,
              iconColor: Color(0xFF92400E), // Brown
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const BibliotecaCCTScreen(),
                  ),
                );
              },
            ),
            _buildModernCard(
              title: 'Verificador de Recibo',
              subtitle: 'Escaneá y verificá tu liquidación',
              icon: Icons.document_scanner_outlined,
              iconColor: AppColors.accentPink,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const VerificadorReciboScreen(),
                  ),
                );
              },
            ),
            
            // === SPRINT 4 + 5: VALIDACIONES Y ALERTAS ===
            
            _buildModernCard(
              title: 'Dashboard de Riesgos',
              subtitle: 'Alertas y advertencias del sistema',
              icon: Icons.warning_amber,
              iconColor: Colors.red[700]!,
              isHighlighted: true,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DashboardRiesgosScreen(),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildModernCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
    bool isHighlighted = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isHighlighted
                  ? AppColors.primary.withOpacity(0.5)
                  : AppColors.glassBorder,
              width: isHighlighted ? 2 : 1,
            ),
            color: isHighlighted
                ? AppColors.primary.withOpacity(0.2)
                : AppColors.glassFill,
            gradient: isHighlighted
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primary.withOpacity(0.2),
                      AppColors.accentOrange.withOpacity(0.15),
                    ],
                  )
                : null,
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: isHighlighted ? 32 : 24,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: isHighlighted ? 18 : 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
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
