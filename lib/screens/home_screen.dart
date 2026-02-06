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
  }

  Future<void> _cargarEmpresas() async {
    final list = await HybridStore.getEmpresas();
    if (mounted) setState(() => _empresas = list);
  }

  Future<void> _navegarAEmpresa(Map<String, String>? empresa) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EmpresaScreen(
          razonSocial: empresa?['razonSocial'],
          cuit: empresa?['cuit'],
          domicilio: empresa?['domicilio'],
          convenio: empresa?['convenio'],
        ),
      ),
    );
    _cargarEmpresas();
  }

  Future<void> _eliminarEmpresa(int index) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar'),
        content: const Text('¿Estás seguro?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sí')),
        ],
      ),
    );

    if (confirmado == true) {
      final nueva = List<Map<String, String>>.from(_empresas)..removeAt(index);
      await HybridStore.saveEmpresas(nueva);
      _cargarEmpresas();
    }
  }

  void _irALiquidador() {
    Navigator.push(context, MaterialPageRoute(builder: (context) => const LiquidadorFinalScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Syncra Arg'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _buildMainButtons(),
            if (_empresas.isNotEmpty) ...[
              const SizedBox(height: 32),
              _buildEmpresasSection(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMainButtons() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      children: [
        _buildMenuButton('Liquidador', Icons.calculate, Colors.blue, _irALiquidador),
        _buildMenuButton('Nueva Empresa', Icons.add_business, Colors.green, () => _navegarAEmpresa(null)),
      ],
    );
  }

  Widget _buildMenuButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.glassFill,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpresasSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Mis Empresas', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _empresas.length,
          itemBuilder: (context, index) => ListTile(
            title: Text(_empresas[index]['razonSocial'] ?? '', style: const TextStyle(color: Colors.white)),
            trailing: IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _eliminarEmpresa(index),
            ),
          ),
        ),
      ],
    );
  }
}
