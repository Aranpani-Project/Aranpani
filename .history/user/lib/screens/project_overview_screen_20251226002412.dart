import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ProjectOverviewScreen extends StatefulWidget {
  final Map<String, dynamic> project;
  const ProjectOverviewScreen({super.key, required this.project});

  @override
  State<ProjectOverviewScreen> createState() => _ProjectOverviewScreenState();
}

class _ProjectOverviewScreenState extends State<ProjectOverviewScreen> {
  // --- Aranpani Theme Colors (Matches Admin) ---
  static const Color primaryMaroon = Color(0xFF6D1B1B);
  static const Color primaryGold = Color(0xFFD4AF37);
  static const Color backgroundCream = Color(0xFFFFF7E8);
  static const Color darkMaroonText = Color(0xFF4A1010);

  int selectedTab = 0;
  final TextEditingController _chatController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Use the document ID from Firestore to link messages
  String get projectId => widget.project['id'] ?? '';

  @override
  void dispose() {
    _chatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundCream,
      appBar: AppBar(
        backgroundColor: primaryMaroon,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              (widget.project['name'] ?? 'Project Overview').toString(),
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              'Project ID: ${widget.project['projectNumber'] ?? 'N/A'}',
              style: const TextStyle(color: primaryGold, fontSize: 12),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // SUB-HEADER TAB BAR (Matches Admin Design)
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2)),
              ],
            ),
            child: Row(
              children: [
                _buildTab('Activities', 0),
                _buildTab('Finances', 1),
                _buildTab('Feedback', 2),
              ],
            ),
          ),
          
          Expanded(
            child: selectedTab == 2 
                ? _buildChatUI() // Special UI for Chat
                : ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                    children: [
                      if (selectedTab == 0) const Center(child: Text("Activities Content")),
                      if (selectedTab == 1) const Center(child: Text("Finances Content")),
                    ],
                  ),
          ),
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
            border: Border(bottom: BorderSide(color: isActive ? primaryGold : Colors.transparent, width: 3)),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isActive ? primaryMaroon : Colors.grey[600],
              fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  // --- FEEDBACK / CHAT UI ---
  Widget _buildChatUI() {
    return Column(
      children: [
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('feedback')
                .where('projectId', isEqualTo: projectId)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

              // Sorting locally to bypass index requirements for now
              var docs = snapshot.data!.docs.toList();
              docs.sort((a, b) {
                var t1 = (a.data() as Map)['createdAt'] ?? Timestamp.now();
                var t2 = (b.data() as Map)['createdAt'] ?? Timestamp.now();
                return t2.compareTo(t1); // Latest at bottom
              });

              return ListView.builder(
                padding: const EdgeInsets.all(20),
                reverse: true, // Chat flows from bottom
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  bool isMe = data['role'] == 'user'; // On User side, "user" is Me

                  return Align(
                    alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 5),
                      padding: const EdgeInsets.all(14),
                      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                      decoration: BoxDecoration(
                        color: isMe ? primaryMaroon : Colors.white,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(16),
                          topRight: const Radius.circular(16),
                          bottomLeft: Radius.circular(isMe ? 16 : 0),
                          bottomRight: Radius.circular(isMe ? 0 : 16),
                        ),
                        border: isMe ? null : Border.all(color: Colors.grey.shade300),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 2))
                        ],
                      ),
                      child: Text(
                        data['text'] ?? '',
                        style: TextStyle(color: isMe ? Colors.white : Colors.black87, fontSize: 15),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        
        // Input Area (Matches Admin Style but simplified for Mobile)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: const Offset(0, -2))],
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _chatController,
                  decoration: InputDecoration(
                    hintText: 'Type your message...',
                    filled: true,
                    fillColor: backgroundCream,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              CircleAvatar(
                backgroundColor: primaryMaroon,
                child: IconButton(
                  icon: const Icon(Icons.send, color: Colors.white, size: 20),
                  onPressed: _sendMessage,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _sendMessage() async {
    if (_chatController.text.trim().isEmpty) return;
    
    final message = _chatController.text.trim();
    _chatController.clear();

    await _firestore.collection('feedback').add({
      'projectId': projectId,
      'text': message,
      'role': 'user', // IDENTIFIER
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}