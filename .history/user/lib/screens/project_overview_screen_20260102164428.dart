import 'dart:io';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'project_chat_section.dart';
import '/services/cloudinary_service.dart';

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
  bool _loadingAdd = false;

  final ImagePicker _picker = ImagePicker();

  // Gemini API Key
  final String _geminiApiKey = "AIzaSyC7rjITsgx4nG4-a3tA9dDkWUW2uP7HRI4";

  // Activities form controllers
  final TextEditingController _godNameController = TextEditingController();
  final TextEditingController _peopleController = TextEditingController();
  final TextEditingController _donationController = TextEditingController();
  final TextEditingController _billingController = TextEditingController();
  String _workPart = 'lingam';

  String get _projectId => widget.project['id'] as String;
  String get _userId => (widget.project['userId'] ?? '') as String;

  CollectionReference<Map<String, dynamic>> get _activitiesRef =>
      _firestore.collection('activities');

  CollectionReference<Map<String, dynamic>> get _billsRef =>
      _firestore.collection('bills');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadLatestActivity();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _godNameController.dispose();
    _peopleController.dispose();
    _donationController.dispose();
    _billingController.dispose();
    super.dispose();
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
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
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

  Future<void> _deleteBill(String docId) async {
    try {
      await _billsRef.doc(docId).delete();
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bill deleted successfully')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e')));
    }
  }

  Future<Map<String, dynamic>?> _extractBillData(File imageFile) async {
    try {
      final model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: _geminiApiKey);
      final bytes = await imageFile.readAsBytes();
      final prompt = TextPart("Extract Merchant Name and Total Amount as JSON: {'name': 'String', 'amount': double}");
      final response = await model.generateContent([
        Content.multi([prompt, DataPart('image/jpeg', bytes)])
      ]);
      final text = response.text ?? "{}";
      final cleanJson = text.replaceAll('```json', '').replaceAll('```', '').trim();
      return jsonDecode(cleanJson);
    } catch (e) {
      return null;
    }
  }

  Future<void> _loadLatestActivity() async {
    try {
      final snap = await _activitiesRef
          .where('projectId', isEqualTo: _projectId)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return;
      final data = snap.docs.first.data();
      setState(() {
        _godNameController.text = data['godName'] ?? '';
        _peopleController.text = data['peopleVisited'] ?? '';
        _workPart = (data['workPart'] ?? 'lingam') as String;
      });
    } catch (_) {}
  }

  Future<void> _submitActivityForm() async {
    final godName = _godNameController.text.trim();
    if (godName.isEmpty) return;
    setState(() => _loadingAdd = true);
    try {
      await _activitiesRef.add({
        'userId': _userId,
        'projectId': _projectId,
        'godName': godName,
        'workPart': _workPart,
        'peopleVisited': _peopleController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Work details saved')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save: $e')));
    } finally {
      if (mounted) setState(() => _loadingAdd = false);
    }
  }

  // --- NEW: REQUEST AMOUNT DIALOG ---
  Future<void> _showRequestAmountDialog() async {
    final titleCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final upiCtrl = TextEditingController();
    File? qrFile;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFFFFF7E8),
          title: Text('Request Amount', style: GoogleFonts.poppins(color: const Color(0xFF6A1F1A))),
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
                    if (img != null) setDialogState(() => qrFile = File(img.path));
                  },
                  icon: const Icon(Icons.qr_code),
                  label: const Text('Upload QR Code'),
                ),
                if (qrFile != null) Text('QR selected', style: TextStyle(color: Colors.green)),
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
                Navigator.pop(context);
              },
              child: const Text('Submit Request'),
            )
          ],
        ),
      ),
    );
  }

  Widget _billsTab() {
    return Column(
      children: [
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _showUploadBillDialog,
          icon: const Icon(Icons.upload),
          label: const Text("Upload Bill"),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _billsRef.where('projectId', isEqualTo: _projectId).snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final docs = snapshot.data!.docs;
              return ListView.builder(
                itemCount: docs.length,
                itemBuilder: (context, i) {
                  final bill = docs[i].data();
                  return Card(
                    child: ExpansionTile(
                      title: Text(bill['title'] ?? 'Bill'),
                      children: [
                        Wrap(
                          children: (bill['imageUrls'] as List).map((url) => Image.network(url, width: 50)).toList(),
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

  Future<void> _showUploadBillDialog() async {
    // Standard implementation for Bill Upload...
  }

  Widget _activitiesTab() {
    return _activitiesTabUI(); // Existing implementation
  }

  Widget _activitiesTabUI() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          TextField(controller: _godNameController, decoration: const InputDecoration(labelText: 'God Name')),
          const SizedBox(height: 20),
          ElevatedButton(onPressed: _submitActivityForm, child: const Text('Save')),
        ],
      ),
    );
  }

  Widget _transactionsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton.icon(
            onPressed: _showRequestAmountDialog,
            icon: const Icon(Icons.add_card),
            label: const Text('Request Amount from Admin'),
            style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _firestore.collection('transactions').where('projectId', isEqualTo: _projectId).snapshots(),
            builder: (context, snap) {
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              final docs = snap.data!.docs;
              return ListView.builder(
                itemCount: docs.length,
                itemBuilder: (context, i) {
                  final d = docs[i].data();
                  final status = d['status'] ?? 'pending';
                  return ListTile(
                    title: Text(d['title']),
                    subtitle: Text('₹${d['amount']} • Status: $status'),
                    trailing: Icon(status == 'pending' ? Icons.hourglass_empty : Icons.check_circle, 
                        color: status == 'pending' ? Colors.orange : Colors.green),
                  );
                },
              );
            },
          ),
        )
      ],
    );
  }

  Widget _feedbackTab() {
    return ProjectChatSection(projectId: _projectId, currentRole: 'user');
  }

  SliverPersistentHeader _buildTabBar() {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _TabBarDelegate(
        TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF8E3D2C),
          tabs: const [
            Tab(text: 'Activities'),
            Tab(text: 'Finances'),
            Tab(text: 'Bills'),
            Tab(text: 'Feedback'),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7E8),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: Container(height: 100, color: const Color(0xFF6A1F1A))),
            _buildTabBar(),
            SliverFillRemaining(
              child: TabBarView(
                controller: _tabController,
                children: [_activitiesTab(), _transactionsTab(), _billsTab(), _feedbackTab()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;
  _TabBarDelegate(this._tabBar);
  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;
  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(color: Colors.white, child: _tabBar);
  }
  @override
  bool shouldRebuild(covariant _TabBarDelegate oldDelegate) => false;
}