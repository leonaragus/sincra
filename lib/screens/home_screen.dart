
import 'package:flutter/material.dart';
import 'package:sincra_app/screens/what_is_syncra_screen.dart';
import 'package:sincra_app/subscription/pricing_screen.dart';
import 'package:sincra_app/subscription/role_selection_dialog.dart';
import 'package:sincra_app/subscription/subscription_service.dart';
import 'package:sincra_app/subscription/user_roles.dart';
import 'package:sincra_app/subscription/subscription_status_screen.dart';
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
        builder: (_) => const RoleSelectionDialog(),
      );
      
      if (selectedRole != null) {
        await SubscriptionService.setUserRole(selectedRole);
        userRole = selectedRole;
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
    final data = await HybridStore.get('empresas');
    if (data != null) {
      setState(() {
        _empresas = List<Map<String, String>>.from(data.map((e) => Map<String, String>.from(e)));
      });
    }
  }

  Future<void> _navegarAEmpresa(Map<String, String>? empresa) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EmpresaScreen(empresa: empresa),
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
        await HybridStore.save('empresas', _empresas);
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
                        _buildModuleGrid(userRole),
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

  Drawer _buildDrawer() { /* ... código sin cambios ... */ return Drawer(); }
  Widget _buildHeader(UserRole userRole, bool isTrialActive) { /* ... código sin cambios ... */ return Container(); }
  Widget _buildEmpresasSection() { /* ... código sin cambios ... */ return Container(); }
  Widget _buildModuleGrid(UserRole userRole) { /* ... código sin cambios ... */ return Container(); }
  Widget _buildWebLoginCard() { /* ... código sin cambios ... */ return Container(); }

}
