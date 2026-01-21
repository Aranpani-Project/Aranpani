import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  
  // Initializing the controller directly to avoid 'undefined' errors
  final TextEditingController _transactionController = TextEditingController();

  @override
  void dispose() {
    // Always dispose controllers when the widget is removed
    _transactionController.dispose();
    super.dispose();
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showMarkAsPaidDialog(String docId) {
    // Safety check: ensure the controller is cleared before showing dialog
    _transactionController.text = ""; 
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Confirm Payment"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Please enter the Transaction ID provided by the user."),
              const SizedBox(height: 15),
              TextField(
                controller: _transactionController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: "Transaction ID",
                  hintText: "Enter ID here",
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              onPressed: () async {
                String txnId = _transactionController.text.trim();
                if (txnId.isEmpty) {
                  _showErrorSnackBar("Transaction ID is required");
                  return;
                }

                try {
                  await FirebaseFirestore.instance
                      .collection('transactions')
                      .doc(docId)
                      .update({
                    'status': 'paid',
                    'transactionId': txnId,
                    'paidAt': FieldValue.serverTimestamp(),
                  });
                  if (mounted) Navigator.pop(context);
                } catch (e) {
                  _showErrorSnackBar("Error updating record: $e");
                }
              },
              child: const Text("PAID", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('transactions')
          .where('projectId', isEqualTo: widget.projectId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        var docs = snapshot.data!.docs;
        
        // Sorting: Pending first, then newest first
        docs.sort((a, b) {
          String statusA = a.data()['status'] ?? 'pending';
          String statusB = b.data()['status'] ?? 'pending';
          if (statusA == 'pending' && statusB != 'pending') return -1;
          if (statusA != 'pending' && statusB == 'pending') return 1;
          Timestamp tA = a.data()['createdAt'] ?? Timestamp.now();
          Timestamp tB = b.data()['createdAt'] ?? Timestamp.now();
          return tB.compareTo(tA);
        });

        if (docs.isEmpty) return const Center(child: Text("No fund requests found."));

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final data = docs[i].data();
            final docId = docs[i].id;
            final status = data['status'] ?? 'pending';
            final amount = (data['amount'] ?? '0').toString();
            final txnId = data['transactionId'] ?? '';

            return Card(
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 10),
              child: ExpansionTile(
                title: Text(data['title'] ?? 'Request',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: darkMaroonText)),
                subtitle: Text('₹$amount • ${status.toUpperCase()}',
                    style: TextStyle(
                        color: status == 'paid' ? Colors.green : (status == 'rejected' ? Colors.red : Colors.orange),
                        fontWeight: FontWeight.bold)),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (data['upiId'] != null)
                          Text('UPI ID: ${data['upiId']}', style: const TextStyle(fontSize: 15)),
                        
                        if (status == 'paid') ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.receipt, size: 16, color: Colors.blueGrey),
                                const SizedBox(width: 8),
                                Text('Txn ID: $txnId', 
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 10),
                        
                        if (data['qrUrl'] != null && status == 'pending') ...[
                          const Text("Scan QR to pay:", style: TextStyle(fontSize: 12, color: Colors.grey)),
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: () => widget.onShowImage(data['qrUrl']),
                            child: Image.network(data['qrUrl'], height: 150),
                          ),
                          const SizedBox(height: 20),
                        ],

                        if (status == 'pending')
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.check_circle_outline, color: Colors.white),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              onPressed: () => _showMarkAsPaidDialog(docId),
                              label: const Text('MARK AS PAID', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
    );
  }
}