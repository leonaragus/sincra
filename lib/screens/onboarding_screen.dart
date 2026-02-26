import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_colors.dart';
import 'home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icono Premium / Regalo
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.accentBlue.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.accentBlue.withOpacity(0.3), width: 2),
                ),
                child: const Icon(
                  Icons.card_giftcard,
                  size: 80,
                  color: AppColors.accentBlue,
                ),
              ),
              const SizedBox(height: 40),
              
              Text(
                '¡Bienvenido a SYncra!',
                style: GoogleFonts.orbitron(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              
              // Tarjeta de Beneficio
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.glassFillStrong,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.glassBorder),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      'Tu primer mes es GRATIS',
                      style: GoogleFonts.roboto(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.accentBlue,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Disfrutá de todas las funciones PREMIUM sin límites por los próximos 30 días.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.roboto(
                        fontSize: 16,
                        color: AppColors.textPrimary,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              
              // Info Version Gratis
              Column(
                children: [
                  _buildFeatureItem(Icons.check_circle_outline, 'Verificador de recibos (Siempre gratis)'),
                  _buildFeatureItem(Icons.check_circle_outline, 'Buscador de categorías (Siempre gratis)'),
                  _buildFeatureItem(Icons.lock_outline, 'Liquidación asistida IA (Premium después de 30 días)', isLocked: true),
                ],
              ),
              
              const Spacer(),
              
              // Botón Comenzar
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: () async {
                    final prefs = await SharedPreferences.getInstance();
                    // Guardar fecha de inicio para controlar los 30 días
                    if (prefs.getString('onboarding_start_date') == null) {
                      await prefs.setString('onboarding_start_date', DateTime.now().toIso8601String());
                    }
                    await prefs.setBool('has_seen_onboarding', true);
                    
                    if (!mounted) return;
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const HomeScreen()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentBlue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(
                    'COMENZAR AHORA',
                    style: GoogleFonts.orbitron(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String text, {bool isLocked = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: isLocked ? AppColors.textMuted : AppColors.success),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.roboto(
                fontSize: 14,
                color: isLocked ? AppColors.textMuted : AppColors.textSecondary,
                decoration: isLocked ? TextDecoration.none : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
