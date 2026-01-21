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

        // --- AUTOMATION CALCULATION ---
        double spentAmount = 0.0;
        
        for (var doc in docs) {
          final data = doc.data();
          final status = (data['status'] ?? 'pending').toString();

          // Calculate spent if approved OR paid
          if (status == 'approved' || status == 'paid') {
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
              _buildSummaryHeader(spentAmount, balance, progress),
              _buildHistoryLabel(),
              Expanded(
                child: _buildTransactionList(docs),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummaryHeader(double spent, double balance, double progress) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _amountColumn("Total", totalBudget, Colors.blueGrey),
              _amountColumn("Spent", spent, Colors.redAccent),
              _amountColumn("Balance", balance, balance < 0 ? Colors.red : Colors.green),
            ],
          ),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.grey[200],
              color: progress > 0.9 ? Colors.red : primaryMaroon,
            ),
          ),
        ],
      ),
    );
  }

  Widget _amountColumn(String label, double value, Color color) {
    return Column(
      children: [
        Text(label, style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey)),
        Text("₹${value.toStringAsFixed(0)}", 
          style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Widget _buildHistoryLabel() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.receipt_long, size: 18, color: primaryMaroon),
          const SizedBox(width: 8),
          Text("TRANSACTION LOG", 
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13, color: primaryMaroon)),
        ],
      ),
    );
  }

  Widget _buildTransactionList(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    if (docs.isEmpty) {
      return Center(child: Text("No transactions found", style: GoogleFonts.poppins(color: Colors.grey)));
    }

    // Sort Newest First
    final sorted = List.from(docs);
    sorted.sort((a, b) {
      final t1 = (a.data()['date'] as Timestamp?) ?? Timestamp.now();
      final t2 = (b.data()['date'] as Timestamp?) ?? Timestamp.now();
      return t2.compareTo(t1);
    });

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: sorted.length,
      itemBuilder: (context, index) {
        final data = sorted[index].data();
        final status = (data['status'] ?? 'pending').toString().toLowerCase();
        final txnId = data['transactionId']; // Get the Transaction ID
        
        Color statusColor = Colors.orange;
        if (status == 'approved' || status == 'paid') statusColor = Colors.green;
        if (status == 'rejected') statusColor = Colors.red;

        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            title: Text(data['title'] ?? 'Expense Request', 
              style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600)),
            
            // --- UPDATED SUBTITLE SECTION ---
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(status.toUpperCase(), 
                  style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor)),
                
                // Show Transaction ID if Paid
                if (status == 'paid' && txnId != null && txnId.toString().isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.green.withOpacity(0.3))
                    ),
                    child: Text(
                      "Txn ID: $txnId",
                      style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.green[800]),
                    ),
                  ),
              ],
            ),
            
            trailing: Text("₹${data['amount']}", 
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15)),
          ),
        );
      },
    );
  }
}