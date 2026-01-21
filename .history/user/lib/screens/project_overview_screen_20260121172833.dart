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

  // ===================== FINANCE LOGIC & HISTORY =====================

  Widget _transactionsTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _firestore
          .collection('transactions')
          .where('projectId', isEqualTo: _projectId)
          .orderBy('date', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: primaryMaroon));
        }

        double paidAmount = 0.0;
        double pendingAmount = 0.0;

        // Automation: Calculate real-time totals
        if (snapshot.hasData) {
          for (var doc in snapshot.data!.docs) {
            final data = doc.data();
            double amt = (data['amount'] ?? 0.0).toDouble();
            String status = data['status'] ?? 'pending';

            if (status == 'paid' || status == 'approved') {
              paidAmount += amt;
            } else if (status == 'pending') {
              pendingAmount += amt;
            }
          }
        }

        return Column(
          children: [
            // Paid vs Pending Summary
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildFinanceStat("Paid", "₹$paidAmount", Colors.green),
                    Container(width: 1, height: 40, color: Colors.grey[200]),
                    _buildFinanceStat("Pending", "₹$pendingAmount", Colors.orange),
                  ],
                ),
              ),
            ),

            // Main Actions
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                children: [
                  ElevatedButton.icon(
                    onPressed: _showRequestAmountDialog,
                    icon: const Icon(Icons.add_card),
                    label: const Text('Request Amount from Admin'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryMaroon,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 12),
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
                    label: Text(_isCompletionRequesting ? 'Sending Request...' : 'Request Project Completion'),
                  ),
                ],
              ),
            ),

            const Padding(
              padding: EdgeInsets.only(left: 18, top: 20, bottom: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text("Transaction History", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: primaryMaroon)),
              ),
            ),

            // History List
            Expanded(
              child: snapshot.data!.docs.isEmpty
                  ? Center(child: Text("No transaction requests found", style: GoogleFonts.poppins(color: Colors.grey)))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: snapshot.data!.docs.length,
                      itemBuilder: (context, index) {
                        final data = snapshot.data!.docs[index].data();
                        final status = data['status'] ?? 'pending';
                        final amount = (data['amount'] ?? 0.0).toDouble();
                        final title = data['title'] ?? 'Request';
                        final date = data['date'] as Timestamp?;

                        Color statusColor = Colors.orange;
                        if (status == 'paid' || status == 'approved') statusColor = Colors.green;
                        if (status == 'rejected') statusColor = Colors.red;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: statusColor.withOpacity(0.1),
                              child: Icon(Icons.currency_rupee, color: statusColor, size: 20),
                            ),
                            title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text("Date: ${_formatTimestamp(date)}"),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text("₹$amount", style: const TextStyle(fontWeight: FontWeight.bold, color: primaryMaroon)),
                                Text(status.toUpperCase(), style: TextStyle(fontSize: 9, color: statusColor, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            onTap: () => _showTransactionDetail(data),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFinanceStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600])),
        Text(value, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  // ===================== ADD WORK DIALOG =====================

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
            TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Description (Optional)'), maxLines: 2),
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

  // ===================== MONEY REQUEST DIALOG =====================

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
                TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Work/Item Name')),
                TextField(controller: amountCtrl, decoration: const InputDecoration(labelText: 'Amount (₹)'), keyboardType: TextInputType.number),
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
                if (qrFile != null) const Text('QR selected', style: TextStyle(color: Colors.green, fontSize: 12)),
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
                  'amount': double.tryParse(amountCtrl.text) ?? 0.0,
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

  void _showTransactionDetail(Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context,
      backgroundColor: backgroundCream,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(data['title'] ?? 'Request Detail', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: primaryMaroon)),
            const Divider(),
            Text("Amount: ₹${data['amount']}", style: const TextStyle(fontSize: 16)),
            Text("Status: ${data['status'].toString().toUpperCase()}", style: const TextStyle(fontSize: 16)),
            if (data['upiId'] != null && data['upiId'].isNotEmpty) Text("UPI ID: ${data['upiId']}", style: const TextStyle(fontSize: 16)),
            if (data['qrUrl'] != null) ...[
              const SizedBox(height: 15),
              const Text("QR Code:", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => _showFullScreenImage(data['qrUrl']),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(data['qrUrl'], height: 120, width: 120, fit: BoxFit.cover),
                ),
              ),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ===================== ACTIVITIES TAB =====================

  Widget _activitiesTab() {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: ElevatedButton.icon(
              onPressed: _showAddWorkDialog,
              icon: const Icon(Icons.add),
              label: const Text("Add New Task"),
              style: ElevatedButton.styleFrom(backgroundColor: primaryMaroon, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 45)),
            ),
          ),
          const TabBar(
            tabs: [Tab(text: "To Do"), Tab(text: "Ongoing"), Tab(text: "Done")],
            labelColor: primaryMaroon,
            indicatorColor: primaryMaroon,
          ),
          Expanded(
            child: TabBarView(
              children: [_buildTodoList(), _buildOngoingList(), _buildCompletedList()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodoList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('project_tasks')
          .where('projectId', isEqualTo: _projectId)
          .where('status', isEqualTo: 'todo')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) return const Center(child: Text("No tasks in To-Do"));
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            return Card(
              child: ListTile(
                title: Text(data['taskName'] ?? ''),
                subtitle: Text(data['description'] ?? ''),
                trailing: ElevatedButton(
                  onPressed: () => _firestore.collection('project_tasks').doc(doc.id).update({
                    'status': 'ongoing',
                    'startedAt': FieldValue.serverTimestamp(),
                  }),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                  child: const Text("Start"),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildOngoingList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('project_tasks')
          .where('projectId', isEqualTo: _projectId)
          .where('status', whereIn: ['ongoing', 'pending_approval']).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) return const Center(child: Text("No ongoing tasks"));
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            return OngoingTaskCard(
              taskId: docs[index].id,
              taskName: data['taskName'] ?? '',
              dateDisplay: _formatTimestamp(data['startedAt']),
              userId: _userId,
              projectId: _projectId,
              currentStatus: data['status'],
            );
          },
        );
      },
    );
  }

  Widget _buildCompletedList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('project_tasks')
          .where('projectId', isEqualTo: _projectId)
          .where('status', isEqualTo: 'completed')
          .orderBy('completedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final data = snapshot.data!.docs[index].data() as Map<String, dynamic>;
            return Card(
              child: ListTile(
                leading: const Icon(Icons.verified, color: Colors.blue),
                title: Text(data['taskName'] ?? ''),
                subtitle: Text("Done: ${_formatTimestamp(data['completedAt'])}"),
                onTap: () {
                  if ((data['endImages'] as List).isNotEmpty) {
                    _showFullScreenImage(data['endImages'][0]);
                  }
                },
              ),
            );
          },
        );
      },
    );
  }

  // ===================== BILLS TAB =====================

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
                TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Title (e.g. Cement)')),
                TextField(controller: amountCtrl, decoration: const InputDecoration(labelText: 'Total Amount'), keyboardType: TextInputType.number),
                const SizedBox(height: 15),
                ElevatedButton.icon(
                  onPressed: () async {
                    final imgs = await _picker.pickMultiImage();
                    if (imgs.isNotEmpty) setDialogState(() => selectedFiles = imgs);
                  },
                  icon: const Icon(Icons.image),
                  label: Text(selectedFiles.isEmpty ? 'Select Bill Photos' : '${selectedFiles.length} Images Selected'),
                ),
                if (isUploading) const LinearProgressIndicator(color: primaryMaroon),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: isUploading ? null : () async {
                if (titleCtrl.text.isEmpty || amountCtrl.text.isEmpty || selectedFiles.isEmpty) return;
                setDialogState(() => isUploading = true);
                List<String> urls = [];
                for (var f in selectedFiles) {
                  String? u = await CloudinaryService.uploadImage(imageFile: f, userId: _userId, projectId: _projectId);
                  if (u != null) urls.add(u);
                }
                await _billsRef.add({
                  'projectId': _projectId,
                  'userId': _userId,
                  'title': titleCtrl.text,
                  'amount': double.tryParse(amountCtrl.text) ?? 0.0,
                  'imageUrls': urls,
                  'createdAt': FieldValue.serverTimestamp(),
                });
                if (mounted) Navigator.pop(context);
              },
              child: const Text('Upload'),
            )
          ],
        ),
      ),
    );
  }

  Widget _billsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: ElevatedButton.icon(
            onPressed: _showUploadBillDialog,
            icon: const Icon(Icons.receipt),
            label: const Text("Upload New Bill"),
            style: ElevatedButton.styleFrom(backgroundColor: primaryMaroon, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 45)),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _billsRef.where('projectId', isEqualTo: _projectId).orderBy('createdAt', descending: true).snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final docs = snapshot.data!.docs;
              if (docs.isEmpty) return const Center(child: Text("No bills uploaded"));
              return ListView.builder(
                itemCount: docs.length,
                itemBuilder: (context, i) {
                  final bill = docs[i].data() as Map<String, dynamic>;
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: ListTile(
                      title: Text(bill['title'] ?? 'Bill'),
                      subtitle: Text("Amount: ₹${bill['amount']}"),
                      trailing: const Icon(Icons.image_search, color: primaryMaroon),
                      onTap: () => _showFullScreenImage(bill['imageUrls'][0]),
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

  // ===================== PROJECT COMPLETION LOGIC =====================

  Future<void> _requestProjectCompletion() async {
    setState(() => _isCompletionRequesting = true);
    try {
      final tasks = await _firestore.collection('project_tasks').where('projectId', isEqualTo: _projectId).get();
      final unfinished = tasks.docs.where((d) => d['status'] != 'completed').length;

      if (tasks.docs.isEmpty || unfinished > 0) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('All tasks must be completed before requesting project completion.')));
        return;
      }

      await _firestore.collection('project_completion_requests').add({
        'projectId': _projectId,
        'userId': _userId,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      await _firestore.collection('project_messages').add({
        'projectId': _projectId,
        'message': 'User has requested to mark the entire project as completed.',
        'senderRole': 'user',
        'createdAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request Sent Successfully!')));
    } finally {
      if (mounted) setState(() => _isCompletionRequesting = false);
    }
  }

  // ===================== MAIN BUILD =====================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundCream,
      body: SafeArea(
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverToBoxAdapter(
              child: StreamBuilder<DocumentSnapshot>(
                stream: _firestore.collection('projects').doc(_projectId).snapshots(),
                builder: (context, snapshot) {
                  // Live fetch budget and project info
                  String totalBudget = "0";
                  String name = widget.project['projectName'] ?? 'Project';
                  if (snapshot.hasData && snapshot.data!.exists) {
                    final data = snapshot.data!.data() as Map<String, dynamic>;
                    totalBudget = (data['totalAmount'] ?? "0").toString();
                    name = data['projectName'] ?? name;
                  }
                  return Container(
                    padding: const EdgeInsets.all(20),
                    color: primaryMaroon,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back, color: Colors.white)),
                            Expanded(child: Text(name, style: GoogleFonts.poppins(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 48.0),
                          child: Text("Total Approved Budget: ₹$totalBudget", style: const TextStyle(color: Colors.white70, fontSize: 14)),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _TabBarDelegate(
                TabBar(
                  controller: _tabController,
                  labelColor: primaryMaroon,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: primaryMaroon,
                  tabs: const [Tab(text: 'Activities'), Tab(text: 'Finances'), Tab(text: 'Bills'), Tab(text: 'Chat')],
                ),
              ),
            ),
          ],
          body: TabBarView(
            controller: _tabController,
            children: [
              _activitiesTab(),
              _transactionsTab(),
              _billsTab(),
              ProjectChatSection(projectId: _projectId, currentRole: 'user'),
            ],
          ),
        ),
      ),
    );
  }
}

