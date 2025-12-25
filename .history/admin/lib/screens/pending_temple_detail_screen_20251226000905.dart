import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PendingTempleDetailScreen extends StatelessWidget {
  final Map<String, dynamic> temple;
  final void Function(Map<String, dynamic>?) onUpdated;
  final VoidCallback onDeleted;

  const PendingTempleDetailScreen({
    Key? key,
    required this.temple,
    required this.onUpdated,
    required this.onDeleted,
  }) : super(key: key);

  // --- Locked Theme Constants ---
  static const Color maroonDeep = Color(0xFF6A1B1A);
  static const Color maroonLight = Color(0xFF8E3D2C);
  static const Color goldAccent = Color(0xFFFFD700);
  static const Color creamBg = Color(0xFFFFFBF2);
  static const Color textDark = Color(0xFF2D2D2D);

  @override
  Widget build(BuildContext context) {
    final status = (temple['status'] ?? 'pending') as String;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        onUpdated(temple);
        Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: creamBg,
        body: Column(
          children: [
            _buildHeader(context, status),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                children: [
                  _buildSectionCard(
                    icon: Icons.person_outline_rounded,
                    title: 'User Information',
                    child: Column(
                      children: [
                        _buildInfoRow('Name', (temple['userName'] ?? '') as String),
                        _buildInfoRow('Email', (temple['userEmail'] ?? '') as String),
                        _buildInfoRow('Phone', (temple['userPhone'] ?? '') as String),
                        _buildInfoRow('Aadhar', (temple['userAadhar'] ?? '') as String),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildSiteImagesCard(),
                  const SizedBox(height: 16),
                  _buildSectionCard(
                    icon: Icons.location_on_outlined,
                    title: 'Location Details',
                    child: Column(
                      children: [
                        _buildInfoRow('Place', (temple['place'] ?? '') as String),
                        _buildInfoRow('District', (temple['district'] ?? '') as String),
                        _buildInfoRow('Taluk', (temple['taluk'] ?? '') as String),
                        _buildInfoRow('Map Link', (temple['mapLocation'] ?? 'Not provided') as String),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildProjectComponentCard(),
                  const SizedBox(height: 16),
                  _buildContactBudgetCard(),
                  const SizedBox(height: 24),
                  _buildActionButtons(context),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // HEADER: Maroon Gradient with Gold Accents
  Widget _buildHeader(BuildContext context, String status) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [maroonDeep, maroonLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: goldAccent, size: 20),
                onPressed: () => onUpdated(temple),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (temple['name'] ?? 'Temple Name') as String,
                      style: GoogleFonts.philosopher(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ID: ${temple['projectNumber'] ?? 'P000'} • ${status.toUpperCase()}',
                      style: GoogleFonts.poppins(
                        color: goldAccent.withOpacity(0.9),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Generic Themed Card Wrapper
  Widget _buildSectionCard({required IconData icon, required String title, required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: maroonDeep.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Icon(icon, color: maroonLight, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: GoogleFonts.philosopher(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                    color: maroonDeep,
                  ),
                ),
              ],
            ),
          ),
          const Divider(indent: 16, endIndent: 16),
          Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _buildSiteImagesCard() {
    final List<String> siteImages = List<String>.from(temple['imageUrls'] ?? <String>[]);
    return _buildSectionCard(
      icon: Icons.camera_alt_outlined,
      title: 'Site Gallery',
      child: siteImages.isEmpty
          ? const Text('No images available')
          : SizedBox(
              height: 160,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: siteImages.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) => ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(siteImages[index], width: 220, fit: BoxFit.cover),
                ),
              ),
            ),
    );
  }

  Widget _buildProjectComponentCard() {
    final feature = (temple['feature'] ?? 'General Renovation') as String;
    return _buildSectionCard(
      icon: Icons.architecture,
      title: 'Project Focus',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: maroonDeep.withOpacity(0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border(left: BorderSide(color: goldAccent, width: 4)),
        ),
        child: Text(
          feature,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: maroonDeep),
        ),
      ),
    );
  }

  Widget _buildContactBudgetCard() {
    final double amount = double.tryParse((temple['estimatedAmount'] ?? '0').toString()) ?? 0.0;
    return _buildSectionCard(
      icon: Icons.account_balance_wallet_outlined,
      title: 'Budget & Contact',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow('Local POC', (temple['contactName'] ?? temple['userName'] ?? '') as String),
          const SizedBox(height: 12),
          Text('ESTIMATED BUDGET', style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey, letterSpacing: 1.2)),
          Text(
            '₹${amount.toStringAsFixed(0)}',
            style: GoogleFonts.philosopher(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: maroonDeep,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(label, style: GoogleFonts.poppins(color: Colors.grey, fontSize: 13)),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(fontWeight: FontWeight.w500, fontSize: 13, color: textDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: () => _handleSanction(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2D6A4F), // Forest Green
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: const Text('SANCTION', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.1)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton(
            onPressed: () => _handleReject(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red[800],
              side: BorderSide(color: Colors.red[800]!),
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('REJECT', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.1)),
          ),
        ),
      ],
    );
  }

  // --- Logic Functions ---

  void _handleSanction(BuildContext context) async {
    final confirm = await _showDialog(context, 'Sanction Project', 'Move this project to the ongoing phase?', Colors.green);
    if (confirm == true) {
      final docId = (temple['id'] ?? '') as String;
      await FirebaseFirestore.instance.collection('projects').doc(docId).update({
        'isSanctioned': true,
        'status': 'ongoing',
      });
      temple['isSanctioned'] = true;
      temple['status'] = 'ongoing';
      onUpdated(temple);
    }
  }

  void _handleReject(BuildContext context) async {
    final confirm = await _showDialog(context, 'Reject Project', 'This will remove the application permanently.', Colors.red);
    if (confirm == true) onDeleted();
  }

  Future<bool?> _showDialog(BuildContext context, String title, String msg, Color color) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: GoogleFonts.philosopher(fontWeight: FontWeight.bold)),
        content: Text(msg),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: color),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }
}