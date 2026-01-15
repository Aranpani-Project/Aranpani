import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

import 'project_chat_section.dart';
import 'finance_tab_section.dart';

class OngoingTempleDetailScreen extends StatefulWidget {
  final Map<String, dynamic> temple;
  final void Function(Map<String, dynamic>?) onUpdated;

  const OngoingTempleDetailScreen({
    Key? key,
    required this.temple,
    required this.onUpdated,
  }) : super(key: key);

  @override
  State<OngoingTempleDetailScreen> createState() =>
      _OngoingTempleDetailScreenState();
}

class _OngoingTempleDetailScreenState
    extends State<OngoingTempleDetailScreen> {
  static const Color primaryMaroon = Color(0xFF6D1B1B);
  static const Color primaryGold = Color(0xFFD4AF37);
  static const Color backgroundCream = Color(0xFFFFF7E8);
  static const Color darkMaroonText = Color(0xFF4A1010);

  late Map<String, dynamic> temple;
  int selectedTab = 0;
  bool isDeleting = false;

  @override
  void initState() {
    super.initState();
    temple = Map<String, dynamic>.from(widget.temple);
  }

  void _handleBackNavigation() {
    widget.onUpdated(temple);
    if (Navigator.canPop(context)) Navigator.pop(context);
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return "N/A";
    DateTime date = timestamp.toDate();
    return "${date.day}/${date.month}/${date.year}";
  }

  Future<void> _deleteProject() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Project?"),
        content: const Text(
          "This will permanently delete this project, all associated tasks, and bills. This action cannot be undone.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("CANCEL"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("DELETE", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => isDeleting = true);

    try {
      final batch = FirebaseFirestore.instance.batch();
      final String projectId = temple['id'];

      final tasksQuery = await FirebaseFirestore.instance
          .collection('project_tasks')
          .where('projectId', isEqualTo: projectId)
          .get();
      for (var doc in tasksQuery.docs) {
        batch.delete(doc.reference);
      }

      final billsQuery = await FirebaseFirestore.instance
          .collection('bills')
          .where('projectId', isEqualTo: projectId)
          .get();
      for (var doc in billsQuery.docs) {
        batch.delete(doc.reference);
      }

      final projectRef =
          FirebaseFirestore.instance.collection('projects').doc(projectId);
      batch.delete(projectRef);

      await batch.commit();

      widget.onUpdated(null);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Project deleted successfully")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error deleting project: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => isDeleting = false);
    }
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
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(
                      child:
                          CircularProgressIndicator(color: Colors.white),
                    );
                  },
                ),
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

  // NEW: mark whole project as completed
  Future<void> _markProjectCompleted() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Mark Project as Completed?"),
        content: const Text(
          "This will mark the entire project as completed and move it to the Completed tab.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("CANCEL"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              "MARK COMPLETED",
              style: TextStyle(color: Colors.green),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final String projectId = temple['id'] ?? temple['projectId'];
      if (projectId == null || projectId.toString().isEmpty) return;

      await FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId.toString())
          .update({
        'status': 'completed',
        'progress': 100,
        'completedDate': FieldValue.serverTimestamp(),
      });

      temple['status'] = 'completed';
      temple['progress'] = 100;

      widget.onUpdated(temple);

      if (mounted) {
        Navigator.pop(context); // back to TempleDetailScreen
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error marking project completed: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundCream,
      appBar: AppBar(
        backgroundColor: primaryMaroon,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: _handleBackNavigation,
        ),
        title: Text(
          (temple['name'] ?? 'Temple Project').toString(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (isDeleting)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.white),
              onPressed: _deleteProject,
              tooltip: "Delete Project",
            ),
        ],
      ),
      body: Column(
        children: [
          // Tabs
          Container(
            color: Colors.white,
            child: Row(
              children: [
                _buildTab('Activities', 0),
                _buildTab('Finances', 1),
                _buildTab('Payment Process', 2),
                _buildTab('Feedback', 3),
              ],
            ),
          ),

          // NEW: Complete project button
          Container(
            width: double.infinity,
            color: Colors.white,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ElevatedButton.icon(
              onPressed: _markProjectCompleted,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[700],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(Icons.flag),
              label: const Text(
                'Mark Project as Completed',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),

          Expanded(child: _buildCurrentTabContent()),
        ],
      ),
    );
  }

  Widget _buildTab(String label, int index) {
    final isActive = selectedTab == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => selectedTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isActive ? primaryGold : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isActive ? primaryMaroon : Colors.grey,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              fontSize: 11,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentTabContent() {
    switch (selectedTab) {
      case 0:
        return _buildActivitiesTab();
      case 1:
        return FinanceTabSection(
          projectId: temple['id'],
          onShowImage: _showFullScreenImage,
        );
      case 2:
        return _buildPaymentProcessTab();
      case 3:
        return ProjectChatSection(
          projectId: temple['id'],
          currentRole: 'admin',
        );
      default:
        return const Center(child: Text("Content Not Found"));
    }
  }

  Widget _buildActivitiesTab() {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Container(
            color: Colors.grey[100],
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
                _buildTaskList('todo'),
                _buildOngoingList(),
                _buildCompletedList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskList(String status) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('project_tasks')
          .where('projectId', isEqualTo: temple['id'])
          .where('status', isEqualTo: status)
          .orderBy('createdAt', descending: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return Center(
            child: Text(
              "No $status works found",
              style: const TextStyle(color: Colors.grey),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                title: Text(
                  data['taskName'] ?? 'Unknown Work',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text("Not started yet"),
                trailing: const Icon(Icons.hourglass_empty,
                    color: Colors.orange),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCompletedList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('project_tasks')
          .where('projectId', isEqualTo: temple['id'])
          .where('status', isEqualTo: 'completed')
          .orderBy('completedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return const Center(
            child: Text("No completed works",
                style: TextStyle(color: Colors.grey)),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;

            Timestamp? start = data['startedAt'];
            Timestamp? end = data['completedAt'];
            String dateText =
                "Start: ${_formatTimestamp(start)}  -  End: ${_formatTimestamp(end)}";

            List<dynamic> endImages = data['endImages'] ?? [];

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
                          child: Text(
                            data['taskName'] ?? 'Unknown Work',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      dateText,
                      style: TextStyle(
                          color: Colors.grey[600], fontSize: 13),
                    ),
                    if (endImages.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      const Text(
                        "Submitted Photos:",
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      const SizedBox(height: 5),
                      SizedBox(
                        height: 70,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: endImages.length,
                          itemBuilder: (context, imgIndex) {
                            return Padding(
                              padding:
                                  const EdgeInsets.only(right: 8.0),
                              child: GestureDetector(
                                onTap: () => _showFullScreenImage(
                                    endImages[imgIndex]),
                                child: ClipRRect(
                                  borderRadius:
                                      BorderRadius.circular(6),
                                  child: Image.network(
                                    endImages[imgIndex],
                                    width: 70,
                                    height: 70,
                                    fit: BoxFit.cover,
                                  ),
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

  Widget _buildOngoingList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('project_tasks')
          .where('projectId', isEqualTo: temple['id'])
          .where('status', whereIn: ['ongoing', 'pending_approval'])
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return const Center(
            child: Text(
              "No ongoing works",
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final docId = docs[index].id;
            final status = data['status'] ?? 'ongoing';

            Timestamp? startTs = data['startedAt'];
            String dateText = startTs != null
                ? "Started: ${_formatTimestamp(startTs)}"
                : "Started: N/A";

            List<dynamic> endImages = data['endImages'] ?? [];

            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          data['taskName'] ?? 'Unknown Work',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: darkMaroonText,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: status == 'pending_approval'
                                ? Colors.orange
                                : Colors.blue[100],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            status == 'pending_approval'
                                ? "Pending Approval"
                                : "In Progress",
                            style: TextStyle(
                              color: status == 'pending_approval'
                                  ? Colors.white
                                  : Colors.blue,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      dateText,
                      style: TextStyle(
                          color: Colors.grey[600], fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    if (endImages.isNotEmpty) ...[
                      const Text(
                        "Attached Photos:",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 80,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: endImages.length,
                          itemBuilder: (ctx, i) => Padding(
                            padding:
                                const EdgeInsets.only(right: 8.0),
                            child: GestureDetector(
                              onTap: () =>
                                  _showFullScreenImage(endImages[i]),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  endImages[i],
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                    if (status == 'pending_approval') ...[
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () =>
                                FirebaseFirestore.instance
                                    .collection('project_tasks')
                                    .doc(docId)
                                    .update({'status': 'ongoing'}),
                            child: const Text(
                              "Not Approved",
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            onPressed: () =>
                                FirebaseFirestore.instance
                                    .collection('project_tasks')
                                    .doc(docId)
                                    .update({
                              'status': 'completed',
                              'completedAt':
                                  FieldValue.serverTimestamp(),
                            }),
                            icon: const Icon(Icons.check, size: 18),
                            label: const Text("Approve"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPaymentProcessTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Budget Utilization',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: darkMaroonText,
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Budget',
                      style: TextStyle(color: Colors.grey)),
                  Text(
                    '₹${temple['budget'] ?? '0'}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: primaryMaroon,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const LinearProgressIndicator(
                value: 0.6,
                backgroundColor: backgroundCream,
                color: primaryGold,
                minHeight: 8,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Bills Uploaded',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: darkMaroonText,
          ),
        ),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('bills')
              .where('projectId', isEqualTo: temple['id'])
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(20),
                child: const Center(child: Text("No bills found.")),
              );
            }
            return Column(
              children: snapshot.data!.docs.map((doc) {
                final bill = doc.data() as Map<String, dynamic>;
                List<dynamic> images = bill['imageUrls'] ?? [];
                return Card(
                  child: ExpansionTile(
                    title: Text(
                      bill['title'] ?? 'Bill',
                      style:
                          const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '₹${bill['amount']}',
                      style: const TextStyle(color: Colors.green),
                    ),
                    children: [
                      if (images.isNotEmpty)
                        SizedBox(
                          height: 100,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: images.length,
                            itemBuilder: (ctx, i) => Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: GestureDetector(
                                onTap: () =>
                                    _showFullScreenImage(images[i]),
                                child: Image.network(images[i]),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}
