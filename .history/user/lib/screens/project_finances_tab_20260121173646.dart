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
          return Center(child: Text("Error loading finances: ${snapshot.error}"));
        }
        
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: primaryMaroon));
        }

        final docs = snapshot.data?.docs ?? [];
        
        // --- FIX: Robust Automation Logic ---
        double spentAmount = 0.0;
        
        for (var doc in docs) {
          final data = doc.data();
          // Only add to 'Spent' if the admin has marked it as 'approved'
          if (data['status'] == 'approved') {
            // Force conversion to double to avoid type errors
            final val = data['amount'];
            if (val is num) {
              spentAmount += val.toDouble();
            } else if (val is String) {
              spentAmount += double.tryParse(val) ?? 0.0;
            }
          }
        }

        double balance = totalBudget - spentAmount;

        return Column(
          children: [
            _buildFinancialSummary(spentAmount, balance),
            const Divider(height: 1),
            Expanded(
              child: Container(
                color: const Color(0xFFFFF7E8), // Matching your cream background
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Transaction History",
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: primaryMaroon,
                            ),
                          ),
                          if (snapshot.isDataDirectlyFromCache == false)
                            const Icon(Icons.sync, size: 14, color: Colors.green),
                        ],
                      ),
                    ),
                    Expanded(child: _buildTransactionHistory(docs)),
                  ],
                ),
              ),
            ),
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
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _summaryItem("Total Budget", "₹${totalBudget.toStringAsFixed(0)}", Colors.blue),
              _summaryItem("Spent", "₹${spent.toStringAsFixed(0)}", Colors.red),
              _summaryItem("Balance", "₹${balance.toStringAsFixed(0)}", balance < 0 ? Colors.red : Colors.green),
            ],
          ),
          const SizedBox(height: 20),
          // Progress bar to show budget depletion
          Stack(
            children: [
              Container(
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              FractionallySizedBox(
                widthFactor: totalBudget > 0 ? (spent / totalBudget).clamp(0, 1) : 0,
                child: Container(
                  height: 12,
                  decoration: BoxDecoration(
                    color: (spent > totalBudget) ? Colors.red : primaryMaroon,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600])),
        const SizedBox(height: 4),
        Text(value, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Widget _buildTransactionHistory(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    if (docs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 8),
            Text("No requests found", style: GoogleFonts.poppins(color: Colors.grey)),
          ],
        ),
      );
    }

    // Sort locally by date descending
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
        IconData statusIcon;
        switch (status) {
          case 'approved':
            statusColor = Colors.green;
            statusIcon = Icons.check_circle_outline;
            break;
          case 'rejected':
            statusColor = Colors.red;
            statusIcon = Icons.cancel_outlined;
            break;
          default:
            statusColor = Colors.orange;
            statusIcon = Icons.hourglass_empty;
        }

        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            side: BorderSide(color: Colors.grey.withOpacity(0.1)),
            borderRadius: BorderRadius.circular(15),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: statusColor.withOpacity(0.1),
              child: Icon(statusIcon, color: statusColor, size: 20),
            ),
            title: Text(data['title'] ?? 'Request', 
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                status.toString().toUpperCase(), 
                style: GoogleFonts.poppins(
                  color: statusColor, 
                  fontSize: 10, 
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5
                ),
              ),
            ),
            trailing: Text(
              "₹${data['amount']}",
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold, 
                fontSize: 16, 
                color: primaryMaroon
              ),
            ),
          ),
        );
      },
    );
  }
}