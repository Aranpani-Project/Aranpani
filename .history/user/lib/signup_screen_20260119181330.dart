// lib/screens/signup_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import 'welcome_screen.dart'; 

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});
  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  // ARANPANI COLOR PALETTE
  final Color _bgColor = const Color(0xFFFFFDF5);
  final Color _accentColor = const Color(0xFF5D4037);
  final Color _sandalwood = const Color(0xFFF5E6CA);
  final Color _mutedBronze = const Color(0xFF8D6E63);
  final Color _darkText = const Color(0xFF3E2723);

  // Controllers
  final TextEditingController _name = TextEditingController();
  final TextEditingController _username = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _aadhar = TextEditingController();
  final TextEditingController _address = TextEditingController();
  final TextEditingController _state = TextEditingController();
  final TextEditingController _country = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirm = TextEditingController();

  final FocusNode _usernameFocus = FocusNode();
  final FocusNode _phoneFocus = FocusNode();
  final FocusNode _aadharFocus = FocusNode();

  String? _usernameError;
  String? _phoneError;
  String? _aadharError;
  bool _checkingPhone = false;
  bool _checkingAadhar = false;
  bool _checkingUsername = false;

  // OTP State
  final List<TextEditingController> _otpControllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes = List.generate(6, (_) => FocusNode());
  bool _otpVisible = false;
  bool _otpVerified = false;
  bool _otpSending = false;
  String _sessionId = "";

  bool _agree = false;
  bool _isLoading = false;

  static const String apiKey = "0b23b35d-c516-11f0-a6b2-0200cd936042";

  @override
  void initState() {
    super.initState();
    _usernameFocus.addListener(() {
      if (!_usernameFocus.hasFocus && _username.text.length >= 4) {
        _checkDuplicate("username", _username.text.trim());
      }
    });
    _phoneFocus.addListener(() {
      if (!_phoneFocus.hasFocus && _phone.text.length == 10) {
        _checkDuplicate("phoneNumber", _phone.text);
      }
    });
    _aadharFocus.addListener(() {
      if (!_aadharFocus.hasFocus && _aadhar.text.length == 12) {
        _checkDuplicate("aadharNumber", _aadhar.text);
      }
    });
  }

  @override
  void dispose() {
    for (var c in _otpControllers) c.dispose();
    for (var f in _otpFocusNodes) f.dispose();
    _name.dispose(); _username.dispose(); _phone.dispose();
    _aadhar.dispose(); _address.dispose(); _state.dispose(); _country.dispose();
    _password.dispose(); _confirm.dispose();
    super.dispose();
  }

  Future<void> _checkDuplicate(String field, String value) async {
    if (value.isEmpty) return;
    setState(() {
      if (field == "phoneNumber") _checkingPhone = true;
      if (field == "aadharNumber") _checkingAadhar = true;
      if (field == "username") _checkingUsername = true;
    });
    try {
      final snapshot = await _firestore.collection('users').where(field, isEqualTo: value).limit(1).get();
      setState(() {
        if (snapshot.docs.isNotEmpty) {
          if (field == "username") _usernameError = "Username taken";
          if (field == "phoneNumber") _phoneError = "Already registered";
          if (field == "aadharNumber") _aadharError = "Already registered";
        } else {
          if (field == "username") _usernameError = null;
          if (field == "phoneNumber") _phoneError = null;
          if (field == "aadharNumber") _aadharError = null;
        }
      });
    } catch (e) {
      debugPrint("DB Check Error: $e");
    } finally {
      setState(() {
        if (field == "phoneNumber") _checkingPhone = false;
        if (field == "aadharNumber") _checkingAadhar = false;
        if (field == "username") _checkingUsername = false;
      });
    }
  }

  Future<void> _sendOTP() async {
    if (_phone.text.length != 10 || _phoneError != null || _checkingPhone) return;
    setState(() => _otpSending = true);
    try {
      final res = await http.get(Uri.parse("https://2factor.in/API/V1/$apiKey/SMS/+91${_phone.text}/AUTOGEN"));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data["Status"] == "Success") {
          setState(() { _otpVisible = true; _sessionId = data["Details"] ?? ""; });
          _otpFocusNodes[0].requestFocus();
        }
      }
    } catch (e) {}
    setState(() => _otpSending = false);
  }

  Future<void> _verifyOtp() async {
    String otp = _otpControllers.map((c) => c.text).join();
    final res = await http.get(Uri.parse("https://2factor.in/API/V1/$apiKey/SMS/VERIFY/$_sessionId/$otp"));
    if (res.statusCode == 200 && jsonDecode(res.body)["Status"] == "Success") {
      setState(() { _otpVerified = true; _otpVisible = false; });
    }
  }

  Future<void> _signup() async {
    if (_usernameError != null || _phoneError != null || _aadharError != null) return;
    if (!_formKey.currentState!.validate()) return;
    if (!_otpVerified) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Verify phone number first")));
      return;
    }
    if (!_agree) return;

    setState(() => _isLoading = true);
    try {
      final uname = _username.text.trim().toLowerCase();
      // HIDDEN VIRTUAL EMAIL GENERATION
      final hiddenEmail = "$uname@aranpani.com";

      final userCred = await _auth.createUserWithEmailAndPassword(
        email: hiddenEmail, 
        password: _password.text.trim()
      );
      
      await _firestore.collection("users").doc(userCred.user!.uid).set({
        "name": _name.text.trim(),
        "username": uname,
        "phoneNumber": _phone.text.trim(),
        "aadharNumber": _aadhar.text.trim(),
        "address": _address.text.trim(),
        "state": _state.text.trim(),
        "country": _country.text.trim(),
        "createdAt": FieldValue.serverTimestamp(),
        "phoneVerified": true,
      });

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const WelcomeScreen()), (route) => false);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
    setState(() => _isLoading = false);
  }

  // --- UI BUILDING BLOCKS ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: Container(
        width: double.infinity, height: double.infinity,
        decoration: BoxDecoration(gradient: LinearGradient(colors: [_bgColor, _sandalwood], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(children: [IconButton(icon: Icon(Icons.arrow_back_ios_new, color: _accentColor), onPressed: () => Navigator.pop(context))]),
              ),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      _buildLogo(),
                      const SizedBox(height: 12),
                      Text("Aranpani", style: GoogleFonts.cinzelDecorative(fontSize: 32, fontWeight: FontWeight.bold, color: _accentColor)),
                      const SizedBox(height: 25),
                      Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: _sandalwood),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              _input(_name, "Full Name", Icons.person_outline, validationType: "name"),
                              const SizedBox(height: 16),
                              _input(_username, "Choose Username", Icons.alternate_email, focusNode: _usernameFocus, validationType: "username", isLoading: _checkingUsername),
                              const SizedBox(height: 16),
                              _phoneSection(),
                              const SizedBox(height: 16),
                              _input(_aadhar, "Aadhar Number", Icons.badge_outlined, focusNode: _aadharFocus, keyboardType: TextInputType.number, validationType: "aadhar", isLoading: _checkingAadhar,
                                formatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(12)]),
                              const SizedBox(height: 16),
                              _input(_address, "Address", Icons.home_outlined, validationType: "required"),
                              const SizedBox(height: 16),
                              _input(_state, "State", Icons.location_city_outlined, validationType: "required"),
                              const SizedBox(height: 16),
                              _input(_country, "Country", Icons.public_outlined, validationType: "required"),
                              const SizedBox(height: 16),
                              _passwordField(_password, "Create Password"),
                              const SizedBox(height: 16),
                              _passwordField(_confirm, "Confirm Password", isConfirm: true),
                              const SizedBox(height: 20),
                              _termsCheckbox(),
                              const SizedBox(height: 20),
                              _signupButton(),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 90, height: 90,
      decoration: BoxDecoration(shape: BoxShape.circle, gradient: const LinearGradient(colors: [Color(0xFFD4AF37), Color(0xFFB8962E)])),
      child: Padding(padding: const EdgeInsets.all(4), child: ClipOval(child: Image.asset('assets/images/shiva.png', fit: BoxFit.cover))),
    );
  }

  Widget _phoneSection() {
    return Column(
      children: [
        if (!_otpVerified)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  controller: _phone,
                  focusNode: _phoneFocus,
                  keyboardType: TextInputType.phone,
                  style: TextStyle(color: _darkText),
                  maxLength: 10,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: _fieldDecoration("Phone Number", Icons.phone_outlined).copyWith(counterText: "", suffix: _checkingPhone ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2)) : null),
                  validator: (v) => (v == null || v.length != 10) ? "Enter 10 digits" : _phoneError,
                ),
              ),
              if (_phone.text.length == 10 && !_otpVisible && _phoneError == null && !_checkingPhone)
                Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _otpSending ? null : _sendOTP,
                      style: ElevatedButton.styleFrom(backgroundColor: _accentColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      child: _otpSending ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2) : const Text("OTP", style: TextStyle(color: Colors.white)),
                    ),
                  ),
                )
            ],
          ),
        if (_otpVisible && !_otpVerified) _otpUI(),
        if (_otpVerified)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.green.withOpacity(0.3))),
            child: const Row(children: [Icon(Icons.check_circle, color: Colors.green), Text(" Phone Verified", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))]),
          ),
      ],
    );
  }

  Widget _otpUI() {
    return Column(children: [
      const SizedBox(height: 12),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(6, (i) => _otpBox(i))),
      const SizedBox(height: 10),
      TextButton(onPressed: _verifyOtp, child: Text("Verify OTP", style: TextStyle(color: _accentColor, fontWeight: FontWeight.bold))),
    ]);
  }

  Widget _otpBox(int index) {
    return Container(
      width: 38, height: 48, margin: const EdgeInsets.symmetric(horizontal: 3),
      child: TextField(
        controller: _otpControllers[index], focusNode: _otpFocusNodes[index],
        maxLength: 1, keyboardType: TextInputType.number, textAlign: TextAlign.center,
        decoration: InputDecoration(counterText: "", filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
        onChanged: (v) {
          if (v.isNotEmpty && index < 5) _otpFocusNodes[index + 1].requestFocus();
          if (v.isEmpty && index > 0) _otpFocusNodes[index - 1].requestFocus();
        },
      ),
    );
  }

  InputDecoration _fieldDecoration(String lbl, IconData ic) {
    return InputDecoration(
      labelText: lbl, labelStyle: TextStyle(color: _mutedBronze, fontSize: 14),
      prefixIcon: Icon(ic, color: _accentColor, size: 20),
      filled: true, fillColor: Colors.white,
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _sandalwood)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _accentColor)),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  Widget _input(TextEditingController c, String lbl, IconData ic, {TextInputType keyboardType = TextInputType.text, String? validationType, List<TextInputFormatter>? formatters, FocusNode? focusNode, bool isLoading = false}) {
    return TextFormField(
      controller: c, focusNode: focusNode, keyboardType: keyboardType, inputFormatters: formatters,
      decoration: _fieldDecoration(lbl, ic).copyWith(suffixIcon: isLoading ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2))) : null),
      validator: (v) => (v == null || v.isEmpty) ? "Required" : null,
    );
  }

  Widget _passwordField(TextEditingController c, String lbl, {bool isConfirm = false}) {
    return TextFormField(
      controller: c, obscureText: true,
      decoration: _fieldDecoration(lbl, Icons.lock_outline),
      validator: (v) {
        if (v == null || v.isEmpty) return "Required";
        if (!isConfirm && v.length < 6) return "Min 6 chars";
        if (isConfirm && v != _password.text) return "Passwords don't match";
        return null;
      },
    );
  }

  Widget _termsCheckbox() {
    return Row(children: [
      Checkbox(value: _agree, activeColor: _accentColor, onChanged: (v) => setState(() => _agree = v ?? false)),
      const Text("I agree to Terms & Conditions", style: TextStyle(fontSize: 13)),
    ]);
  }

  Widget _signupButton() {
    return _isLoading ? CircularProgressIndicator(color: _accentColor) : SizedBox(width: double.infinity, height: 55,
      child: ElevatedButton(onPressed: _signup, style: ElevatedButton.styleFrom(backgroundColor: _accentColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
        child: const Text("Create Account", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
      ),
    );
  }
}