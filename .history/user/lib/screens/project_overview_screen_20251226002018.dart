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

  // Aranpani Theme Colors
  static const Color primaryMaroon = Color(0xFF6D1B1B);
  static const Color primaryGold = Color(0xFFD4AF37);
  static const Color backgroundCream = Color(0xFFFFF7E8);
  static const Color darkMaroonText = Color(0xFF4A1010);

  late TabController _tabController;
  bool _loadingAdd = false;
  final ImagePicker _picker = ImagePicker();

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

  Future<void> _restoreData() async {
    try {
      final activitySnap = await _firestore.collection('activities')
          .where('projectId', isEqualTo: _projectId)
          .get();

      if (activitySnap.docs.isNotEmpty) {
        var sortedDocs = activitySnap.docs.toList()
          ..sort((a, b) => (b.data()['createdAt'] as Timestamp? ?? Timestamp.now())
              .compareTo(a.data()['createdAt'] as Timestamp? ?? Timestamp.now()));
        
        final data = sortedDocs.first.data();
        setState(() {
          _godNameController.text = (data['godName'] ?? '').toString();
          _peopleController.text = (data['peopleVisited'] ?? '').toString();
          _donationController.text = (data['amountDonated'] ?? '').toString();
          _billingController.text = (data['billingCurrent'] ?? '').toString();
          _workPart = (data['workPart'] ?? 'lingam') as String;
        });
      }
    } catch (e) {
      debugPrint("Restore Error: $e");
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

  // --- TAB 1: WORK ---
  Widget _activitiesTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('Daily Progress Update', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: darkMaroonText)),
        const SizedBox(height: 20),
        _buildInputField(_godNameController, 'Deity Name', Icons.temple_hindu),
        const SizedBox(height: 15),
        const Text('Part of work', style: TextStyle(color: darkMaroonText, fontWeight: FontWeight.bold)),
        ...['lingam', 'avudai', 'nandhi', 'shed'].map((part) => RadioListTile(
          value: part, groupValue: _workPart, title: Text(part.toUpperCase()),
          activeColor: primaryMaroon,
          onChanged: (v) => setState(() => _workPart = v.toString()),
        )),
        _buildInputField(_peopleController, 'Visitors', Icons.people, isNum: true),
        const SizedBox(height: 15),
        _buildInputField(_donationController, 'Donation Received', Icons.currency_rupee, isNum: true),
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Progress Saved')));
    } finally {
      setState(() => _loadingAdd = false);
    }
  }

  // --- TAB 2: FINANCE ---
  Widget _financeTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _firestore.collection('transactions').where('projectId', isEqualTo: _projectId).snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snap.data!.docs;
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, i) => Card(
            color: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: primaryGold.withOpacity(0.3))),
            child: ListTile(
              title: Text('₹${docs[i].data()['amount']}', style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(docs[i].data()['title'] ?? ''),
            ),
          ),
        );
      },
    );
  }

  // --- TAB 3: BILLS ---
  Widget _billsTab() {
    return Center(child: Text("Bills Tab Logic Here"));
  }

  // --- TAB 4: COMMUNICATION LOG (FIXED FIELD NAMES) ---
  Widget _feedbackTab() {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 10),
          child: Text('Communication Log', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: darkMaroonText)),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _firestore.collection('feedback')
                .where('projectId', isEqualTo: _projectId)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              
              // Local Sort to avoid Index Error
              List<DocumentSnapshot> docs = snapshot.data!.docs;
              docs.sort((a, b) {
                Timestamp t1 = (a.data() as Map)['createdAt'] ?? Timestamp.now();
                Timestamp t2 = (b.data() as Map)['createdAt'] ?? Timestamp.now();
                return t2.compareTo(t1); // Newest at bottom (because of reverse: true)
              });

              return ListView.builder(
                padding: const EdgeInsets.all(15),
                reverse: true,
                itemCount: docs.length,
                itemBuilder: (context, i) {
                  final data = docs[i].data() as Map<String, dynamic>;
                  // Admin uses 'role' == 'admin'. User is anything else.
                  bool isAdmin = data['role'] == 'admin';
                  
                  return Align(
                    alignment: isAdmin ? Alignment.centerLeft : Alignment.centerRight,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 5),
                      padding: const EdgeInsets.all(12),
                      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                      decoration: BoxDecoration(
                        color: isAdmin ? Colors.grey[300] : primaryMaroon,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        data['text'] ?? '', // SYNCED WITH ADMIN FIELD NAME 'text'
                        style: TextStyle(color: isAdmin ? Colors.black : Colors.white),
                      ),
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
      padding: const EdgeInsets.all(10),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _feedbackInputController,
              decoration: InputDecoration(
                hintText: 'Type message to admin...',
                filled: true, fillColor: backgroundCream,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
              ),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: primaryMaroon,
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white, size: 18), 
              onPressed: _sendFeedback
            ),
          )
        ],
      ),
    );
  }

  void _sendFeedback() async {
    final msgText = _feedbackInputController.text.trim();
    if (msgText.isEmpty) return;
    
    _feedbackInputController.clear();

    await _firestore.collection('feedback').add({
      'projectId': _projectId,
      'text': msgText, // MATCHING ADMIN FIELD NAME
      'role': 'user',
      'createdAt': FieldValue.serverTimestamp(),
      'time': DateTime.now().toString(), // MATCHING ADMIN LOGIC
    });
  }

  Widget _buildInputField(TextEditingController ctrl, String label, IconData icon, {bool isNum = false}) {
    return TextField(
      controller: ctrl,
      keyboardType: isNum ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label, prefixIcon: Icon(icon, color: primaryMaroon),
        filled: true, fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundCream,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(color: primaryMaroon),
              child: Row(
                children: [
                  IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
                  const SizedBox(width: 10),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Project Overview', style: GoogleFonts.poppins(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    Text(widget.project['place'] ?? '', style: GoogleFonts.poppins(color: primaryGold, fontSize: 13)),
                  ]),
                ],
              ),
            ),
            TabBar(
              controller: _tabController,
              labelColor: primaryMaroon, unselectedLabelColor: Colors.grey,
              indicatorColor: primaryGold,
              tabs: const [Tab(text: 'Work'), Tab(text: 'Finance'), Tab(text: 'Bills'), Tab(text: 'Chat')],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [_activitiesTab(), _financeTab(), _billsTab(), _feedbackTab()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}