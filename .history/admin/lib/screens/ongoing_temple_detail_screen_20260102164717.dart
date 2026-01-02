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
  State<OngoingTempleDetailScreen> createState() =>
      _OngoingTempleDetailScreenState();
}

class _OngoingTempleDetailScreenState extends State<OngoingTempleDetailScreen> {
  // --- Aranpani Theme Colors ---
  static const Color primaryMaroon = Color(0xFF6D1B1B);
  static const Color primaryGold = Color(0xFFD4AF37);
  static const Color backgroundCream = Color(0xFFFFF7E8);
  static const Color darkMaroonText = Color(0xFF4A1010);

  late Map<String, dynamic> temple;
  int selectedTab = 0;

  @override
  void initState() {
    super.initState();
    temple = Map<String, dynamic>.from(widget.temple);
  }

  void _handleBackNavigation() {
    widget.onUpdated(temple);
    Navigator.pop(context);
  }

  // --- NEW: FULL SCREEN IMAGE VIEWER ---
  void _showFullScreenImage(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(10),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Allows users to pinch and zoom into the bill
            InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 4.0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    );
                  },
                ),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: CircleAvatar(
                backgroundColor: Colors.black54,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundCream,
      appBar: AppBar(
        backgroundColor: primaryMaroon,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: _handleBackNavigation,
        ),
        title: Text(
          (temple['name'] ?? 'Temple Project').toString(),
          style: const TextStyle(
              color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            child: Row(
              children: [
                _buildTab('Activities', 0),
                _buildTab('Finances', 1),
                _buildTab('Payment Process', 2),
                _buildTab('Feedback', 3),
              ],
            ),
          ),
          Expanded(child: _buildCurrentTabContent()),
        ],
      ),
    );
  }

  Widget _buildCurrentTabContent() {
    switch (selectedTab) {
      case 2:
        return _buildPaymentProcessTab();
      case 3:
        return ProjectChatSection(projectId: temple['id'], currentRole: 'admin');
      default:
        return const Center(child: Text("Other Tabs Content"));
    }
  }

  Widget _buildTab(String label, int index) {
    final isActive = selectedTab == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => selectedTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            border: Border(
                bottom: BorderSide(
                    color: isActive ? primaryGold : Colors.transparent,
                    width: 3)),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isActive ? primaryMaroon : Colors.grey,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  // --- PAYMENT PROCESS TAB (Real-time Synced) ---
  Widget _buildPaymentProcessTab() {
    return ListView(
      padding: const EdgeInsets.all(20.0),
      children: [
        const Text('Budget Utilization',
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: darkMaroonText)),
        const SizedBox(height: 20),
        _buildBudgetCard(),
        const SizedBox(height: 24),
        const Text('Bills Uploaded from Site',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: darkMaroonText)),
        const SizedBox(height: 12),

        // --- REAL-TIME STREAM OF BILLS ---
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('bills')
              .where('projectId', isEqualTo: temple['id'])
              .snapshots(),
          builder: (context, snapshot) {
            debugPrint("Admin searching for Project ID: ${temple['id']}");

            if (snapshot.hasError) {
              return Text("Error loading bills: ${snapshot.error}",
                  style: const TextStyle(color: Colors.red));
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                  child: CircularProgressIndicator(color: primaryMaroon));
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return _buildEmptyState("No bills found for this project ID.");
            }

            return Column(
              children: snapshot.data!.docs.map((doc) {
                final bill = doc.data() as Map<String, dynamic>;
                return _buildBillCard(bill);
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildBillCard(Map<String, dynamic> bill) {
    final List<dynamic> images = bill['imageUrls'] ?? [];
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey.shade300)),
      child: ExpansionTile(
        title: Text(bill['title'] ?? 'New Bill',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('Amount: ₹${bill['amount']}',
            style: const TextStyle(
                color: Colors.green, fontWeight: FontWeight.bold)),
        children: [
          if (images.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: images.length,
                  itemBuilder: (ctx, i) {
                    final imageUrl = images[i].toString();
                    return Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: GestureDetector(
                        onTap: () => _showFullScreenImage(imageUrl),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                imageUrl,
                                width: 100,
                                height: 100,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              bottom: 4,
                              right: 4,
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Icon(
                                  Icons.fullscreen,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBudgetCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300)),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('Total Budget', style: TextStyle(color: Colors.grey)),
              Text('₹5,00,000',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: primaryMaroon)),
            ],
          ),
          const SizedBox(height: 12),
          const LinearProgressIndicator(
              value: 0.6,
              backgroundColor: backgroundCream,
              color: primaryGold,
              minHeight: 8),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String msg) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child:
          Center(child: Text(msg, style: const TextStyle(color: Colors.grey))),
    );
  }
}