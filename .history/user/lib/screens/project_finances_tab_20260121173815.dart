import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ProjectFinancesTab extends StatelessWidget {
  final String projectId;
  final String userId;
  final double totalBudget;

  const ProjectFinancesTab({
    super.key,
    required this.projectId,
    required this.userId,
    required this.totalBudget,
  });

  static const Color primaryMaroon = Color(0xFF6A1F1A);
  static const Color backgroundCream = Color(0xFFFFF7E8);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      // Listen to transactions specifically for this project
      stream: FirebaseFirestore.instance
          .collection('transactions')
          .where('projectId', isEqualTo: projectId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: primaryMaroon));
        }

        final docs = snapshot.data?.docs ?? [];

        // --- AUTOMATION ENGINE ---
        // We calculate these values locally based on the real-time stream
        double spentAmount = 0.0;
        
        for (var doc in docs) {
          final data = doc.data();
          // ONLY count approved transactions toward 'Spent'
          if (data['status'] == 'approved') {
            final val = data['amount'];
            if (val is num) {
              spentAmount += val.toDouble();
            } else if (val is String) {
              spentAmount += double.tryParse(val) ?? 0.0;
            }
          }
        }

        double balance = totalBudget - spentAmount;
        double progress = totalBudget > 0 ? (spentAmount / totalBudget).clamp(0.0, 1.0) : 0.0;

        return Container(
          color: backgroundCream,
          child: Column(
            children: [
              _buildHeaderCard(spentAmount, balance, progress),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 20, 20, 10),
                child: Row(
                  children: [
                    Icon(Icons.history, size: 18, color: primaryMaroon),
                    SizedBox(width: 8),
                    Text(
                      "Transaction History",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: primaryMaroon,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _buildTransactionList(docs),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeaderCard(double spent, double balance, double progress) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _statItem("Total Budget", "₹$totalBudget", Colors.blueGrey),
              _statItem("Spent", "₹$spent", Colors.redAccent),
              _statItem("Remaining", "₹$balance", balance < 0 ? Colors.red : Colors.green),
            ],
          ),
          const SizedBox(height: 25),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: Colors.grey[200],
              color: progress > 0.9 ? Colors.red : primaryMaroon,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            "${(progress * 100).toStringAsFixed(1)}% of budget utilized",
            style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 5),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionList(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    if (docs.isEmpty) {
      return Center(
        child: Text(
          "No payment requests yet",
          style: GoogleFonts.poppins(color: Colors.grey),
        ),
      );
    }

    // Sort: Newest requests at the top
    final sortedDocs = List.from(docs);
    sortedDocs.sort((a, b) {
      final t1 = (a.data()['date'] as Timestamp?) ?? Timestamp.now();
      final t2 = (b.data()['date'] as Timestamp?) ?? Timestamp.now();
      return t2.compareTo(t1);
    });

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: sortedDocs.length,
      itemBuilder: (context, index) {
        final data = sortedDocs[index].data();
        final status = data['status'] ?? 'pending';
        
        Color statusColor;
        switch (status) {
          case 'approved': statusColor = Colors.green; break;
          case 'rejected': statusColor = Colors.red; break;
          default: statusColor = Colors.orange;
        }

        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: ListTile(
            title: Text(
              data['title'] ?? 'Request',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              status.toString().toUpperCase(),
              style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  "₹${data['amount']}",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  _formatDate(data['date']),
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp is Timestamp) {
      DateTime dt = timestamp.toDate();
      return "${dt.day}/${dt.month}/${dt.year}";
    }
    return "";
  }
}