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
  
  // Controller for the Transaction ID input
  final TextEditingController _transactionController = TextEditingController();

  @override
  void dispose() {
    _transactionController.dispose();
    super.dispose();
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  // DIALOG FUNCTION
  void _showMarkAsPaidDialog(String docId) {
    debugPrint("Attempting to show dialog for doc: $docId"); // Debug log
    
    _transactionController.text = ""; // Reset input
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text("Enter Payment Details"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Enter the Transaction ID / Reference Number to mark this as paid."),
              const SizedBox(height: 16),
              TextField(
                controller: _transactionController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: "Transaction ID",
                  border: OutlineInputBorder(),
                  hintText: "e.g. 123456789",
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              onPressed: () async {
                String txnId = _transactionController.text.trim();
                if (txnId.isEmpty) {
                  _showErrorSnackBar("Please enter a Transaction ID");
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
                  if (mounted) Navigator.pop(dialogContext);
                } catch (e) {
                  _showErrorSnackBar("Update failed: $e");
                }
              },
              child: const Text("MARK PAID", style: TextStyle(color: Colors.white)),
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
        
        // Sorting
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
                          Text('UPI ID: ${data['upiId']}', style: const TextStyle(fontSize: 14)),
                        
                        if (status == 'paid') ...[
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.green.withOpacity(0.3)),
                            ),
                            child: Text('Transaction ID: $txnId', 
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                          ),
                        ],

                        if (status == 'pending') ...[
                          const SizedBox(height: 10),
                          if (data['qrUrl'] != null)
                            Center(
                              child: GestureDetector(
                                onTap: () => widget.onShowImage(data['qrUrl']),
                                child: Image.network(data['qrUrl'], height: 120),
                              ),
                            ),
                          const SizedBox(height: 15),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              onPressed: () {
                                _showMarkAsPaidDialog(docId);
                              },
                              child: const Text('MARK AS PAID', 
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
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