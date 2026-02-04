import 'package:flutter/material.dart';
import '../services/app_lock_service.dart';

class AppLockScreen extends StatefulWidget {
  const AppLockScreen({super.key});

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> {
  bool _isAuthenticating = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _unlockWithBiometric();
  }

  // ================= SYSTEM AUTH ONLY =================
  Future<void> _unlockWithBiometric() async {
    if (_isAuthenticating) return;

    setState(() {
      _isAuthenticating = true;
      _failed = false;
    });

    final success = await AppLockService.authenticate();

    if (!mounted) return;

    if (success) {
      Navigator.pop(context);
    } else {
      setState(() {
        _isAuthenticating = false;
        _failed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock, size: 60),
              const SizedBox(height: 16),
              const Text(
                'Unlock App',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 16),

              if (_failed)
                const Text(
                  'Authentication failed. Try again.',
                  style: TextStyle(color: Colors.red),
                ),

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _unlockWithBiometric,
                  child: const Text('Unlock'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
