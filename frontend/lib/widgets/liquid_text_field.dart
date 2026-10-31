import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/theme/liquid_glass_theme.dart';
import '../core/theme/theme_controller.dart';

class LiquidTextField extends StatefulWidget {
  final TextEditingController controller;
  final String? label;
  final String hint;
  final IconData prefixIcon;
  final bool isPassword;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final double borderRadius;

  const LiquidTextField({
    super.key,
    required this.controller,
    this.label,
    required this.hint,
    required this.prefixIcon,
    this.isPassword = false,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.borderRadius = 999, // full sleek glass pill
  });

  @override
  State<LiquidTextField> createState() => _LiquidTextFieldState();
}

class _LiquidTextFieldState extends State<LiquidTextField> {
  bool _obscureText = true;
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final isDark = LiquidGlassTheme.isDark;
    final theme = ThemeController.instance;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.label != null && widget.label!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 6),
            child: Text(
              widget.label!,
              style: GoogleFonts.inter(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: theme.textSecondary,
              ),
            ),
          ),
        Focus(
          onFocusChange: (focused) => setState(() => _isFocused = focused),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.borderRadius),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Stack(
                  children: [
                    // Base Glassmorphic Frosted Sheen Container
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(widget.borderRadius),
                        gradient: LinearGradient(
                          begin: const Alignment(-0.6, -1.0),
                          end: const Alignment(0.6, 1.0),
                          colors: isDark
                              ? (_isFocused
                                  ? [
                                      theme.cardBg.withOpacity(0.95),
                                      theme.inputFill.withOpacity(0.85),
                                      theme.surfaceBg.withOpacity(0.70),
                                    ]
                                  : [
                                      theme.inputFill.withOpacity(0.75),
                                      theme.surfaceBg.withOpacity(0.55),
                                      theme.scaffoldBg.withOpacity(0.40),
                                    ])
                              : (_isFocused
                                  ? [
                                      Colors.white.withOpacity(0.95),
                                      Colors.white.withOpacity(0.78),
                                      theme.inputFill.withOpacity(0.50),
                                    ]
                                  : [
                                      Colors.white.withOpacity(0.80),
                                      Colors.white.withOpacity(0.55),
                                      theme.inputFill.withOpacity(0.35),
                                    ]),
                          stops: const [0.0, 0.45, 1.0],
                        ),
                        border: Border.all(
                          color: _isFocused
                              ? theme.primaryColor
                              : (isDark
                                  ? theme.border.withOpacity(0.60)
                                  : Colors.white.withOpacity(0.85)),
                          width: _isFocused ? 1.6 : 1.2,
                        ),
                      ),
                      child: TextFormField(
                        controller: widget.controller,
                        obscureText: widget.isPassword && _obscureText,
                        keyboardType: widget.keyboardType,
                        validator: widget.validator,
                        style: GoogleFonts.inter(
                          color: theme.textPrimary,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          hintText: widget.hint,
                          hintStyle: GoogleFonts.inter(
                            color: theme.textMuted,
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                          ),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
                          prefixIcon: Padding(
                            padding: const EdgeInsets.only(left: 16, right: 10),
                            child: Icon(
                              widget.prefixIcon,
                              color: _isFocused ? theme.primaryColor : theme.textSecondary,
                              size: 19,
                            ),
                          ),
                          prefixIconConstraints: const BoxConstraints(minWidth: 45, minHeight: 48),
                          suffixIcon: widget.isPassword
                              ? GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () => setState(() => _obscureText = !_obscureText),
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 14),
                                    child: Icon(
                                      _obscureText
                                          ? CupertinoIcons.eye_slash
                                          : CupertinoIcons.eye,
                                      color: theme.textSecondary,
                                      size: 19,
                                    ),
                                  ),
                                )
                              : null,
                          suffixIconConstraints: const BoxConstraints(minWidth: 45, minHeight: 48),
                          border: InputBorder.none,
                          errorBorder: InputBorder.none,
                          focusedErrorBorder: InputBorder.none,
                          errorStyle: GoogleFonts.inter(
                            fontSize: 11.5,
                            color: const Color(0xFFEF4444),
                            fontWeight: FontWeight.w500,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ),

                    // Top Specular Curved Glass Highlight Reflection Line
                    Positioned(
                      top: 1.5,
                      left: 24,
                      right: 24,
                      height: 1.5,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withOpacity(0.0),
                              Colors.white.withOpacity(0.95),
                              Colors.white.withOpacity(0.0),
                            ],
                            stops: const [0.0, 0.5, 1.0],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
