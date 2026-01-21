import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

// Internal Imports
import 'project_chat_section.dart';
import 'project_finances_tab.dart'; // Import the new file
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
  double get _totalBudget => (widget.project['budget'] ?? 0).toDouble();

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

  // Helper for UI
  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ===================== DIALOGS =====================

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
          title: Text('Request Funds', style: GoogleFonts.poppins(color: primaryMaroon, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Purpose (e.g. Materials)')),
                TextField(controller: amountCtrl, decoration: const InputDecoration(labelText: 'Amount'), keyboardType: TextInputType.number),
                TextField(controller: upiCtrl, decoration: const InputDecoration(labelText: 'UPI ID (Optional)')),
                const SizedBox(height: 15),
                ElevatedButton.icon(
                  onPressed: () async {
                    final img = await _picker.pickImage(source: ImageSource.gallery);
                    if (img != null) setDialogState(() => qrFile = img);
                  },
                  icon: const Icon(Icons.qr_code),
                  label: Text(qrFile == null ? 'Upload QR' : 'QR Selected'),
                ),
                if (isUploading) const LinearProgressIndicator(),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
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
                  'title': titleCtrl.text,
                  'amount': double.parse(amountCtrl.text),
                  'upiId': upiCtrl.text,
                  'qrUrl': qrUrl,
                  'status': 'pending',
                  'date': FieldValue.serverTimestamp(),
                });
                if (mounted) Navigator.pop(context);
              },
              child: const Text('Submit'),
            )
          ],
        ),
      ),
    );
  }

  // ===================== UI BUILDERS =====================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundCream,
      appBar: AppBar(
        title: Text(widget.project['projectName'] ?? 'Project Overview', 
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: primaryMaroon,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: primaryMaroon,
          unselectedLabelColor: Colors.grey,
          indicatorColor: primaryMaroon,
          tabs: const [
            Tab(icon: Icon(Icons. assignment), text: 'Work'),
            Tab(icon: Icon(Icons.payments), text: 'Finance'),
            Tab(icon: Icon(Icons.receipt_long), text: 'Bills'),
            Tab(icon: Icon(Icons.forum), text: 'Chat'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _activitiesTab(),
          ProjectFinancesTab(projectId: _projectId, userId: _userId, totalBudget: _totalBudget),
          _billsTab(),
          ProjectChatSection(projectId: _projectId, currentRole: 'user'),
        ],
      ),
      floatingActionButton: _buildFab(),
    );
  }

  Widget? _buildFab() {
    // Only show FAB for Finance and Bills tab to keep UI clean
    return ValueListenableBuilder(
      valueListenable: _tabController.animation!,
      builder: (context, anim, child) {
        int index = _tabController.index;
        if (index == 1) {
          return FloatingActionButton.extended(
            onPressed: _showRequestAmountDialog,
            backgroundColor: primaryMaroon,
            label: const Text("Request Funds"),
            icon: const Icon(Icons.add),
          );
        } else if (index == 2) {
          return FloatingActionButton.extended(
            onPressed: _showUploadBillDialog, // Reuse your existing method
            backgroundColor: primaryMaroon,
            label: const Text("Add Bill"),
            icon: const Icon(Icons.receipt),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  // Note: Include your existing _activitiesTab(), _billsTab(), _showUploadBillDialog() 
  // and other helper methods here to complete the class.
}