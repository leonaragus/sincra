import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../services/api_service.dart';
import '../services/hybrid_store.dart';
import '../services/teacher_omni_engine.dart';
import '../theme/app_colors.dart';
import '../models/convenio_model.dart';
import 'plan_selection_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Mínimo tiempo de espera de 3 segundos
    final minWait = Future.delayed(const Duration(seconds: 3));

    // Inicialización de servicios
    final initServices = _initServices();

    // Esperar a que ambos terminen
    await Future.wait([minWait, initServices]);

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const PlanSelectionScreen()),
      );
    }
  }

  Future<void> _initServices() async {
    try {
      await Supabase.initialize(
        url: SupabaseConfig.url,
        anonKey: SupabaseConfig.anonKey,
      );
    } catch (e) {
      debugPrint('Supabase init error: $e');
    }

    try {
      if (kIsWeb) {
        await HybridStore.initIsar('');
      } else {
        final dir = await getApplicationDocumentsDirectory();
        await HybridStore.initIsar(dir.path);
      }
    } catch (e) {
      debugPrint('Isar init error: $e');
    }

    try {
      await ApiService.syncOrLoadLocal().catchError((_) => <ConvenioModel>[]);
      HybridStore.pullFromSupabase().catchError((_) {});
      TeacherOmniEngine.loadParitariasCache().catchError((_) {});
    } catch (e) {
      debugPrint('Data sync error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo inventado: Un icono estilizado
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.2),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.primary,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: const Icon(
                Icons.sync_lock_rounded, // Icono que sugiere sincronización y seguridad/trabajo
                size: 80,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 24),
            
            // Nombre de la App
            const Text(
              'Syncra Arg',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            
            // Tagline
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: const Text(
                'Herramienta para los profesionales y los trabajadores',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
            
            const SizedBox(height: 48),
            
            // Indicador de carga sutil
            const CircularProgressIndicator(
              color: AppColors.primary,
              strokeWidth: 2,
            ),
          ],
        ),
      ),
    );
  }
}
