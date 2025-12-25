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

  @override
  Widget build(BuildContext context) {
    final status = (temple['status'] ?? 'pending') as String;

    return WillPopScope(
      onWillPop: () async {
        onUpdated(temple);
        return false;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFFDF8EE), // Light cream background
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
                  const SizedBox(height: 16),
                  _buildSanctionRejectButtons(context),
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
          colors: [Color(0xFF6A1F1A), Color(0xFF8E3D2C)], // Maroon Gradient
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => onUpdated(temple),
              ),
              Text(
                (temple['name'] ?? '') as String,
                style: GoogleFonts.poppins(
                  color: const Color(0xFFFFD700), // Gold text
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${temple['projectNumber'] ?? 'P000'} • ${status.toUpperCase()}',
                style: GoogleFonts.poppins(
                  color: Colors.white70,
                  fontSize: 14,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // USER INFO
  Widget _buildUserInfoCard() {
    return _customCard(
      icon: Icons.person_pin_rounded,
      title: 'User Information',
      child: Column(
        children: [
          _buildInfoRow('Name:', (temple['userName'] ?? '') as String),
          _buildInfoRow('Email:', (temple['userEmail'] ?? '') as String),
          _buildInfoRow('Phone:', (temple['userPhone'] ?? '') as String),
          _buildInfoRow('Aadhar:', (temple['userAadhar'] ?? '') as String),
        ],
      ),
    );
  }

  // SITE IMAGES
  Widget _buildSiteImagesCard() {
    final List<String> siteImages = List<String>.from(temple['imageUrls'] ?? <String>[]);

    return _customCard(
      icon: Icons.image_search_rounded,
      title: 'Site Images',
      child: siteImages.isEmpty
          ? const Text('No site images available.', style: TextStyle(color: Colors.grey))
          : SizedBox(
              height: 180,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: siteImages.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      siteImages[index],
                      width: 240,
                      fit: BoxFit.cover,
                    ),
                  );
                },
              ),
            ),
    );
  }

  // LOCATION CARD
  Widget _buildLocationCard() {
    return _customCard(
      icon: Icons.map_rounded,
      title: 'Location Details',
      child: Column(
        children: [
          _buildInfoRow('Place:', (temple['place'] ?? '') as String),
          _buildInfoRow('Nearby Town:', (temple['nearbyTown'] ?? '') as String),
          _buildInfoRow('District:', (temple['district'] ?? '') as String),
          _buildInfoRow('Map:', (temple['mapLocation'] ?? 'Not provided') as String),
        ],
      ),
    );
  }

  // PROJECT COMPONENT
  Widget _buildProjectComponentCard() {
    final feature = (temple['feature'] ?? '') as String;
    return _customCard(
      icon: Icons.account_tree_rounded,
      title: 'Project Component',
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF7E8),
          borderRadius: BorderRadius.circular(8),
          border: const Border(left: BorderSide(color: Color(0xFFB6862C), width: 4)),
        ),
        child: Text(
          feature.isEmpty ? 'Feature not selected' : feature,
          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF6A1F1A)),
        ),
      ),
    );
  }

  // BUDGET CARD
  Widget _buildContactBudgetCard() {
    final double estimatedAmount = double.tryParse((temple['estimatedAmount'] ?? '0').toString()) ?? 0.0;
    return _customCard(
      icon: Icons.payments_rounded,
      title: 'Budget Information',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow('Local Contact:', (temple['contactName'] ?? temple['userName'] ?? '') as String),
          const SizedBox(height: 10),
          const Text('Estimated Budget', style: TextStyle(color: Colors.grey, fontSize: 12)),
          Text(
            '₹${estimatedAmount.toStringAsFixed(0)}',
            style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.bold, color: const Color(0xFF8E3D2C)),
          ),
        ],
      ),
    );
  }

  // REUSABLE CARD WRAPPER
  Widget _customCard({required IconData icon, required String title, required Widget child}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: const Color(0xFFB6862C), size: 20),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF6A1F1A))),
              ],
            ),
            const Divider(height: 24, thickness: 1),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14)),
          const SizedBox(width: 8),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
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
            icon: const Icon(Icons.verified_rounded),
            label: const Text('SANCTION'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _handleAction(context, false),
            icon: const Icon(Icons.cancel_outlined),
            label: const Text('REJECT'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red[700],
              side: BorderSide(color: Colors.red[700]!),
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
        title: Text('$actionName Project'),
        content: Text('Are you sure you want to $actionName this temple request?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Back')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: isSanction ? Colors.green : Colors.red),
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