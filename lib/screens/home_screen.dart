
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui';
import 'dart:convert';
import 'dart:async';
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
import '../models/subscription_plan.dart';
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
import 'buscador_categorias_screen.dart';
import 'dashboard_riesgos_screen.dart';

import 'verificador_recibo_screen.dart';
import 'validador_lsd_screen.dart';
import '../services/sync_service.dart';

import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'qr_scanner_screen.dart';
import '../services/web_auth_service.dart'; // <- Importar el nuevo servicio

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  List<Map<String, String>> _empresas = [];
  Future<void>? _initialSync;
  bool _isPremium = true;
  final _webAuthService = WebAuthService(); // <- Instancia del servicio

  @override
  void initState() {
    super.initState();
    _checkPremiumStatus();
    _cargarEmpresas();
    _initialSync = _syncAndMaybeShowSnackBar();
  }

  @override
  void dispose() {
    _webAuthService.dispose(); // <- Limpiar el servicio
    super.dispose();
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: isError ? Colors.redAccent : AppColors.primary,
    ));
  }

  Future<void> _checkPremiumStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final startDateStr = prefs.getString('onboarding_start_date');
    if (startDateStr != null) {
      final startDate = DateTime.parse(startDateStr);
      final now = DateTime.now();
      final difference = now.difference(startDate).inDays;
      
      if (difference > 30) {
        if (mounted) setState(() => _isPremium = false);
      }
    }
  }

  Future<void> _syncAndMaybeShowSnackBar() async {
    await ApiService.syncOrLoadLocal();
    await _maybeShowUpdateSnackBar();
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

  List<Widget> _buildModuleList() {
    return [
      _buildModernCard(
        title: 'Tu Empresa',
        subtitle: 'Configura los datos de tu empresa',
        icon: Icons.business_center,
        iconColor: AppColors.accentBlue,
        onTap: () => _navegarAEmpresa(null),
      ),
      if (_isPremium)
        _buildModernCard(
          title: 'Validador LSD ARCA',
          subtitle: 'Validador previo de archivos LSD 2026',
          icon: Icons.fact_check,
          iconColor: AppColors.accentBlue,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ValidadorLSDScreen())),
        ),
      _buildModernCard(
        title: 'Verificador de Recibo',
        subtitle: 'Escaneá y verificá tu liquidación',
        icon: Icons.document_scanner_outlined,
        iconColor: AppColors.accentPink,
        onTap: _navegarVerificadorRecibo,
      ),
      if (_isPremium)
        _buildModernCard(
          title: 'Liquidador Final',
          subtitle: 'Genera las liquidaciones de empleados',
          icon: Icons.calculate,
          iconColor: AppColors.primary,
          isHighlighted: true,
          onTap: _irALiquidador,
        ),
      if (_isPremium)
        _buildModernCard(
          title: 'Convenios',
          subtitle: 'Gestiona los convenios laborales',
          icon: Icons.description,
          iconColor: AppColors.accentYellow,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ConveniosScreen())),
        ),
      if (_isPremium)
        _buildModernCard(
          title: 'Liquidación Docente 2026',
          subtitle: 'Sistema federal de liquidación docente',
          icon: Icons.school,
          iconColor: AppColors.accentEmerald,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TeacherInterfaceScreen())),
        ),
      if (_isPremium)
        _buildModernCard(
          title: 'Liquidación Sanidad 2026',
          subtitle: 'Sistema de liquidación para sanidad',
          icon: Icons.local_hospital,
          iconColor: AppColors.accentPink,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SanidadInterfaceScreen())),
        ),
      if (_isPremium)
        _buildModernCard(
          title: 'Gestión de Empleados',
          subtitle: 'Base de datos completa de empleados',
          icon: Icons.people,
          iconColor: AppColors.accentBlue,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GestionEmpleadosScreen())),
        ),
      if (_isPremium)
        _buildModernCard(
          title: 'Liquidación Masiva',
          subtitle: 'Procesa múltiples empleados en paralelo',
          icon: Icons.bolt,
          iconColor: AppColors.accentOrange,
          isHighlighted: true,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LiquidacionMasivaScreen())),
        ),
      if (_isPremium)
        _buildModernCard(
          title: 'Dashboard Gerencial',
          subtitle: 'Reportes y gráficos ejecutivos',
          icon: Icons.dashboard,
          iconColor: const Color(0xFF9333EA),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DashboardGerencialScreen())),
        ),
      if (_isPremium)
        _buildModernCard(
          title: 'Conceptos Recurrentes',
          subtitle: 'Vales, sindicato, embargos automáticos',
          icon: Icons.receipt_long,
          iconColor: AppColors.accentEmerald,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GestionConceptosScreen())),
        ),
      if (_isPremium)
        _buildModernCard(
          title: 'Ausencias y Licencias',
          subtitle: 'Gestión de ausencias con aprobación',
          icon: Icons.event_busy,
          iconColor: const Color(0xFF14B8A6),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GestionAusenciasScreen())),
        ),
      if (_isPremium)
        _buildModernCard(
          title: 'Préstamos',
          subtitle: 'Préstamos con cuotas automáticas',
          icon: Icons.attach_money,
          iconColor: const Color(0xFF6366F1),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GestionPrestamosScreen())),
        ),
      if (_isPremium)
        _buildModernCard(
          title: 'Biblioteca CCT',
          subtitle: 'Convenios actualizados vía robot BAT',
          icon: Icons.library_books,
          iconColor: const Color(0xFF92400E),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BibliotecaCCTScreen())),
        ),
      _buildModernCard(
        title: 'Buscador de Categorías',
        subtitle: 'Encontrá tu categoría por tareas',
        icon: Icons.search,
        iconColor: AppColors.accentBlue,
        isHighlighted: true,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BuscadorCategoriasScreen())),
      ),
      if (_isPremium)
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

  Widget _buildMainButtons() {
    return Column(
      children: [
        _buildWebLoginCard(),
        const SizedBox(height: 12),
        ..._buildModuleGrid(),
      ],
    );
  }

  Widget _buildWebLoginCard() {
    return _buildModernCard(
      title: 'Acceso Web / PC',
      subtitle: 'Sincronizá tus datos y trabajá en PC',
      icon: Icons.qr_code_scanner,
      iconColor: AppColors.accentBlue,
      isHighlighted: true,
      onTap: _mostrarOpcionesWebLogin,
    );
  }
  
  // REFACTORIZADO: Usa el WebAuthService
  Future<void> _handleQrScan() async {
    final String? channelId = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const QRScannerScreen()),
    );

    if (channelId != null && channelId.isNotEmpty) {
      try {
        await _webAuthService.sendSessionToWeb(channelId);
        _showSnackBar('¡Vinculación QR exitosa! Revisá tu navegador.');
      } catch (e) {
        _showSnackBar('Error al vincular: ${e.toString()}', isError: true);
      }
    }
  }

  // REFACTORIZADO: Usa el WebAuthService
  Future<void> _handleManualCode() async {
    // Muestra un dialog mientras se genera el código y se espera.
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final code = await _webAuthService.listenForManualCodeRequest(
        onTokenSent: () {
          if (mounted) Navigator.pop(context); // Cierra el loader
          _showSnackBar('Dispositivo vinculado exitosamente.');
        },
      );
      
      if (mounted) {
        Navigator.pop(context); // Cierra el loader
        _mostrarCodigoGenerado(code);
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _showSnackBar('Error al generar el código: ${e.toString()}', isError: true);
    }
  }

  void _mostrarOpcionesWebLogin() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.backgroundLight,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Acceso a Versión Web', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            const Text('Para ingresar en tu PC, andá a syncra.com.ar/login', style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 24),
            
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppColors.pastelBlue, borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.qr_code_scanner, color: AppColors.accentBlue),
              ),
              title: const Text('Escanear QR de la pantalla', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              subtitle: const Text('La forma más rápida de ingresar', style: TextStyle(color: AppColors.textSecondary)),
              onTap: () {
                Navigator.pop(ctx);
                _handleQrScan();
              },
            ),
            const SizedBox(height: 16),
            
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppColors.pastelOrange, borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.key, color: AppColors.accentOrange),
              ),
              title: const Text('Generar Código de Acceso', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              subtitle: const Text('Para ingresar manualmente en la web', style: TextStyle(color: AppColors.textSecondary)),
              onTap: () {
                Navigator.pop(ctx);
                _handleManualCode();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarCodigoGenerado(String codigo) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.backgroundLight,
        title: const Text('Tu Código de Acceso', style: TextStyle(color: AppColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Ingresá este código en la web:', style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            Text(codigo, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 4, color: AppColors.accentBlue)),
            const SizedBox(height: 8),
            const Text('Válido por 3 minutos', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              _webAuthService.dispose(); // Cancela la escucha si el usuario cierra manualmente
              Navigator.pop(ctx);
            },
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }


  List<Widget> _buildModuleGrid() {
    final modules = _buildModuleList();
    if (modules.isEmpty) {
      return [const Center(child: Text('No hay módulos disponibles.'))];
    }

    final width = MediaQuery.sizeOf(context).width;
    final crossAxisCount = width >= 1100 ? 3 : width >= 760 ? 2 : 1;

    if (crossAxisCount == 1) {
      return [
        for (var i = 0; i < modules.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          modules[i],
        ],
      ];
    }

    return [
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: crossAxisCount == 3 ? 2.2 : 2.0,
        ),
        itemCount: modules.length,
        itemBuilder: (context, index) => modules[index],
      )
    ];
  }


  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;
    
    return Scaffold(
      backgroundColor: backgroundColor,
      drawer: _buildDrawer(),
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: (isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark).copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: backgroundColor,
          systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        ),
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            color: backgroundColor,
          ),
          child: SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1100),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            FutureBuilder<void>(
                              future: _initialSync,
                              builder: (context, snapshot) {
                                if (snapshot.connectionState != ConnectionState.done) return const SizedBox.shrink();
                                final status = ApiService.lastSyncStatus;
                                final dataUpdateDate = status.dataUpdateDate;
                                
                                if (!status.success || dataUpdateDate == null) return const SizedBox.shrink();

                                final dateText = "${dataUpdateDate.day.toString().padLeft(2, '0')}/${dataUpdateDate.month.toString().padLeft(2, '0')}/${dataUpdateDate.year}";
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: AppColors.glassFill,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: AppColors.glassBorder, width: 1),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.update, color: AppColors.textPrimary, size: 18),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            'Convenios actualizados al $dateText',
                                            style: const TextStyle(
                                              color: AppColors.textPrimary,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                            _buildMainButtons(),
                            if (_empresas.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              _buildEmpresasSection(),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
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
            helpContent['title'] ?? 'Ayuda',
            helpContent['content'] ?? 'Información no disponible',
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
            Builder(
              builder: (context) => IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.glassFill,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.glassBorder, width: 1),
                  ),
                  child: const Icon(Icons.menu, color: AppColors.textPrimary, size: 20),
                ),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
            const SizedBox(width: 8),
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
              'Sincra',
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
                Provider.of<ThemeProvider>(context, listen: false).toggleTheme();
              },
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.glassFill,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.glassBorder, width: 1),
                ),
                child: Icon(
                  Provider.of<ThemeProvider>(context).isDarkMode ? Icons.light_mode : Icons.dark_mode,
                  color: AppColors.accentYellow,
                  size: 20,
                ),
              ),
              tooltip: 'Cambiar Tema',
            ),
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
            AppHelp.buildHelpButton(context, 'home'),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: AppColors.background,
      child: Column(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              color: AppColors.backgroundLight,
              border: Border(bottom: BorderSide(color: AppColors.glassBorder)),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.account_balance_wallet, size: 48, color: AppColors.accentBlue),
                  const SizedBox(height: 12),
                  const Text(
                    'SYncra Premium',
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.card_giftcard, color: Colors.redAccent),
            title: const Text(
              'Prueba Gratis de un Mes',
              style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
            ),
            subtitle: const Text('Disfrutá de todas las funciones', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            onTap: () {
              Navigator.pop(context);
              _mostrarInfoPruebaGratis();
            },
          ),
          ListTile(
            leading: const Icon(Icons.person_outline, color: AppColors.accentBlue),
            title: const Text('Plan Contador & Pymes', style: TextStyle(color: Colors.white)),
            subtitle: const Text('Costo: 15 USD/mes', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            onTap: () {
              Navigator.pop(context);
              _mostrarInfoPlan('Contador');
            },
          ),
          ListTile(
            leading: const Icon(Icons.business_outlined, color: AppColors.accentOrange),
            title: const Text('Plan Business Pro', style: TextStyle(color: Colors.white)),
            subtitle: const Text('Acceso Ilimitado - 70 USD/mes', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            onTap: () {
              Navigator.pop(context);
              _mostrarInfoPlan('Business Pro');
            },
          ),
          const Divider(color: AppColors.glassBorder),
          ListTile(
            leading: const Icon(Icons.star_outline, color: AppColors.accentYellow),
            title: const Text('Beneficios Premium', style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              _mostrarBeneficios();
            },
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              _isPremium ? 'Prueba Premium Activa (30 días)' : 'Versión Gratuita',
              style: TextStyle(
                color: _isPremium ? AppColors.success : AppColors.accentOrange,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarInfoPruebaGratis() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.backgroundLight,
        title: const Text('Prueba Gratis de 30 Días', style: TextStyle(color: Colors.redAccent)),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Durante este mes tenés acceso total a todas las funciones premium de SYncra.',
              style: TextStyle(color: Colors.white),
            ),
            SizedBox(height: 12),
            Text(
              'Al finalizar el periodo de prueba:',
              style: TextStyle(color: AppColors.accentBlue, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            _BenefitItem(icon: Icons.check_circle_outline, text: 'Verificador de recibos (Siempre gratis)'),
            _BenefitItem(icon: Icons.check_circle_outline, text: 'Buscador de categorías (Siempre gratis)'),
            _BenefitItem(icon: Icons.lock_outline, text: 'Liquidación asistida y LSD (Solo en planes premium)'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  void _mostrarInfoPlan(String planName) {
    final plan = planName == 'Contador' 
        ? SubscriptionPlan.contador 
        : SubscriptionPlan.businessPro;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.backgroundLight,
        title: Text('Plan ${plan.name}', style: const TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${plan.price} USD / mes', style: const TextStyle(color: AppColors.accentBlue, fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text(
              planName == 'Contador' 
                ? 'Ideal para profesionales independientes y pequeñas pymes.'
                : 'Para grandes contadores y empresas con volumen ilimitado.',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            if (plan.isUnlimited) ...[
              const _BenefitItem(icon: Icons.all_inclusive, text: 'Empresas ilimitadas'),
              const _BenefitItem(icon: Icons.people_alt, text: 'Empleados ilimitados'),
              const _BenefitItem(icon: Icons.analytics, text: 'Informes y reportes ilimitados'),
              const _BenefitItem(icon: Icons.download_for_offline, text: 'Descargas de recibos y LSD ilimitadas'),
            ] else ...[
              _BenefitItem(icon: Icons.business, text: 'Hasta ${plan.maxCompanies} empresas'),
              _BenefitItem(icon: Icons.people, text: 'Hasta ${plan.maxEmployeesPerCompany} empleados por empresa'),
              _BenefitItem(icon: Icons.file_download, text: '${plan.maxMonthlyDownloads} recibos y LSD por mes'),
              const _BenefitItem(icon: Icons.cloud_done, text: 'Sincronización en la nube'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _procesarPagoPlayStore(plan.name);
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.accentBlue),
            child: const Text('Suscribirse'),
          ),
        ],
      ),
    );
  }

  void _procesarPagoPlayStore(String plan) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Conectando con Google Play Store para el Plan $plan...'),
        backgroundColor: AppColors.accentBlue,
      ),
    );
  }

  void _mostrarBeneficios() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.backgroundLight,
        title: const Text('Beneficios Premium', style: TextStyle(color: Colors.white)),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _BenefitItem(icon: Icons.bolt, text: 'Liquidación Masiva Ultra-Rápida'),
            _BenefitItem(icon: Icons.cloud_sync, text: 'Sincronización en la Nube'),
            _BenefitItem(icon: Icons.support_agent, text: 'Soporte Técnico 24/7'),
            _BenefitItem(icon: Icons.security, text: 'Backups automáticos diarios'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar')),
        ],
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
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isHighlighted ? AppColors.glassFillStrong : AppColors.glassFill,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isHighlighted ? AppColors.glassBorder.withOpacity(0.9) : AppColors.glassBorder,
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: iconColor.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.glassBorder, width: 1),
                    ),
                    child: Icon(icon, color: iconColor, size: 22),
                  ),
                  const Spacer(),
                  const Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 22),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
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
}

class _BenefitItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const _BenefitItem({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: AppColors.accentBlue, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
