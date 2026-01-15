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

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return "N/A";
    DateTime date = timestamp.toDate();
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

  Future<void> _showAddWorkDialog() async {
    final TextEditingController nameCtrl = TextEditingController();

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
                  const Text(
                    "Note: Start date will be captured automatically when you start the work.",
                    style: TextStyle(fontSize: 12, color: Colors.grey),
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
                    if (nameCtrl.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter work name')));
                      return;
                    }
                    await _firestore.collection('project_tasks').add({
                      'projectId': _projectId,
                      'taskName': nameCtrl.text,
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
          style: ElevatedButton.styleFrom(backgroundColor: primaryMaroon, foregroundColor: Colors.white),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _billsRef.where('projectId', isEqualTo: _projectId).orderBy('createdAt', descending: true).snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final docs = snapshot.data!.docs;
              if (docs.isEmpty) return Center(child: Text("No bills uploaded yet", style: GoogleFonts.poppins(color: Colors.grey)));
              
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
                TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Bill For (Title)')),
                TextField(controller: amountCtrl, decoration: const InputDecoration(labelText: 'Total Amount'), keyboardType: TextInputType.number),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: isUploading ? null : () async {
                    final imgs = await _picker.pickMultiImage();
                    if (imgs.isNotEmpty) setDialogState(() => selectedFiles = imgs);
                  },
                  icon: const Icon(Icons.image),
                  label: Text(selectedFiles.isEmpty ? 'Select Bill Photos' : '${selectedFiles.length} Images Selected'),
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
              onPressed: isUploading ? null : () async {
                if (titleCtrl.text.isEmpty || amountCtrl.text.isEmpty || selectedFiles.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all fields and select images')));
                  return;
                }

                setDialogState(() => isUploading = true);
                try {
                  List<String> urls = [];
                  for (var file in selectedFiles) {
                    String? url = await CloudinaryService.uploadImage(
                      imageFile: file, 
                      userId: _userId, 
                      projectId: _projectId
                    );
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

                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bill Uploaded Successfully!')));
                  }
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
                
                return TodoTaskCard(
                  taskId: docId,
                  taskName: data['taskName'] ?? 'Unknown Work',
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
            
            Timestamp? startTs = data['startedAt'];
            String dateDisplay = startTs != null ? "Started: ${_formatTimestamp(startTs)}" : "Date not captured";

            return OngoingTaskCard(
              taskId: docId,
              taskName: data['taskName'] ?? 'Unknown Work',
              dateDisplay: dateDisplay,
              userId: _userId,
              projectId: _projectId,
              currentStatus: status, 
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
            
            Timestamp? startTs = data['startedAt'];
            Timestamp? endTs = data['completedAt'];

            String startStr = _formatTimestamp(startTs);
            String endStr = _formatTimestamp(endTs);

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: const Icon(Icons.check_circle, color: Colors.green),
                title: Text(
                  data['taskName'] ?? '', 
                  style: const TextStyle(fontWeight: FontWeight.bold) 
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Work Completed"),
                    const SizedBox(height: 4),
                    Text("Start: $startStr | End: $endStr", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
                trailing: const Icon(Icons.verified, color: Colors.blue),
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
// 1. TODO TASK CARD (UPDATED - Accumulative Image Selection)
// =========================================================
class TodoTaskCard extends StatefulWidget {
  final String taskId;
  final String taskName;
  final String userId;
  final String projectId;

  const TodoTaskCard({
    super.key,
    required this.taskId,
    required this.taskName,
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
    // FIX: ADD images to existing list instead of replacing
    final List<XFile> images = await _picker.pickMultiImage(); 
    
    if (images.isNotEmpty) {
      setState(() {
        _selectedImages.addAll(images);
        // Enforce limit of 10
        if (_selectedImages.length > 10) {
          _selectedImages = _selectedImages.sublist(0, 10);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Maximum 10 images allowed")));
        }
      });
    }
  }

  // Helper to remove an image if user wants
  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
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
            Text("Not started yet", style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600], fontStyle: FontStyle.italic)),
            const SizedBox(height: 16),
            Text("Upload Start Photo:", style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87)),
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
                  runSpacing: 8,
                  children: _selectedImages.asMap().entries.map((entry) {
                    int idx = entry.key;
                    XFile img = entry.value;
                    return Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4), 
                          child: kIsWeb 
                              ? Image.network(img.path, width: 60, height: 60, fit: BoxFit.cover) 
                              : Image.file(File(img.path), width: 60, height: 60, fit: BoxFit.cover)
                        ),
                        Positioned(
                          right: 0,
                          top: 0,
                          child: GestureDetector(
                            onTap: () => _removeImage(idx),
                            child: Container(
                              color: Colors.black54,
                              child: const Icon(Icons.close, color: Colors.white, size: 16),
                            ),
                          ),
                        )
                      ],
                    );
                  }).toList()
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
// 2. ONGOING TASK CARD (UPDATED - Accumulative Image Selection)
// =========================================================
class OngoingTaskCard extends StatefulWidget {
  final String taskId;
  final String taskName;
  final String dateDisplay;
  final String userId;
  final String projectId;
  final String currentStatus;

  const OngoingTaskCard({
    super.key,
    required this.taskId,
    required this.taskName,
    required this.dateDisplay,
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
    // FIX: ADD images to existing list instead of replacing
    final List<XFile> images = await _picker.pickMultiImage(); 
    
    if (images.isNotEmpty) {
      setState(() {
        _selectedImages.addAll(images);
        // Enforce limit of 10
        if (_selectedImages.length > 10) {
          _selectedImages = _selectedImages.sublist(0, 10);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Maximum 10 images allowed")));
        }
      });
    }
  }

  // Helper to remove an image if user wants
  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
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
            Text(widget.dateDisplay, style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600])),
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
                  padding: const EdgeInsets.only(top: 10, bottom: 16), 
                  child: Wrap(
                    spacing: 8, 
                    runSpacing: 8,
                    children: _selectedImages.asMap().entries.map((entry) {
                      int idx = entry.key;
                      XFile img = entry.value;
                      return Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4), 
                            child: kIsWeb 
                                ? Image.network(img.path, width: 60, height: 60, fit: BoxFit.cover) 
                                : Image.file(File(img.path), width: 60, height: 60, fit: BoxFit.cover)
                          ),
                          Positioned(
                            right: 0,
                            top: 0,
                            child: GestureDetector(
                              onTap: () => _removeImage(idx),
                              child: Container(
                                color: Colors.black54,
                                child: const Icon(Icons.close, color: Colors.white, size: 16),
                              ),
                            ),
                          )
                        ],
                      );
                    }).toList()
                  )
                )
              else 
                const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                height: 45,
                child: ElevatedButton(
                  onPressed: _isUploading ? null : _sendForApproval,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)), elevation: 0),
                  child: _isUploading 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Send for Approval", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ] else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                child: const Row(
                  children: [
                    Icon(Icons.hourglass_bottom, color: Colors.orange),
                    SizedBox(width: 10),
                    Text("Pending Admin Approval", style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                  ],
                ),
              )
            ],
          ],
        ),
      ),
    );
  }
}