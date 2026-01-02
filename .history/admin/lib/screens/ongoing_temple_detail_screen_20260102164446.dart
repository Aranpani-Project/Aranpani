import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'project_chat_section.dart';

class OngoingTempleDetailScreen extends StatefulWidget {
  final Map<String, dynamic> temple;
  final void Function(Map<String, dynamic>?) onUpdated;

  const OngoingTempleDetailScreen({
    Key? key,
    required this.temple,
    required this.onUpdated,
  }) : super(key: key);

  @override
  State<OngoingTempleDetailScreen> createState() => _OngoingTempleDetailScreenState();
}

class _OngoingTempleDetailScreenState extends State<OngoingTempleDetailScreen> {
  static const Color primaryMaroon = Color(0xFF6D1B1B);
  static const Color backgroundCream = Color(0xFFFFF7E8);

  late Map<String, dynamic> temple;
  int selectedTab = 0;

  @override
  void initState() {
    super.initState();
    temple = Map<String, dynamic>.from(widget.temple);
  }

  void _showFullScreenImage(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: InteractiveViewer(child: Image.network(imageUrl)),
      ),
    );
  }

  Widget _buildTab(String title, int index) {
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => selectedTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: selectedTab == index ? primaryMaroon : Colors.transparent, width: 3)),
          ),
          child: Text(title, textAlign: TextAlign.center, style: TextStyle(color: selectedTab == index ? primaryMaroon : Colors.grey)),
        ),
      ),
    );
  }

  Widget _buildFinancesTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('transactions')
          .where('projectId', isEqualTo: temple['id'])
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data!.docs;

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final data = docs[i].data();
            final docId = docs[i].id;

            return Card(
              margin: const EdgeInsets.all(10),
              child: ExpansionTile(
                title: Text(data['title'] ?? 'Request'),
                subtitle: Text('₹${data['amount']} • Status: ${data['status']}'),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('UPI ID: ${data['upiId'] ?? 'Not provided'}'),
                        const SizedBox(height: 10),
                        if (data['qrUrl'] != null)
                          GestureDetector(
                            onTap: () => _showFullScreenImage(data['qrUrl']),
                            child: Column(
                              children: [
                                const Text('Payment QR (Tap to expand):'),
                                Image.network(data['qrUrl'], height: 150),
                              ],
                            ),
                          ),
                        const SizedBox(height: 15),
                        if (data['status'] == 'pending')
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                                onPressed: () async {
                                  await FirebaseFirestore.instance
                                      .collection('transactions')
                                      .doc(docId)
                                      .update({'status': 'paid'});
                                },
                                child: const Text('Mark as Paid'),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                onPressed: () async {
                                  await FirebaseFirestore.instance
                                      .collection('transactions')
                                      .doc(docId)
                                      .update({'status': 'rejected'});
                                },
                                child: const Text('Reject'),
                              ),
                            ],
                          )
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundCream,
      appBar: AppBar(backgroundColor: primaryMaroon, title: Text(temple['name'] ?? 'Admin')),
      body: Column(
        children: [
          Row(children: [_buildTab('Activities', 0), _buildTab('Finances', 1)]),
          Expanded(child: selectedTab == 0 ? const Center(child: Text('Activities List')) : _buildFinancesTab()),
        ],
      ),
    );
  }
}