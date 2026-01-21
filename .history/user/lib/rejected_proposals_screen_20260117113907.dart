import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class RejectedProposalsScreen extends StatelessWidget {
  const RejectedProposalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFFFFDF5),
      appBar: AppBar(
        title: Text(
          'Rejected History',
          style: GoogleFonts.cinzel(fontWeight: FontWeight.bold, color: const Color(0xFF3E2723)),
        ),
        backgroundColor: const Color(0xFFF5E6CA),
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF5D4037)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('projects')
            .where('userId', isEqualTo: user?.uid)
            .where('status', isEqualTo: 'archived_rejected') // Fetches moved/deleted rejected projects
            .orderBy('dateCreated', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF5D4037)));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.folder_off_outlined, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    "No rejected history found.",
                    style: GoogleFonts.poppins(color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final doc = snapshot.data!.docs[index];
              final data = doc.data() as Map<String, dynamic>;
              return _buildRejectedCard(data);
            },
          );
        },
      ),
    );
  }

  Widget _buildRejectedCard(Map<String, dynamic> data) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.red.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Project ID on Top Left
          Text(
            data['projectId'] ?? 'No ID',
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.red[900],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            data['place'] ?? 'Unnamed Temple',
            style: GoogleFonts.cinzel(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF3E2723),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.location_on, size: 14, color: Color(0xFF8D6E63)),
              const SizedBox(width: 4),
              Text(
                "${data['taluk']}, ${data['district']}",
                style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF8D6E63)),
              ),
            ],
          ),
          const Divider(height: 24),
          
          // Details of submission
          Text("SUBMISSION DETAILS:", 
            style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey[600])),
          const SizedBox(height: 8),
          
          _detailRow("Estimated Cost", "₹${data['estimatedAmount']}"),
          _detailRow("Visit Date", data['visitDate'] != null 
              ? DateFormat('dd-MM-yyyy').format((data['visitDate'] as Timestamp).toDate()) 
              : "N/A"),
          
          const SizedBox(height: 8),
          Text("Features Selected:", 
            style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            children: (data['features'] as List? ?? []).map((f) {
              final feature = f as Map<String, dynamic>;
              return Chip(
                label: Text("${feature['label']}: ${feature['condition'].toString().toUpperCase()}"),
                backgroundColor: const Color(0xFFFFF9C4),
                labelStyle: const TextStyle(fontSize: 9, color: Colors.black87),
                visualDensity: VisualDensity.compact,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[700])),
          Text(value, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF3E2723))),
        ],
      ),
    );
  }
}