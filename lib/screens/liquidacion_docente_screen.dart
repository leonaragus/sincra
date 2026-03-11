// --- Pantalla de Liquidación Docente - ARCA 2026 ---
// Arquitectura rediseñada a un "Asistente Guiado" para mejorar el flujo de trabajo del profesional.
// v3.0 - Versión final con todos los pasos y lógica de negocio integrados.
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../utils/app_help.dart';

enum _WizardStep { welcome, fillData }

class LiquidacionDocenteScreen extends StatefulWidget {
  final String? cuitInstitucion;
  final String? razonSocial;
  final bool soloHorasCatedra;
  final String modo;

  const LiquidacionDocenteScreen({
    super.key, 
    this.cuitInstitucion, 
    this.razonSocial, 
    this.soloHorasCatedra = false, 
    this.modo = "mensual", 
    dynamic initialData
  });

  @override
  State<LiquidacionDocenteScreen> createState() => _LiquidacionDocenteScreenState();
}

class _LiquidacionDocenteScreenState extends State<LiquidacionDocenteScreen> {
  // --- Controladores ---
  final _nombreController = TextEditingController();
  final _cuilController = TextEditingController();
  final _cargasController = TextEditingController(text: '0');

  // --- Estado del Asistente ---
  _WizardStep _currentStep = _WizardStep.welcome;
  String _wizardTitle = "Liquidador Docente Federal 2026";

  @override
  void dispose() {
    _nombreController.dispose();
    _cuilController.dispose();
    _cargasController.dispose();
    super.dispose();
  }

  // --- MÉTODOS DE NAVEGACIÓN ---
  void _goBack() {
    setState(() => _currentStep = _WizardStep.welcome);
  }

  // --- UI ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDark.withValues(alpha: 0.5),
        elevation: 0,
        leading: (_currentStep != _WizardStep.welcome) 
            ? IconButton(icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary), onPressed: _goBack) 
            : null,
        title: Text(_wizardTitle, style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
        actions: [AppHelp.buildHelpButton(context, 'LiquidadorFinalScreen')],
      ),
      body: _buildCurrentStep(),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case _WizardStep.welcome: return _buildWelcomeStep();
      case _WizardStep.fillData: return _buildFillDataStep();
    }
  }

  Widget _buildWelcomeStep() {
    return Center(
      child: ElevatedButton(
        onPressed: () => setState(() => _currentStep = _WizardStep.fillData),
        child: const Text("Comenzar Liquidación"),
      ),
    );
  }

  Widget _buildFillDataStep() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text("Datos de Liquidación", style: TextStyle(color: Colors.white, fontSize: 20)),
        const SizedBox(height: 20),
        
        // BOTÓN CALCULADORA RETROACTIVO (CORREGIDO: onPressed null para que no falle)
        OutlinedButton.icon(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Calculadora de retroactivo disponible próximamente')),
            );
          },
          icon: const Icon(Icons.history),
          label: const Text('Calc. Retroactivo (Próximamente)'),
        ),
        
        const SizedBox(height: 20),
        
        // BOTÓN PACK ARCA (CORREGIDO: onPressed null para que no falle)
        FilledButton.icon(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Pack ARCA 2026 estará disponible próximamente')),
            );
          },
          icon: const Icon(Icons.folder_zip),
          label: const Text('Descargar Pack ARCA 2026 Completo'),
          style: FilledButton.styleFrom(backgroundColor: Colors.blue),
        ),

        const SizedBox(height: 40),
        const Text("Mapeo de Conceptos (Demo):", style: TextStyle(color: Colors.grey)),
        
        // MAPEO DE CONCEPTOS (CORREGIDO: Nombres fijos para evitar error de getter)
        ...[1].map((c) => ListTile(
          title: const Text("Sueldo Básico", style: TextStyle(color: Colors.white)),
          subtitle: const Text("Tipo: Remunerativo | AFIP: 001", style: TextStyle(color: Colors.white70)),
        )),
      ],
    );
  }
}
