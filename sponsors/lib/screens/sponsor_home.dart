import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; 
import '../core/app_theme.dart';
import 'login_screen.dart'; 
import 'finance_screen.dart'; // <--- CORRECT IMPORT

class SponsorHome extends StatelessWidget {
  const SponsorHome({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text("Sponsor Dashboard"),
        backgroundColor: AppTheme.primaryBrand,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.temple_buddhist, size: 80, color: AppTheme.primaryBrand),
            const SizedBox(height: 20),
            const Text("Welcome, Sponsor!", 
              style: TextStyle(fontSize: 24, color: Colors.black87)),
            const SizedBox(height: 40),
            
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBrand,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              onPressed: () {
                final user = FirebaseAuth.instance.currentUser;
                if (user != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const FinanceScreen()),
                  );
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                  );
                }
              },
              child: const Text("Make a Donation", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            )
          ],
        ),
      ),
    );
  }
}