// Helper for Sliver Header
class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  _TabBarDelegate(this.tabBar);
  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;
  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(color: Colors.white, child: tabBar);
  }
  @override
  bool shouldRebuild(_TabBarDelegate oldDelegate) => false;
}

// Task Card with Approval Logic
class OngoingTaskCard extends StatefulWidget {
  final String taskId, taskName, dateDisplay, userId, projectId, currentStatus;
  const OngoingTaskCard({super.key, required this.taskId, required this.taskName, required this.dateDisplay, required this.userId, required this.projectId, required this.currentStatus});

  @override
  State<OngoingTaskCard> createState() => _OngoingTaskCardState();
}

class _OngoingTaskCardState extends State<OngoingTaskCard> {
  bool _isUploading = false;
  final ImagePicker _picker = ImagePicker();

  @override
  Widget build(BuildContext context) {
    bool isPending = widget.currentStatus == 'pending_approval';
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        title: Text(widget.taskName, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text("Started: ${widget.dateDisplay}"),
        trailing: isPending
            ? const Text("Pending Admin", style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold))
            : ElevatedButton(
                onPressed: _isUploading ? null : _completeTask,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                child: _isUploading ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text("Finish"),
              ),
      ),
    );
  }

  Future<void> _completeTask() async {
    final imgs = await _picker.pickMultiImage();
    if (imgs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select at least one photo of the work")));
      return;
    }

    setState(() => _isUploading = true);
    try {
      List<String> urls = [];
      for (var f in imgs) {
        String? u = await CloudinaryService.uploadImage(imageFile: f, userId: widget.userId, projectId: widget.projectId);
        if (u != null) urls.add(u);
      }
      await FirebaseFirestore.instance.collection('project_tasks').doc(widget.taskId).update({
        'status': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
        'endImages': urls,
      });
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }
}