import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class OngoingTempleDetailScreen extends StatefulWidget {
  final Map<String, dynamic> temple;
  const OngoingTempleDetailScreen({Key? key, required this.temple}) : super(key: key);

  @override
  State<OngoingTempleDetailScreen> createState() => _OngoingTempleDetailScreenState();
}

class _OngoingTempleDetailScreenState extends State<OngoingTempleDetailScreen> {
  static const Color primaryMaroon = Color(0xFF6D1B1B);
  static const Color primaryGold = Color(0xFFD4AF37);
  static const Color backgroundCream = Color(0xFFFFF7E8);
  static const Color darkMaroonText = Color(0xFF4A1010);

  int selectedTab = 0;
  final TextEditingController _feedbackInputController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String get templeId => widget.temple['id'] ?? '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundCream,
      appBar: AppBar(
        backgroundColor: primaryMaroon,
        title: Text(widget.temple['name'] ?? 'Admin View'),
      ),
      body: Column(
        children: [
          // CUSTOM TAB BAR
          Row(
            children: [
              _buildTabItem('Work', 0),
              _buildTabItem('Feedback', 1),
            ],
          ),
          Expanded(
            child: selectedTab == 0 
              ? const Center(child: Text("Work Progress")) 
              : _buildAdminFeedbackTab(),
          ),
        ],
      ),
    );
  }

  Widget _buildTabItem(String label, int index) {
    bool isActive = selectedTab == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => selectedTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: isActive ? primaryGold : Colors.transparent, width: 3))),
          child: Text(label, textAlign: TextAlign.center, style: TextStyle(color: isActive ? primaryMaroon : Colors.grey, fontWeight: isActive ? FontWeight.bold : FontWeight.normal)),
        ),
      ),
    );
  }

  Widget _buildAdminFeedbackTab() {
    return Column(
      children: [
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _firestore.collection('feedback').where('projectId', isEqualTo: templeId).snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              
              var docs = snapshot.data!.docs;
              docs.sort((a, b) {
                var t1 = (a.data() as Map)['createdAt'] ?? Timestamp.now();
                var t2 = (b.data() as Map)['createdAt'] ?? Timestamp.now();
                return t2.compareTo(t1);
              });

              return ListView.builder(
                padding: const EdgeInsets.all(15),
                reverse: true,
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final msg = docs[index].data() as Map<String, dynamic>;
                  bool isAdmin = msg['role'] == 'admin'; // Admin is "Me" on this side

                  return Align(
                    alignment: isAdmin ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.symmetric(vertical: 5),
                      decoration: BoxDecoration(
                        color: isAdmin ? primaryMaroon : Colors.grey[300],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(msg['text'] ?? '', style: TextStyle(color: isAdmin ? Colors.white : Colors.black)),
                    ),
                  );
                },
              );
            },
          ),
        ),
        _buildAdminChatInput(),
      ],
    );
  }

  Widget _buildAdminChatInput() {
    return Container(
      padding: const EdgeInsets.all(10),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _feedbackInputController,
              decoration: InputDecoration(hintText: 'Reply to User...', border: OutlineInputBorder(borderRadius: BorderRadius.circular(30))),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: primaryMaroon,
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white),
              onPressed: _sendAdminReply,
            ),
          )
        ],
      ),
    );
  }

  void _sendAdminReply() async {
    if (_feedbackInputController.text.trim().isEmpty) return;
    String txt = _feedbackInputController.text.trim();
    _feedbackInputController.clear();

    await _firestore.collection('feedback').add({
      'projectId': templeId,
      'text': txt,
      'role': 'admin',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}