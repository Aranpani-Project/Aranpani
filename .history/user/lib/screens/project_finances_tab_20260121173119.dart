import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ProjectFinancesTab extends StatelessWidget {
  final String projectId;
  final String userId;
  final double totalBudget; // Passed from the project document

  const ProjectFinancesTab({
    super.key,
    required this.projectId,
    required this.userId,
    required this.totalBudget,
  });

  static const Color primaryMaroon = Color(0xFF6A1F1A);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('transactions')
          .where('projectId', isEqualTo: projectId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];
        
        // Automation: Calculate Spent Amount from 'approved' transactions
        double spentAmount = 0;
        for (var doc in docs) {
          final data = doc.data();
          if (data['status'] == 'approved') {
            spentAmount += (data['amount'] ?? 0).toDouble();
          }
        }

        double balance = totalBudget - spentAmount;

        return Column(
          children: [
            _buildFinancialSummary(spentAmount, balance),
            const Divider(height: 1),
            Expanded(child: _buildTransactionHistory(docs)),
          ],
        );
      },
    );
  }

  Widget _buildFinancialSummary(double spent, double balance) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _summaryItem("Total Budget", "₹${totalBudget.toStringAsFixed(0)}", Colors.blue),
              _summaryItem("Spent", "₹${spent.toStringAsFixed(0)}", Colors.red),
              _summaryItem("Balance", "₹${balance.toStringAsFixed(0)}", Colors.green),
            ],
          ),
          const SizedBox(height: 15),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: totalBudget > 0 ? (spent / totalBudget) : 0,
              backgroundColor: Colors.grey[200],
              color: balance < 0 ? Colors.red : primaryMaroon,
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
        Text(value, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Widget _buildTransactionHistory(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    if (docs.isEmpty) {
      return Center(
        child: Text("No transaction history", style: GoogleFonts.poppins(color: Colors.grey)),
      );
    }

    // Sort docs by date (client-side if necessary, or orderBy in stream)
    final sortedDocs = List.from(docs);
    sortedDocs.sort((a, b) {
      Timestamp t1 = a.data()['date'] ?? Timestamp.now();
      Timestamp t2 = b.data()['date'] ?? Timestamp.now();
      return t2.compareTo(t1);
    });

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sortedDocs.length,
      itemBuilder: (context, index) {
        final data = sortedDocs[index].data();
        final status = data['status'] ?? 'pending';
        
        Color statusColor = Colors.orange;
        if (status == 'approved') statusColor = Colors.green;
        if (status == 'rejected') statusColor = Colors.red;

        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(
            side: BorderSide(color: Colors.grey.withOpacity(0.2)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: statusColor.withOpacity(0.1),
              child: Icon(Icons.account_balance_wallet, color: statusColor, size: 20),
            ),
            title: Text(data['title'] ?? 'Requested Amount', 
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(status.toString().toUpperCase(), 
                style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
            trailing: Text(
              "₹${data['amount']}",
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
        );
      },
    );
  }
}