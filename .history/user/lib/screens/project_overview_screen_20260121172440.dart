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

  // Theme Colors
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

  // ===================== ADD WORK (To Do) =====================

  Future<void> _showAddWorkDialog() async {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: backgroundCream,
        title: Text(
          'Add Work (To Do)',
          style: GoogleFonts.poppins(color: primaryMaroon),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Work name',
                ),
              ),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;

              await _firestore.collection('project_tasks').add({
                'projectId': _projectId,
                'userId': _userId,
                'taskName': nameCtrl.text.trim(),
                'description': descCtrl.text.trim(),
                'status': 'todo',
                'createdAt': FieldValue.serverTimestamp(),
                'startedAt': null,
                'completedAt': null,
                'endImages': <String>[],
              });

              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  // ===================== MONEY REQUEST / BILLS =====================

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
                    decoration:
                        const InputDecoration(labelText: 'Work Name')),
                TextField(
                    controller: amountCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Amount'),
                    keyboardType: TextInputType.number),
                TextField(
                    controller: upiCtrl,
                    decoration: const InputDecoration(
                        labelText: 'UPI ID (Optional)')),
                const SizedBox(height: 15),
                ElevatedButton.icon(
                  onPressed: () async {
                    final img =
                        await _picker.pickImage(source: ImageSource.gallery);
                    if (img != null) setDialogState(() => qrFile = img);
                  },
                  icon: const Icon(Icons.qr_code),
                  label: const Text('Upload QR Code'),
                ),
                if (qrFile != null)
                  const Text('QR selected',
                      style: TextStyle(color: Colors.green)),
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
                  'date': FieldValue.serverTimestamp(),
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

  // ===================== FINANCES TAB (AUTOMATION & HISTORY) =====================

  Widget _transactionsTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _firestore
          .collection('transactions')
          .where('projectId', isEqualTo: _projectId)
          .orderBy('date', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        double totalPaid = 0;
        double totalPending = 0;

        if (snapshot.hasData) {
          for (var doc in snapshot.data!.docs) {
            double amt = (doc.data()['amount'] ?? 0).toDouble();
            if (doc.data()['status'] == 'paid') {
              totalPaid += amt;
            } else if (doc.data()['status'] == 'pending') {
              totalPending += amt;
            }
          }
        }

        return Column(
          children: [
            // Automation Summary Card
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: primaryMaroon,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                children: [
                  Text("BUDGET AUTOMATION", 
                    style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12, letterSpacing: 1.2)),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _summaryColumn("Received", "₹$totalPaid", Colors.greenAccent),
                      Container(width: 1, height: 40, color: Colors.white24),
                      _summaryColumn("Ongoing Req.", "₹$totalPending", Colors.orangeAccent),
                    ],
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ElevatedButton.icon(
                onPressed: _showRequestAmountDialog,
                icon: const Icon(Icons.add_card),
                label: const Text('Request New Amount'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryMaroon,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),

            const Padding(
              padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text("Transaction History", 
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: primaryMaroon)),
              ),
            ),

            Expanded(
              child: snapshot.hasData && snapshot.data!.docs.isNotEmpty
                  ? ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: snapshot.data!.docs.length,
                      itemBuilder: (context, index) {
                        final data = snapshot.data!.docs[index].data();
                        return _buildHistoryCard(data);
                      },
                    )
                  : const Center(child: Text("No transaction history available")),
            ),
          ],
        );
      },
    );
  }

  Widget _summaryColumn(String title, String val, Color color) {
    return Column(
      children: [
        Text(title, style: const TextStyle(color: Colors.white60, fontSize: 12)),
        Text(val, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> data) {
    String status = data['status'] ?? 'pending';
    Color statusColor = status == 'paid' ? Colors.green : (status == 'rejected' ? Colors.red : Colors.orange);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: Colors.grey.shade200)),
      child: ListTile(
        title: Text(data['title'] ?? 'Request', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text("Date: ${_formatTimestamp(data['date'] as Timestamp?)}"),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text("₹${data['amount']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text(status.toUpperCase(), style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  // ===================== OTHER UI TABS (BILLS / ACTIVITIES) =====================

  Widget _billsTab() {
    return Column(
      children: [
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _showUploadBillDialog,
          icon: const Icon(Icons.upload),
          label: const Text("Upload Bill"),
          style: ElevatedButton.styleFrom(
              backgroundColor: primaryMaroon,
              foregroundColor: Colors.white),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _billsRef
                .where('projectId', isEqualTo: _projectId)
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final docs = snapshot.data!.docs;
              if (docs.isEmpty) return const Center(child: Text("No bills uploaded yet"));

              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: docs.length,
                itemBuilder: (context, i) {
                  final bill = docs[i].data();
                  final imageUrls = (bill['imageUrls'] as List? ?? []);
                  return Card(
                    child: ExpansionTile(
                      title: Text(bill['title'] ?? 'Bill', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('Amount: ₹${bill['amount'] ?? '0'}'),
                      children: [
                        if (imageUrls.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: imageUrls.map((url) => GestureDetector(
                                onTap: () => _showFullScreenImage(url.toString()),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(url.toString(), width: 80, height: 80, fit: BoxFit.cover),
                                ),
                              )).toList(),
                            ),
                          )
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

  // Placeholder build methods for required widgets
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundCream,
      appBar: AppBar(
        title: Text(widget.project['projectName'] ?? 'Project Overview', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        backgroundColor: primaryMaroon,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: "Tasks", icon: Icon(Icons.task)),
            Tab(text: "Bills", icon: Icon(Icons.receipt_long)),
            Tab(text: "Finances", icon: Icon(Icons.account_balance_wallet)),
            Tab(text: "Chat", icon: Icon(Icons.chat)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _activitiesTab(), // Task Lists
          _billsTab(),     // Bill Management
          _transactionsTab(), // History & Automation
          ProjectChatSection(projectId: _projectId), // Chat
        ],
      ),
    );
  }

  // Re-include these from your original code
  Future<void> _showUploadBillDialog() async { /* ... Same as original ... */ }
  Widget _activitiesTab() { /* ... Same as original ... */ }
  Future<void> _requestProjectCompletion() async { /* ... Same as original ... */ }
}

// Ensure you have an OngoingTaskCard widget defined as per your previous implementation.
class OngoingTaskCard extends StatelessWidget {
  final String taskId, taskName, dateDisplay, userId, projectId, currentStatus;
  const OngoingTaskCard({super.key, required this.taskId, required this.taskName, required this.dateDisplay, required this.userId, required this.projectId, required this.currentStatus});
  @override
  Widget build(BuildContext context) => Card(child: ListTile(title: Text(taskName), subtitle: Text(dateDisplay)));
}