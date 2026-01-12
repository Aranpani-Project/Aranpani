import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Optional for now
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/app_theme.dart';
import '../services/receipt_service.dart';

class MakeDonationScreen extends StatefulWidget {
  const MakeDonationScreen({super.key});

  @override
  State<MakeDonationScreen> createState() => _MakeDonationScreenState();
}

class _MakeDonationScreenState extends State<MakeDonationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _nameController = TextEditingController();
  final _govIdController = TextEditingController();
  bool _isLoading = false;

  Future<void> _processDonation() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    // 1. UPI Logic (Simulated for UI testing)
    const String upiId = "your_trust@upi"; 
    final String amount = _amountController.text;
    final String upiUrl = "upi://pay?pa=$upiId&pn=TempleTrust&am=$amount&cu=INR";

    try {
      if (await canLaunchUrl(Uri.parse(upiUrl))) {
        await launchUrl(Uri.parse(upiUrl));
      } else {
        // Fallback if no UPI app found (or use manual confirm for testing)
        debugPrint("No UPI app found, simulating success...");
      }
      
      // 2. Simulate Success & Generate Receipt
      await Future.delayed(const Duration(seconds: 2)); // Fake delay
      if (!mounted) return;

      // Generate Receipt
      await ReceiptService.generateReceipt(
        name: _nameController.text,
        amount: amount,
        donationId: "DON-${DateTime.now().millisecondsSinceEpoch}",
        date: DateTime.now(),
      );

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Donation Successful! Receipt Generated.")));
      Navigator.pop(context); // Go back to Home

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Make a Donation"),
        backgroundColor: AppTheme.primaryBrand,
        foregroundColor: AppTheme.textOnDark,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: "Full Name"),
                validator: (v) => v!.isEmpty ? "Required" : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _govIdController,
                decoration: const InputDecoration(labelText: "PAN / Aadhaar Number"),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Amount (₹)", prefixText: "₹ "),
                validator: (v) => v!.isEmpty ? "Required" : null,
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _processDonation,
                  child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white) 
                    : const Text("PAY NOW"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}