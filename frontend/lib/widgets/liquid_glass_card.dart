import 'dart:ui';
import 'package:flutter/material.dart';
import '../core/theme/liquid_glass_theme.dart';

class LiquidGlassCard extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final Color? customBackground;
  final double blurSigma;
  final Border? customBorder;

  const LiquidGlassCard({
    super.key,
    required this.child,
    this.borderRadius = 20.0,
    this.padding = const EdgeInsets.all(16.0),
    this.margin,
    this.width,
    this.height,
    this.customBackground,
    this.blurSigma = 16.0,
    this.customBorder,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(borderRadius),
              color: customBackground ?? LiquidGlassTheme.bgCard,
              border: customBorder ??
                  Border.all(
                    color: LiquidGlassTheme.borderSubtle,
                    width: 1.2,
                  ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
