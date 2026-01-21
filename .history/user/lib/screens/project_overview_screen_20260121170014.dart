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
  
  // Get initial total budget from project data
  double get _initialBudget => double.tryParse(widget.project['budget']?.toString() ?? '0') ?? 0.0;

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

  // ===================== FINANCE LOGIC & UI =====================

  Widget _transactionsTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _firestore
          .collection('transactions')
          .where('projectId', isEqualTo: _projectId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        final allDocs = snapshot.data!.docs;
        
        // Filter out rejected ones and separate Paid vs Ongoing
        final paidDocs = allDocs.where((d) => d['status'] == 'paid').toList();
        final ongoingDocs = allDocs.where((d) => d['status'] == 'pending' || d['status'] == 'approved').toList();
        // Rejected ones are simply ignored here

        // Calculate Remaining Budget
        double totalPaid = 0;
        for (var doc in paidDocs) {
          totalPaid += (doc['amount'] ?? 0).toDouble();
        }
        double remainingBudget = _initialBudget - totalPaid;

        return SingleChildScrollView(
          child: Column(
            children: [
              // Budget Summary Card
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: primaryMaroon,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Column(
                  children: [
                    Text("Project Budget Status", 
                      style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14)),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _budgetStat("Total", "₹$_initialBudget"),
                        const VerticalDivider(color: Colors.white24),
                        _budgetStat("Remaining", "₹$remainingBudget", color: Colors.greenAccent),
                      ],
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: ElevatedButton.icon(
                  onPressed: _showRequestAmountDialog,
                  icon: const Icon(Icons.add_card),
                  label: const Text('Request New Payment'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryMaroon,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                  ),
                ),
              ),

              _financeSectionTitle("Ongoing Finances"),
              if (ongoingDocs.isEmpty) 
                const Padding(padding: EdgeInsets.all(20), child: Text("No ongoing requests")),
              ...ongoingDocs.map((d) => _financeCard(d.data(), Colors.orange)),

              _financeSectionTitle("Paid Finances"),
              if (paidDocs.isEmpty) 
                const Padding(padding: EdgeInsets.all(20), child: Text("No payments completed yet")),
              ...paidDocs.map((d) => _financeCard(d.data(), Colors.green)),

              const SizedBox(height: 20),
              _completionRequestButton(),
              const SizedBox(height: 100), // Space for scrolling
            ],
          ),
        );
      },
    );
  }

  Widget _budgetStat(String label, String value, {Color color = Colors.white}) {
    return Column(
      children: [
        Text(label, style: GoogleFonts.poppins(color: Colors.white60, fontSize: 12)),
        Text(value, style: GoogleFonts.poppins(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _financeSectionTitle(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: primaryMaroon)),
    );
  }

  Widget _financeCard(Map<String, dynamic> data, Color statusColor) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withOpacity(0.1),
          child: Icon(Icons.currency_rupee, color: statusColor),
        ),
        title: Text(data['title'] ?? 'Request', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text("Requested on: ${_formatTimestamp(data['date'] as Timestamp?)}"),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text("₹${data['amount']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text(data['status'].toString().toUpperCase(), style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _completionRequestButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        children: [
          ElevatedButton.icon(
            onPressed: _isCompletionRequesting ? null : _requestProjectCompletion,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: _isCompletionRequesting 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.flag),
            label: Text(_isCompletionRequesting ? 'Sending...' : 'Request Project Completion'),
          ),
          const SizedBox(height: 8),
          Text(
            'Note: All tasks must be completed before requesting finalization.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  // ===================== EXISTING DIALOGS & UTILS (UNCHANGED) =====================

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
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(imageUrl, fit: BoxFit.contain),
              ),
            ),
            Positioned(
              top: 10, right: 10,
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

  Future<void> _showAddWorkDialog() async {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: backgroundCream,
        title: Text('Add Work (To Do)', style: GoogleFonts.poppins(color: primaryMaroon)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Work name')),
            TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Description'), maxLines: 3),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
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
              });
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

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
          title: Text('Request Amount', style: GoogleFonts.poppins(color: primaryMaroon)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Work Name')),
                TextField(controller: amountCtrl, decoration: const InputDecoration(labelText: 'Amount'), keyboardType: TextInputType.number),
                TextField(controller: upiCtrl, decoration: const InputDecoration(labelText: 'UPI ID (Optional)')),
                const SizedBox(height: 15),
                ElevatedButton.icon(
                  onPressed: () async {
                    final img = await _picker.pickImage(source: ImageSource.gallery);
                    if (img != null) setDialogState(() => qrFile = img);
                  },
                  icon: const Icon(Icons.qr_code),
                  label: const Text('Upload QR Code'),
                ),
                if (qrFile != null) const Text('QR selected', style: TextStyle(color: Colors.green)),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (titleCtrl.text.isEmpty || amountCtrl.text.isEmpty) return;
                String? qrUrl;
                if (qrFile != null) {
                  qrUrl = await CloudinaryService.uploadImage(imageFile: qrFile!, userId: _userId, projectId: _projectId);
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

  Future<void> _showUploadBillDialog() async {
    final titleCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    List<XFile> selectedFiles = [];
    bool isUploading = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: backgroundCream,
          title: Text('Upload New Bill', style: GoogleFonts.poppins(color: primaryMaroon, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Bill For (Title)')),
                TextField(controller: amountCtrl, decoration: const InputDecoration(labelText: 'Total Amount'), keyboardType: TextInputType.number),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: isUploading ? null : () async {
                    final imgs = await _picker.pickMultiImage();
                    if (imgs.isNotEmpty) setDialogState(() => selectedFiles = imgs);
                  },
                  icon: const Icon(Icons.image),
                  label: Text(selectedFiles.isEmpty ? 'Select Bill Photos' : '${selectedFiles.length} Images Selected'),
                ),
                if (isUploading) const CircularProgressIndicator(color: primaryMaroon),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: isUploading ? null : () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: isUploading ? null : () async {
                if (titleCtrl.text.isEmpty || amountCtrl.text.isEmpty || selectedFiles.isEmpty) return;
                setDialogState(() => isUploading = true);
                try {
                  List<String> urls = [];
                  for (var file in selectedFiles) {
                    String? url = await CloudinaryService.uploadImage(imageFile: file, userId: _userId, projectId: _projectId);
                    if (url != null) urls.add(url);
                  }
                  await _billsRef.add({
                    'projectId': _projectId,
                    'userId': _userId,
                    'title': titleCtrl.text,
                    'amount': double.parse(amountCtrl.text),
                    'imageUrls': urls,
                    'createdAt': FieldValue.serverTimestamp(),
                  });
                  if (mounted) Navigator.pop(context);
                } finally {
                  setDialogState(() => isUploading = false);
                }
              },
              child: const Text('Upload'),
            )
          ],
        ),
      ),
    );
  }

  // ===================== OTHER TABS (Simplified for full code) =====================

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
                        Wrap(
                          children: (bill['imageUrls'] as List? ?? []).map((url) => Image.network(url, width: 60, height: 60)).toList(),
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

  Widget _activitiesTab() {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton(onPressed: _showAddWorkDialog, child: const Text("Add Work")),
          ),
          const TabBar(
            labelColor: primaryMaroon,
            tabs: [Tab(text: "To Do"), Tab(text: "Ongoing"), Tab(text: "Completed")],
          ),
          const Expanded(
            child: TabBarView(
              children: [
                Center(child: Text("To Do List")),
                Center(child: Text("Ongoing List")),
                Center(child: Text("Completed List")),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _requestProjectCompletion() async {
    setState(() => _isCompletionRequesting = true);
    // Logic for completion request...
    await Future.delayed(const Duration(seconds: 1)); // Placeholder
    setState(() => _isCompletionRequesting = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundCream,
      appBar: AppBar(
        title: Text(widget.project['title'] ?? 'Project Overview', style: GoogleFonts.poppins(color: Colors.white)),
        backgroundColor: primaryMaroon,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Activities'),
            Tab(text: 'Finances'),
            Tab(text: 'Bills'),
            Tab(text: 'Feedback'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _activitiesTab(),
          _transactionsTab(),
          _billsTab(),
          ProjectChatSection(projectId: _projectId, currentRole: 'user'),
        ],
      ),
    );
  }
}