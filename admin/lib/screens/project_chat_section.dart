import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ProjectChatSection extends StatefulWidget {
  final String projectId;
  final String currentRole; // 'user' or 'admin'

  const ProjectChatSection({
    super.key,
    required this.projectId,
    required this.currentRole,
  });

  @override
  State<ProjectChatSection> createState() => _ProjectChatSectionState();
}

class _ProjectChatSectionState extends State<ProjectChatSection> {
  final TextEditingController _messageController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Colors
  final Color primaryMaroon = const Color(0xFF6A1F1A);
  final Color myBubbleColor = const Color(0xFF8E3D2C);

  void _sendMessage() async {
    // DEBUG PRINT 1: Did we click it?
    print("--- ATTEMPTING TO SEND MESSAGE ---");
    
    final text = _messageController.text.trim();
    print("Input Text: '$text'");
    print("Project ID: '${widget.projectId}'");
    print("Role: '${widget.currentRole}'");

    if (text.isEmpty) {
      print("❌ STOPPING: Text is empty");
      return;
    }

    _messageController.clear(); 

    try {
      print("... Sending to Firebase 'project_messages' ...");
      await _firestore.collection('project_messages').add({
        'projectId': widget.projectId,
        'message': text,
        'senderRole': widget.currentRole,
        'createdAt': FieldValue.serverTimestamp(),
      });
      print("✅ SUCCESS: Message sent to database!");
    } catch (e) {
      print("🔥 ERROR: Could not send message. Reason: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('project_messages')
                .where('projectId', isEqualTo: widget.projectId)
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                 print("Stream Error: ${snapshot.error}");
                 return Center(child: Text("Error loading messages"));
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snapshot.data?.docs ?? [];
              print("Stream updated. Found ${docs.length} messages for this project.");

              if (docs.isEmpty) {
                return Center(
                  child: Text("No messages yet.", 
                    style: GoogleFonts.poppins(color: Colors.grey)),
                );
              }

              return ListView.builder(
                reverse: true,
                padding: const EdgeInsets.all(16),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  final message = data['message'] ?? '';
                  final role = data['senderRole'] ?? '';
                  
                  final isMe = role == widget.currentRole;

                  return Align(
                    alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.all(12),
                      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                      decoration: BoxDecoration(
                        color: isMe ? myBubbleColor : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(color: Colors.black12, blurRadius: 2, offset: const Offset(0, 1))
                        ],
                      ),
                      child: Text(
                        message,
                        style: GoogleFonts.poppins(
                          color: isMe ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.all(10),
          color: Colors.white,
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  // Enable Enter Key sending
                  onSubmitted: (_) => _sendMessage(),
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: "Type a message...",
                    hintStyle: GoogleFonts.poppins(color: Colors.grey),
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
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
}