import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'package:netracare/app/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (_) {
    // Firebase not configured yet — Google Sign-In will be unavailable
    debugPrint('Firebase not initialized. Google Sign-In disabled.');
  }
  runApp(const NetraCareApp());
}
