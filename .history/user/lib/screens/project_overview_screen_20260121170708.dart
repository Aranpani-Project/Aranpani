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

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return "N/A";
    final date = timestamp.toDate();
    return "${date.day}/${date.month}/${date.year}";
  }

  // ===================== FIX: FETCH PROJECT BUDGET =====================
  Future<double> _fetchProjectBudget() async {
    final snap =
        await _firestore.collection('projects').doc(_projectId).get();
    if (!snap.exists) return 0.0;
    final data = snap.data();
    return double.tryParse(data?['budget']?.toString() ?? '0') ?? 0.0;
  }

  // ===================== TRANSACTIONS TAB (LOGIC FIXED ONLY) =====================
  Widget _transactionsTab() {
    return FutureBuilder<double>(
      future: _fetchProjectBudget(),
      builder: (context, budgetSnap) {
        if (!budgetSnap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final double totalBudget = budgetSnap.data!;

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _firestore
              .collection('transactions')
              .where('projectId', isEqualTo: _projectId)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final docs = snapshot.data!.docs;

            final ongoingDocs = docs.where((d) =>
                d['status'] == 'pending' || d['status'] == 'approved').toList();

            final paidDocs = docs.where((d) =>
                d['status'] == 'completed' || d['status'] == 'paid').toList();

            double totalPaid = 0;
            for (var d in paidDocs) {
              totalPaid += (d['amount'] ?? 0).toDouble();
            }

            final double remainingAmount =
                (totalBudget - totalPaid) < 0 ? 0 : (totalBudget - totalPaid);

            return SingleChildScrollView(
              child: Column(
                children: [
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
                                color: Colors.white70, fontSize: 14)),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _budgetStat("Total", "₹$totalBudget"),
                            const VerticalDivider(color: Colors.white24),
                            _budgetStat("Remaining", "₹$remainingAmount",
                                color: Colors.greenAccent),
                          ],
                        ),
                      ],
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: ElevatedButton.icon(
                      onPressed: _showRequestAmountDialog,
                      icon: const Icon(Icons.add_card),
                      label: const Text('Request New Payment'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryMaroon,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                      ),
                    ),
                  ),

                  _financeSectionTitle("Ongoing Finances"),
                  if (ongoingDocs.isEmpty)
                    const Padding(
                        padding: EdgeInsets.all(20),
                        child: Text("No ongoing requests")),
                  ...ongoingDocs
                      .map((d) => _financeCard(d.data(), Colors.orange)),

                  _financeSectionTitle("Completed Finances"),
                  if (paidDocs.isEmpty)
                    const Padding(
                        padding: EdgeInsets.all(20),
                        child: Text("No payments completed yet")),
                  ...paidDocs
                      .map((d) => _financeCard(d.data(), Colors.green)),

                  const SizedBox(height: 20),
                  _completionRequestButton(),
                  const SizedBox(height: 80),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _budgetStat(String label, String value, {Color color = Colors.white}) {
    return Column(
      children: [
        Text(label,
            style: GoogleFonts.poppins(color: Colors.white60, fontSize: 12)),
        Text(value,
            style: GoogleFonts.poppins(
                color: color, fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _financeSectionTitle(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(title,
          style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: primaryMaroon)),
    );
  }

  Widget _financeCard(Map<String, dynamic> data, Color statusColor) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withOpacity(0.1),
          child: Icon(Icons.currency_rupee, color: statusColor),
        ),
        title: Text(data['title'] ?? 'Request',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle:
            Text("Requested on: ${_formatTimestamp(data['date'] as Timestamp?)}"),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text("₹${data['amount']}",
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text(data['status'].toString().toUpperCase(),
                style: TextStyle(
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _completionRequestButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: ElevatedButton.icon(
        onPressed:
            _isCompletionRequesting ? null : _requestProjectCompletion,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 50),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        icon: _isCompletionRequesting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.flag),
        label: Text(
            _isCompletionRequesting ? 'Sending...' : 'Request Project Completion'),
      ),
    );
  }

  // ===================== OTHER TABS (UNCHANGED) =====================
  // Activities, Bills, Feedback, dialogs, OngoingTaskCard
  // REMAIN EXACTLY AS IN YOUR ORIGINAL CODE

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundCream,
      appBar: AppBar(
        title: Text(widget.project['title'] ?? 'Project Overview',
            style: GoogleFonts.poppins(color: Colors.white)),
        backgroundColor: primaryMaroon,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Activities'),
            Tab(text: 'Finances'),
            Tab(text: 'Bills'),
            Tab(text: 'Feedback'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _activitiesTab(),
          _transactionsTab(),
          _billsTab(),
          ProjectChatSection(projectId: _projectId, currentRole: 'user'),
        ],
      ),
    );
  }
}
