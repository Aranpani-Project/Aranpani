import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

// Internal Imports
import 'project_chat_section.dart';
import 'project_finances_tab.dart'; 
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
  
  // --- FIX: Robust Budget Parsing to prevent automation crashes ---
  double get _totalBudget {
    final b = widget.project['budget'];
    if (b is num) return b.toDouble();
    if (b is String) return double.tryParse(b) ?? 0.0;
    return 0.0;
  }

  CollectionReference<Map<String, dynamic>> get _billsRef =>
      _firestore.collection('bills');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    // Listen to tab changes to refresh the FloatingActionButton
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {}); 
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ===================== DIALOGS & ACTIONS =====================

  Future<void> _showAddWorkDialog() async {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: backgroundCream,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text('Add Work (To Do)', 
          style: GoogleFonts.poppins(color: primaryMaroon, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Work name')),
            TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Description'), maxLines: 2),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: primaryMaroon),
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
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Add', style: TextStyle(color: Colors.white)),
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
    bool isUploading = false;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: backgroundCream,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Text('Request Amount', style: GoogleFonts.poppins(color: primaryMaroon, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Work Title (e.g. Raw Material)')),
                TextField(controller: amountCtrl, decoration: const InputDecoration(labelText: 'Amount'), keyboardType: TextInputType.number),
                TextField(controller: upiCtrl, decoration: const InputDecoration(labelText: 'UPI ID (Optional)')),
                const SizedBox(height: 15),
                OutlinedButton.icon(
                  onPressed: () async {
                    final img = await _picker.pickImage(source: ImageSource.gallery);
                    if (img != null) setDialogState(() => qrFile = img);
                  },
                  icon: Icon(qrFile == null ? Icons.qr_code : Icons.check_circle, color: primaryMaroon),
                  label: Text(qrFile == null ? 'Upload QR Code' : 'QR Selected', style: const TextStyle(color: primaryMaroon)),
                ),
                if (isUploading) const Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: LinearProgressIndicator(color: primaryMaroon),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: primaryMaroon),
              onPressed: isUploading ? null : () async {
                if (titleCtrl.text.isEmpty || amountCtrl.text.isEmpty) return;
                setDialogState(() => isUploading = true);
                
                String? qrUrl;
                if (qrFile != null) {
                  qrUrl = await CloudinaryService.uploadImage(imageFile: qrFile!, userId: _userId, projectId: _projectId);
                }

                await _firestore.collection('transactions').add({
                  'projectId': _projectId,
                  'userId': _userId,
                  'title': titleCtrl.text.trim(),
                  'amount': double.tryParse(amountCtrl.text) ?? 0.0,
                  'upiId': upiCtrl.text.trim(),
                  'qrUrl': qrUrl,
                  'status': 'pending', // Automation counts this only when changed to 'approved'
                  'date': FieldValue.serverTimestamp(),
                });
                
                if (mounted) Navigator.pop(context);
              },
              child: const Text('Submit Request', style: TextStyle(color: Colors.white)),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Text('Upload New Bill', style: GoogleFonts.poppins(color: primaryMaroon, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Bill For (Title)')),
                TextField(controller: amountCtrl, decoration: const InputDecoration(labelText: 'Total Amount'), keyboardType: TextInputType.number),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () async {
                    final imgs = await _picker.pickMultiImage();
                    if (imgs.isNotEmpty) setDialogState(() => selectedFiles = imgs);
                  },
                  icon: const Icon(Icons.image),
                  label: Text(selectedFiles.isEmpty ? 'Select Bill Photos' : '${selectedFiles.length} Selected'),
                ),
                if (isUploading) const LinearProgressIndicator(color: primaryMaroon),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: primaryMaroon),
              onPressed: isUploading ? null : () async {
                if (titleCtrl.text.isEmpty || selectedFiles.isEmpty) return;
                setDialogState(() => isUploading = true);
                
                List<String> urls = [];
                for (var file in selectedFiles) {
                  String? url = await CloudinaryService.uploadImage(imageFile: file, userId: _userId, projectId: _projectId);
                  if (url != null) urls.add(url);
                }
                
                await _billsRef.add({
                  'projectId': _projectId,
                  'userId': _userId,
                  'title': titleCtrl.text.trim(),
                  'amount': double.tryParse(amountCtrl.text) ?? 0.0,
                  'imageUrls': urls,
                  'createdAt': FieldValue.serverTimestamp(),
                });
                
                if (mounted) Navigator.pop(context);
              },
              child: const Text('Upload', style: TextStyle(color: Colors.white)),
            )
          ],
        ),
      ),
    );
  }

  // ===================== TABS CONTENT =====================

  Widget _activitiesTab() {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _showAddWorkDialog,
                icon: const Icon(Icons.add_task),
                label: Text('Add Work (To Do)', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryMaroon, 
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                ),
              ),
            ),
          ),
          const TabBar(
            labelColor: primaryMaroon,
            indicatorColor: primaryMaroon,
            unselectedLabelColor: Colors.grey,
            tabs: [Tab(text: "To Do"), Tab(text: "Ongoing"), Tab(text: "Completed")],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildTaskList('todo'),
                _buildTaskList('ongoing'),
                _buildTaskList('completed'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskList(String status) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('project_tasks')
          .where('projectId', isEqualTo: _projectId)
          .where('status', isEqualTo: status)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: primaryMaroon));
        final docs = snapshot.data!.docs;
        
        if (docs.isEmpty) {
          return Center(child: Text("No tasks in $status", style: GoogleFonts.poppins(color: Colors.grey)));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            return Card(
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                title: Text(data['taskName'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(data['description'] ?? ''),
                trailing: status != 'completed' 
                  ? const Icon(Icons.arrow_forward_ios, size: 14) 
                  : const Icon(Icons.check_circle, color: Colors.green),
              ),
            );
          },
        );
      },
    );
  }

  Widget _billsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _showUploadBillDialog,
              icon: const Icon(Icons.receipt_long),
              label: Text("Upload Bill", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryMaroon, 
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
              ),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _billsRef
                .where('projectId', isEqualTo: _projectId)
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: primaryMaroon));
              final docs = snapshot.data!.docs;
              
              if (docs.isEmpty) {
                return Center(child: Text("No bills uploaded yet", style: GoogleFonts.poppins(color: Colors.grey)));
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: docs.length,
                itemBuilder: (context, i) {
                  final bill = docs[i].data();
                  return Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      leading: const Icon(Icons.receipt, color: primaryMaroon),
                      title: Text(bill['title'] ?? 'Unnamed Bill'),
                      subtitle: Text("Amount: ₹${bill['amount']}"),
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

  // ===================== BUILD METHOD =====================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundCream,
      appBar: AppBar(
        title: Text(widget.project['projectName'] ?? 'Project', 
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: primaryMaroon,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: primaryMaroon,
          unselectedLabelColor: Colors.grey,
          indicatorColor: primaryMaroon,
          labelStyle: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold),
          tabs: const [
            Tab(icon: Icon(Icons.list_alt, size: 20), text: 'Activities'),
            Tab(icon: Icon(Icons.account_balance_wallet, size: 20), text: 'Finances'),
            Tab(icon: Icon(Icons.receipt, size: 20), text: 'Bills'),
            Tab(icon: Icon(Icons.feedback, size: 20), text: 'Feedback'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _activitiesTab(),
          ProjectFinancesTab(
            projectId: _projectId, 
            userId: _userId, 
            totalBudget: _totalBudget
          ),
          _billsTab(),
          ProjectChatSection(projectId: _projectId, currentRole: 'user'),
        ],
      ),
      // --- FIX: Logic to show "Request Funds" only on the Finances Tab ---
      floatingActionButton: _tabController.index == 1 
        ? FloatingActionButton.extended(
            onPressed: _showRequestAmountDialog,
            backgroundColor: primaryMaroon,
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text("Request Funds", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          )
        : null,
    );
  }
}