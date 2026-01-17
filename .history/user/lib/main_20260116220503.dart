// main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Add this import
import 'splash_screen.dart';
import 'welcome_screen.dart'; // Import your Welcome/Home screen
import 'login_screen.dart';   // Import your Login screen
import 'firebase_options.dart';
import 'utils/colors.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TerraDev',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // ... keeping your existing theme settings ...
        primaryColor: AppColors.primary,
        scaffoldBackgroundColor: AppColors.primary,
        // (Keep the rest of your theme code here)
      ),
      // Use StreamBuilder to persist login state
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // If Firebase is still checking the token, show Splash
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SplashScreen();
          }
          // If a user is found, go to Welcome/Home
          if (snapshot.hasData) {
            return const WelcomeScreen(); 
          }
          // Otherwise, go to Splash which leads to Login
          return const SplashScreen();
        },
      ),
    );
  }
}