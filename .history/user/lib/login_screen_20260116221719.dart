// lib/screens/login_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  final _formKey = GlobalKey<FormKey>();
  
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;

  // ARANPANI COLOR PALETTE (Matching Signup)
  final Color _bgColor = const Color(0xFFFFFDF5);
  final Color _accentColor = const Color(0xFF5D4037);
  final Color _sandalwood = const Color(0xFFF5E6CA);
  final Color _mutedBronze = const Color(0xFF8D6E63);
  final Color _darkText = const Color(0xFF3E2723);

  @override
  void dispose() {
    _usernameController.dispose();
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
      // 1. MATCHING VIRTUAL EMAIL LOGIC
      // We convert the user's input to the exact format stored in Firebase
      String username = _usernameController.text.trim().toLowerCase();
      String virtualEmail = "$username@aranpani.com"; 

      // 2. Direct Login
      await _auth.signInWithEmailAndPassword(
        email: virtualEmail,
        password: _passwordController.text.trim(),
      );

      // 3. Success navigation
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const WelcomeScreen()),
        );
      }
      
    } on FirebaseAuthException catch (e) {
      String msg = "Login failed.";
      // Firebase throws 'invalid-credential' for both wrong user or wrong pass for security
      if (e.code == 'user-not-found') {
        msg = "Username not registered.";
      } else if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        msg = "Incorrect username or password.";
      }
      _showError(msg);
    } catch (e) {
      _showError("An unexpected error occurred.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_bgColor, _sandalwood],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildLogo(),
                  const SizedBox(height: 16),
                  Text(
                    'Aranpani',
                    style: GoogleFonts.cinzelDecorative(
                      fontSize: 32, 
                      fontWeight: FontWeight.bold, 
                      color: _accentColor,
                    ),
                  ),
                  const SizedBox(height: 35),
                  
                  // Login Box
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: _sandalwood),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        )
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          _buildInput(
                            controller: _usernameController,
                            label: 'Username',
                            icon: Icons.alternate_email,
                          ),
                          const SizedBox(height: 18),
                          _buildInput(
                            controller: _passwordController,
                            label: 'Password',
                            icon: Icons.lock_outline,
                            isPassword: true,
                          ),
                          const SizedBox(height: 28),
                          
                          _buildLoginButton(),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 25),
                  _buildFooter(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInput({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword ? _obscurePassword : false,
      style: TextStyle(color: _darkText),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: _mutedBronze, fontSize: 14),
        prefixIcon: Icon(icon, color: _accentColor, size: 22),
        suffixIcon: isPassword 
          ? IconButton(
              icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: _accentColor),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            )
          : null,
        filled: true,
        fillColor: Colors.white,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _sandalwood),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _accentColor, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red),
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      validator: (v) => v == null || v.isEmpty ? 'Enter $label' : null,
    );
  }

  Widget _buildLoginButton() {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _login,
        style: ElevatedButton.styleFrom(
          backgroundColor: _accentColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 2,
        ),
        child: _isLoading
            ? const SizedBox(
                height: 20, width: 20, 
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
              )
            : const Text(
                'Sign In', 
                style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)
              ),
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 96, height: 96,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(colors: [Color(0xFFD4AF37), Color(0xFFB8962E)]),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 12, offset: const Offset(0, 6))
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: ClipOval(
          child: Image.asset(
            'assets/images/shiva.png', 
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const Icon(Icons.person, size: 50, color: Colors.white),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text("Don't have an account? ", style: TextStyle(color: _darkText)),
        TextButton(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SignupScreen())),
          child: Text(
            'Register Now', 
            style: TextStyle(color: _accentColor, fontWeight: FontWeight.bold)
          ),
        ),
      ],
    );
  }
}