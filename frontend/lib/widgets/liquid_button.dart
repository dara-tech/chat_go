import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/theme/theme_controller.dart';

class LiquidButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final double height;
  final double? width;
  final double borderRadius;
  final Gradient? gradient;
  final Color? textColor;

  const LiquidButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.height = 44,
    this.width,
    this.borderRadius = 999, // fully rounded pill
    this.gradient,
    this.textColor,
  });

  @override
  State<LiquidButton> createState() => _LiquidButtonState();
}

class _LiquidButtonState extends State<LiquidButton> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (!widget.isLoading && widget.onPressed != null) {
      _animController.forward();
    }
  }

  void _onTapUp(TapUpDetails details) {
    if (!widget.isLoading && widget.onPressed != null) {
      _animController.reverse();
    }
  }

  void _onTapCancel() {
    if (!widget.isLoading && widget.onPressed != null) {
      _animController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) => Transform.scale(
        scale: _scaleAnimation.value,
        child: child,
      ),
      child: GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        onTap: widget.isLoading ? null : widget.onPressed,
        child: Container(
          width: widget.width ?? double.infinity,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: widget.gradient ?? ThemeController.instance.primaryGradient,
            border: Border.all(
              color: Colors.white.withOpacity(0.35),
              width: 1.0,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            child: Stack(
              children: [
                // 1. Top Specular Glass Reflection Sheen
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: widget.height * 0.48,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withOpacity(0.38),
                          Colors.white.withOpacity(0.0),
                        ],
                      ),
                    ),
                  ),
                ),

                // 2. Button Content
                Center(
                  child: widget.isLoading
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              widget.textColor ?? Colors.white,
                            ),
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (widget.icon != null) ...[
                              Icon(
                                widget.icon,
                                color: widget.textColor ?? Colors.white,
                                size: 19,
                              ),
                              const SizedBox(width: 8),
                            ],
                            Text(
                              widget.text,
                              style: GoogleFonts.inter(
                                color: widget.textColor ?? Colors.white,
                                fontSize: 15.5,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.1,
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
