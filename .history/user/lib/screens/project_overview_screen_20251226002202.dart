import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ProjectOverviewScreen extends StatefulWidget {
  final Map<String, dynamic> project;
  const ProjectOverviewScreen({Key? key, required this.project}) : super(key: key);

  @override
  State<ProjectOverviewScreen> createState() => _ProjectOverviewScreenState();
}

class _ProjectOverviewScreenState extends State<ProjectOverviewScreen> with SingleTickerProviderStateMixin {
  // --- Aranpani Theme Colors ---
  static const Color primaryMaroon = Color(0xFF6D1B1B);
  static const Color primaryGold = Color(0xFFD4AF37);
  static const Color backgroundCream = Color(0xFFFFF7E8);
  static const Color darkMaroonText = Color(0xFF4A1010);

  late TabController _tabController;
  final TextEditingController _feedbackInputController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  String get projectId => widget.project['id'] ?? '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundCream,
      appBar: AppBar(
        backgroundColor: primaryMaroon,
        title: Text(widget.project['name'] ?? 'Project Details', style: const TextStyle(color: Colors.white)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: primaryGold,
          tabs: const [Tab(text: 'Work'), Tab(text: 'Finance'), Tab(text: 'Feedback')],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          const Center(child: Text("Work Progress")),
          const Center(child: Text("Finance Details")),
          _buildFeedbackTab(),
        ],
      ),
    );
  }

  Widget _buildFeedbackTab() {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('Communication Log', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: darkMaroonText)),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _firestore.collection('feedback')
                .where('projectId', isEqualTo: projectId)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              
              var docs = snapshot.data!.docs;
              // Sort locally to avoid Index requirements
              docs.sort((a, b) {
                var t1 = (a.data() as Map)['createdAt'] ?? Timestamp.now();
                var t2 = (b.data() as Map)['createdAt'] ?? Timestamp.now();
                return t2.compareTo(t1); 
              });

              return ListView.builder(
                padding: const EdgeInsets.all(15),
                reverse: true, // Chat moves upward
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final msg = docs[index].data() as Map<String, dynamic>;
                  bool isMe = msg['role'] == 'user'; // User is "Me" on this side

                  return Align(
                    alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.symmetric(vertical: 5),
                      decoration: BoxDecoration(
                        color: isMe ? primaryMaroon : Colors.grey[300],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        msg['text'] ?? '',
                        style: TextStyle(color: isMe ? Colors.white : Colors.black),
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
                hintText: 'Message Admin...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: primaryMaroon,
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white),
              onPressed: _sendMessage,
            ),
          )
        ],
      ),
    );
  }

  void _sendMessage() async {
    if (_feedbackInputController.text.trim().isEmpty) return;
    String txt = _feedbackInputController.text.trim();
    _feedbackInputController.clear();

    await _firestore.collection('feedback').add({
      'projectId': projectId,
      'text': txt,
      'role': 'user',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}