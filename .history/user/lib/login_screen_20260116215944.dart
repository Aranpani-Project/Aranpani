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
  
  final TextEditingController _identifierController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

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
      String input = _identifierController.text.trim();
      
      // 1. Identify if input is the Phone Number or the Username
      bool isPhone = RegExp(r'^[0-9]+$').hasMatch(input);

      // 2. Search Firestore using your specific field names
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

      // 3. Check if the user document exists
      if (query.docs.isEmpty) {
        _showError(isPhone ? 'Phone number not found.' : 'Username not found.');
        setState(() => _isLoading = false);
        return;
      }

      // 4. GET DATA SAFELY
      final userData = query.docs.first.data() as Map<String, dynamic>;
      
      // IMPORTANT: Your Firestore record is missing the 'email' field.
      // Firebase Auth NEEDs an email for password login.
      // If you don't have the email in Firestore, we can try a fallback 
      // or show a specific error.
      if (!userData.containsKey('email')) {
        _showError("Database Error: No 'email' field found for user '${userData['username']}'. Please add it in Firestore.");
        setState(() => _isLoading = false);
        return;
      }

      String userEmail = userData['email'];

      // 5. Perform the sign-in
      await _auth.signInWithEmailAndPassword(
        email: userEmail,
        password: _passwordController.text.trim(),
      );

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
      } else if (e.code == 'user-not-found') {
        msg = "No Firebase account exists for this email.";
      }
      _showError(msg);
    } catch (e) {
      _showError("Unexpected Error: ${e.toString()}");
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
              _buildLogo(),
              const SizedBox(height: 16),
              Text(
                'ShivPunarva',
                style: GoogleFonts.cinzelDecorative(
                  fontSize: 30, fontWeight: FontWeight.bold, color: const Color(0xFF6D1B1B),
                ),
              ),
              const SizedBox(height: 32),
              
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
                        decoration: InputDecoration(
                          labelText: 'Username or Phone',
                          hintText: 'e.g., waseem or 7845719687',
                          prefixIcon: const Icon(Icons.person_outline, color: Color(0xFF6D1B1B)),
                          filled: true,
                          fillColor: const Color(0xFFFFFBF2),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 18),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
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
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 96, height: 96,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: [Color(0xFFD4AF37), Color(0xFFB8962E)]),
      ),
      child: ClipOval(
        child: Image.asset(
          'assets/images/shiva.png',
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Icon(Icons.person, size: 50, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('New here? ', style: TextStyle(color: Colors.black87)),
        TextButton(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SignupScreen())),
          child: const Text('Create Account', style: TextStyle(color: Color(0xFF6D1B1B), fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}