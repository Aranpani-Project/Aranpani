import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import 'project_chat_section.dart';
import '../services/cloudinary_service.dart';

class ProjectOverviewScreen extends StatefulWidget {
  final Map<String, dynamic> project;
  const ProjectOverviewScreen({super.key, required this.project});

  @override
  State<ProjectOverviewScreen> createState() => _ProjectOverviewScreenState();
}

class _ProjectOverviewScreenState extends State<ProjectOverviewScreen>
    with SingleTickerProviderStateMixin {
  final _firestore = FirebaseFirestore.instance;
  late TabController _tabController;
  final ImagePicker _picker = ImagePicker();

  static const Color primaryMaroon = Color(0xFF6A1F1A);
  static const Color backgroundCream = Color(0xFFFFF7E8);

  String get _projectId => widget.project['id'] as String;
  String get _userId => (widget.project['userId'] ?? '') as String;

  CollectionReference<Map<String, dynamic>> get _billsRef =>
      _firestore.collection('bills');

  bool _isCompletionRequesting = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _formatTimestamp(Timestamp? ts) {
    if (ts == null) return "N/A";
    final d = ts.toDate();
    return "${d.day}/${d.month}/${d.year}";
  }

  // ===================== BUDGET AUTOMATION =====================

  Future<double> _fetchProjectBudget() async {
    final snap =
        await _firestore.collection('projects').doc(_projectId).get();
    if (!snap.exists) return 0.0;
    return double.tryParse(snap.data()?['budget']?.toString() ?? '0') ?? 0.0;
  }

  // ===================== FINANCES TAB (FIXED) =====================

  Widget _transactionsTab() {
    return FutureBuilder<double>(
      future: _fetchProjectBudget(),
      builder: (context, budgetSnap) {
        if (!budgetSnap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final totalBudget = budgetSnap.data!;

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _firestore
              .collection('transactions')
              .where('projectId', isEqualTo: _projectId)
              .orderBy('date', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final docs = snapshot.data!.docs;

            final ongoing = docs.where((d) =>
                d['status'] == 'pending' || d['status'] == 'approved').toList();

            final paid = docs.where((d) =>
                d['status'] == 'completed' || d['status'] == 'paid').toList();

            double totalPaid = 0;
            for (var d in paid) {
              totalPaid += (d['amount'] ?? 0).toDouble();
            }

            final remaining =
                (totalBudget - totalPaid) < 0 ? 0 : (totalBudget - totalPaid);

            return SingleChildScrollView(
              child: Column(
                children: [
                  // ===== Budget Card =====
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: primaryMaroon,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Column(
                      children: [
                        Text("Project Budget Status",
                            style: GoogleFonts.poppins(
                                color: Colors.white70)),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _budgetStat("Total", "₹$totalBudget"),
                            const VerticalDivider(color: Colors.white24),
                            _budgetStat("Remaining", "₹$remaining",
                                color: Colors.greenAccent),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // ===== Action Buttons =====
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        ElevatedButton.icon(
                          onPressed: _showRequestAmountDialog,
                          icon: const Icon(Icons.add_card),
                          label: const Text('Request Amount from Admin'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryMaroon,
                            foregroundColor: Colors.white,
                            minimumSize:
                                const Size(double.infinity, 50),
                          ),
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton.icon(
                          onPressed: _isCompletionRequesting
                              ? null
                              : _requestProjectCompletion,
                          icon: const Icon(Icons.flag),
                          label: const Text('Request Project Completion'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            minimumSize:
                                const Size(double.infinity, 50),
                          ),
                        ),
                      ],
                    ),
                  ),

                  _financeTitle("Ongoing Payments"),
                  if (ongoing.isEmpty)
                    const Padding(
                        padding: EdgeInsets.all(20),
                        child: Text("No ongoing requests")),
                  ...ongoing.map((d) =>
                      _financeCard(d.data(), Colors.orange)),

                  _financeTitle("Paid Payments"),
                  if (paid.isEmpty)
                    const Padding(
                        padding: EdgeInsets.all(20),
                        child: Text("No completed payments")),
                  ...paid.map((d) =>
                      _financeCard(d.data(), Colors.green)),

                  const SizedBox(height: 80),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _budgetStat(String label, String value,
      {Color color = Colors.white}) {
    return Column(
      children: [
        Text(label,
            style: GoogleFonts.poppins(
                color: Colors.white60, fontSize: 12)),
        Text(value,
            style: GoogleFonts.poppins(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _financeTitle(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(title,
          style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: primaryMaroon)),
    );
  }

  Widget _financeCard(Map<String, dynamic> data, Color color) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          child: Icon(Icons.currency_rupee, color: color),
        ),
        title: Text(data['title'] ?? 'Request',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle:
            Text("Date: ${_formatTimestamp(data['date'])}"),
        trailing: Text(
          "₹${data['amount']}",
          style: const TextStyle(
              fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
    );
  }

  // ===================== OTHER TABS (UNCHANGED) =====================

  // All your existing methods:
  // _showAddWorkDialog
  // _showRequestAmountDialog
  // _showUploadBillDialog
  // _billsTab
  // _activitiesTab
  // task lists
  // completion logic
  // OngoingTaskCard
  // TabBar + build()
  // (unchanged from your provided code)

  // --------------------------------------------------------------
  // ⚠️ For brevity here, those methods remain EXACTLY as you sent.
  // --------------------------------------------------------------

}
