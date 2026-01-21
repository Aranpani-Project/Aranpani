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
  final TextEditingController _transactionController = TextEditingController();

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  // This replaces the old UPI/Cash selection logic
  void _inputTransactionId(String docId) {
    _transactionController.clear();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Confirm Payment"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Please enter the Transaction ID / Reference Number below to mark this as paid."),
            const SizedBox(height: 15),
            TextField(
              controller: _transactionController,
              decoration: const InputDecoration(
                labelText: "Transaction ID",
                hintText: "Enter ID here",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.receipt_long),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
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
                Navigator.pop(context);
              } catch (e) {
                _showErrorSnackBar("Failed to update: $e");
              }
            },
            child: const Text("SUBMIT & PAID", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
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
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        var docs = snapshot.data!.docs;
        
        // Sorting: Pending first, then by date
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ExpansionTile(
                leading: Icon(
                  status == 'paid' ? Icons.check_circle : Icons.pending_actions,
                  color: status == 'paid' ? Colors.green : Colors.orange,
                ),
                title: Text(data['title'] ?? 'Request',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: darkMaroonText)),
                subtitle: Text('₹$amount • ${status.toUpperCase()}',
                    style: TextStyle(
                        color: status == 'paid' ? Colors.green : Colors.orange,
                        fontWeight: FontWeight.bold)),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (data['upiId'] != null)
                           Text('Pay to (UPI ID): ${data['upiId']}', style: const TextStyle(fontSize: 14)),
                        
                        const Divider(height: 20),

                        if (status == 'paid') ...[
                          const Text("Payment Details:", style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('Transaction ID: $txnId', 
                              style: const TextStyle(fontSize: 15, color: Colors.blueGrey, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 10),
                        ],

                        if (data['qrUrl'] != null && status == 'pending') ...[
                          const Text("Scan QR to Pay:", style: TextStyle(fontSize: 12, color: Colors.grey)),
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: () => widget.onShowImage(data['qrUrl']),
                            child: Image.network(data['qrUrl'], height: 150),
                          ),
                          const SizedBox(height: 15),
                        ],

                        if (status == 'pending')
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              onPressed: () => _inputTransactionId(docId),
                              child: const Text('I HAVE PAID (ENTER ID)', 
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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