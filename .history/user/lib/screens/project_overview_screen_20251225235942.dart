import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
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

  // Local bills cache for UI
  List<Map<String, dynamic>> _localBills = [];

  // Controllers
  final TextEditingController _godNameController = TextEditingController();
  final TextEditingController _peopleController = TextEditingController();
  final TextEditingController _donationController = TextEditingController();
  final TextEditingController _billingController = TextEditingController();
  final TextEditingController _feedbackReplyController = TextEditingController();
  String _workPart = 'lingam';

  String get _projectId => widget.project['id'] as String;
  String get _userId => (widget.project['userId'] ?? '') as String;

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
    _feedbackReplyController.dispose();
    super.dispose();
  }

  // ------------ DATA LOADING ------------
  Future<void> _loadLatestActivity() async {
    try {
      final snap = await _firestore
          .collection('activities')
          .where('projectId', isEqualTo: _projectId)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (snap.docs.isEmpty) return;

      final data = snap.docs.first.data();
      setState(() {
        _godNameController.text = data['godName'] ?? '';
        _peopleController.text = data['peopleVisited'] ?? '';
        _donationController.text = data['amountDonated'] ?? '';
        _billingController.text = data['billingCurrent'] ?? '';
        _workPart = (data['workPart'] ?? 'lingam') as String;
      });
    } catch (_) {}
  }

  // ------------ FORM SUBMISSION ------------
  Future<void> _submitActivityForm() async {
    final godName = _godNameController.text.trim();
    if (godName.isEmpty) return;
    setState(() => _loadingAdd = true);
    try {
      await _firestore.collection('activities').add({
        'userId': _userId,
        'projectId': _projectId,
        'godName': godName,
        'workPart': _workPart,
        'peopleVisited': _peopleController.text.trim(),
        'amountDonated': _donationController.text.trim(),
        'billingCurrent': _billingController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      await _loadLatestActivity();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Work details saved')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save: $e')));
    } finally {
      if (mounted) setState(() => _loadingAdd = false);
    }
  }

  // ------------ BILLS LOGIC ------------
  Future<void> _showUploadBillDialog() async {
    final TextEditingController titleCtrl = TextEditingController();
    final TextEditingController amountCtrl = TextEditingController();
    List<XFile> selectedImages = [];

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFFFFF7E8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: Color(0xFFB6862C), width: 2)),
          title: Text('Upload Bill', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: const Color(0xFF6A1F1A))),
          content: StatefulBuilder(
            builder: (context, setStateSB) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(controller: titleCtrl, decoration: InputDecoration(labelText: 'Bill Name', filled: true, fillColor: const Color(0xFFFFF2D5))),
                    const SizedBox(height: 12),
                    TextField(controller: amountCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Amount', filled: true, fillColor: const Color(0xFFFFF2D5))),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8E3D2C)),
                      onPressed: () async {
                        final imgs = await _picker.pickMultiImage();
                        if (imgs != null) setStateSB(() => selectedImages = imgs);
                      },
                      child: Text('Select Images', style: const TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8E3D2C)),
              onPressed: () async {
                if (titleCtrl.text.isEmpty || amountCtrl.text.isEmpty || selectedImages.isEmpty) return;
                Navigator.pop(context);
                try {
                  final List<String> urls = [];
                  for (final x in selectedImages) {
                    final url = await CloudinaryService.uploadImage(imageFile: File(x.path), userId: _userId, projectId: _projectId);
                    urls.add(url);
                  }
                  final now = DateTime.now();
                  final doc = await _firestore.collection('bills').add({
                    'userId': _userId, 'projectId': _projectId, 'title': titleCtrl.text.trim(),
                    'amount': double.tryParse(amountCtrl.text) ?? 0, 'imageUrls': urls, 'createdAt': now,
                  });
                  setState(() => _localBills.insert(0, {'id': doc.id, 'title': titleCtrl.text, 'amount': amountCtrl.text, 'imageUrls': urls, 'date': now}));
                } catch (e) { print(e); }
              },
              child: const Text('Upload', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  // ------------ FEEDBACK LOGIC ------------
  Future<void> _sendFeedback() async {
    final msg = _feedbackReplyController.text.trim();
    if (msg.isEmpty) return;
    try {
      await _firestore.collection('feedback').add({
        'projectId': _projectId,
        'author': 'Ground Team',
        'role': 'user',
        'message': msg,
        'createdAt': FieldValue.serverTimestamp(),
      });
      _feedbackReplyController.clear();
    } catch (e) { print(e); }
  }

  // ------------ TAB WIDGETS ------------
  Widget _activitiesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Work Details', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w600, color: const Color(0xFF6A1F1A))),
          const SizedBox(height: 12),
          TextField(controller: _godNameController, decoration: const InputDecoration(labelText: 'Name of God')),
          const SizedBox(height: 16),
          ...['lingam', 'avudai', 'nandhi', 'shed'].map((part) => RadioListTile<String>(
            value: part, groupValue: _workPart, title: Text(part.toUpperCase()),
            activeColor: const Color(0xFF8E3D2C), onChanged: (v) => setState(() => _workPart = v!),
          )),
          TextField(controller: _peopleController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'People Visited')),
          const SizedBox(height: 12),
          TextField(controller: _donationController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount Donated')),
          const SizedBox(height: 12),
          TextField(controller: _billingController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Current Billing')),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _loadingAdd ? null : _submitActivityForm, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8E3D2C)), child: const Text('Save Work', style: TextStyle(color: Colors.white)))),
        ],
      ),
    );
  }

  Widget _transactionsTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _firestore.collection('transactions').where('projectId', isEqualTo: _projectId).orderBy('date', descending: true).snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snap.data!.docs;
        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final d = docs[i].data();
            return ListTile(title: Text(d['title'] ?? 'Transaction'), subtitle: Text('₹${d['amount']}'));
          },
        );
      },
    );
  }

  Widget _billsTab() {
    return Column(
      children: [
        Padding(padding: const EdgeInsets.all(16), child: ElevatedButton(onPressed: _showUploadBillDialog, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8E3D2C)), child: const Text("Upload Bill", style: TextStyle(color: Colors.white)))),
        Expanded(
          child: ListView.builder(
            itemCount: _localBills.length,
            itemBuilder: (context, i) => ListTile(title: Text(_localBills[i]['title']), subtitle: Text('₹${_localBills[i]['amount']}')),
          ),
        ),
      ],
    );
  }

  Widget _feedbackTab() {
    return Column(
      children: [
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _firestore.collection('feedback').where('projectId', isEqualTo: _projectId).orderBy('createdAt', descending: true).snapshots(),
            builder: (context, snap) {
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              final docs = snap.data!.docs;
              return ListView.builder(
                reverse: true,
                padding: const EdgeInsets.all(16),
                itemCount: docs.length,
                itemBuilder: (context, i) {
                  final d = docs[i].data();
                  bool isMe = d['role'] == 'user';
                  return Align(
                    alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 5),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: isMe ? const Color(0xFF8E3D2C) : Colors.grey[300], borderRadius: BorderRadius.circular(12)),
                      child: Text(d['message'] ?? '', style: TextStyle(color: isMe ? Colors.white : Colors.black)),
                    ),
                  );
                },
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              Expanded(child: TextField(controller: _feedbackReplyController, decoration: const InputDecoration(hintText: "Reply to Admin..."))),
              IconButton(icon: const Icon(Icons.send, color: Color(0xFF8E3D2C)), onPressed: _sendFeedback),
            ],
          ),
        )
      ],
    );
  }

  // ------------ MAIN BUILD ------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF6A1F1A), Color(0xFFB6862C)])),
                child: Text('Project Overview', style: GoogleFonts.poppins(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _TabBarDelegate(TabBar(
                controller: _tabController,
                labelColor: const Color(0xFF8E3D2C),
                tabs: const [Tab(text: 'Work'), Tab(text: 'Cash'), Tab(text: 'Bills'), Tab(text: 'Chat')],
              )),
            ),
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
  @override double get minExtent => 50;
  @override double get maxExtent => 50;
  @override Widget build(context, offset, overlaps) => Container(color: Colors.white, child: _tabBar);
  @override bool shouldRebuild(old) => false;
}