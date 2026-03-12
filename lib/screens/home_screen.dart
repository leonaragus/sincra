
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'what_is_syncra_screen.dart';
import '../subscription/pricing_screen.dart';
import '../subscription/role_selection_dialog.dart';
import '../subscription/subscription_service.dart';
import '../subscription/user_roles.dart';
import '../subscription/subscription_status_screen.dart';
import 'dart:async';
import 'empresa_screen.dart';
import '../services/hybrid_store.dart';
import '../models/empresa.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/web_auth_service.dart';
import '../config/app_modules.dart';
import '../services/auth_service.dart';
import 'web_login_screen.dart' show isAdminBypass; // Importamos el bypass de admin

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  List<Map<String, String>> _empresas = [];
  final _webAuthService = WebAuthService();
  
  // El Future que gobernará el estado de la UI
  Future<Map<String, dynamic>>? _initialDataFuture;

  @override
  void initState() {
    super.initState();
    // Iniciamos la carga de todos los datos críticos
    _initialDataFuture = _loadInitialData();
    _cargarEmpresas(); 
  }

  @override
  void dispose() {
    _webAuthService.dispose();
    super.dispose();
  }

  /// Carga todos los datos críticos de estado del usuario desde el servidor.
  /// Esto incluye el estado de la suscripción, la prueba y el rol.
  /// Es la ÚNICA fuente de verdad para construir la UI.
  Future<Map<String, dynamic>> _loadInitialData() async {
    // Si estamos en bypass de admin, devolvemos un estado de acceso total inmediatamente.
    if (isAdminBypass) {
      return {
        'isSubscribed': true,
        'isTrialActive': true,
        'userRole': UserRole.professional,
      };
    }

    // Se ejecutan en paralelo para máxima eficiencia
    final results = await Future.wait([
      SubscriptionService.isSubscribed(),
      SubscriptionService.isTrialActive(),
      SubscriptionService.getUserRole(),
    ]);

    bool isSubscribed = results[0] as bool;
    bool isTrialActive = results[1] as bool;
    UserRole userRole = results[2] as UserRole;

    // Si el rol nunca fue decidido, forzamos la selección
    if (userRole == UserRole.undecided) {
      // El `useRootNavigator: false` es importante si se llama desde initState
      final selectedRole = await showDialog<UserRole>(
        context: context,
        barrierDismissible: false,
        builder: (_) => RoleSelectionDialog(onRoleSelected: () {}),
      );
      
      if (selectedRole != null) {
        await SubscriptionService.setUserRole(selectedRole);
        userRole = selectedRole;
        
        // Si elige Profesional y la prueba terminó, redirigimos a planes
        if (selectedRole == UserRole.professional && !isTrialActive && !isSubscribed) {
           if (mounted) {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const PricingScreen()));
           }
        }
      }
    }

    // Lógica de degradación: si la prueba terminó y no hay suscripción, se revoca el acceso.
    if (!isTrialActive && !isSubscribed && userRole == UserRole.professional) {
        await SubscriptionService.setUserRole(UserRole.information);
        userRole = UserRole.information;
        _showSnackBar('Tu período de prueba ha terminado. Algunas funciones han sido desactivadas.');
    }

    return {
      'isSubscribed': isSubscribed,
      'isTrialActive': isTrialActive,
      'userRole': userRole,
    };
  }

  Future<void> _refreshData() async {
    setState(() {
      _initialDataFuture = _loadInitialData();
      _cargarEmpresas();
    });
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : AppColors.accentBlue,
        ));
    }
  }

  Future<void> _cargarEmpresas() async {
    final list = await HybridStore.getEmpresas();
    setState(() {
      _empresas = list;
    });
  }

  Future<void> _navegarAEmpresa(Map<String, String>? empresa) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const EmpresaScreen(),
      ),
    );
    if (result == true) {
      _cargarEmpresas();
    }
  }

  Future<void> _eliminarEmpresa(int index) async {
    final empresa = _empresas[index];
    final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirmar eliminación'),
          content: Text('¿Estás seguro de que querés eliminar la empresa ${empresa['razonSocial']}?'),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
            TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Eliminar')),
          ],
        ));

    if (confirm == true) {
      _empresas.removeAt(index);
      await HybridStore.saveEmpresas(_empresas);
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildDrawer(),
      backgroundColor: AppColors.background,
      body: FutureBuilder<Map<String, dynamic>>(
        future: _initialDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError || !snapshot.hasData) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Ocurrió un error al cargar tus datos.'),
                  const SizedBox(height: 10),
                  ElevatedButton(onPressed: _refreshData, child: const Text('Reintentar'))
                ],
              )
            );
          }

          final data = snapshot.data!;
          final isTrialActive = data['isTrialActive'] as bool;
          final isSubscribed = data['isSubscribed'] as bool;
          final userRole = data['userRole'] as UserRole;

          return RefreshIndicator(
            onRefresh: _refreshData,
            child: CustomScrollView(
              slivers: [
                _buildAppBar(context, userRole, isTrialActive),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildHeader(userRole, isTrialActive),
                        const SizedBox(height: 24),
                        if (userRole == UserRole.professional || (isTrialActive && userRole != UserRole.information) ) ...[
                          _buildEmpresasSection(),
                          const SizedBox(height: 24),
                        ],
                        _buildModuleGrid(userRole, isTrialActive),
                        const SizedBox(height: 24),
                        if (isTrialActive || isSubscribed)
                          _buildWebLoginCard(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }


  SliverAppBar _buildAppBar(BuildContext context, UserRole userRole, bool isTrialActive) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return SliverAppBar(
        title: const Text('Syncra'),
        backgroundColor: AppColors.backgroundLight,
        floating: true,
        pinned: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'Descubrí el poder de Syncra',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const WhatIsSyncraScreen())),
          ),
          if (!isTrialActive && userRole == UserRole.information) ...[
             IconButton(
                icon: const Icon(Icons.star, color: AppColors.accentGold),
                tooltip: 'Volvete Premium',
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PricingScreen())),
              )
          ],
          IconButton(
            icon: Icon(themeProvider.themeMode == ThemeMode.dark ? Icons.light_mode : Icons.dark_mode),
            onPressed: () => themeProvider.toggleTheme(),
          ),
          IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          )
        ],
    );
}

  Drawer _buildDrawer() {
    return Drawer(
      backgroundColor: AppColors.backgroundLight,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: AppColors.accentBlue,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Text(
                  'Syncra',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                FutureBuilder<Map<String, dynamic>?>(
                  future: AuthMiddleware.getCurrentUserInfo(),
                  builder: (context, snapshot) {
                    if (snapshot.hasData) {
                      final user = snapshot.data!['user'] as User;
                      final plan = snapshot.data!['plan_name'] as String;
                      return Text(
                        '${user.email} • $plan',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      );
                    }
                    return const SizedBox();
                  },
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.web, color: AppColors.textPrimary),
            title: const Text('Syncra Web', style: TextStyle(color: AppColors.textPrimary)),
            onTap: () async {
              final url = Uri.parse('https://sincra.web.app/');
              if (await canLaunchUrl(url)) {
                await launchUrl(url);
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.policy, color: AppColors.textPrimary),
            title: const Text('Política de Privacidad', style: TextStyle(color: AppColors.textPrimary)),
            onTap: () async {
              final url = Uri.parse('https://sincra.web.app/privacy-policy');
              if (await canLaunchUrl(url)) {
                await launchUrl(url);
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.star, color: AppColors.textPrimary),
            title: const Text('Planes y Suscripciones', style: TextStyle(color: AppColors.textPrimary)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (context) => const PricingScreen()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.info, color: AppColors.textPrimary),
            title: const Text('Acerca de Syncra', style: TextStyle(color: AppColors.textPrimary)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (context) => const WhatIsSyncraScreen()));
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.exit_to_app, color: AppColors.errorRed),
            title: const Text('Cerrar Sesión', style: TextStyle(color: AppColors.errorRed)),
            onTap: () async {
              await Supabase.instance.client.auth.signOut();
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
  Widget _buildHeader(UserRole userRole, bool isTrialActive) { /* ... código sin cambios ... */ return Container(); }
  Widget _buildEmpresasSection() { /* ... código sin cambios ... */ return Container(); }
  Widget _buildModuleGrid(UserRole userRole, bool isTrialActive) {
    final modules = appModules;
    final width = MediaQuery.of(context).size.width;
    final cross = width >= 1000 ? 4 : width >= 700 ? 3 : 2;
    return GridView.builder(
      itemCount: modules.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cross,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.25,
      ),
      itemBuilder: (context, i) {
        final m = modules[i];
        final hasAccess = !m.isPremium || userRole == UserRole.professional || (isTrialActive && userRole != UserRole.information);
        return InkWell(
          onTap: hasAccess
              ? () => Navigator.push(context, MaterialPageRoute(builder: (context) => m.buildRoute(context)))
              : _showUpgradeDialog,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.backgroundLight,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(m.icon, color: m.iconColor, size: 28),
                const SizedBox(height: 12),
                Text(m.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                const SizedBox(height: 6),
                Text(m.subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                const Spacer(),
                if (!hasAccess)
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.accentYellow.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text('Premium', style: TextStyle(color: AppColors.accentYellow, fontSize: 12)),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
  Widget _buildWebLoginCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.accentBlue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accentBlue.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.web, color: AppColors.accentBlue, size: 24),
              const SizedBox(width: 12),
              const Text(
                'Acceso Web Premium',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Accedé a Syncra desde cualquier navegador con todas tus empresas y datos sincronizados.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () async {
              final url = Uri.parse('https://sincra.web.app/');
              if (await canLaunchUrl(url)) {
                await launchUrl(url);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              minimumSize: const Size(double.infinity, 48),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.open_in_browser, size: 20),
                SizedBox(width: 8),
                Text('Abrir Syncra Web'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showUpgradeDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Función Premium'),
          content: const Text('Para usar este módulo necesitás una suscripción.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar')),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const PricingScreen()));
              },
              child: const Text('Ver Planes'),
            ),
          ],
        );
      },
    );
  }
}
