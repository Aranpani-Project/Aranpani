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
  
  // This controller accepts Username OR Phone Number
  final TextEditingController _identifierController = TextEditingController();
  final TextEditingController _password = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;

  // ARANPANI THEME COLORS
  final Color _maroon = const Color(0xFF6D1B1B);
  final Color _gold = const Color(0xFFD4AF37);
  final Color _bgColor = const Color(0xFFFFF7E8);

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

      // 1. CHECK IF INPUT IS A PHONE NUMBER (10 digits)
      bool isPhone = RegExp(r'^[0-9]+$').hasMatch(input) && input.length == 10;

      if (isPhone) {
        // If they entered a phone, we find the username associated with it
        final snapshot = await _firestore
            .collection('users')
            .where('phoneNumber', isEqualTo: input)
            .limit(1)
            .get();

        if (snapshot.docs.isEmpty) {
          throw 'This phone number is not registered.';
        }
        
        String username = snapshot.docs.first.get('username');
        finalEmail = "$username@aranpani.com";
      } else {
        // 2. USERNAME LOGIN (This answers your question!)
        // It simply takes the username and adds the virtual domain.
        // This is fast because it doesn't need to check Firestore.
        finalEmail = "$input@aranpani.com";
      }

      // 3. PERFORM SIGN IN
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
      String msg = "Login failed.";
      if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
        msg = "Invalid credentials. Please check your username/phone and password.";
      } else if (e.code == 'wrong-password') {
        msg = "Incorrect password.";
      }
      _showError(msg);
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
              
              // LOGO SECTION
              _buildLogo(),

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

              // LOGIN CARD
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: _gold, width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // USERNAME OR PHONE FIELD
                      TextFormField(
                        controller: _identifierController,
                        style: const TextStyle(color: Colors.black),
                        decoration: InputDecoration(
                          labelText: 'Username or Phone Number',
                          prefixIcon: Icon(Icons.person_outline, color: _maroon),
                          filled: true,
                          fillColor: const Color(0xFFFFFBF2),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                      ),

                      const SizedBox(height: 18),

                      // PASSWORD FIELD
                      TextFormField(
                        controller: _password,
                        obscureText: _obscurePassword,
                        style: const TextStyle(color: Colors.black),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: Icon(Icons.lock_outline, color: _maroon),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_off : Icons.visibility,
                              color: _maroon,
                            ),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                          filled: true,
                          fillColor: const Color(0xFFFFFBF2),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (v) => v != null && v.length >= 6 ? null : 'Min 6 chars',
                      ),

                      const SizedBox(height: 28),

                      // SIGN IN BUTTON
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF7A1E1E),
                            elevation: 3,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Text(
                                  'Sign In',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFFFFF4D6),
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 22),

              // FOOTER
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('New here?'),
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

  Widget _buildLogo() {
    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [_gold, const Color(0xFFB8962E)],
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
          ),
        ),
      ),
    );
  }
}