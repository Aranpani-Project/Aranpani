import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'signup_screen.dart';
import 'welcome_screen.dart';
import 'package:google_fonts/google_fonts.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _identifierController = TextEditingController();
  final TextEditingController _password = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;

  // Custom Temple Theme Colors
  final Color _maroon = const Color(0xFF6D1B1B);
  final Color _templeMaroon = const Color(0xFF7A1E1E);
  final Color _gold = const Color(0xFFD4AF37);
  final Color _darkGold = const Color(0xFFB8962E);
  final Color _bgColor = const Color(0xFFFFF7E8);
  final Color _inputFill = const Color(0xFFFFFBF2);
  final Color _goldTextColor = const Color(0xFFFFF4D6);

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade800,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      String input = _identifierController.text.trim().toLowerCase();
      String finalEmail = "";

      // Logic: Handle Phone Number or Username
      bool isPhone = RegExp(r'^[0-9]+$').hasMatch(input) && input.length == 10;

      if (isPhone) {
        final snapshot = await _firestore
            .collection('users')
            .where('phoneNumber', isEqualTo: input)
            .limit(1)
            .get();

        if (snapshot.docs.isEmpty) {
          throw 'Not a registered user. Please Sign Up to continue.';
        }
        
        String username = snapshot.docs.first.get('username');
        finalEmail = "$username@aranpani.com";
      } else {
        // Direct username login
        finalEmail = "$input@aranpani.com";
      }

      await _auth.signInWithEmailAndPassword(
        email: finalEmail,
        password: _password.text.trim(),
      );

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const WelcomeScreen()),
        );
      }
    } on FirebaseAuthException catch (e) {
      // Specifically handle "user not found" scenario
      if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
        _showError("Not a registered user. Please Sign Up to continue.");
      } else {
        _showError("Login failed: ${e.message}");
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 40),

              // --- LATEST LOGO DESIGN ---
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [_gold, _darkGold],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 12,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(5),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/images/shiva.png',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.temple_hindu, size: 50, color: Colors.white),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              Text(
                'ShivPunarva',
                style: GoogleFonts.cinzelDecorative(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: _maroon,
                ),
              ),

              const SizedBox(height: 32),

              // --- LOGIN BOX ---
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: _gold, width: 1.2),
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _identifierController,
                        style: const TextStyle(color: Colors.black),
                        decoration: InputDecoration(
                          labelText: 'Username or Phone',
                          prefixIcon: Icon(Icons.person_outline, color: _maroon),
                          filled: true,
                          fillColor: _inputFill,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 18),
                      TextFormField(
                        controller: _password,
                        obscureText: _obscurePassword,
                        style: const TextStyle(color: Colors.black),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: Icon(Icons.lock_outline, color: _maroon),
                          suffixIcon: IconButton(
                            icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                          filled: true,
                          fillColor: _inputFill,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (v) => v != null && v.length >= 6 ? null : 'Min 6 chars',
                      ),
                      const SizedBox(height: 28),
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _templeMaroon,
                            elevation: 3,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : Text(
                                  'Sign In',
                                  style: TextStyle(
                                    color: _goldTextColor,
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 22),

              // --- FOOTER: NEW TO ARANPANI ---
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'New to Aranpani?',
                    style: TextStyle(color: Colors.black87),
                  ),
                  TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SignupScreen()),
                    ),
                    child: Text(
                      'Sign Up Here',
                      style: TextStyle(
                        color: _maroon,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}