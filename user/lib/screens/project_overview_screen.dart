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

  // Helper to format date as YYYY-MM-DD
  String _formatDate(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
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
                TextField(controller: amountCtrl, decoration: const InputDecoration(labelText: 'Amount'), keyboardType: TextInputType.number),
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

  Future<DateTime?> _pickDate(BuildContext context) async {
    return await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
    );
  }

  Future<void> _showAddWorkDialog() async {
    final TextEditingController nameCtrl = TextEditingController();
    DateTime? fromDate;
    DateTime? toDate;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: backgroundCream,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              title: Text('Add New Work', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: primaryMaroon)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      labelText: 'Work Name',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 15),
                  ListTile(
                    tileColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    title: Text(fromDate == null ? 'From Date' : '${fromDate!.day}/${fromDate!.month}/${fromDate!.year}'),
                    trailing: const Icon(Icons.calendar_today, color: primaryMaroon),
                    onTap: () async {
                      final picked = await _pickDate(context);
                      if (picked != null) setStateDialog(() => fromDate = picked);
                    },
                  ),
                  const SizedBox(height: 10),
                  ListTile(
                    tileColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    title: Text(toDate == null ? 'To Date' : '${toDate!.day}/${toDate!.month}/${toDate!.year}'),
                    trailing: const Icon(Icons.event, color: primaryMaroon),
                    onTap: () async {
                      final picked = await _pickDate(context);
                      if (picked != null) setStateDialog(() => toDate = picked);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: primaryMaroon),
                  onPressed: () async {
                    if (nameCtrl.text.isEmpty || fromDate == null || toDate == null) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all fields')));
                      return;
                    }
                    await _firestore.collection('project_tasks').add({
                      'projectId': _projectId,
                      'taskName': nameCtrl.text,
                      'fromDate': fromDate,
                      'toDate': toDate,
                      'status': 'todo',
                      'createdAt': FieldValue.serverTimestamp(),
                    });
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Work Added Successfully!')));
                  },
                  child: const Text('Add Work', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
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
                padding: const EdgeInsets.all(12),
                itemCount: docs.length,
                itemBuilder: (context, i) {
                  final bill = docs[i].data();
                  final imageUrls = (bill['imageUrls'] as List? ?? []);
                  return Card(
                    child: ExpansionTile(
                      title: Text(bill['title'] ?? 'Bill', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('Amount: ₹${bill['amount'] ?? '0'}'),
                      children: [
                        if (imageUrls.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: imageUrls.map((url) => GestureDetector(
                                onTap: () => _showFullScreenImage(url.toString()),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(url.toString(), width: 80, height: 80, fit: BoxFit.cover),
                                ),
                              )).toList(),
                            ),
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

  Future<void> _showUploadBillDialog() async {}

  Widget _activitiesTab() {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Container(
            color: Colors.white,
            child: const TabBar(
              labelColor: primaryMaroon,
              unselectedLabelColor: Colors.grey,
              indicatorColor: primaryMaroon,
              tabs: [
                Tab(text: "To Do"),
                Tab(text: "Ongoing"),
                Tab(text: "Completed"),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildTodoList(),    
                _buildOngoingList(),
                _buildCompletedList(), 
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodoList() {
    return Stack(
      children: [
        StreamBuilder<QuerySnapshot>(
          stream: _firestore
              .collection('project_tasks')
              .where('projectId', isEqualTo: _projectId)
              .where('status', isEqualTo: 'todo')
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final docs = snapshot.data!.docs;

            if (docs.isEmpty) {
              return Center(child: Text("No works to be done", style: GoogleFonts.poppins(color: Colors.grey)));
            }

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80), 
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final data = docs[index].data() as Map<String, dynamic>;
                final docId = docs[index].id;
                
                DateTime from = DateTime.now();
                if (data['fromDate'] != null) from = (data['fromDate'] as Timestamp).toDate();
                DateTime to = DateTime.now();
                if (data['toDate'] != null) to = (data['toDate'] as Timestamp).toDate();

                return TodoTaskCard(
                  taskId: docId,
                  taskName: data['taskName'] ?? 'Unknown Work',
                  fromDate: _formatDate(from),
                  toDate: _formatDate(to),
                  userId: _userId,
                  projectId: _projectId,
                );
              },
            );
          },
        ),

        Positioned(
          bottom: 20,
          right: 20,
          child: FloatingActionButton.extended(
            backgroundColor: primaryMaroon,
            onPressed: _showAddWorkDialog,
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text("Add Work", style: TextStyle(color: Colors.white)),
          ),
        ),
      ],
    );
  }

  // --- 2. Ongoing List ---
  Widget _buildOngoingList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('project_tasks')
          .where('projectId', isEqualTo: _projectId)
          .where('status', whereIn: ['ongoing', 'pending_approval']) 
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data!.docs;

        if (docs.isEmpty) {
          return Center(child: Text("No ongoing works", style: GoogleFonts.poppins(color: Colors.grey)));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final docId = docs[index].id;
            final status = data['status'] ?? 'ongoing';
            
            DateTime from = DateTime.now();
            if (data['fromDate'] != null) from = (data['fromDate'] as Timestamp).toDate();
            DateTime to = DateTime.now();
            if (data['toDate'] != null) to = (data['toDate'] as Timestamp).toDate();

            return OngoingTaskCard(
              taskId: docId,
              taskName: data['taskName'] ?? 'Unknown Work',
              fromDate: _formatDate(from),
              toDate: _formatDate(to),
              userId: _userId,
              projectId: _projectId,
              currentStatus: status, 
            );
          },
        );
      },
    );
  }

  // --- 3. Completed List (FIX: Deleted Icon Removed) ---
  Widget _buildCompletedList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('project_tasks')
          .where('projectId', isEqualTo: _projectId)
          .where('status', isEqualTo: 'completed')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data!.docs;

        if (docs.isEmpty) {
          return Center(child: Text("No completed works", style: GoogleFonts.poppins(color: Colors.grey)));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: const Icon(Icons.check_circle, color: Colors.green),
                title: Text(
                  data['taskName'] ?? '', 
                  style: const TextStyle(fontWeight: FontWeight.bold) 
                ),
                subtitle: const Text("Work Completed"),
                trailing: const Icon(Icons.verified, color: Colors.blue), // Replaced delete with verified icon
              ),
            );
          },
        );
      },
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

  Widget _feedbackTab() => ProjectChatSection(projectId: _projectId, currentRole: 'user');

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
      backgroundColor: backgroundCream,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                color: primaryMaroon,
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Project Overview',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
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

