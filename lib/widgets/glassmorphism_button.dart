import 'package:flutter/material.dart';
import 'dart:ui';
import '../theme/app_colors.dart';

/// Botón tipo tarjeta grande con efecto glassmorphism sobre fondo oscuro.
/// Usa colores pastel para el acento.
class GlassmorphismButton extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback? onTap;
  final double? width;
  final double? height;
  final List<Color> gradientColors;
  final bool isLarge;

  const GlassmorphismButton({
    super.key,
    required this.title,
    required this.icon,
    this.onTap,
    this.width,
    this.height,
    required this.gradientColors,
    this.isLarge = false,
  });

  @override
  Widget build(BuildContext context) {
    final buttonWidth = width ?? (isLarge ? 200.0 : 120.0);
    final buttonHeight = height ?? (isLarge ? 200.0 : 140.0);
    final iconSize = isLarge ? 56.0 : 40.0;
    final fontSize = isLarge ? 18.0 : 14.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: buttonWidth,
        height: buttonHeight,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Color.lerp(
                gradientColors.first,
                Colors.black,
                0.6,
              )!.withValues(alpha: 0.4),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: AppColors.glassBorder,
                  width: 1.5,
                ),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    gradientColors.first.withValues(alpha: 0.35),
                    gradientColors.length > 1
                        ? gradientColors[1].withValues(alpha: 0.25)
                        : gradientColors.first.withValues(alpha: 0.2),
                    AppColors.glassFill,
                  ],
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: iconSize,
                    color: AppColors.textPrimary,
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: fontSize,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                        shadows: const [
                          Shadow(
                            color: Color.fromRGBO(0, 0, 0, 0.3),
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
