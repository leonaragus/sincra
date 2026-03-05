
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui';
import 'dart:convert';
import 'dart:async';
import 'empresa_screen.dart';
import '../services/hybrid_store.dart';
import '../models/empresa.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import 'empleado_screen.dart';
import 'lista_empleados_screen.dart';
import 'parametros_legales_screen.dart';
import '../utils/logo_avatar.dart';
import '../utils/app_help.dart';

import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'qr_scanner_screen.dart';
import '../services/web_auth_service.dart';
import '../config/app_modules.dart';
import '../models/module_info.dart';
import 'subscription_screen.dart'; // <- IMPORTACIÓN NUEVA

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  List<Map<String, String>> _empresas = [];
  Future<void>? _initialSync;
  bool _isPremium = true;
  final _webAuthService = WebAuthService();

  @override
  void initState() {
    super.initState();
    _checkPremiumStatus();
    _cargarEmpresas();
    _initialSync = _syncAndMaybeShowSnackBar();
  }

  @override
  void dispose() {
    _webAuthService.dispose();
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
            onPressed: () async {
               if (!mounted) return;
               Navigator.pop(context, true);
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmado == true) {
      final empresaAEliminar = _empresas[index];
      final nuevasEmpresas = List<Map<String, String>>.from(_empresas)..removeAt(index);
      await HybridStore.saveEmpresas(nuevasEmpresas);
      
      // Adicionalmente, limpiar los datos asociados a la empresa
      await HybridStore.removeEmpleadosOfEmpresa(empresaAEliminar['razonSocial']! );

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

  Widget _buildMainButtons() {
    return Column(
      children: [
        _buildWebLoginCard(),
        const SizedBox(height: 12),
        _buildModuleGrid(),
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

  Future<void> _handleManualCode() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final code = await _webAuthService.listenForManualCodeRequest(
        onTokenSent: () {
          if (mounted) Navigator.pop(context);
          _showSnackBar('Dispositivo vinculado exitosamente.');
        },
      );
      
      if (mounted) {
        Navigator.pop(context);
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
              _webAuthService.dispose();
              Navigator.pop(ctx);
            },
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Widget _buildModuleGrid() {
    final visibleModules = appModules.where((module) {
      return !module.isPremium || _isPremium;
    }).toList();

    if (visibleModules.isEmpty) {
      return const Center(child: Text('No hay módulos disponibles.'));
    }

    final width = MediaQuery.sizeOf(context).width;
    final crossAxisCount = width >= 1100 ? 3 : width >= 760 ? 2 : 1;

    if (crossAxisCount == 1) {
      return ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: visibleModules.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final module = visibleModules[index];
          return _buildModernCard(
            title: module.title,
            subtitle: module.subtitle,
            icon: module.icon,
            iconColor: module.iconColor,
            isHighlighted: module.isHighlighted,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: module.buildRoute)),
          );
        },
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: crossAxisCount == 3 ? 2.2 : 2.0,
      ),
      itemCount: visibleModules.length,
      itemBuilder: (context, index) {
        final module = visibleModules[index];
        return _buildModernCard(
          title: module.title,
          subtitle: module.subtitle,
          icon: module.icon,
          iconColor: module.iconColor,
          isHighlighted: module.isHighlighted,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: module.buildRoute)),
        );
      },
    );
  }

  // NUEVO MÉTODO: Maneja el cierre de sesión.
  Future<void> _signOut() async {
    try {
      await Supabase.instance.client.auth.signOut();
      // El WebAuthGate se encargará de la redirección a la pantalla de login.
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Error al cerrar sesión: ${e.toString()}', isError: true);
    }
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
                            const SizedBox(height: 16),
                            _buildEmpresasSection(), 
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

  // REFACTORIZADO: El Drawer ahora es un menú de navegación estándar.
  Widget _buildDrawer() {
    final currentUser = Supabase.instance.client.auth.currentUser;
    final userEmail = currentUser?.email ?? 'Bienvenido';

    return Drawer(
      backgroundColor: AppColors.background,
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            accountName: Text(
              userEmail.split('@').first,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            accountEmail: Text(userEmail),
            currentAccountPicture: const CircleAvatar(
              backgroundColor: AppColors.primary,
              child: Icon(Icons.person, color: Colors.white, size: 36),
            ),
            decoration: const BoxDecoration(
              color: AppColors.backgroundLight,
              border: Border(bottom: BorderSide(color: AppColors.glassBorder)),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.home_outlined, color: AppColors.textSecondary),
            title: const Text('Inicio', style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.star_border, color: AppColors.accentYellow),
            title: const Text('Planes y Suscripción', style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context); // Cierra el drawer
              Navigator.push(context, MaterialPageRoute(builder: (_) => const SubscriptionScreen()));
            },
          ),
          const Divider(color: AppColors.glassBorder, indent: 16, endIndent: 16),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.redAccent),
            title: const Text('Cerrar Sesión', style: TextStyle(color: Colors.redAccent)),
            onTap: () {
               Navigator.pop(context);
               _signOut();
            },
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              _isPremium ? 'Estado: Prueba Premium Activa' : 'Estado: Versión Gratuita',
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

  // ELIMINADOS: _mostrarInfoPruebaGratis, _mostrarInfoPlan, _procesarPagoPlayStore,
  // _mostrarBeneficios, y la clase _BenefitItem ya no son necesarios aquí.

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
              if (_empresas.isNotEmpty) IconButton(
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
          _empresas.isEmpty
              ? _buildEmptyEmpresasCard()
              : GridView.builder(
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

  Widget _buildEmptyEmpresasCard() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _navegarAEmpresa(null),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.glassFillStrong,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.glassBorder.withOpacity(0.5)),
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_business_outlined, size: 32, color: AppColors.textSecondary),
              SizedBox(height: 12),
              Text(
                'Crea tu primera empresa',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Pulsa aquí para configurar los datos y empezar a liquidar.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ],
          ),
        ),
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
