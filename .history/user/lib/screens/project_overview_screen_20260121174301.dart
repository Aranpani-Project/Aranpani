import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import 'project_chat_section.dart';
import '../services/cloudinary_service.dart';

// Helper Widget for Ongoing Tasks (Assuming it exists in your project)
class OngoingTaskCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        title: Text(taskName, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(dateDisplay),
        trailing: currentStatus == 'pending_approval'
            ? const Text("Pending Approval", style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold))
            : ElevatedButton(
                onPressed: () {
                  // Logic to request completion for specific task
                },
                child: const Text("Finish"),
              ),
      ),
    );
  }
}

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

  // ===================== ADD WORK (To Do) =====================

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
                decoration: const InputDecoration(
                  labelText: 'Work name',
                ),
              ),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                ),
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

  // ===================== MONEY REQUEST / BILLS =====================

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
          title: Text('Request Amount',
              style: GoogleFonts.poppins(color: primaryMaroon)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                    controller: titleCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Work Name')),
                TextField(
                    controller: amountCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Amount'),
                    keyboardType: TextInputType.number),
                TextField(
                    controller: upiCtrl,
                    decoration: const InputDecoration(
                        labelText: 'UPI ID (Optional)')),
                const SizedBox(height: 15),
                ElevatedButton.icon(
                  onPressed: () async {
                    final img =
                        await _picker.pickImage(source: ImageSource.gallery);
                    if (img != null) setDialogState(() => qrFile = img);
                  },
                  icon: const Icon(Icons.qr_code),
                  label: const Text('Upload QR Code'),
                ),
                if (qrFile != null)
                  const Text('QR selected',
                      style: TextStyle(color: Colors.green)),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (titleCtrl.text.isEmpty || amountCtrl.text.isEmpty) return;
                String? qrUrl;
                if (qrFile != null) {
                  qrUrl = await CloudinaryService.uploadImage(
                      imageFile: qrFile!,
                      userId: _userId,
                      projectId: _projectId);
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
              style: GoogleFonts.poppins(
                  color: primaryMaroon, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Bill For (Title)')),
                TextField(
                    controller: amountCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Total Amount'),
                    keyboardType: TextInputType.number),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: isUploading
                      ? null
                      : () async {
                          final imgs = await _picker.pickMultiImage();
                          if (imgs.isNotEmpty) {
                            setDialogState(() => selectedFiles = imgs);
                          }
                        },
                  icon: const Icon(Icons.image),
                  label: Text(
                      selectedFiles.isEmpty
                          ? 'Select Bill Photos'
                          : '${selectedFiles.length} Images Selected'),
                ),
                if (isUploading)
                  const Padding(
                    padding: EdgeInsets.only(top: 20),
                    child:
                        CircularProgressIndicator(color: primaryMaroon),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed:
                  isUploading ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isUploading
                  ? null
                  : () async {
                      if (titleCtrl.text.isEmpty ||
                          amountCtrl.text.isEmpty ||
                          selectedFiles.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    'Please fill all fields and select images')));
                        return;
                      }

                      setDialogState(() => isUploading = true);
                      try {
                        List<String> urls = [];
                        for (var file in selectedFiles) {
                          String? url =
                              await CloudinaryService.uploadImage(
                                  imageFile: file,
                                  userId: _userId,
                                  projectId: _projectId);
                          if (url != null) urls.add(url);
                        }

                        await _billsRef.add({
                          'projectId': _projectId,
                          'userId': _userId,
                          'title': titleCtrl.text,
                          'amount':
                              double.parse(amountCtrl.text),
                          'imageUrls': urls,
                          'createdAt':
                              FieldValue.serverTimestamp(),
                        });

                        if (mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'Bill Uploaded Successfully!')));
                        }
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text('Upload failed: $e')));
                      } finally {
                        setDialogState(
                            () => isUploading = false);
                      }
                    },
              child: const Text('Upload'),
            )
          ],
        ),
      ),
    );
  }

  // Bills tab
  Widget _billsTab() {
    return Column(
      children: [
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _showUploadBillDialog,
          icon: const Icon(Icons.upload),
          label: const Text("Upload Bill"),
          style: ElevatedButton.styleFrom(
              backgroundColor: primaryMaroon,
              foregroundColor: Colors.white),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _billsRef
                .where('projectId', isEqualTo: _projectId)
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(
                    child: CircularProgressIndicator());
              }
              final docs = snapshot.data!.docs;
              if (docs.isEmpty) {
                return Center(
                    child: Text("No bills uploaded yet",
                        style: GoogleFonts.poppins(
                            color: Colors.grey)));
              }

              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: docs.length,
                itemBuilder: (context, i) {
                  final bill = docs[i].data();
                  final imageUrls =
                      (bill['imageUrls'] as List? ?? []);
                  return Card(
                    child: ExpansionTile(
                      title: Text(bill['title'] ?? 'Bill',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold)),
                      subtitle: Text(
                          'Amount: ₹${bill['amount'] ?? '0'}'),
                      children: [
                        if (imageUrls.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: imageUrls
                                  .map((url) => GestureDetector(
                                        onTap: () =>
                                            _showFullScreenImage(
                                                url.toString()),
                                        child: ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(
                                                  8),
                                          child: Image.network(
                                              url.toString(),
                                              width: 80,
                                              height: 80,
                                              fit: BoxFit.cover),
                                        ),
                                      ))
                                  .toList(),
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

  // ===================== ACTIVITIES: TODO / ONGOING / COMPLETED =====================

  Widget _activitiesTab() {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          // Add work button
          Padding(
            padding:
                const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                onPressed: _showAddWorkDialog,
                icon: const Icon(Icons.add_task),
                label: const Text('Add Work (To Do)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryMaroon,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ),
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
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('project_tasks')
          .where('projectId', isEqualTo: _projectId)
          .where('status', isEqualTo: 'todo')
          .orderBy('createdAt', descending: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
              child: CircularProgressIndicator());
        }
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return Center(
              child: Text("No To Do works",
                  style: GoogleFonts.poppins(
                      color: Colors.grey)));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data =
                doc.data() as Map<String, dynamic>;
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                title: Text(
                  data['taskName'] ?? 'Unknown Work',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                    data['description'] ?? 'Not started yet'),
                trailing: ElevatedButton(
                  onPressed: () async {
                    await _firestore
                        .collection('project_tasks')
                        .doc(doc.id)
                        .update({
                      'status': 'ongoing',
                      'startedAt':
                          FieldValue.serverTimestamp(),
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
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
          .where('status', whereIn: ['ongoing', 'pending_approval'])
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
              child: CircularProgressIndicator());
        }
        final docs = snapshot.data!.docs;

        if (docs.isEmpty) {
          return Center(
              child: Text("No ongoing works",
                  style: GoogleFonts.poppins(
                      color: Colors.grey)));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data =
                docs[index].data() as Map<String, dynamic>;
            final docId = docs[index].id;
            final status = data['status'] ?? 'ongoing';

            final Timestamp? startTs = data['startedAt'];
            final String dateDisplay = startTs != null
                ? "Started: ${_formatTimestamp(startTs)}"
                : "Date not captured";

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
          .orderBy('completedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
              child: CircularProgressIndicator());
        }
        final docs = snapshot.data!.docs;

        if (docs.isEmpty) {
          return Center(
              child: Text("No completed works",
                  style: GoogleFonts.poppins(
                      color: Colors.grey)));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data =
                docs[index].data() as Map<String, dynamic>;

            final Timestamp? startTs = data['startedAt'];
            final Timestamp? endTs = data['completedAt'];

            final String startStr = _formatTimestamp(startTs);
            final String endStr = _formatTimestamp(endTs);

            final List<dynamic> endImages =
                data['endImages'] ?? [];

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.check_circle,
                            color: Colors.green),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            data['taskName'] ?? '',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16),
                          ),
                        ),
                        const Icon(Icons.verified,
                            color: Colors.blue),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text("Start: $startStr | End: $endStr",
                        style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey)),
                    if (endImages.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      const Text("Submitted Photos:",
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12)),
                      const SizedBox(height: 5),
                      SizedBox(
                        height: 70,
                        child: ListView.builder(
                          scrollDirection:
                              Axis.horizontal,
                          itemCount: endImages.length,
                          itemBuilder:
                              (context, imgIndex) {
                            return Padding(
                              padding:
                                  const EdgeInsets.only(
                                      right: 8.0),
                              child: GestureDetector(
                                onTap: () =>
                                    _showFullScreenImage(
                                        endImages[
                                            imgIndex]),
                                child: ClipRRect(
                                  borderRadius:
                                      BorderRadius
                                          .circular(6),
                                  child: Image.network(
                                      endImages[
                                          imgIndex],
                                      width: 70,
                                      height: 70,
                                      fit: BoxFit.cover),
                                ),
                              ),
                            );
                          },
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

  // ===================== COMPLETION REQUEST =====================

  Future<int> _getCompletedTasksCount() async {
    final snap = await _firestore
        .collection('project_tasks')
        .where('projectId', isEqualTo: _projectId)
        .where('status', isEqualTo: 'completed')
        .limit(1)
        .get();
    return snap.docs.length;
  }

  Future<int> _getOngoingTasksCount() async {
    final snap = await _firestore
        .collection('project_tasks')
        .where('projectId', isEqualTo: _projectId)
        .where('status', whereIn: ['ongoing', 'pending_approval'])
        .limit(1)
        .get();
    return snap.docs.length;
  }

  Future<int> _getTodoTasksCount() async {
    final snap = await _firestore
        .collection('project_tasks')
        .where('projectId', isEqualTo: _projectId)
        .where('status', isEqualTo: 'todo')
        .limit(1)
        .get();
    return snap.docs.length;
  }

  Future<void> _requestProjectCompletion() async {
  setState(() => _isCompletionRequesting = true);
  try {
    final completed = await _getCompletedTasksCount();
    final ongoing = await _getOngoingTasksCount();
    final todo = await _getTodoTasksCount();

    if (completed == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Complete at least one work before requesting project completion.'),
        ),
      );
      return;
    }

    if (ongoing > 0 || todo > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'All works must be completed or deleted. No To Do or Ongoing tasks allowed when requesting completion.'),
        ),
      );
      return;
    }

    // 1) Create completion request document
    await _firestore
        .collection('project_completion_requests')
        .add({
      'projectId': _projectId,
      'userId': _userId,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });

    // 2) Send a chat message that will be visible in ProjectChatSection
    await _firestore.collection('project_messages').add({
      'projectId': _projectId,
      'message':
          'User has requested to mark this project as completed. Please review all works and update the project status.',
      'senderRole': 'user',                    // matches ProjectChatSection
      'createdAt': FieldValue.serverTimestamp(),
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
            'Completion request sent to admin and a message posted in project chat.'),
      ),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error sending request: $e')),
    );
  } finally {
    if (mounted) setState(() => _isCompletionRequesting = false);
  }
}


  // ===================== TABS WRAPPERS =====================

  Widget _transactionsTab() {
    return Column(
      children: [
        // Top Action Buttons
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              ElevatedButton.icon(
                onPressed: _showRequestAmountDialog,
                icon: const Icon(Icons.add_card),
                label: const Text('Request Amount from Admin'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _isCompletionRequesting ? null : _requestProjectCompletion,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: _isCompletionRequesting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.flag),
                label: Text(
                  _isCompletionRequesting
                      ? 'Sending completion request...'
                      : 'Request Project Completion',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Requirements:\n• 1+ work completed • No To Do • No Ongoing',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey[700]),
              ),
            ],
          ),
        ),

        // Section Title
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.history, size: 20, color: primaryMaroon),
              const SizedBox(width: 8),
              Text(
                "TRANSACTION HISTORY",
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: primaryMaroon,
                ),
              ),
            ],
          ),
        ),

        // Transaction List
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _firestore
                .collection('transactions')
                .where('projectId', isEqualTo: _projectId)
                .orderBy('date', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text("Error: ${snapshot.error}"));
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: primaryMaroon));
              }

              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return Center(
                  child: Text("No transaction history", style: GoogleFonts.poppins(color: Colors.grey)),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data();
                  final status = (data['status'] ?? 'pending').toString().toLowerCase();
                  
                  Color statusColor = Colors.orange;
                  if (status == 'approved') statusColor = Colors.green;
                  if (status == 'rejected') statusColor = Colors.red;

                  return Card(
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      title: Text(
                        data['title'] ?? 'Amount Request',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      subtitle: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              status.toUpperCase(),
                              style: TextStyle(color: statusColor, fontSize: 9, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            _formatTimestamp(data['date'] as Timestamp?),
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                      trailing: Text(
                        "₹${data['amount']}",
                        style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: primaryMaroon),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _billsTabWrapper() => _billsTab();

  Widget _feedbackTab() =>
      ProjectChatSection(projectId: _projectId, currentRole: 'user');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundCream,
      appBar: AppBar(
        backgroundColor: primaryMaroon,
        foregroundColor: Colors.white,
        title: Text(widget.project['projectName'] ?? 'Project Overview', 
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 18)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Activities'),
            Tab(text: 'Finances'),
            Tab(text: 'Bills'),
            Tab(text: 'Chat'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _activitiesTab(),
          _transactionsTab(),
          _billsTabWrapper(),
          _feedbackTab(),
        ],
      ),
    );
  }
}

// Delegate for TabBar (if you use SliverPersistentHeader)
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