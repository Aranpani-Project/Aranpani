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

  // Collection References
  CollectionReference<Map<String, dynamic>> get _activitiesRef => _firestore.collection('activities');
  CollectionReference<Map<String, dynamic>> get _billsRef => _firestore.collection('bills');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _initializeData();
  }

  // Restore data every time the user comes in
  Future<void> _initializeData() async {
    await _loadLatestActivity();
    await _loadBills();
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

  // --- RESTORE DATA LOGIC ---
  Future<void> _loadLatestActivity() async {
    try {
      final snap = await _activitiesRef
          .where('projectId', isEqualTo: _projectId)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (snap.docs.isNotEmpty) {
        final data = snap.docs.first.data();
        setState(() {
          _godNameController.text = (data['godName'] ?? '').toString();
          _peopleController.text = (data['peopleVisited'] ?? '').toString();
          _donationController.text = (data['amountDonated'] ?? '').toString();
          _billingController.text = (data['billingCurrent'] ?? '').toString();
          _workPart = (data['workPart'] ?? 'lingam') as String;
        });
      }
    } catch (e) {
      debugPrint("Error loading activity: $e");
    }
  }

  Future<void> _loadBills() async {
    try {
      final snap = await _billsRef
          .where('projectId', isEqualTo: _projectId)
          .orderBy('createdAt', descending: true)
          .get();
      
      setState(() {
        _localBills = snap.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'title': data['title'],
            'amount': data['amount'],
            'imageUrls': data['imageUrls'],
            'date': (data['createdAt'] as Timestamp).toDate(),
          };
        }).toList();
      });
    } catch (e) {
      debugPrint("Error loading bills: $e");
    }
  }

  // --- SUBMIT WORK ---
  Future<void> _submitActivityForm() async {
    if (_godNameController.text.trim().isEmpty) return;

    setState(() => _loadingAdd = true);
    try {
      await _activitiesRef.add({
        'userId': _userId,
        'projectId': _projectId,
        'godName': _godNameController.text.trim(),
        'workPart': _workPart,
        'peopleVisited': _peopleController.text.trim(),
        'amountDonated': _donationController.text.trim(),
        'billingCurrent': _billingController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Work details updated and saved')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $e')));
    } finally {
      if (mounted) setState(() => _loadingAdd = false);
    }
  }

  // --- UI COMPONENTS ---

  Widget _activitiesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Work Details', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF6A1F1A))),
          const SizedBox(height: 15),
          _buildField(_godNameController, 'Name of God'),
          const SizedBox(height: 15),
          Text('Part of work', style: GoogleFonts.poppins(color: Colors.brown)),
          ...['lingam', 'avudai', 'nandhi', 'shed'].map((part) => RadioListTile(
            value: part, groupValue: _workPart, title: Text(part.toUpperCase()),
            activeColor: const Color(0xFF8E3D2C),
            onChanged: (v) => setState(() => _workPart = v.toString()),
          )),
          _buildField(_peopleController, 'People Visited', isNum: true),
          const SizedBox(height: 12),
          _buildField(_donationController, 'Donation Amount', isNum: true),
          const SizedBox(height: 12),
          _buildField(_billingController, 'Current Billing', isNum: true),
          const SizedBox(height: 25),
          SizedBox(
            width: double.infinity, height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8E3D2C), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: _loadingAdd ? null : _submitActivityForm,
              child: _loadingAdd ? const CircularProgressIndicator(color: Colors.white) : Text('SAVE WORK', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildField(TextEditingController controller, String label, {bool isNum = false}) {
    return TextField(
      controller: controller,
      keyboardType: isNum ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label, filled: true, fillColor: const Color(0xFFFFF2D5),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFB6862C))),
      ),
    );
  }

  Widget _feedbackTab() {
    return Column(
      children: [
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _firestore.collection('feedback').where('projectId', isEqualTo: _projectId).orderBy('createdAt', descending: true).snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final docs = snapshot.data!.docs;
              return ListView.builder(
                padding: const EdgeInsets.all(10),
                reverse: true,
                itemCount: docs.length,
                itemBuilder: (context, i) {
                  final data = docs[i].data() as Map<String, dynamic>;
                  bool isMe = data['role'] == 'user';
                  return Align(
                    alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 5),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isMe ? const Color(0xFF8E3D2C) : Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        border: isMe ? null : Border.all(color: const Color(0xFFB6862C)),
                      ),
                      child: Text(data['message'] ?? '', style: GoogleFonts.poppins(color: isMe ? Colors.white : Colors.black)),
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
      padding: const EdgeInsets.all(8),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _feedbackInputController,
              decoration: InputDecoration(hintText: 'Message Admin...', border: OutlineInputBorder(borderRadius: BorderRadius.circular(30))),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send, color: Color(0xFF8E3D2C)),
            onPressed: () async {
              if (_feedbackInputController.text.trim().isEmpty) return;
              await _firestore.collection('feedback').add({
                'projectId': _projectId,
                'message': _feedbackInputController.text.trim(),
                'role': 'user',
                'createdAt': FieldValue.serverTimestamp(),
              });
              _feedbackInputController.clear();
            },
          )
        ],
      ),
    );
  }

  // --- PRE-EXISTING BILLS & TRANSACTIONS ---
  Widget _transactionsTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _firestore.collection('transactions').where('projectId', isEqualTo: _projectId).orderBy('date', descending: true).snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snap.data!.docs;
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final d = docs[i].data();
            return Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: Color(0xFFB6862C))),
              child: ListTile(title: Text(d['title'] ?? '', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)), subtitle: Text('₹${d['amount']}')),
            );
          },
        );
      },
    );
  }

  Widget _billsTab() {
    return Column(
      children: [
        const SizedBox(height: 10),
        ElevatedButton.icon(
          onPressed: _showUploadBillDialog,
          icon: const Icon(Icons.upload, color: Colors.white),
          label: const Text("UPLOAD BILL", style: TextStyle(color: Colors.white)),
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8E3D2C)),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _localBills.length,
            itemBuilder: (context, i) {
              final bill = _localBills[i];
              return Card(
                child: ListTile(
                  title: Text(bill['title'], style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("₹${bill['amount']} - ${bill['date'].day}/${bill['date'].month}"),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // --- BILL DIALOG & TAB BAR DELEGATE ---
  // (Note: Kept your original logic for _showUploadBillDialog to ensure functionality remains same)
  Future<void> _showUploadBillDialog() async {
    final TextEditingController titleCtrl = TextEditingController();
    final TextEditingController amountCtrl = TextEditingController();
    List<XFile> selectedImages = [];

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Upload Bill'),
        content: StatefulBuilder(builder: (context, setStateSB) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Bill Name')),
            TextField(controller: amountCtrl, decoration: const InputDecoration(labelText: 'Amount'), keyboardType: TextInputType.number),
            ElevatedButton(onPressed: () async {
              final imgs = await _picker.pickMultiImage();
              if (imgs != null) setStateSB(() => selectedImages = imgs);
            }, child: const Text('Select Images')),
          ],
        )),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(onPressed: () async {
            if (titleCtrl.text.isEmpty || amountCtrl.text.isEmpty) return;
            Navigator.pop(context);
            // Original Cloudinary logic...
            final List<String> urls = [];
            for (var x in selectedImages) {
              final url = await CloudinaryService.uploadImage(imageFile: File(x.path), userId: _userId, projectId: _projectId);
              urls.add(url);
            }
            final now = DateTime.now();
            final doc = await _billsRef.add({
              'userId': _userId, 'projectId': _projectId, 'title': titleCtrl.text, 'amount': double.parse(amountCtrl.text), 'imageUrls': urls, 'createdAt': now,
            });
            setState(() {
              _localBills.insert(0, {'id': doc.id, 'title': titleCtrl.text, 'amount': amountCtrl.text, 'imageUrls': urls, 'date': now});
            });
          }, child: const Text('Upload'))
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF6A1F1A), Color(0xFFB6862C)])),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
                    Text('Project Overview', style: GoogleFonts.poppins(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
                    Text(widget.project['place'] ?? '', style: GoogleFonts.poppins(color: Colors.white70)),
                  ],
                ),
              ),
            ),
            SliverPersistentHeader(pinned: true, delegate: _TabBarDelegate(TabBar(
              controller: _tabController, labelColor: const Color(0xFF8E3D2C), unselectedLabelColor: Colors.grey,
              tabs: const [Tab(text: 'Work'), Tab(text: 'Cash'), Tab(text: 'Bills'), Tab(text: 'Chat')],
            ))),
            SliverFillRemaining(child: TabBarView(controller: _tabController, children: [_activitiesTab(), _transactionsTab(), _billsTab(), _feedbackTab()])),
          ],
        ),
      ),
    );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  _TabBarDelegate(this.tabBar);
  @override double get minExtent => tabBar.preferredSize.height;
  @override double get maxExtent => tabBar.preferredSize.height;
  @override Widget build(context, offset, overlaps) => Container(color: Colors.white, child: tabBar);
  @override bool shouldRebuild(old) => false;
}