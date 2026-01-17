import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  final _formKey = GlobalKey<FormState>();
  
  // Controller for Username or Phone Number only
  final TextEditingController _identifierController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade800,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      String input = _identifierController.text.trim();
      String? email;

      // 1. Determine if input is Phone Number or Username
      // Regex check: If it's all digits, we treat it as a phone number
      bool isPhone = RegExp(r'^[0-9]+$').hasMatch(input);

      QuerySnapshot query;
      if (isPhone) {
        query = await FirebaseFirestore.instance
            .collection('users')
            .where('phoneNumber', isEqualTo: input)
            .limit(1)
            .get();
      } else {
        query = await FirebaseFirestore.instance
            .collection('users')
            .where('username', isEqualTo: input)
            .limit(1)
            .get();
      }

      // 2. Check if user exists in Firestore
      if (query.docs.isEmpty) {
        _showError(isPhone ? 'Phone number not found.' : 'Username not found.');
        setState(() => _isLoading = false);
        return;
      }

      // 3. Extract the email tied to this account for Firebase Auth
      final userData = query.docs.first.data() as Map<String, dynamic>;
      if (userData.containsKey('email')) {
        email = userData['email'];
      } else {
        _showError('This account is missing internal email data.');
        setState(() => _isLoading = false);
        return;
      }

      // 4. Perform the actual Login
      final userCred = await _auth.signInWithEmailAndPassword(
        email: email!,
        password: _passwordController.text.trim(),
      );

      final user = userCred.user;

      if (user != null) {
        // Handle Email Verification
        if (!user.emailVerified) {
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => VerifyEmailScreen(user: user)),
            );
          }
          return;
        }

        // Navigate to App
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const WelcomeScreen()),
          );
        }
      }
      
    } on FirebaseAuthException catch (e) {
      String errorMsg = 'Login failed.';
      if (e.code == 'wrong-password') {
        errorMsg = 'Incorrect password.';
      } else if (e.code == 'too-many-requests') {
        errorMsg = 'Too many attempts. Try again later.';
      }
      _showError(errorMsg);
    } catch (e) {
      _showError('Error: ${e.toString()}');
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
              const SizedBox(height: 40),
              // Avatar/Logo
              Container(
                width: 96, height: 96,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFFD4AF37), Color(0xFFB8962E)],
                  ),
                  boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 6))],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(5),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/images/shiva.png',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(Icons.person, size: 50, color: Colors.white),
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
                        controller: _identifierController,
                        style: const TextStyle(color: Colors.black),
                        decoration: InputDecoration(
                          labelText: 'Username or Phone Number',
                          hintText: 'e.g. shiva_dev or 9876543210',
                          prefixIcon: const Icon(Icons.person_outline, color: Color(0xFF6D1B1B)),
                          filled: true,
                          fillColor: const Color(0xFFFFFBF2),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (v) => v == null || v.isEmpty ? 'Please enter username or phone' : null,
                      ),
                      const SizedBox(height: 18),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        style: const TextStyle(color: Colors.black),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF6D1B1B)),
                          suffixIcon: IconButton(
                            icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: const Color(0xFF6D1B1B)),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                          filled: true,
                          fillColor: const Color(0xFFFFFBF2),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (v) => v != null && v.length >= 6 ? null : 'Min 6 characters',
                      ),
                      const SizedBox(height: 28),
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF7A1E1E),
                            elevation: 3,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text(
                                  'Sign In',
                                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFFFFF4D6)),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('New to Aranpani? ', style: TextStyle(color: Colors.black87)),
                  TextButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SignupScreen())),
                    child: const Text(
                      'Create Account',
                      style: TextStyle(color: Color(0xFF6D1B1B), fontWeight: FontWeight.bold),
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