// =========================================================
// 1. TODO TASK CARD
// =========================================================
class TodoTaskCard extends StatefulWidget {
  final String taskId;
  final String taskName;
  final String fromDate;
  final String toDate;
  final String userId;
  final String projectId;

  const TodoTaskCard({
    super.key,
    required this.taskId,
    required this.taskName,
    required this.fromDate,
    required this.toDate,
    required this.userId,
    required this.projectId,
  });

  @override
  State<TodoTaskCard> createState() => _TodoTaskCardState();
}

class _TodoTaskCardState extends State<TodoTaskCard> {
  final ImagePicker _picker = ImagePicker();
  List<XFile> _selectedImages = [];
  bool _isUploading = false;

  Future<void> _pickImages() async {
    final List<XFile> images = await _picker.pickMultiImage(limit: 5); 
    if (images.isNotEmpty) {
      if (images.length > 5) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Maximum 5 images allowed")));
        setState(() => _selectedImages = images.sublist(0, 5));
      } else {
        setState(() => _selectedImages = images);
      }
    }
  }

  Future<void> _deleteTask() async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Work"),
        content: const Text("Are you sure you want to delete this work?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Delete", style: TextStyle(color: Colors.red))),
        ],
      ),
    ) ?? false;

    if (confirm) {
      await FirebaseFirestore.instance.collection('project_tasks').doc(widget.taskId).delete();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Work deleted")));
    }
  }

  Future<void> _startTask() async {
    if (_selectedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please upload progress photos first")));
      return;
    }
    setState(() => _isUploading = true);
    try {
      List<String> uploadedUrls = [];
      for (var image in _selectedImages) {
        String? url = await CloudinaryService.uploadImage(imageFile: image, userId: widget.userId, projectId: widget.projectId);
        if (url != null) uploadedUrls.add(url);
      }
      await FirebaseFirestore.instance.collection('project_tasks').doc(widget.taskId).update({
        'status': 'ongoing',
        'startImages': uploadedUrls,
        'startedAt': FieldValue.serverTimestamp(),
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Work Started! Moved to Ongoing.")));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(widget.taskName, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87))),
                IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20), onPressed: _deleteTask),
              ],
            ),
            Text("${widget.fromDate} to ${widget.toDate}", style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600])),
            const SizedBox(height: 16),
            Text("Upload Progress Photo:", style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87)),
            const SizedBox(height: 8),
            Row(
              children: [
                ElevatedButton(
                  onPressed: _pickImages,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE0E0E0), foregroundColor: Colors.black, elevation: 0),
                  child: const Text("Choose File"),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(_selectedImages.isEmpty ? "No file chosen" : "${_selectedImages.length} files selected", style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 13), overflow: TextOverflow.ellipsis)),
              ],
            ),
            if (_selectedImages.isNotEmpty) 
              Padding(
                padding: const EdgeInsets.only(top: 10), 
                child: Wrap(
                  spacing: 8, 
                  children: _selectedImages.map((img) => 
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4), 
                      child: kIsWeb 
                          ? Image.network(img.path, width: 50, height: 50, fit: BoxFit.cover) 
                          : Image.file(File(img.path), width: 50, height: 50, fit: BoxFit.cover)
                    )
                  ).toList()
                )
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 45,
              child: ElevatedButton(
                onPressed: _isUploading ? null : _startTask,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4285F4), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)), elevation: 0),
                child: _isUploading 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text("Start", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =========================================================
// 2. ONGOING TASK CARD (With "Send for Approval" Logic)
// =========================================================
class OngoingTaskCard extends StatefulWidget {
  final String taskId;
  final String taskName;
  final String fromDate;
  final String toDate;
  final String userId;
  final String projectId;
  final String currentStatus;

  const OngoingTaskCard({
    super.key,
    required this.taskId,
    required this.taskName,
    required this.fromDate,
    required this.toDate,
    required this.userId,
    required this.projectId,
    required this.currentStatus,
  });

  @override
  State<OngoingTaskCard> createState() => _OngoingTaskCardState();
}

class _OngoingTaskCardState extends State<OngoingTaskCard> {
  final ImagePicker _picker = ImagePicker();
  List<XFile> _selectedImages = [];
  bool _isUploading = false;

  Future<void> _pickImages() async {
    final List<XFile> images = await _picker.pickMultiImage(limit: 5); 
    if (images.isNotEmpty) {
      if (images.length > 5) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Maximum 5 images allowed")));
        setState(() => _selectedImages = images.sublist(0, 5));
      } else {
        setState(() => _selectedImages = images);
      }
    }
  }

  Future<void> _deleteTask() async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Work"),
        content: const Text("Are you sure you want to delete this work?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Delete", style: TextStyle(color: Colors.red))),
        ],
      ),
    ) ?? false;
    if (confirm) {
      await FirebaseFirestore.instance.collection('project_tasks').doc(widget.taskId).delete();
    }
  }

  // --- SEND FOR APPROVAL ---
  Future<void> _sendForApproval() async {
    setState(() => _isUploading = true);
    try {
      List<String> uploadedUrls = [];
      if (_selectedImages.isNotEmpty) {
        for (var image in _selectedImages) {
          String? url = await CloudinaryService.uploadImage(imageFile: image, userId: widget.userId, projectId: widget.projectId);
          if (url != null) uploadedUrls.add(url);
        }
      }
      
      // Update status to 'pending_approval'
      await FirebaseFirestore.instance.collection('project_tasks').doc(widget.taskId).update({
        'status': 'pending_approval',
        'endImages': uploadedUrls,
      });
      
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Sent for approval!")));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isPending = widget.currentStatus == 'pending_approval';

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(widget.taskName, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87))),
                IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20), onPressed: _deleteTask),
              ],
            ),
            Text("${widget.fromDate} to ${widget.toDate}", style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600])),
            const SizedBox(height: 16),
            
            if (!isPending) ...[
              Text("Upload Completion Photo (Optional):", style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87)),
              const SizedBox(height: 8),
              Row(
                children: [
                  ElevatedButton(
                    onPressed: _pickImages,
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE0E0E0), foregroundColor: Colors.black, elevation: 0),
                    child: const Text("Choose File"),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(_selectedImages.isEmpty ? "No file chosen" : "${_selectedImages.length} files selected", style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 13), overflow: TextOverflow.ellipsis)),
                ],
              ),
              if (_selectedImages.isNotEmpty) 
                Padding(
                  padding: const EdgeInsets.only(top: 10), 
                  child: Wrap(
                    spacing: 8, 
                    children: _selectedImages.map((img) => 
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4), 
                        child: kIsWeb 
                            ? Image.network(img.path, width: 50, height: 50, fit: BoxFit.cover)
                            : Image.file(File(img.path), width: 50, height: 50, fit: BoxFit.cover)
                      )
                    ).toList()
                  )
                ),
              const SizedBox(height: 16),
            ] else ...[
               const SizedBox(height: 8),
               Container(
                 padding: const EdgeInsets.all(8),
                 decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8)),
                 child: Row(
                   children: [
                     const Icon(Icons.lock_clock, size: 16, color: Color(0xFF6A1F1A)),
                     const SizedBox(width: 8),
                     const Text("Waiting for admin approval...", style: TextStyle(color: Color(0xFF6A1F1A), fontSize: 13, fontStyle: FontStyle.italic)),
                   ],
                 ),
               ),
               const SizedBox(height: 16),
            ],
            
            SizedBox(
              width: double.infinity,
              height: 45,
              child: ElevatedButton(
                onPressed: (isPending || _isUploading) ? null : _sendForApproval,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isPending ? Colors.grey[300] : Colors.green, 
                  foregroundColor: isPending ? Colors.white : Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)), 
                  elevation: 0
                ),
                child: _isUploading 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(
                      isPending ? "Pending Approval" : "Send for Approval", 
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600)
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}