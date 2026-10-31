import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:frontend/core/api/api_client.dart';
import 'package:frontend/core/theme/theme_controller.dart';
import 'package:frontend/widgets/liquid_background.dart';
import 'package:frontend/widgets/liquid_button.dart';
import 'package:frontend/widgets/liquid_text_field.dart';
import 'package:frontend/features/home/screens/home_dashboard_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isLogin = true;
  bool _isLoading = false;
  String? _errorMessage;

  // Controllers (Username, Email, Password, Login Identifier)
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _loginIdentController = TextEditingController();

  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _loginIdentController.dispose();
    super.dispose();
  }

  void _toggleMode() {
    setState(() {
      _isLogin = !_isLogin;
      _errorMessage = null;

      if (_isLogin) {
        // Sync identifier from sign up to sign in
        if (_usernameController.text.trim().isNotEmpty) {
          _loginIdentController.text = _usernameController.text.trim();
        } else if (_emailController.text.trim().isNotEmpty) {
          _loginIdentController.text = _emailController.text.trim();
        }
      } else {
        // Sync identifier from sign in to sign up
        final ident = _loginIdentController.text.trim();
        if (ident.contains('@')) {
          _emailController.text = ident;
        } else if (ident.isNotEmpty) {
          _usernameController.text = ident;
        }
      }
    });
  }

  Future<void> _handleSubmit() async {
    setState(() => _errorMessage = null);

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      if (_isLogin) {
        final authData = await ApiClient.instance.login(
          usernameOrEmail: _loginIdentController.text.trim(),
          password: _passwordController.text,
        );
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => HomeDashboardScreen(user: authData.user),
            ),
          );
        }
      } else {
        final authData = await ApiClient.instance.register(
          username: _usernameController.text.trim(),
          email: _emailController.text.trim(),
          password: _passwordController.text,
          displayName: _usernameController.text.trim(),
        );
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => HomeDashboardScreen(user: authData.user),
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception:', '').trim();
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        final theme = ThemeController.instance;

        return LiquidBackground(
          child: Stack(
            children: [
              // 1. Top Quick Theme / Dark Mode Action Pill
              Positioned(
                top: 8,
                right: 20,
                child: GestureDetector(
                  onTap: () => theme.toggleDarkMode(),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: theme.cardBg.withOpacity(theme.isDark ? 0.70 : 0.85),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: theme.border.withOpacity(theme.isDark ? 0.40 : 0.60),
                        width: 0.8,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(theme.isDark ? 0.25 : 0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          theme.isDark ? CupertinoIcons.sun_max_fill : CupertinoIcons.moon_fill,
                          size: 14,
                          color: theme.isDark ? const Color(0xFFF59E0B) : theme.primaryColor,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          theme.isDark ? 'Light' : 'Dark',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: theme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 2. Center Auth Content (Card removed)
              Center(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 36.0),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 380),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Clean Brand Header
                        _buildModernHeader(theme),
                        const SizedBox(height: 24),

                        // Segmented Switcher Pill (Sign In / Sign Up)
                        _buildSegmentedTab(theme),
                        const SizedBox(height: 24),

                        // Form Fields & Submission
                        Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Error Banner
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                child: _errorMessage != null
                                    ? Padding(
                                        padding: const EdgeInsets.only(bottom: 16.0),
                                        child: _buildErrorBanner(_errorMessage!, theme),
                                      )
                                    : const SizedBox.shrink(),
                              ),

                              // Form Fields
                              AnimatedSize(
                                duration: const Duration(milliseconds: 240),
                                curve: Curves.easeInOutCubic,
                                alignment: Alignment.topCenter,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    if (_isLogin) ...[
                                      LiquidTextField(
                                        controller: _loginIdentController,
                                        hint: 'Username or email',
                                        prefixIcon: CupertinoIcons.person_crop_circle_fill,
                                        validator: (v) => v == null || v.trim().isEmpty
                                            ? 'Enter your username or email'
                                            : null,
                                      ),
                                      const SizedBox(height: 14),
                                      LiquidTextField(
                                        controller: _passwordController,
                                        hint: 'Password',
                                        prefixIcon: CupertinoIcons.lock_fill,
                                        isPassword: true,
                                        validator: (v) => v == null || v.isEmpty
                                            ? 'Enter your password'
                                            : null,
                                      ),
                                    ] else ...[
                                      LiquidTextField(
                                        controller: _usernameController,
                                        hint: 'Username',
                                        prefixIcon: CupertinoIcons.person_crop_circle_fill,
                                        validator: (v) => v == null || v.trim().length < 3
                                            ? 'At least 3 characters'
                                            : null,
                                      ),
                                      const SizedBox(height: 14),
                                      LiquidTextField(
                                        controller: _emailController,
                                        hint: 'Email address',
                                        prefixIcon: CupertinoIcons.mail_solid,
                                        keyboardType: TextInputType.emailAddress,
                                        validator: (v) => v == null || !v.contains('@')
                                            ? 'Enter a valid email'
                                            : null,
                                      ),
                                      const SizedBox(height: 14),
                                      LiquidTextField(
                                        controller: _passwordController,
                                        hint: 'Password (min. 6 characters)',
                                        prefixIcon: CupertinoIcons.lock_fill,
                                        isPassword: true,
                                        validator: (v) => v == null || v.length < 6
                                            ? 'At least 6 characters'
                                            : null,
                                      ),
                                    ],
                                  ],
                                ),
                              ),

                              const SizedBox(height: 24),

                              // Action Button with Theme Primary Gradient
                              LiquidButton(
                                text: _isLogin ? 'Sign In' : 'Create Account',
                                height: 50,
                                borderRadius: 999,
                                gradient: theme.primaryGradient,
                                isLoading: _isLoading,
                                onPressed: _handleSubmit,
                              ),

                              const SizedBox(height: 20),

                              // Switcher Bottom Prompt
                              GestureDetector(
                                onTap: _toggleMode,
                                behavior: HitTestBehavior.opaque,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                                  child: Center(
                                    child: RichText(
                                      text: TextSpan(
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          color: theme.textSecondary,
                                        ),
                                        children: [
                                          TextSpan(
                                            text: _isLogin
                                                ? "Don't have an account? "
                                                : "Already have an account? ",
                                          ),
                                          TextSpan(
                                            text: _isLogin ? 'Sign Up' : 'Sign In',
                                            style: GoogleFonts.inter(
                                              fontWeight: FontWeight.w700,
                                              color: theme.primaryColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
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
            ],
          ),
        );
      },
    );
  }

  Widget _buildSegmentedTab(ThemeController theme) {
    return Container(
      height: 44,
      padding: const EdgeInsets.all(3.5),
      decoration: BoxDecoration(
        color: theme.inputFill.withOpacity(theme.isDark ? 0.65 : 0.60),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: theme.border.withOpacity(theme.isDark ? 0.25 : 0.40),
          width: 0.8,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (!_isLogin) _toggleMode();
              },
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _isLogin ? theme.cardBg : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: _isLogin
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(theme.isDark ? 0.30 : 0.08),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  'Sign In',
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    fontWeight: _isLogin ? FontWeight.w600 : FontWeight.w500,
                    color: _isLogin ? theme.textPrimary : theme.textSecondary,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (_isLogin) _toggleMode();
              },
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: !_isLogin ? theme.cardBg : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: !_isLogin
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(theme.isDark ? 0.30 : 0.08),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
              ),
              child: Text(
                'Sign Up',
                style: GoogleFonts.inter(
                  fontSize: 13.5,
                  fontWeight: !_isLogin ? FontWeight.w600 : FontWeight.w500,
                  color: !_isLogin ? theme.textPrimary : theme.textSecondary,
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

  Widget _buildModernHeader(ThemeController theme) {
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: theme.primaryGradient,
            border: Border.all(
              color: Colors.white.withOpacity(0.35),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: theme.primaryColor.withOpacity(theme.isDark ? 0.35 : 0.25),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              children: [
                // Top Gloss Reflection Sheen
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 26,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withOpacity(0.40),
                          Colors.white.withOpacity(0.0),
                        ],
                      ),
                    ),
                  ),
                ),
                const Center(
                  child: Icon(
                    CupertinoIcons.chat_bubble_2_fill,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'ChatGo',
          style: GoogleFonts.outfit(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: theme.textPrimary,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 5),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: Text(
            _isLogin
                ? 'Sign in to continue your conversations'
                : 'Create an account to get started',
            key: ValueKey<bool>(_isLogin),
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: theme.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorBanner(String message, ThemeController theme) {
    final isDark = theme.isDark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF7F1D1D).withOpacity(0.32)
            : const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? const Color(0xFFEF4444).withOpacity(0.40)
              : const Color(0xFFFCA5A5),
          width: 1.0,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            CupertinoIcons.exclamationmark_circle_fill,
            color: Color(0xFFEF4444),
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.inter(
                color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C),
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
