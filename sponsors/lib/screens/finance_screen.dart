import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; 
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart'; // For kIsWeb check
import '../core/app_theme.dart';
import 'receipt_screen.dart';

class FinanceScreen extends StatelessWidget {
  const FinanceScreen({super.key});

  void _showImageDialog(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.network(imageUrl),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Close"),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Donate to NGO"),
        backgroundColor: const Color(0xFF6D1B1B), 
        foregroundColor: Colors.white,
      ),
      body: FinanceTabSection(
        projectId: "project_1", 
        onShowImage: (url) => _showImageDialog(context, url),
      ),
    );
  }
}

class FinanceTabSection extends StatefulWidget {
  final String projectId;
  final Function(String) onShowImage;

  const FinanceTabSection({
    Key? key,
    required this.projectId,
    required this.onShowImage,
  }) : super(key: key);

  @override
  State<FinanceTabSection> createState() => _FinanceTabSectionState();
}

class _FinanceTabSectionState extends State<FinanceTabSection> {
  static const Color primaryMaroon = Color(0xFF6D1B1B);
  static const Color darkMaroonText = Color(0xFF4A1010);
  
  // REPLACE THIS WITH YOUR NGO'S MAIN UPI ID
  static const String mainNgoUpiId = "temple@upi"; 

  // --- STEP 1: LAUNCH UPI ---
  Future<void> _launchUPI(String upiId, String amount, String title) async {
    // WEB CHECK: UPI doesn't work on PC browsers
    if (kIsWeb) {
      _showErrorSnackBar("UPI Payment requires a Mobile Phone with GPay/PhonePe.");
      return;
    }

    final String upiUrl =
        "upi://pay?pa=$upiId&pn=TempleNGO&am=$amount&cu=INR&tn=${Uri.encodeComponent("Donation for $title")}";
    final Uri uri = Uri.parse(upiUrl);

    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      _showErrorSnackBar("Could not launch payment app. Make sure GPay/PhonePe is installed.");
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  // --- STEP 2: SHOW DONATION FORM ---
  void _showDonationForm(String? projectDocId, String upiId, String defaultAmount, String title, {bool isGeneral = false}) {
    final user = FirebaseAuth.instance.currentUser;
    
    final nameController = TextEditingController(text: user?.displayName ?? "");
    final phoneController = TextEditingController();
    final addressController = TextEditingController();
    final amountController = TextEditingController(text: defaultAmount);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, 
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20, right: 20, top: 20
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                   Icon(isGeneral ? Icons.volunteer_activism : Icons.temple_buddhist, color: primaryMaroon),
                   const SizedBox(width: 10),
                   Expanded(child: Text(isGeneral ? "General Donation" : "Donate to $title", 
                     style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                ],
              ),
              const Divider(),
              
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Donation Amount (₹)", 
                  border: OutlineInputBorder(),
                  prefixText: "₹ ",
                ),
              ),
              const SizedBox(height: 15),

              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: "Your Name", border: OutlineInputBorder(), prefixIcon: Icon(Icons.person)),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: "Phone Number", border: OutlineInputBorder(), prefixIcon: Icon(Icons.phone)),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: addressController,
                decoration: const InputDecoration(labelText: "Address (Optional)", border: OutlineInputBorder(), prefixIcon: Icon(Icons.home)),
              ),
              const SizedBox(height: 20),
              
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  icon: const Icon(Icons.currency_rupee, color: Colors.white),
                  label: const Text("PROCEED TO PAY", style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
                  onPressed: () async {
                    if (nameController.text.isEmpty || amountController.text.isEmpty) {
                      _showErrorSnackBar("Please enter Name and Amount");
                      return;
                    }
                    Navigator.pop(context); 
                    
                    String finalAmount = amountController.text;

                    // A. Launch UPI
                    await _launchUPI(upiId, finalAmount, title);
                    
                    // B. Ask Confirmation
                    _askIfPaid(
                      projectDocId, title, finalAmount, 
                      nameController.text, 
                      phoneController.text, 
                      addressController.text
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  // --- STEP 3: CONFIRM & SAVE ---
  void _askIfPaid(String? projectDocId, String title, String amount, String name, String phone, String address) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirm Payment"),
        content: Text("Did you successfully donate ₹$amount via UPI?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: const Text("No / Failed", style: TextStyle(color: Colors.red))
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () async {
              final user = FirebaseAuth.instance.currentUser;
              
              // Save to donations_history (Works for both General and Specific)
              await FirebaseFirestore.instance.collection('donations_history').add({
                'relatedProjectId': projectDocId ?? 'general_fund', // 'general_fund' if generic
                'projectTitle': title,
                'amount': amount,
                'donorName': name,
                'donorPhone': phone,
                'donorAddress': address,
                'donorId': user?.uid ?? 'anonymous',
                'donatedAt': FieldValue.serverTimestamp(),
                'method': 'upi',
                'status': 'success'
              });
              
              Navigator.pop(context);

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ReceiptScreen(
                    title: title,
                    amount: amount,
                    transactionId: "TXN-${DateTime.now().millisecondsSinceEpoch}",
                    method: "UPI Payment",
                    date: DateTime.now(),
                    donorName: name, 
                  ),
                ),
              );
            },
            child: const Text("Yes, Successful", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // ---------------------------------------------------------
          // 1. GENERAL NGO DONATION CARD (Always at Top)
          // ---------------------------------------------------------
          Card(
            margin: const EdgeInsets.all(12),
            color: Colors.white,
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  const Icon(Icons.volunteer_activism, size: 50, color: primaryMaroon),
                  const SizedBox(height: 10),
                  const Text("Support Our NGO", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: darkMaroonText)),
                  const Text("Contribute to our general welfare fund.", style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: primaryMaroon, padding: const EdgeInsets.symmetric(vertical: 12)),
                      onPressed: () => _showDonationForm(null, mainNgoUpiId, "1000", "General NGO Fund", isGeneral: true),
                      child: const Text("DONATE TO NGO", style: TextStyle(color: Colors.white, fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text("Specific Causes", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)),
            ),
          ),

          // ---------------------------------------------------------
          // 2. SPECIFIC CAUSES LIST (From Firebase)
          // ---------------------------------------------------------
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('transactions')
                .where('projectId', isEqualTo: widget.projectId)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              var docs = snapshot.data!.docs;

              if (docs.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(20), child: Text("No specific causes active.")));

              return ListView.builder(
                shrinkWrap: true, // Important for SingleChildScrollView
                physics: const NeverScrollableScrollPhysics(), // Disable scrolling inside this list
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: docs.length,
                itemBuilder: (context, i) {
                  final data = docs[i].data();
                  final docId = docs[i].id;
                  final upiId = data['upiId'] ?? '';
                  final amount = (data['amount'] ?? '0').toString();

                  return Card(
                    elevation: 2,
                    margin: const EdgeInsets.only(bottom: 15),
                    child: ExpansionTile(
                      initiallyExpanded: true,
                      title: Text(data['title'] ?? 'Cause',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: darkMaroonText)),
                      subtitle: Text('Target: ₹$amount', style: const TextStyle(color: Colors.grey)),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (data['qrUrl'] != null) ...[
                                GestureDetector(
                                  onTap: () => widget.onShowImage(data['qrUrl']),
                                  child: Image.network(data['qrUrl'], height: 100),
                                ),
                                const SizedBox(height: 15),
                              ],
                              
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  icon: const Icon(Icons.favorite_border, color: primaryMaroon),
                                  style: OutlinedButton.styleFrom(side: const BorderSide(color: primaryMaroon)),
                                  onPressed: () => _showDonationForm(docId, upiId, amount, data['title'] ?? 'Request'),
                                  label: const Text('DONATE TO THIS CAUSE', style: TextStyle(color: primaryMaroon, fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ],
                          ),
                        )
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}