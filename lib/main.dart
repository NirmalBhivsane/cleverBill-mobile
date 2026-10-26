import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'features/notifications/push_service.dart';
import 'providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
  );
  // Requires android/app/google-services.json (run `flutterfire configure` or download from Firebase console).
  try {
    await Firebase.initializeApp();
    await PushService.init();
  } catch (e) {
    // Firebase not configured for this platform (e.g. running on web without options).
    // Email/password login still works; phone OTP, Google and push need Firebase.
    debugPrint('Firebase init skipped: $e');
  }
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [prefsProvider.overrideWithValue(prefs)],
      child: const CleverBillApp(),
    ),
  );
}
