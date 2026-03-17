import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class AnimatedLogo extends StatefulWidget {
  final double size;
  final bool showGlow;

  const AnimatedLogo({
    super.key,
    this.size = 100,
    this.showGlow = true,
  });

  @override
  State<AnimatedLogo> createState() => _AnimatedLogoState();
}

class _AnimatedLogoState extends State<AnimatedLogo> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _opacityAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Opacity(
            opacity: _opacityAnimation.value,
            child: Container(
              height: widget.size,
              width: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: widget.showGlow
                    ? [
                        BoxShadow(
                          color: AppColors.accentBlue.withOpacity(0.3),
                          blurRadius: widget.size * 0.2,
                          spreadRadius: widget.size * 0.05,
                        ),
                      ]
                    : null,
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/images/logo.png',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(
                      Icons.business,
                      size: widget.size * 0.6,
                      color: AppColors.accentBlue,
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
