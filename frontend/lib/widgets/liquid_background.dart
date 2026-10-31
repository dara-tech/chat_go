import 'package:flutter/material.dart';
import '../core/theme/theme_controller.dart';

class LiquidBackground extends StatelessWidget {
  final Widget child;
  final bool safeAreaBottom;

  const LiquidBackground({
    super.key,
    required this.child,
    this.safeAreaBottom = true,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        final theme = ThemeController.instance;
        final isDark = theme.isDark;

        return Scaffold(
          backgroundColor: theme.scaffoldBg,
          body: Stack(
            fit: StackFit.expand,
            children: [
              // 1. Subtle, calm static studio gradient
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: isDark
                        ? [
                            theme.scaffoldBg,
                            theme.surfaceBg,
                            theme.cardBg,
                          ]
                        : [
                            theme.scaffoldBg,
                            theme.surfaceBg,
                            theme.border.withOpacity(0.35),
                          ],
                    stops: const [0.0, 0.45, 1.0],
                  ),
                ),
              ),

              // 2. Soft, static ambient glow matching primary accent
              Positioned(
                top: -120,
                left: -80,
                right: -80,
                height: 480,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.topCenter,
                      radius: 1.0,
                      colors: [
                        theme.primaryColor.withOpacity(isDark ? 0.20 : 0.10),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              // 3. Foreground Content
              SafeArea(
                bottom: safeAreaBottom,
                child: child,
              ),
            ],
          ),
        );
      },
    );
  }
}
