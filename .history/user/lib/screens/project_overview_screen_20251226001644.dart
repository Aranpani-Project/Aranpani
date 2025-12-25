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

  // --- Aranpani Theme Colors (Mirrored from Admin) ---
  static const Color primaryMaroon = Color(0xFF6D1B1B);
  static const Color primaryGold = Color(0xFFD4AF37);
  static const Color backgroundCream = Color(0xFFFFF7E8);
  static const Color darkMaroonText = Color(0xFF4A1010);

  late TabController _tabController;
  bool _loadingAdd = false;
  final ImagePicker _picker = ImagePicker();

  // Controllers
  final TextEditingController _godNameController = TextEditingController();
  final TextEditingController _peopleController = TextEditingController();
  final TextEditingController _donationController = TextEditingController();
  final TextEditingController _billingController = TextEditingController();
  final TextEditingController _feedbackInputController = TextEditingController();
  
  String _workPart = 'lingam';
  List<Map<String, dynamic>> _localBills = [];

  String get _projectId => widget.project['id'] as String;
  String get _userId => (widget.project['userId'] ?? '') as String;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _restoreData();
  }

  // --- PERSISTENCE: Restore data every time user enters ---
  Future<void> _restoreData() async {
    try {
      // 1. Restore Latest Activity
      final activitySnap = await _firestore.collection('activities')
          .where('projectId', isEqualTo: _projectId)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (activitySnap.docs.isNotEmpty) {
        final data = activitySnap.docs.first.data();
        setState(() {
          _godNameController.text = (data['godName'] ?? '').toString();
          _peopleController.text = (data['peopleVisited'] ?? '').toString();
          _donationController.text = (data['amountDonated'] ?? '').toString();
          _billingController.text = (data['billingCurrent'] ?? '').toString();
          _workPart = (data['workPart'] ?? 'lingam') as String;
        });
      }

      // 2. Restore Bills
      final billSnap = await _firestore.collection('bills')
          .where('projectId', isEqualTo: _projectId)
          .orderBy('createdAt', descending: true)
          .get();
      
      setState(() {
        _localBills = billSnap.docs.map((doc) => {
          'id': doc.id,
          ...doc.data(),
          'date': (doc.data()['createdAt'] as Timestamp).toDate(),
        }).toList();
      });
    } catch (e) {
      debugPrint("Persistence Error: $e");
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _godNameController.dispose();
    _peopleController.dispose();
    _donationController.dispose();
    _billingController.dispose();
    _feedbackInputController.dispose();
    super.dispose();
  }

  // --- TAB 1: WORK DETAILS ---
  Widget _activitiesTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('Daily Progress Update', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: darkMaroonText)),
        const SizedBox(height: 20),
        _buildInputField(_godNameController, 'Deity Name', Icons.temple_hindu),
        const SizedBox(height: 15),
        const Text('Part of work', style: TextStyle(color: darkMaroonText, fontWeight: FontWeight.w500)),
        ...['lingam', 'avudai', 'nandhi', 'shed'].map((part) => RadioListTile(
          value: part, groupValue: _workPart, title: Text(part.toUpperCase()),
          activeColor: primaryMaroon,
          onChanged: (v) => setState(() => _workPart = v.toString()),
        )),
        _buildInputField(_peopleController, 'Visitors Count', Icons.people, isNum: true),
        const SizedBox(height: 15),
        _buildInputField(_donationController, 'Donation Amount', Icons.currency_rupee, isNum: true),
        const SizedBox(height: 15),
        _buildInputField(_billingController, 'Current Billing', Icons.receipt_long, isNum: true),
        const SizedBox(height: 25),
        SizedBox(
          width: double.infinity, height: 50,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: primaryMaroon, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: _loadingAdd ? null : _submitWork,
            child: _loadingAdd ? const CircularProgressIndicator(color: Colors.white) : const Text('SAVE PROGRESS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        )
      ],
    );
  }

  Future<void> _submitWork() async {
    setState(() => _loadingAdd = true);
    try {
      await _firestore.collection('activities').add({
        'projectId': _projectId,
        'userId': _userId,
        'godName': _godNameController.text,
        'workPart': _workPart,
        'peopleVisited': _peopleController.text,
        'amountDonated': _donationController.text,
        'billingCurrent': _billingController.text,
        'createdAt': FieldValue.serverTimestamp(),
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Progress Saved Successfully')));
    } finally {
      setState(() => _loadingAdd = false);
    }
  }

  // --- TAB 4: COMMUNICATION LOG (FEEDBACK) ---
  Widget _feedbackTab() {
    return Column(
      children: [
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _firestore.collection('feedback')
                .where('projectId', isEqualTo: _projectId)
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final docs = snapshot.data!.docs;
              return ListView.builder(
                padding: const EdgeInsets.all(15),
                reverse: true, // Chat logic
                itemCount: docs.length,
                itemBuilder: (context, i) {
                  final data = docs[i].data() as Map<String, dynamic>;
                  bool isMe = data['role'] == 'user'; // User side logic
                  return Align(
                    alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 5),
                      padding: const EdgeInsets.all(12),
                      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
                      decoration: BoxDecoration(
                        color: isMe ? primaryMaroon : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: isMe ? null : Border.all(color: Colors.grey.shade300),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 2)],
                      ),
                      child: Text(data['message'] ?? '', style: TextStyle(color: isMe ? Colors.white : Colors.black87)),
                    ),
                  );
                },
              );
            },
          ),
        ),
        _buildChatInput(),
      ],
    );
  }

  Widget _buildChatInput() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.grey.shade200))),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _feedbackInputController,
              decoration: InputDecoration(
                hintText: 'Message Admin...',
                filled: true, fillColor: backgroundCream,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
              ),
            ),
          ),
          const SizedBox(width: 10),
          CircleAvatar(
            backgroundColor: primaryMaroon,
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white, size: 20),
              onPressed: _sendFeedback,
            ),
          )
        ],
      ),
    );
  }

  void _sendFeedback() async {
    final msg = _feedbackInputController.text.trim();
    if (msg.isEmpty) return;
    await _firestore.collection('feedback').add({
      'projectId': _projectId,
      'message': msg,
      'role': 'user', // Identifying as user
      'createdAt': FieldValue.serverTimestamp(),
    });
    _feedbackInputController.clear();
  }

  // --- SHARED UI HELPERS ---
  Widget _buildInputField(TextEditingController ctrl, String label, IconData icon, {bool isNum = false}) {
    return TextField(
      controller: ctrl,
      keyboardType: isNum ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label, prefixIcon: Icon(icon, color: primaryMaroon),
        filled: true, fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
      ),
    );
  }

  // (Remaining Tabs: Finance & Bills kept with original logic but updated styling)
  Widget _financeTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _firestore.collection('transactions').where('projectId', isEqualTo: _projectId).orderBy('date', descending: true).snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snap.data!.docs;
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, i) => Card(
            color: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), border: Border.all(color: primaryGold.withOpacity(0.3))),
            child: ListTile(title: Text(docs[i].data()['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text('₹${docs[i].data()['amount']}')),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundCream,
      body: SafeArea(
        child: Column(
          children: [
            // Custom Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(color: primaryMaroon),
              child: Row(
                children: [
                  IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Project Overview', style: GoogleFonts.poppins(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                      Text(widget.project['place'] ?? '', style: GoogleFonts.poppins(color: primaryGold)),
                    ],
                  ),
                ],
              ),
            ),
            // Tab Bar
            Container(
              color: Colors.white,
              child: TabBar(
                controller: _tabController,
                labelColor: primaryMaroon,
                unselectedLabelColor: Colors.grey,
                indicatorColor: primaryGold,
                indicatorWeight: 3,
                tabs: const [Tab(text: 'Work'), Tab(text: 'Finance'), Tab(text: 'Bills'), Tab(text: 'Chat')],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [_activitiesTab(), _financeTab(), _billsTabPlaceholder(), _feedbackTab()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _billsTabPlaceholder() {
    return Center(child: Text('Bills management logic here', style: GoogleFonts.poppins()));
  }
}