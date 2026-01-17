import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'signup_screen.dart';
import 'welcome_screen.dart';
import 'verify_email_screen.dart';

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
  final Color _brightMaroon = const Color(0xFF7A1E1E);
  final Color _gold = const Color(0xFFD4AF37);
  final Color _darkGold = const Color(0xFFB8962E);
  final Color _bgColor = const Color(0xFFFFF7E8);
  final Color _inputFill = const Color(0xFFFFFBF2);
  final Color _buttonTextColor = const Color(0xFFFFF4D6);

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

      // Logic: Handle Phone Number, Username, or Direct Email
      bool isPhone = RegExp(r'^[0-9]+$').hasMatch(input) && input.length == 10;

      if (input.contains('@')) {
        finalEmail = input;
      } else if (isPhone) {
        final snapshot = await _firestore
            .collection('users')
            .where('phoneNumber', isEqualTo: input)
            .limit(1)
            .get();

        if (snapshot.docs.isEmpty) throw 'Phone number not registered.';
        finalEmail = snapshot.docs.first.get('email');
      } else {
        // Assume Username
        final snapshot = await _firestore
            .collection('users')
            .where('username', isEqualTo: input)
            .limit(1)
            .get();

        if (snapshot.docs.isEmpty) throw 'Username not found.';
        finalEmail = snapshot.docs.first.get('email');
      }

      final userCred = await _auth.signInWithEmailAndPassword(
        email: finalEmail,
        password: _password.text.trim(),
      );

      final user = userCred.user;
      if (user != null && !user.emailVerified) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => VerifyEmailScreen(user: user)),
          );
        }
        return;
      }

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const WelcomeScreen()),
        );
      }
    } on FirebaseAuthException catch (e) {
      _showError(e.message ?? "Login failed");
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
              
              // --- LOGO SECTION ---
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
                        Icon(Icons.temple_hindu, size: 50, color: Colors.white),
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

              // --- FORM SECTION ---
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
                          prefixIcon: Icon(Icons.person, color: _maroon),
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
                          prefixIcon: Icon(Icons.lock, color: _maroon),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_off : Icons.visibility,
                              color: _maroon.withOpacity(0.7),
                            ),
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
                            backgroundColor: _brightMaroon,
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
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: _buttonTextColor,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 22),

              // --- FOOTER SECTION ---
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('New to Aranpani?'),
                  TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SignupScreen()),
                    ),
                    child: Text(
                      'Create Account',
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