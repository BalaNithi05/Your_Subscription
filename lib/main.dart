import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'screens/splash_screen.dart';
import 'screens/app_lock_screen.dart';
import 'services/notification_service.dart';
import 'services/app_lock_service.dart';

/// 🌙 GLOBAL THEME NOTIFIER
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

/// 💰 GLOBAL CURRENCY NOTIFIER
final ValueNotifier<String> currencyNotifier = ValueNotifier<String>('₹');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // =========================
  // 🔐 LOAD ENV (SAFE MODE)
  // =========================
  try {
    await dotenv.load(fileName: ".env");
    debugPrint("✅ ENV Loaded");
  } catch (e) {
    debugPrint("⚠️ ENV NOT FOUND – continuing without it");
  }

  // =========================
  // 🔥 SUPABASE INIT
  // =========================
  await Supabase.initialize(
    url: 'https://wlexhuscevscxcwzphje.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndsZXhodXNjZXZzY3hjd3pwaGplIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njg5MDA3MDAsImV4cCI6MjA4NDQ3NjcwMH0.03kGhGf-exrthzj4LgA1kW02slAniabAag-7Xg2ImEo',
  );

  // =========================
  // 🔔 NOTIFICATIONS
  // =========================
  await NotificationService.init();
  await NotificationService.requestPermission();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, mode, __) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          themeMode: mode,
          theme: ThemeData(brightness: Brightness.light, useMaterial3: true),
          darkTheme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
          home: const AppEntry(),
        );
      },
    );
  }
}

/// 🔐 APP ENTRY WITH RELIABLE AUTO-LOCK
class AppEntry extends StatefulWidget {
  const AppEntry({super.key});

  @override
  State<AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends State<AppEntry> with WidgetsBindingObserver {
  DateTime? _lastPausedAt;
  bool _initialChecked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkInitialLock();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _checkInitialLock() async {
    try {
      final enabled = await AppLockService.isEnabled();

      if (!mounted) return;

      if (enabled) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AppLockScreen()),
          );
        });
      }
    } catch (e) {
      debugPrint("AppLock check error: $e");
    }

    setState(() {
      _initialChecked = true;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.paused) {
      _lastPausedAt = DateTime.now();
    }

    if (state == AppLifecycleState.resumed && _lastPausedAt != null) {
      final enabled = await AppLockService.isEnabled();
      if (!enabled || !mounted) return;

      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AppLockScreen()),
        );
      });

      _lastPausedAt = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialChecked) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return const SplashScreen();
  }
}
