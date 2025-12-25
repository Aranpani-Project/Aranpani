import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

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

  // HEADER
  Widget _buildHeader(BuildContext context, String status) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
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
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${temple['projectNumber'] ?? 'P000'} - ${status.toUpperCase()}',
                style: const TextStyle(
                  color: Color(0xFFC7D2FE),
                  fontSize: 14,
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.people, color: Color(0xFF4F46E5)),
                SizedBox(width: 8),
                Text(
                  'User Information',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _buildInfoRow('Name:', (temple['userName'] ?? '') as String),
            _buildInfoRow('Email:', (temple['userEmail'] ?? '') as String),
            _buildInfoRow('Phone:', (temple['userPhone'] ?? '') as String),
            _buildInfoRow('Aadhar:', (temple['userAadhar'] ?? '') as String),
          ],
        ),
      ),
    );
  }

  // SITE IMAGES (from imageUrls)
  Widget _buildSiteImagesCard() {
    final List<String> siteImages =
        List<String>.from(temple['imageUrls'] ?? <String>[]);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Site Images',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const Divider(height: 24),
            if (siteImages.isEmpty)
              const Text(
                'No site images available.',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              )
            else
              SizedBox(
                height: 180,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: siteImages.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final url = siteImages[index];
                    return GestureDetector(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (_) => Dialog(
                            child: InteractiveViewer(
                              child: Image.network(
                                url,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        );
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          url,
                          width: 240,
                          height: 180,
                          fit: BoxFit.cover,
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  // LOCATION CARD
  Widget _buildLocationCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.location_on, color: Color(0xFF4F46E5)),
                SizedBox(width: 8),
                Text(
                  'Location Details',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _buildInfoRow('Place:', (temple['place'] ?? '') as String),
            _buildInfoRow(
                'Nearby Town:', (temple['nearbyTown'] ?? '') as String),
            _buildInfoRow('Taluk:', (temple['taluk'] ?? '') as String),
            _buildInfoRow('District:', (temple['district'] ?? '') as String),
            _buildInfoRow(
                'Map Location:', (temple['mapLocation'] ?? '') as String),
          ],
        ),
      ),
    );
  }

  // PROJECT COMPONENT (feature / type / dimension / amount)
  Widget _buildProjectComponentCard() {
    final feature = (temple['feature'] ?? '') as String;
    final featureType = (temple['featureType'] ?? '') as String;
    final featureDimension = (temple['featureDimension'] ?? '') as String;
    final double featureAmount =
        double.tryParse((temple['featureAmount'] ?? '0').toString()) ?? 0.0;

    final typeLabel = featureType.isEmpty
        ? '-'
        : '${featureType[0].toUpperCase()}${featureType.substring(1)}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Project Component',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const Divider(height: 24),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: const Border(
                  left: BorderSide(
                    color: Color(0xFF4F46E5),
                    width: 4,
                  ),
                ),
                color: Colors.grey.shade50,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    feature.isEmpty ? 'Feature not selected' : feature,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Type: $typeLabel',
                    style: const TextStyle(fontSize: 13),
                  ),
                  if (featureDimension.isNotEmpty)
                    Text(
                      'Dimension: $featureDimension',
                      style: const TextStyle(fontSize: 13),
                    ),
                  if (featureAmount > 0)
                    Text(
                      'Feature Amount: ₹${featureAmount.toStringAsFixed(0)}',
                      style: const TextStyle(fontSize: 13),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // CONTACT & BUDGET
  Widget _buildContactBudgetCard() {
    final double estimatedAmount =
        double.tryParse((temple['estimatedAmount'] ?? '0').toString()) ?? 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Contact & Budget',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const Divider(height: 24),
            _buildInfoRow(
              'Local Contact:',
              (temple['contactName'] ??
                      temple['localPerson'] ??
                      temple['userName'] ??
                      '') as String,
            ),
            _buildInfoRow(
              'Contact Phone:',
              (temple['contactPhone'] ?? temple['userPhone'] ?? '') as String,
            ),
            const SizedBox(height: 8),
            const Text(
              'Estimated Amount:',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            Text(
              '₹${estimatedAmount.toStringAsFixed(0)}',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF4F46E5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  // SANCTION / REJECT
  Widget _buildSanctionRejectButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Sanction Project'),
                  content: const Text(
                      'Are you sure you want to sanction this project?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                      ),
                      child: const Text('Sanction'),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                final docId = (temple['id'] ?? '') as String;

                // Update in Firestore: mark sanctioned/approved
                await FirebaseFirestore.instance
                    .collection('projects')
                    .doc(docId)
                    .update({
                  'isSanctioned': true,
                  'status': 'approved',
                  'progress': temple['progress'] ?? 0,
                });

                // Update local copy and send back -> router will open ongoing screen
                temple['isSanctioned'] = true;
                temple['status'] = 'ongoing';
                onUpdated(temple);
              }
            },
            icon: const Icon(Icons.check),
            label: const Text('Sanction'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Reject Project'),
                  content: const Text(
                    'Are you sure you want to reject this project? This action cannot be undone.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      child: const Text('Reject'),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                // Optional: delete/mark removed in Firestore
                onDeleted();
              }
            },
            icon: const Icon(Icons.close),
            label: const Text('Reject'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      ],
    );
  }
}
