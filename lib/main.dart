import 'package:flutter/material.dart';
import 'screens/home_page.dart';
import 'screens/splash_screen.dart';
import 'screens/onboarding_flow.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'app/constants.dart';

final FlutterLocalNotificationsPlugin flnp = FlutterLocalNotificationsPlugin();
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) {}
Future<bool> _hasNotificationPermission() async {
  final status = await Permission.notification.status;
  return status.isGranted;
}

Future<bool> _needsOnboarding() async {
  final locationStatus = await Permission.locationAlways.status;
  final notificationStatus = await Permission.notification.status;
  
  // Show onboarding if location permission is not granted
  return !locationStatus.isGranted;
}

Future<void> _initLocalNotifications() async {
  const AndroidInitializationSettings initAndroid =
      AndroidInitializationSettings('ic_stat_ms');

  // Create notification channel
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    kServiceChannelId,
    'MosqueSilence Service',
    description: 'Shows when MosqueSilence is monitoring mosque locations',
    importance: Importance.low,
    showBadge: false,
  );

  await flnp
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  final InitializationSettings init = InitializationSettings(android: initAndroid);
  await flnp.initialize(
    init,
    onDidReceiveNotificationResponse: (resp) {
      navigatorKey.currentState?.pushNamedAndRemoveUntil('/', (r) => false);
    },
    onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
  );
}


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _initLocalNotifications();
  runApp(const MosqueSilenceApp());
}

class MosqueSilenceApp extends StatelessWidget {
  const MosqueSilenceApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'MosqueSilence',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F8A8E),
        ), // refined teal
        scaffoldBackgroundColor: const Color(0xFF0F172A), 
        snackBarTheme: const SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: Colors.white.withValues(alpha: 0.08),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
      home: const AppWrapper(),
    );
  }
}

class AppWrapper extends StatefulWidget {
  const AppWrapper({super.key});

  @override
  State<AppWrapper> createState() => _AppWrapperState();
}

class _AppWrapperState extends State<AppWrapper> {
  bool _showSplash = true;
  bool _showOnboarding = false;

  void _onSplashComplete() {
    _checkOnboarding();
  }

  Future<void> _checkOnboarding() async {
    final needsOnboarding = await _needsOnboarding();
    
    setState(() {
      _showSplash = false;
      _showOnboarding = needsOnboarding;
    });
  }

  void _onOnboardingComplete() {
    setState(() {
      _showOnboarding = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_showSplash) {
      return SplashScreen(onComplete: _onSplashComplete);
    }
    
    if (_showOnboarding) {
      return OnboardingFlow(onComplete: _onOnboardingComplete);
    }
    
    return const HomePage();
  }
}