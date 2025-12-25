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

  // Theme Constants
  static const Color maroonPrimary = Color(0xFF6A1F1A);
  static const Color maroonGradientEnd = Color(0xFF8E3D2C);
  static const Color goldAccent = Color(0xFFFFD700);
  static const Color creamBg = Color(0xFFFDF8EE);
  static const Color cardGoldBorder = Color(0xFFB6862C);

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
                padding: const EdgeInsets.all(16),
                children: [
                  _buildUserInfoCard(),
                  const SizedBox(height: 16),
                  _buildSiteImagesCard(),
                  const SizedBox(height: 16),
                  _buildLocationCard(),
                  const SizedBox(height: 16),
                  _buildProjectComponentCard(),
                  const SizedBox(height: 16),
                  _buildContactBudgetCard(),
                  const SizedBox(height: 24),
                  _buildSanctionRejectButtons(context),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // HEADER WITH MAROON & GOLD GRADIENT
  Widget _buildHeader(BuildContext context, String status) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [maroonPrimary, maroonGradientEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                onPressed: () => onUpdated(temple),
              ),
              const SizedBox(height: 8),
              Text(
                (temple['name'] ?? '') as String,
                style: GoogleFonts.poppins(
                  color: goldAccent,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${temple['projectNumber'] ?? 'P000'} • ${status.toUpperCase()}',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // REUSABLE STYLED CARD WRAPPER
  Widget _buildThemeCard({required IconData icon, required String title, required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: maroonPrimary.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: maroonPrimary.withOpacity(0.03),
              child: Row(
                children: [
                  Icon(icon, color: cardGoldBorder, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: maroonPrimary,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: child,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserInfoCard() {
    return _buildThemeCard(
      icon: Icons.person_pin_rounded,
      title: 'User Information',
      child: Column(
        children: [
          _buildInfoRow('Name', (temple['userName'] ?? '') as String),
          _buildInfoRow('Email', (temple['userEmail'] ?? '') as String),
          _buildInfoRow('Phone', (temple['userPhone'] ?? '') as String),
          _buildInfoRow('Aadhar', (temple['userAadhar'] ?? '') as String),
        ],
      ),
    );
  }

  Widget _buildSiteImagesCard() {
    final List<String> siteImages = List<String>.from(temple['imageUrls'] ?? <String>[]);
    return _buildThemeCard(
      icon: Icons.image_search_rounded,
      title: 'Site Images',
      child: siteImages.isEmpty
          ? const Text('No images uploaded yet', style: TextStyle(color: Colors.grey))
          : SizedBox(
              height: 180,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: siteImages.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      siteImages[index],
                      width: 260,
                      fit: BoxFit.cover,
                    ),
                  );
                },
              ),
            ),
    );
  }

  Widget _buildLocationCard() {
    return _buildThemeCard(
      icon: Icons.map_outlined,
      title: 'Location Details',
      child: Column(
        children: [
          _buildInfoRow('Place', (temple['place'] ?? '') as String),
          _buildInfoRow('District', (temple['district'] ?? '') as String),
          _buildInfoRow('Taluk', (temple['taluk'] ?? '') as String),
          _buildInfoRow('Map Link', (temple['mapLocation'] ?? 'Not provided') as String),
        ],
      ),
    );
  }

  Widget _buildProjectComponentCard() {
    final feature = (temple['feature'] ?? '') as String;
    return _buildThemeCard(
      icon: Icons.architecture_rounded,
      title: 'Component Detail',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF9E1),
          borderRadius: BorderRadius.circular(8),
          border: const Border(left: BorderSide(color: cardGoldBorder, width: 4)),
        ),
        child: Text(
          feature.isEmpty ? 'General Renovation' : feature,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: maroonPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildContactBudgetCard() {
    final double amount = double.tryParse((temple['estimatedAmount'] ?? '0').toString()) ?? 0.0;
    return _buildThemeCard(
      icon: Icons.payments_outlined,
      title: 'Budget Summary',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow('In-charge', (temple['contactName'] ?? temple['userName'] ?? '') as String),
          const Divider(height: 20),
          Text('ESTIMATED TOTAL', style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey, letterSpacing: 1.1)),
          Text(
            '₹${amount.toStringAsFixed(0)}',
            style: GoogleFonts.poppins(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: maroonGradientEnd,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  // SANCTION / REJECT BUTTONS
  Widget _buildSanctionRejectButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _handleAction(context, true),
            icon: const Icon(Icons.verified_user_rounded),
            label: const Text('SANCTION'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2D6A4F),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _handleAction(context, false),
            icon: const Icon(Icons.block_flipped),
            label: const Text('REJECT'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red[800],
              side: BorderSide(color: Colors.red[800]!),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  void _handleAction(BuildContext context, bool isSanction) async {
    final actionName = isSanction ? 'Sanction' : 'Reject';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text('$actionName Project?'),
        content: Text('Confirming will update the status of this temple request.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Go Back')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: isSanction ? Colors.green[700] : Colors.red[700],
            ),
            child: Text('Confirm $actionName'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (isSanction) {
        await FirebaseFirestore.instance.collection('projects').doc(temple['id']).update({
          'isSanctioned': true,
          'status': 'ongoing',
        });
        temple['isSanctioned'] = true;
        temple['status'] = 'ongoing';
        onUpdated(temple);
      } else {
        onDeleted();
      }
    }
  }
}