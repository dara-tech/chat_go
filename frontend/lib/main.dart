import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/api/api_client.dart';
import 'core/notifications/in_app_notification_banner_overlay.dart';
import 'core/notifications/notification_alert_service.dart';
import 'core/services/chat_folder_controller.dart';
import 'core/theme/theme_controller.dart';
import 'models/user_model.dart';
import 'screens/auth_screen.dart';
import 'screens/home_dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ThemeController.instance.init();
  await ChatFolderController.instance.init();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(
    const ProviderScope(
      child: ChatGoApp(),
    ),
  );
}

class ChatGoApp extends StatefulWidget {
  const ChatGoApp({super.key});

  @override
  State<ChatGoApp> createState() => _ChatGoAppState();
}

class _ChatGoAppState extends State<ChatGoApp> {
  bool _isCheckingAuth = true;
  UserModel? _loggedInUser;

  @override
  void initState() {
    super.initState();
    _checkInitialAuth();
  }

  Future<void> _checkInitialAuth() async {
    try {
      final token = await ApiClient.instance.getAccessToken();
      if (token != null && token.isNotEmpty) {
        final user = await ApiClient.instance.getMe();
        NotificationAlertService.instance.init(user: user);
        setState(() {
          _loggedInUser = user;
        });
      }
    } catch (_) {
      // Token expired or server unreachable, fallback to AuthScreen
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingAuth = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        return MaterialApp(
          navigatorKey: NotificationAlertService.navigatorKey,
          title: 'ChatGo',
          debugShowCheckedModeBanner: false,
          themeAnimationDuration: Duration.zero,
          builder: (context, child) {
            return Stack(
              children: [
                ?child,
                const InAppNotificationBannerOverlay(),
              ],
            );
          },
          theme: ThemeData(
            brightness: ThemeController.instance.isDark ? Brightness.dark : Brightness.light,
            scaffoldBackgroundColor: ThemeController.instance.scaffoldBg,
            colorScheme: ColorScheme(
              brightness: ThemeController.instance.isDark ? Brightness.dark : Brightness.light,
              primary: ThemeController.instance.primaryColor,
              onPrimary: Colors.white,
              secondary: ThemeController.instance.secondaryColor,
              onSecondary: Colors.white,
              error: const Color(0xFFEF4444),
              onError: Colors.white,
              surface: ThemeController.instance.surfaceBg,
              onSurface: ThemeController.instance.textPrimary,
            ),
          ),
          home: _isCheckingAuth
              ? Scaffold(
                  backgroundColor: ThemeController.instance.scaffoldBg,
                  body: Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(ThemeController.instance.primaryColor),
                    ),
                  ),
                )
              : _loggedInUser != null
                  ? HomeDashboardScreen(user: _loggedInUser!)
                  : const AuthScreen(),
        );
      },
    );
  }
}
