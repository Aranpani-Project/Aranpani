import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'signup_screen.dart';
import 'verify_email_screen.dart';
import 'welcome_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailOrUsername = TextEditingController();

  final TextEditingController _identifierController = TextEditingController();
  final TextEditingController _password = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;

  // Theme Colors
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
      String input = _emailOrUsername.text.trim();
      String email = input;
      String input = _identifierController.text.trim().toLowerCase();
      String finalEmail = "";

      // Logic: Handle Phone Number or Username
      bool isPhone = RegExp(r'^[0-9]+$').hasMatch(input) && input.length == 10;

      if (!input.contains('@')) {
        final snapshot = await FirebaseFirestore.instance
      if (isPhone) {
        final snapshot = await _firestore
            .collection('users')
            .where('username', isEqualTo: input)
            .where('phoneNumber', isEqualTo: input)
            .limit(1)
            .get();
        if (snapshot.docs.isEmpty) throw ('No user found');
        email = snapshot.docs.first['email'];

        if (snapshot.docs.isEmpty) {
          throw 'Not a registered user. Please Sign Up to continue.';
        }
        
        String username = snapshot.docs.first.get('username');
        finalEmail = "$username@aranpani.com";
      } else {
        finalEmail = "$input@aranpani.com";
      }

      final userCred = await _auth.signInWithEmailAndPassword(
        email: email,
      await _auth.signInWithEmailAndPassword(
        email: finalEmail,
        password: _password.text.trim(),
      );

      final user = userCred.user!;
      if (!user.emailVerified) {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => VerifyEmailScreen(user: user)),
          MaterialPageRoute(builder: (_) => const WelcomeScreen()),
        );
        return;
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      );
    } on FirebaseAuthException catch (e) {
      // Specific error handling for unregistered users
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
@@ -65,165 +99,168 @@ class _LoginScreenState extends State<LoginScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7E8),
      backgroundColor: _bgColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 40),

              
              // --- LOGO WITH IMAGE ASSET ---
              Container(
                width: 96,
                height: 96,
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFD4AF37),
                      Color(0xFFB8962E),
                    ],
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
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(5),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/images/shiva.png',
                      fit: BoxFit.cover,
                  padding: const EdgeInsets.all(4), // Border thickness for gradient
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/images/shiva.png',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            Icon(Icons.temple_hindu, size: 50, color: _maroon),
                      ),
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
                  color: const Color(0xFF6D1B1B),
                  color: _maroon,
                ),
              ),

              const SizedBox(height: 32),

              // --- LOGIN FORM CONTAINER ---
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: const Color(0xFFD4AF37),
                    width: 1.2,
                  ),
                  border: Border.all(color: _gold, width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: _maroon.withOpacity(0.05),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _emailOrUsername,
                        controller: _identifierController,
                        style: const TextStyle(color: Colors.black),
                        decoration: InputDecoration(
                          labelText: 'Email or Username',
                          prefixIcon: const Icon(Icons.person),
                          labelText: 'Username or Phone',
                          prefixIcon: Icon(Icons.person_outline, color: _maroon),
                          filled: true,
                          fillColor: const Color(0xFFFFFBF2),
                          fillColor: _inputFill,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: _gold.withOpacity(0.5)),
                          ),
                        ),
                        validator: (v) =>
                            v == null || v.isEmpty ? 'Required' : null,
                        validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                      ),

                      const SizedBox(height: 18),

                      TextFormField(
                        controller: _password,
                        obscureText: _obscurePassword,
                        style: const TextStyle(color: Colors.black),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock),
                          prefixIcon: Icon(Icons.lock_outline, color: _maroon),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword),
                            icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                          filled: true,
                          fillColor: const Color(0xFFFFFBF2),
                          fillColor: _inputFill,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: _gold.withOpacity(0.5)),
                          ),
                        ),
                        validator: (v) =>
                            v != null && v.length >= 6 ? null : 'Min 6 chars',
                        validator: (v) => v != null && v.length >= 6 ? null : 'Min 6 chars',
                      ),

                      const SizedBox(height: 28),

                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                const Color(0xFF7A1E1E), // temple maroon
                            elevation: 3,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            backgroundColor: _templeMaroon,
                            elevation: 2,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator(
                                  color: Colors.white)
                              : const Text(
                                  'Sign In',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFFFFF4D6),
                                  ),
                          child: _isLoading 
                            ? const CircularProgressIndicator(color: Colors.white) 
                            : Text(
                                'Sign In', 
                                style: TextStyle(
                                  color: _goldTextColor,
                                  fontSize: 16,
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
              const SizedBox(height: 24),

              // --- UPDATED FOOTER DESIGN ---
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('New to Aranpani?'),
                  TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const SignupScreen()),
                  const Text(
                    'New to Aranpani? ',
                    style: TextStyle(color: Colors.black87),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context, 
                      MaterialPageRoute(builder: (_) => const SignupScreen())
                    ),
                    child: const Text(
                      'Create Account',
                    child: Text(
                      'Sign Up Here',
                      style: TextStyle(
                        color: Color(0xFF6D1B1B),
                        color: _maroon,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
@@ -235,4 +272,4 @@ class _LoginScreenState extends State<LoginScreen> {
      ),
    );
  }