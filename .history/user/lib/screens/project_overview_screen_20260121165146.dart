import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import 'project_chat_section.dart';
import '../services/cloudinary_service.dart';

class ProjectOverviewScreen extends StatefulWidget {
  final Map<String, dynamic> project;
  const ProjectOverviewScreen({super.key, required this.project});

  @override
  State<ProjectOverviewScreen> createState() => _ProjectOverviewScreenState();
}

class _ProjectOverviewScreenState extends State<ProjectOverviewScreen>
    with SingleTickerProviderStateMixin {
  final _firestore = FirebaseFirestore.instance;

  late TabController _tabController;
  final ImagePicker _picker = ImagePicker();

  static const Color primaryMaroon = Color(0xFF6A1F1A);
  static const Color backgroundCream = Color(0xFFFFF7E8);

  String get _projectId => widget.project['id'] as String;
  String get _userId => (widget.project['userId'] ?? '') as String;

  CollectionReference<Map<String, dynamic>> get _billsRef =>
      _firestore.collection('bills');

  bool _isCompletionRequesting = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return "N/A";
    final date = timestamp.toDate();
    return "${date.day}/${date.month}/${date.year}";
  }

  void _showFullScreenImage(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(10),
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 4.0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(imageUrl, fit: BoxFit.contain),
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

  // ===================== MONEY REQUEST LOGIC =====================

  Future<void> _showRequestAmountDialog() async {
    final titleCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final upiCtrl = TextEditingController();
    XFile? qrFile;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: backgroundCream,
          title: Text('Request Amount',
              style: GoogleFonts.poppins(color: primaryMaroon)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(labelText: 'Work Name')),
                TextField(
                    controller: amountCtrl,
                    decoration: const InputDecoration(labelText: 'Amount'),
                    keyboardType: TextInputType.number),
                TextField(
                    controller: upiCtrl,
                    decoration: const InputDecoration(labelText: 'UPI ID (Optional)')),
                const SizedBox(height: 15),
                ElevatedButton.icon(
                  onPressed: () async {
                    final img = await _picker.pickImage(source: ImageSource.gallery);
                    if (img != null) setDialogState(() => qrFile = img);
                  },
                  icon: const Icon(Icons.qr_code),
                  label: const Text('Upload QR Code'),
                ),
                if (qrFile != null)
                  const Text('QR selected', style: TextStyle(color: Colors.green)),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (titleCtrl.text.isEmpty || amountCtrl.text.isEmpty) return;
                String? qrUrl;
                if (qrFile != null) {
                  qrUrl = await CloudinaryService.uploadImage(
                      imageFile: qrFile!,
                      userId: _userId,
                      projectId: _projectId);
                }
                await _firestore.collection('transactions').add({
                  'projectId': _projectId,
                  'userId': _userId,
                  'title': titleCtrl.text,
                  'amount': double.parse(amountCtrl.text),
                  'upiId': upiCtrl.text,
                  'qrUrl': qrUrl,
                  'status': 'pending',
                  'transactionId': '', // Initialize as empty
                  'createdAt': FieldValue.serverTimestamp(),
                });
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Submit Request'),
            )
          ],
        ),
      ),
    );
  }

  // ===================== FINANCES TAB (UPDATED) =====================

  Widget _transactionsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              ElevatedButton.icon(
                onPressed: _showRequestAmountDialog,
                icon: const Icon(Icons.add_card),
                label: const Text('Request Amount from Admin'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  backgroundColor: primaryMaroon,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: _isCompletionRequesting ? null : _requestProjectCompletion,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                ),
                icon: _isCompletionRequesting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.flag),
                label: Text(_isCompletionRequesting ? 'Sending...' : 'Request Project Completion'),
              ),
            ],
          ),
        ),
        
        const Divider(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text("Request History", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ),

        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _firestore
                .collection('transactions')
                .where('projectId', isEqualTo: _projectId)
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return Center(child: Text("Error loading transactions"));
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              
              final docs = snapshot.data!.docs;
              if (docs.isEmpty) return const Center(child: Text("No requests found."));

              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: docs.length,
                itemBuilder: (context, i) {
                  final data = docs[i].data();
                  final status = data['status'] ?? 'pending';
                  final isPaid = status == 'paid';

                  return Card(
                    color: isPaid ? Colors.green[50] : Colors.white,
                    child: ListTile(
                      leading: Icon(
                        isPaid ? Icons.check_circle : Icons.pending_actions,
                        color: isPaid ? Colors.green : Colors.orange,
                      ),
                      title: Text(data['title'] ?? 'Amount Request', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Amount: ₹${data['amount']}'),
                          if (isPaid && data['transactionId'] != null)
                            Text('Txn ID: ${data['transactionId']}', 
                                style: const TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.bold, fontSize: 12)),
                        ],
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isPaid ? Colors.green : Colors.orange,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          status.toString().toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // ===================== OTHER WIDGETS (Rest of your code) =====================

  Future<void> _requestProjectCompletion() async {
    // ... (Your existing logic for checking task counts)
    setState(() => _isCompletionRequesting = true);
    try {
      await _firestore.collection('project_completion_requests').add({
        'projectId': _projectId,
        'userId': _userId,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request Sent')));
    } finally {
      if (mounted) setState(() => _isCompletionRequesting = false);
    }
  }

  Widget _billsTab() {
    return Column(
      children: [
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _showUploadBillDialog,
          icon: const Icon(Icons.upload),
          label: const Text("Upload Bill"),
          style: ElevatedButton.styleFrom(backgroundColor: primaryMaroon, foregroundColor: Colors.white),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _billsRef.where('projectId', isEqualTo: _projectId).orderBy('createdAt', descending: true).snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final docs = snapshot.data!.docs;
              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: docs.length,
                itemBuilder: (context, i) {
                  final bill = docs[i].data();
                  return Card(
                    child: ExpansionTile(
                      title: Text(bill['title'] ?? 'Bill'),
                      subtitle: Text('Amount: ₹${bill['amount']}'),
                      children: [
                        // Image listing logic here as per your original code...
                      ],
                    ),
                  );
                },
              );
            },
          ),
        )
      ],
    );
  }

  // Boilerplate for remaining UI...
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundCream,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.all(12),
                color: primaryMaroon,
                child: Text("Project: ${widget.project['title']}", style: const TextStyle(color: Colors.white, fontSize: 18)),
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _TabBarDelegate(
                TabBar(
                  controller: _tabController,
                  labelColor: primaryMaroon,
                  tabs: const [
                    Tab(text: 'Activities'),
                    Tab(text: 'Finances'),
                    Tab(text: 'Bills'),
                    Tab(text: 'Feedback'),
                  ],
                ),
              ),
            ),
            SliverFillRemaining(
              child: TabBarView(
                controller: _tabController,
                children: [
                  const Center(child: Text("Activities Content")), // Replace with _activitiesTab()
                  _transactionsTab(),
                  _billsTab(),
                  ProjectChatSection(projectId: _projectId, currentRole: 'user'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Placeholder functions and classes for compilation
  Future<void> _showUploadBillDialog() async {}
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  _TabBarDelegate(this.tabBar);
  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;
  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(color: Colors.white, child: tabBar);
  }
  @override
  bool shouldRebuild(_TabBarDelegate oldDelegate) => false;
}

class OngoingTaskCard extends StatelessWidget {
  final String taskId, taskName, dateDisplay, userId, projectId, currentStatus;
  const OngoingTaskCard({super.key, required this.taskId, required this.taskName, required this.dateDisplay, required this.userId, required this.projectId, required this.currentStatus});
  @override
  Widget build(BuildContext context) => const Card();
}