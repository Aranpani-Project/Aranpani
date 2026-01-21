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

  // ===================== LOGIC: ADD WORK =====================

  Future<void> _showAddWorkDialog() async {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: backgroundCream,
        title: Text(
          'Add Work (To Do)',
          style: GoogleFonts.poppins(color: primaryMaroon),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Work name'),
              ),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(labelText: 'Description (optional)'),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
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

  // ===================== LOGIC: MONEY REQUEST =====================

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
                TextField(
                    controller: amountCtrl,
                    decoration: const InputDecoration(labelText: 'Amount'),
                    keyboardType: TextInputType.number),
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
                  qrUrl = await CloudinaryService.uploadImage(
                      imageFile: qrFile!, userId: _userId, projectId: _projectId);
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

  // ===================== LOGIC: BILLS =====================

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
          title: Text('Upload New Bill',
              style: GoogleFonts.poppins(color: primaryMaroon, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Bill For (Title)')),
                TextField(
                    controller: amountCtrl,
                    decoration: const InputDecoration(labelText: 'Total Amount'),
                    keyboardType: TextInputType.number),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: isUploading
                      ? null
                      : () async {
                          final imgs = await _picker.pickMultiImage();
                          if (imgs.isNotEmpty) setDialogState(() => selectedFiles = imgs);
                        },
                  icon: const Icon(Icons.image),
                  label: Text(selectedFiles.isEmpty
                      ? 'Select Bill Photos'
                      : '${selectedFiles.length} Images Selected'),
                ),
                if (isUploading)
                  const Padding(
                    padding: EdgeInsets.only(top: 20),
                    child: CircularProgressIndicator(color: primaryMaroon),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isUploading ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isUploading
                  ? null
                  : () async {
                      if (titleCtrl.text.isEmpty || amountCtrl.text.isEmpty || selectedFiles.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please fill all fields and select images')));
                        return;
                      }
                      setDialogState(() => isUploading = true);
                      try {
                        List<String> urls = [];
                        for (var file in selectedFiles) {
                          String? url = await CloudinaryService.uploadImage(
                              imageFile: file, userId: _userId, projectId: _projectId);
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
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
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

  // ===================== UI COMPONENTS =====================

  Widget _buildTodoList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('project_tasks')
          .where('projectId', isEqualTo: _projectId)
          .where('status', isEqualTo: 'todo')
          .orderBy('createdAt', descending: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) return Center(child: Text("No To Do works", style: GoogleFonts.poppins(color: Colors.grey)));

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                title: Text(data['taskName'] ?? 'Unknown Work', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(data['description'] ?? 'Not started yet'),
                trailing: ElevatedButton(
                  onPressed: () async {
                    await _firestore.collection('project_tasks').doc(doc.id).update({
                      'status': 'ongoing',
                      'startedAt': FieldValue.serverTimestamp(),
                    });
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                  child: const Text('Start'),
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
        if (docs.isEmpty) return Center(child: Text("No ongoing works", style: GoogleFonts.poppins(color: Colors.grey)));

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final docId = docs[index].id;
            final Timestamp? startTs = data['startedAt'];
            return OngoingTaskCard(
              taskId: docId,
              taskName: data['taskName'] ?? 'Unknown Work',
              dateDisplay: startTs != null ? "Started: ${_formatTimestamp(startTs)}" : "Date not captured",
              userId: _userId,
              projectId: _projectId,
              currentStatus: data['status'] ?? 'ongoing',
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
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) return Center(child: Text("No completed works", style: GoogleFonts.poppins(color: Colors.grey)));

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final List<dynamic> endImages = data['endImages'] ?? [];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.green),
                        const SizedBox(width: 10),
                        Expanded(
                            child: Text(data['taskName'] ?? '',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                        const Icon(Icons.verified, color: Colors.blue),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text("Start: ${_formatTimestamp(data['startedAt'])} | End: ${_formatTimestamp(data['completedAt'])}",
                        style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    if (endImages.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 70,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: endImages.length,
                          itemBuilder: (context, imgIndex) => Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: GestureDetector(
                              onTap: () => _showFullScreenImage(endImages[imgIndex]),
                              child: ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: Image.network(endImages[imgIndex], width: 70, height: 70, fit: BoxFit.cover)),
                            ),
                          ),
                        ),
                      )
                    ]
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ===================== AUTOMATED FINANCES TAB =====================

  Widget _transactionsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('transactions').where('projectId', isEqualTo: _projectId).snapshots(),
      builder: (context, snapshot) {
        double paidAmount = 0;
        if (snapshot.hasData) {
          for (var doc in snapshot.data!.docs) {
            final d = doc.data() as Map<String, dynamic>;
            if (d['status'] == 'paid') {
              paidAmount += (d['amount'] ?? 0).toDouble();
            }
          }
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildFinanceStat("Paid", "₹$paidAmount", Colors.green),
                    _buildFinanceStat("Pending", "Calculating...", Colors.orange),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: ElevatedButton.icon(
                onPressed: _showRequestAmountDialog,
                icon: const Icon(Icons.add_card),
                label: const Text('Request Amount from Admin'),
                style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
              ),
            ),
            const Divider(height: 32),
            Expanded(
              child: snapshot.hasData && snapshot.data!.docs.isNotEmpty
                  ? ListView.builder(
                      itemCount: snapshot.data!.docs.length,
                      itemBuilder: (context, index) {
                        final trans = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                        return ListTile(
                          title: Text(trans['title'] ?? 'Request'),
                          subtitle: Text(_formatTimestamp(trans['date'])),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text("₹${trans['amount']}", style: const TextStyle(fontWeight: FontWeight.bold)),
                              Text(trans['status'].toString().toUpperCase(),
                                  style: TextStyle(
                                      fontSize: 10, color: trans['status'] == 'paid' ? Colors.green : Colors.orange)),
                            ],
                          ),
                        );
                      },
                    )
                  : const Center(child: Text("No transaction history")),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton.icon(
                onPressed: _isCompletionRequesting ? null : _requestProjectCompletion,
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 50)),
                icon: const Icon(Icons.flag),
                label: Text(_isCompletionRequesting ? 'Requesting...' : 'Request Project Completion'),
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
        Text(label, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
        Text(value, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  // ===================== PROJECT COMPLETION LOGIC =====================

  Future<void> _requestProjectCompletion() async {
    setState(() => _isCompletionRequesting = true);
    try {
      final tasks = await _firestore.collection('project_tasks').where('projectId', isEqualTo: _projectId).get();
      final ongoing = tasks.docs.where((d) => d['status'] != 'completed').length;

      if (tasks.docs.isEmpty || ongoing > 0) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('All tasks must be completed first.')));
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
        'message': 'Project completion requested by user.',
        'senderRole': 'user',
        'createdAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request Sent!')));
    } finally {
      setState(() => _isCompletionRequesting = false);
    }
  }

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
                  String total = widget.project['totalAmount']?.toString() ?? "0";
                  if (snapshot.hasData && snapshot.data!.exists) {
                    final data = snapshot.data!.data() as Map<String, dynamic>;
                    total = data['totalAmount']?.toString() ?? total;
                  }
                  return Container(
                    padding: const EdgeInsets.all(20),
                    color: primaryMaroon,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.project['projectName'] ?? 'Project',
                            style: GoogleFonts.poppins(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),
                        Text("Total Budget: ₹$total", style: const TextStyle(color: Colors.white70, fontSize: 16)),
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
                  tabs: const [
                    Tab(text: 'Activities'),
                    Tab(text: 'Finances'),
                    Tab(text: 'Bills'),
                    Tab(text: 'Chat'),
                  ],
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

  Widget _activitiesTab() {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
                onPressed: _showAddWorkDialog, icon: const Icon(Icons.add), label: const Text("Add New Task")),
          ),
          const TabBar(
            tabs: [Tab(text: "To Do"), Tab(text: "Ongoing"), Tab(text: "Done")],
            labelColor: primaryMaroon,
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

  Widget _billsTab() {
    return Column(
      children: [
        const SizedBox(height: 16),
        ElevatedButton.icon(onPressed: _showUploadBillDialog, icon: const Icon(Icons.upload), label: const Text("Upload Bill")),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _billsRef.where('projectId', isEqualTo: _projectId).snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              return ListView.builder(
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, i) {
                  final bill = snapshot.data!.docs[i].data() as Map<String, dynamic>;
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: ListTile(
                      title: Text(bill['title'] ?? 'Bill'),
                      subtitle: Text("₹${bill['amount']}"),
                      trailing: const Icon(Icons.receipt_long),
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
}

// Helper classes for UI consistency
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

class OngoingTaskCard extends StatelessWidget {
  final String taskId, taskName, dateDisplay, userId, projectId, currentStatus;
  const OngoingTaskCard(
      {super.key,
      required this.taskId,
      required this.taskName,
      required this.dateDisplay,
      required this.userId,
      required this.projectId,
      required this.currentStatus});

  @override
  Widget build(BuildContext context) {
    bool isPending = currentStatus == 'pending_approval';
    return Card(
      child: ListTile(
        title: Text(taskName),
        subtitle: Text(dateDisplay),
        trailing: isPending
            ? const Text("Pending Admin...", style: TextStyle(color: Colors.orange))
            : ElevatedButton(
                onPressed: () => _markComplete(context),
                child: const Text("Finish"),
              ),
      ),
    );
  }

  Future<void> _markComplete(BuildContext context) async {
    // Logic to upload final images and update status to completed
    await FirebaseFirestore.instance.collection('project_tasks').doc(taskId).update({
      'status': 'completed',
      'completedAt': FieldValue.serverTimestamp(),
    });
  }
}