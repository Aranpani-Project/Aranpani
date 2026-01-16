import 'package:admin/screens/login_screen.dart';
import 'package:admin/screens/dashboard_screen.dart'; // Make sure to import your dashboard
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const AranpaniAdminApp());
}

class AranpaniAdminApp extends StatelessWidget {
  const AranpaniAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aranpani Admin',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        scaffoldBackgroundColor: const Color(0xFFF9FAFB),
      ),
      // Use a StreamBuilder to check the persistent login state
      home: const AuthGate(),
      debugShowCheckedModeBanner: false,
    );
  }
}

/// This widget listens to the authentication state and switches screens automatically
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // If the connection is active, check for the user
        if (snapshot.connectionState == ConnectionState.active) {
          User? user = snapshot.data;
          
          // If user is null, they are not logged in
          if (user == null) {
            return const LoginScreen();
          }
          
          // If user exists, go straight to Dashboard
          return const DashboardScreen();
        }

        // While checking the auth state, show a loading spinner
        return const Scaffold(
          body: Center(
            child: CircularProgressIndicator(color: Color(0xFF6D1B1B)),
          ),
        );
      },
    );
  }
}