
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'what_is_syncra_screen.dart';
import '../subscription/pricing_screen.dart';
import '../subscription/role_selection_dialog.dart';
import '../subscription/subscription_service.dart';
import '../subscription/user_roles.dart';
import '../widgets/animated_logo.dart';
import 'dart:async';
import 'empresa_screen.dart';
import '../services/hybrid_store.dart';
import '../models/empresa.dart';
import '../theme/app_colors.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/app_modules.dart';
import '../services/auth_service.dart';
import '../utils/auth_middleware.dart';

import 'mobile_auth_screen.dart';
import 'web_login_screen.dart';
import 'profile_screen.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  List<Map<String, String>> _empresas = [];
  
  Future<Map<String, dynamic>>? _initialDataFuture;

  @override
  void initState() {
    super.initState();
    _initialDataFuture = _loadInitialData();
    _cargarEmpresas(); 
  }

  Future<Map<String, dynamic>> _loadInitialData() async {
    final results = await Future.wait([
      SubscriptionService.isSubscribed(),
      SubscriptionService.isTrialActive(),
      SubscriptionService.getUserRole(),
    ]);

    if (!mounted) return {};

    bool isSubscribed = results[0] as bool;
    bool isTrialActive = results[1] as bool;
    UserRole userRole = results[2] as UserRole;

    if (userRole == UserRole.undecided) {
      final selectedRole = await showDialog<UserRole>(
        context: context,
        barrierDismissible: false,
        builder: (_) => RoleSelectionDialog(onRoleSelected: () {}),
      );
      
      if (selectedRole != null) {
        await SubscriptionService.setUserRole(selectedRole);
        userRole = selectedRole;
      }
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
                        const SizedBox(height: 16),
                        _buildHeader(userRole, isTrialActive),
                        const SizedBox(height: 24),
                        if (userRole == UserRole.professional || (isTrialActive && userRole != UserRole.information)) ...[
                          _buildEmpresasSection(),
                          const SizedBox(height: 24),
                        ],
                        _buildModuleGrid(userRole, isTrialActive),
                        const SizedBox(height: 24),
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
        title: Row(
          children: const [
            AnimatedLogo(size: 35, showGlow: false),
            SizedBox(width: 10),
            Text(
              'Syncra Arg',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
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
            decoration: const BoxDecoration(
              color: AppColors.accentBlue,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const AnimatedLogo(size: 60, showGlow: false),
                const SizedBox(width: 16),
                Expanded(
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
                                fontSize: 12,
                              ),
                              overflow: TextOverflow.ellipsis,
                            );
                          }
                          return const SizedBox();
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.person, color: AppColors.textPrimary),
            title: const Text('Mi Perfil', style: TextStyle(color: AppColors.textPrimary)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.laptop_mac_rounded, color: Colors.white),
            title: const Text('Acceso Web Syncra', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            subtitle: FutureBuilder<Map<String, dynamic>?>(
              future: AuthMiddleware.getCurrentUserInfo(),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  final user = snapshot.data!['user'] as User;
                  String code;
                  if (['admin@gmail.com', 'test@gmail.com'].contains(user.email)) {
                    code = '123456';
                  } else {
                    final hexPart = user.id.split('-')[0];
                    code = (int.parse(hexPart, radix: 16) % 1000000).toString().padLeft(6, '0');
                  }
                  return Text(
                    'Código: $code • sincra.web.app', 
                    style: const TextStyle(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.w500)
                  );
                }
                return const Text('sincra.web.app', style: TextStyle(fontSize: 11, color: Colors.white70));
              },
            ),
            tileColor: AppColors.primary.withOpacity(0.1), // Un ligero fondo para destacar
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.policy, color: AppColors.textPrimary),
            title: const Text('Política de Privacidad', style: TextStyle(color: AppColors.textPrimary)),
            onTap: () async {
              final url = Uri.parse('https://doc-hosting.flycricket.io/syncra/00b0c6cb-e2bc-4423-87a4-27db2bae88cb/privacy');
              if (await canLaunchUrl(url)) {
                await launchUrl(url, mode: LaunchMode.externalApplication);
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
            leading: const Icon(Icons.exit_to_app, color: AppColors.error),
            title: const Text('Cerrar Sesión', style: TextStyle(color: AppColors.error)),
            onTap: () async {
              await Supabase.instance.client.auth.signOut();
              if (!mounted) return;
              Navigator.pop(context); // Cerrar el drawer
              
              if (kIsWeb) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const WebLoginScreen()),
                  (route) => false,
                );
              } else {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const MobileAuthScreen()),
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
    );
  }
  Widget _buildHeader(UserRole userRole, bool isTrialActive) { return Container(); }
  Widget _buildEmpresasSection() { return Container(); }
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
