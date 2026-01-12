import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'; // REQUIRED for kIsWeb
import 'core/app_theme.dart';
import 'screens/sponsor_home.dart';
import 'screens/login_screen.dart'; // Ensure this file exists

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    // -----------------------------------------------------------
    // WEB CONFIGURATION (Filled with your keys)
    // -----------------------------------------------------------
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyCobJRau9a8YdLSnzXYoOeGAEeDev27KYE",
        authDomain: "barrenlanddevleopment.firebaseapp.com",
        projectId: "barrenlanddevleopment",
        storageBucket: "barrenlanddevleopment.firebasestorage.app",
        messagingSenderId: "39473406312",
        appId: "1:39473406312:web:586b9bc0239e627a9c76dd",
        measurementId: "G-DDTYB70Z1L",
      ),
    );
  } else {
    // -----------------------------------------------------------
    // ANDROID / iOS CONFIGURATION
    // -----------------------------------------------------------
    await Firebase.initializeApp();
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false, 
      title: 'Temple Sponsors',
      theme: AppTheme.lightTheme,
      // --- FIXED LINE BELOW ---
      // Changed 'login_screen' to 'LoginScreen' (Capital L, no underscore)
      home: const LoginScreen(), 
    );
  }
}