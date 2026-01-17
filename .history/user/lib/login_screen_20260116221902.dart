import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'signup_screen.dart';
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
  final _formKey = GlobalKey<FormState>();
  
  // Controllers for Username and Password
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;

  // Custom error snackbar
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
      String usernameInput = _usernameController.text.trim();

      // 1. Find the user in Firestore using ONLY the username
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('username', isEqualTo: usernameInput)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        _showError('Username "$usernameInput" not found.');
        return;
      }

      // 2. Extract the hidden email from that user's document
      final userData = snapshot.docs.first.data();
      if (!userData.containsKey('email')) {
        _showError('This account is not set up correctly (missing email).');
        return;
      }
      
      String internalEmail = userData['email'];

      // 3. Log in with Firebase Auth using the email we just found
      await _auth.signInWithEmailAndPassword(
        email: internalEmail,
        password: _passwordController.text.trim(),
      );

      // 4. Success Navigation
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const WelcomeScreen()),
        );
      }
      
    } on FirebaseAuthException catch (e) {
      String msg = "Login failed.";
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        msg = "Incorrect password.";
      }
      _showError(msg);
    } catch (e) {
      _showError("System Error: ${e.toString()}");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7E8),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 60),
              
              // Logo Section
              Container(
                width: 96, height: 96,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [Color(0xFFD4AF37), Color(0xFFB8962E)]),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(5),
                  child: ClipOval(
                    child: Image.asset('assets/images/shiva.png', fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(Icons.person, size: 50, color: Colors.white),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),
              Text(
                'ShivPunarva',
                style: GoogleFonts.cinzelDecorative(
                  fontSize: 30, fontWeight: FontWeight.bold, color: const Color(0xFF6D1B1B),
                ),
              ),

              const SizedBox(height: 32),

              // Login Box
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFD4AF37), width: 1.2),
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _usernameController,
                        decoration: InputDecoration(
                          labelText: 'Username',
                          prefixIcon: const Icon(Icons.person, color: Color(0xFF6D1B1B)),
                          filled: true,
                          fillColor: const Color(0xFFFFFBF2),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (v) => v == null || v.isEmpty ? 'Please enter username' : null,
                      ),
                      const SizedBox(height: 18),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock, color: Color(0xFF6D1B1B)),
                          suffixIcon: IconButton(
                            icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: const Color(0xFF6D1B1B)),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                          filled: true,
                          fillColor: const Color(0xFFFFFBF2),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (v) => v == null || v.length < 6 ? 'Password too short' : null,
                      ),
                      const SizedBox(height: 28),
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF7A1E1E),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text('Sign In', style: TextStyle(fontSize: 17, color: Color(0xFFFFF4D6), fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 22),
              
              // Footer
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('New here? '),
                  TextButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SignupScreen())),
                    child: const Text('Create Account', style: TextStyle(color: Color(0xFF6D1B1B), fontWeight: FontWeight.bold)),
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