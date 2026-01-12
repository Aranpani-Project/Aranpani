import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../core/app_theme.dart';
import 'sponsor_home.dart'; // <--- CORRECT IMPORT

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      const String webClientId = "39473406312-nqs9m3rm7nic3j20la2ka6861ne4tlhr.apps.googleusercontent.com";
      final GoogleSignIn googleSignIn = GoogleSignIn(clientId: webClientId);
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      
      if (googleUser != null) {
        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
        final AuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        await FirebaseAuth.instance.signInWithCredential(credential);
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const SponsorHome()),
        );
      }
    } catch (e) {
      debugPrint("Login Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Login Failed: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(decoration: const BoxDecoration(gradient: AppTheme.mainGradient)),
          Positioned(
            top: -100, right: -100,
            child: Container(
              width: 300, height: 300,
              decoration: BoxDecoration(
                color: AppTheme.primaryAccent.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(4), 
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.primaryAccent, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryAccent.withOpacity(0.6),
                          blurRadius: 25,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const CircleAvatar(
                      radius: 60, 
                      backgroundColor: Colors.black, 
                      backgroundImage: AssetImage('assets/shiva.png'), 
                    ),
                  ),
                  const SizedBox(height: 40),
                  Container(
                    constraints: const BoxConstraints(maxWidth: 400),
                    padding: const EdgeInsets.all(40),
                    decoration: AppTheme.cardDecoration,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          "Temple Trust",
                          style: TextStyle(
                            fontSize: 28, 
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryBrand,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          "Sign in to manage your donations\nand view history.",
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 14, color: Colors.grey, height: 1.5),
                        ),
                        const SizedBox(height: 40),
                        _isLoading 
                          ? const CircularProgressIndicator(color: AppTheme.primaryBrand)
                          : SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  side: const BorderSide(color: Colors.grey),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  backgroundColor: Colors.white,
                                ),
                                icon: const Icon(Icons.g_mobiledata, size: 30, color: Colors.red), 
                                label: const Text(
                                  "Continue with Google",
                                  style: TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.w500),
                                ),
                                onPressed: _handleGoogleSignIn,
                              ),
                            ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}