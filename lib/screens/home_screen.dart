
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sincra_app/screens/what_is_syncra_screen.dart';
import 'package:sincra_app/subscription/pricing_screen.dart';
import 'package:sincra_app/subscription/role_selection_dialog.dart';
import 'package:sincra_app/subscription/subscription_service.dart';
import 'package:sincra_app/subscription/user_roles.dart';
import 'package:sincra_app/subscription/subscription_status_screen.dart';
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

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  List<Map<String, String>> _empresas = [];
  Future<void>? _initialSync;
  final _webAuthService = WebAuthService();

  bool _isTrialActive = true; 
  UserRole _userRole = UserRole.undecided;
  bool _isSubscribed = false; 
  bool _isLoadingSubscription = true;

  @override
  void initState() {
    super.initState();
    _checkRoleAndSubscription();
    _cargarEmpresas();
    _initialSync = _syncAndMaybeShowSnackBar();
  }
  
  @override
  void dispose() {
    _webAuthService.dispose();
    super.dispose();
  }

  Future<void> _checkRoleAndSubscription() async { /* ... */ }
  void _showSnackBar(String message, {bool isError = false}) { /* ... */ }
  Future<void> _syncAndMaybeShowSnackBar() async { /* ... */ }
  Future<void> _maybeShowUpdateSnackBar() async { /* ... */ }
  void _showUpdateSnackBar(String date) { /* ... */ }
  Future<void> _cargarEmpresas() async { /* ... */ }
  Future<void> _navegarAEmpresa(Map<String, String>? empresa) async { /* ... */ }
  Future<void> _eliminarEmpresa(int index) async { /* ... */ }
  Future<Empresa> _crearEmpresaDesdeMap(Map<String, String> empresaMap) async { return Empresa(razonSocial: '', cuit: '', domicilio: '', convenioId: '', convenioNombre: '', convenioPersonalizado: false, categorias: [], parametros: []);}
  Widget _buildMainButtons() { return Container();}
  Widget _buildWebLoginCard() { return Container();}
  Future<void> _handleQrScan() async { /* ... */ }
  Future<void> _handleManualCode() async { /* ... */ }
  void _mostrarOpcionesWebLogin() { /* ... */ }
  void _mostrarCodigoGenerado(String codigo) { /* ... */ }
  Widget _buildModuleGrid() { return Container(); }
  Future<void> _signOut() async { /* ... */ }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text('Syncra'),
        backgroundColor: AppColors.backgroundLight,
        elevation: 0,
        actions: [
          // --- BOTÓN DE LA VERDAD ---
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'Descubrí el poder de Syncra',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const WhatIsSyncraScreen()),
              );
            },
          ),
          if (!_isTrialActive && _userRole == UserRole.information) ... [/* Botón Premium */] else ...[],
          IconButton(
            icon: Icon(themeProvider.themeMode == ThemeMode.dark ? Icons.light_mode : Icons.dark_mode),
            onPressed: () => themeProvider.toggleTheme(),
          ),
        ],
      ),
      drawer: _buildDrawer(),
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: () async {
          await _syncAndMaybeShowSnackBar();
          await _cargarEmpresas();
        },
        child: FutureBuilder(
          future: _initialSync,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting || _isLoadingSubscription) {
              return const Center(child: CircularProgressIndicator());
            }
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 24),
                  if (_userRole == UserRole.professional || _isTrialActive) ...[
                    _buildEmpresasSection(),
                    const SizedBox(height: 24),
                  ],
                  _buildModuleGrid(),
                  const SizedBox(height: 24),
                  if (_isTrialActive || _isSubscribed)
                     _buildWebLoginCard(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader() { /* ... */ return Container(); }
  Widget _buildDrawer() { /* ... */ return Container(); }
  Widget _buildEmpresasSection() { /* ... */ return Container(); }
  Widget _buildEmptyEmpresasCard() { /* ... */ return Container(); }
  Widget _buildEmpresaCard(Map<String, String> empresa, int index) { /* ... */ return Container(); }
  Widget _buildModernCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
    bool isHighlighted = false,
  }) { /* ... */ return Container(); }
}
