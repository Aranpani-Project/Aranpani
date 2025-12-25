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

  // Activities form
  final TextEditingController _godNameController = TextEditingController();
  final TextEditingController _peopleController = TextEditingController();
  final TextEditingController _donationController = TextEditingController();
  final TextEditingController _billingController = TextEditingController();
  final TextEditingController _feedbackInputController = TextEditingController(); // Added for Feedback
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
    _feedbackInputController.dispose(); // Dispose feedback controller
    super.dispose();
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
        _donationController.text = data['amountDonated'] ?? '';
        _billingController.text = data['billingCurrent'] ?? '';
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

  Future<void> _showUploadBillDialog() async {
    final TextEditingController titleCtrl = TextEditingController();
    final TextEditingController amountCtrl = TextEditingController();
    List<XFile> selectedImages = [];

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFFFFF7E8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: Color(0xFFB6862C), width: 2),
          ),
          title: Text('Upload Bill', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: const Color(0xFF6A1F1A))),
          content: StatefulBuilder(
            builder: (context, setStateSB) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleCtrl,
                      decoration: InputDecoration(
                        labelText: 'Bill Name',
                        labelStyle: GoogleFonts.poppins(color: Colors.brown),
                        filled: true,
                        fillColor: const Color(0xFFFFF2D5),
                        enabledBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Color(0xFFB6862C)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Amount',
                        labelStyle: GoogleFonts.poppins(color: Colors.brown),
                        filled: true,
                        fillColor: const Color(0xFFFFF2D5),
                        enabledBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Color(0xFFB6862C)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8E3D2C)),
                      onPressed: () async {
                        final imgs = await _picker.pickMultiImage();
                        if (imgs != null && imgs.isNotEmpty) {
                          setStateSB(() => selectedImages = imgs);
                        }
                      },
                      child: Text('Select Images', style: GoogleFonts.poppins(color: Colors.white)),
                    ),
                    const SizedBox(height: 10),
                    selectedImages.isEmpty
                        ? Text('No images selected', style: GoogleFonts.poppins(color: Colors.grey))
                        : Wrap(
                            spacing: 8,
                            children: selectedImages.map((img) => ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(File(img.path), width: 60, height: 60, fit: BoxFit.cover),
                            )).toList(),
                          ),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.brown))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8E3D2C)),
              onPressed: () async {
                if (titleCtrl.text.trim().isEmpty || amountCtrl.text.trim().isEmpty || selectedImages.isEmpty) return;
                Navigator.pop(context);
                try {
                  final amount = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
                  final now = DateTime.now();
                  final List<String> urls = [];
                  for (final x in selectedImages) {
                    final url = await CloudinaryService.uploadImage(imageFile: File(x.path), userId: _userId, projectId: _projectId);
                    urls.add(url);
                  }
                  final doc = await _billsRef.add({
                    'userId': _userId,
                    'projectId': _projectId,
                    'title': titleCtrl.text.trim(),
                    'amount': amount,
                    'imageUrls': urls,
                    'createdAt': now,
                  });
                  setState(() {
                    _localBills.insert(0, {'id': doc.id, 'title': titleCtrl.text.trim(), 'amount': amount, 'imageUrls': urls, 'date': now});
                  });
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
                }
              },
              child: Text('Upload', style: GoogleFonts.poppins(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  // --- TAB: BILLS ---
  Widget _billsTab() {
    return Column(
      children: [
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            height: 54, width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.upload, color: Colors.white),
              label: Text("Upload Bill", style: GoogleFonts.poppins(fontSize: 16, color: Colors.white)),
              onPressed: _showUploadBillDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8E3D2C),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Expanded(
          child: _localBills.isEmpty
              ? Center(child: Text('No bills yet', style: GoogleFonts.poppins(color: Colors.grey)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _localBills.length,
                  itemBuilder: (context, i) {
                    final bill = _localBills[i];
                    return Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: Color(0xFFB6862C), width: 1)),
                      margin: const EdgeInsets.symmetric(vertical: 10),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(14),
                        title: Text(bill['title'], style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: const Color(0xFF6A1F1A))),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("₹${bill['amount']}", style: GoogleFonts.poppins(color: Colors.brown)),
                            const SizedBox(height: 4),
                            Text("Date: ${bill['date'].day}/${bill['date'].month}/${bill['date'].year}", style: GoogleFonts.poppins(color: Colors.brown)),
                            const SizedBox(height: 8),
                            if (bill['imageUrls'] != null && (bill['imageUrls'] as List).isNotEmpty)
                              SizedBox(
                                height: 80,
                                child: ListView(
                                  scrollDirection: Axis.horizontal,
                                  children: (bill['imageUrls'] as List).map<Widget>((url) => Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.network(url as String, width: 80, height: 80, fit: BoxFit.cover)),
                                  )).toList(),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // --- TAB: ACTIVITIES ---
  Widget _activitiesTab() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Work Details', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w600, color: const Color(0xFF6A1F1A))),
            const SizedBox(height: 12),
            _buildTextField(_godNameController, 'Name of God', 'e.g. Shiva, Perumal'),
            const SizedBox(height: 16),
            Text('Part of work', style: GoogleFonts.poppins(color: Colors.brown, fontSize: 13)),
            ...['lingam', 'avudai', 'nandhi', 'shed'].map((part) => RadioListTile<String>(
              value: part, groupValue: _workPart, activeColor: const Color(0xFF8E3D2C),
              title: Text(part[0].toUpperCase() + part.substring(1)),
              onChanged: (v) => setState(() => _workPart = v!),
            )),
            const SizedBox(height: 8),
            _buildTextField(_peopleController, 'Number of people visited', '', isNum: true),
            const SizedBox(height: 12),
            _buildTextField(_donationController, 'Amount donated', '', isNum: true),
            const SizedBox(height: 12),
            _buildTextField(_billingController, 'Billing: current amount received', '', isNum: true),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity, height: 52,
              child: ElevatedButton(
                onPressed: _loadingAdd ? null : _submitActivityForm,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8E3D2C), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                child: _loadingAdd ? const CircularProgressIndicator(color: Colors.white) : Text('Save Work', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController ctrl, String label, String hint, {bool isNum = false}) {
    return TextField(
      controller: ctrl, keyboardType: isNum ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label, hintText: hint, labelStyle: GoogleFonts.poppins(color: Colors.brown),
        filled: true, fillColor: const Color(0xFFFFF2D5),
        enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Color(0xFFB6862C)), borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Color(0xFF8E3D2C), width: 2), borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // --- TAB: TRANSACTIONS ---
  Widget _transactionsTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _firestore.collection('transactions').where('projectId', isEqualTo: _projectId).orderBy('date', descending: true).snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) return Center(child: Text('No transactions', style: GoogleFonts.poppins(color: Colors.grey)));
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final d = docs[i].data();
            return Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: Color(0xFFB6862C), width: 1)),
              child: ListTile(title: Text(d['title'] ?? 'Txn', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: const Color(0xFF6A1F1A))), subtitle: Text(d['amount'] != null ? '₹${d['amount']}' : '', style: GoogleFonts.poppins(color: Colors.brown))),
            );
          },
        );
      },
    );
  }

  // --- TAB: FEEDBACK (UPDATED WITH SENDING FUNCTIONALITY) ---
  Widget _feedbackTab() {
    return Column(
      children: [
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _firestore.collection('feedback').where('projectId', isEqualTo: _projectId).orderBy('createdAt', descending: true).snapshots(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              final docs = snap.data?.docs ?? [];
              if (docs.isEmpty) return Center(child: Text('No feedback yet', style: GoogleFonts.poppins(color: Colors.grey)));
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                reverse: true, // Chat flow
                itemCount: docs.length,
                itemBuilder: (context, i) {
                  final d = docs[i].data();
                  bool isMe = d['role'] == 'user';
                  return Align(
                    alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isMe ? const Color(0xFF8E3D2C) : Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        border: isMe ? null : Border.all(color: const Color(0xFFB6862C)),
                      ),
                      child: Column(
                        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                        children: [
                          Text(d['message'] ?? '', style: GoogleFonts.poppins(color: isMe ? Colors.white : Colors.black87, fontSize: 14)),
                          const SizedBox(height: 2),
                          Text(isMe ? "You" : "Admin", style: GoogleFonts.poppins(color: isMe ? Colors.white70 : Colors.black45, fontSize: 10)),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: Colors.white,
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _feedbackInputController,
                  decoration: InputDecoration(
                    hintText: "Message Admin...",
                    filled: true, fillColor: const Color(0xFFFFF7E8),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                backgroundColor: const Color(0xFF8E3D2C),
                child: IconButton(
                  icon: const Icon(Icons.send, color: Colors.white, size: 20),
                  onPressed: _sendUserFeedback,
                ),
              )
            ],
          ),
        ),
      ],
    );
  }

  void _sendUserFeedback() async {
    final msg = _feedbackInputController.text.trim();
    if (msg.isEmpty) return;
    await _firestore.collection('feedback').add({
      'projectId': _projectId,
      'userId': _userId,
      'message': msg,
      'role': 'user',
      'createdAt': FieldValue.serverTimestamp(),
    });
    _feedbackInputController.clear();
  }

  // --- HEADER & TABS ---
  SliverPersistentHeader _buildTabBar() {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _TabBarDelegate(
        TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF8E3D2C),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF8E3D2C),
          tabs: [
            Tab(child: Text('Activities', style: GoogleFonts.poppins(fontSize: 12))),
            Tab(child: Text('Transactions', style: GoogleFonts.poppins(fontSize: 12))),
            Tab(child: Text('Bills', style: GoogleFonts.poppins(fontSize: 12))),
            Tab(child: Text('Feedback', style: GoogleFonts.poppins(fontSize: 12))),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final projectName = widget.project['place'] ?? 'Project';
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Container(
                width: double.infinity, padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF6A1F1A), Color(0xFFB6862C)], begin: Alignment.topLeft, end: Alignment.bottomRight)),
                child: Row(
                  children: [
                    IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Project Overview', style: GoogleFonts.poppins(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                          Text(projectName, style: GoogleFonts.poppins(color: Colors.white70, fontSize: 16)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
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
  @override double get minExtent => _tabBar.preferredSize.height;
  @override double get maxExtent => _tabBar.preferredSize.height;
  @override Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(color: Colors.white, child: Material(color: Colors.white, child: _tabBar));
  }
  @override bool shouldRebuild(covariant _TabBarDelegate oldDelegate) => oldDelegate._tabBar != _tabBar;
}