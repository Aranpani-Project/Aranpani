import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'temple_detail_screen.dart';

class PlaceTemplesScreen extends StatefulWidget {
  final String placeId;

  const PlaceTemplesScreen({
    super.key,
    required this.placeId,
  });

  @override
  State<PlaceTemplesScreen> createState() => _PlaceTemplesScreenState();
}

class _PlaceTemplesScreenState extends State<PlaceTemplesScreen> {
  // --- Aranpani Theme Tokens ---
  static const Color primaryMaroon = Color(0xFF6D1B1B);
  static const Color primaryAccentGold = Color(0xFFD4AF37);
  static const Color secondaryGold = Color(0xFFB8962E);
  static const Color backgroundCream = Color(0xFFFFF7E8);
  static const Color softParchment = Color(0xFFFFFBF2);
  static const Color darkMaroonText = Color(0xFF4A1010);
  static const Color lightGoldText = Color(0xFFFFF4D6);

  bool isLoading = true;
  String placeName = '';
  String districtName = '';
  List<Map<String, dynamic>> temples = [];
  int statusTab = 0;

  List<Map<String, dynamic>> get pending =>
      temples.where((t) => t['status'] == 'pending').toList();

  List<Map<String, dynamic>> get ongoing =>
      temples.where((t) => t['status'] == 'ongoing').toList();

  List<Map<String, dynamic>> get completed =>
      temples.where((t) => t['status'] == 'completed').toList();

  List<Map<String, dynamic>> get currentList {
    if (statusTab == 0) return pending;
    if (statusTab == 1) return ongoing;
    return completed;
  }

  @override
  void initState() {
    super.initState();
    _loadTemples();
  }

  Future<void> _loadTemples() async {
    setState(() => isLoading = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('projects')
          .where('taluk', isEqualTo: widget.placeId)
          .get();

      placeName = widget.placeId;

      if (snap.docs.isNotEmpty) {
        districtName = (snap.docs.first.data()['district'] ?? '').toString();
      }

      final Set<String> userIds = {};
      for (final doc in snap.docs) {
        final uid = (doc.data()['userId'] ?? '').toString();
        if (uid.isNotEmpty) userIds.add(uid);
      }

      final Map<String, Map<String, dynamic>> usersById = {};
      if (userIds.isNotEmpty) {
        final userSnap = await FirebaseFirestore.instance
            .collection('users')
            .where(FieldPath.documentId, whereIn: userIds.toList())
            .get();

        for (final u in userSnap.docs) {
          usersById[u.id] = u.data();
        }
      }

      temples = snap.docs.map((doc) {
        final data = doc.data();
        final uid = (data['userId'] ?? '').toString();
        final userData = usersById[uid] ?? {};

        final bool isSanctioned = data['isSanctioned'] == true;
        final int progress = ((data['progress'] ?? 0) as num).toInt();

        String status;
        if (!isSanctioned) {
          status = 'pending';
        } else if (progress >= 100) {
          status = 'completed';
        } else {
          status = 'ongoing';
        }

        return <String, dynamic>{
          'id': doc.id,
          'district': data['district'] ?? '',
          'taluk': data['taluk'] ?? '',
          'place': data['place'] ?? '',
          'feature': data['feature'] ?? '',
          'featureType': data['featureType'] ?? '',
          'featureDimension': data['featureDimension'] ?? '',
          'featureAmount': double.tryParse((data['featureAmount'] ?? '0').toString()) ?? 0.0,
          'name': (data['feature'] != null && data['feature'] != '')
              ? '${data['feature']} Project'
              : 'Temple Project',
          'status': status,
          'progress': progress,
          'isSanctioned': isSanctioned,
          'userName': userData['name'] ?? data['contactName'] ?? '',
          'userEmail': userData['email'] ?? '',
          'userPhone': userData['phoneNumber'] ?? data['contactPhone'] ?? '',
          'estimatedAmount': double.tryParse((data['estimatedAmount'] ?? '0').toString()) ?? 0.0,
          'imageUrls': List<String>.from(data['imageUrls'] ?? []),
          'submittedDate': (data['dateCreated'] != null && data['dateCreated'] is Timestamp)
              ? (data['dateCreated'] as Timestamp).toDate().toIso8601String().substring(0, 10)
              : '',
          'raw': data,
        };
      }).toList();
    } catch (e) {
      debugPrint('Error loading temples: $e');
      temples = [];
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundCream,
      body: Column(
        children: [
          // Header with Temple Maroon Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [primaryMaroon, Color(0xFF4A1010)],
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: lightGoldText),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Text(
                      placeName,
                      style: const TextStyle(
                        color: lightGoldText,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      districtName.isEmpty ? 'Temple Projects' : '$districtName District',
                      style: const TextStyle(color: primaryAccentGold, fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _buildStatusTab('Pending (${pending.length})', 0),
                        _buildStatusTab('Ongoing (${ongoing.length})', 1),
                        _buildStatusTab('Completed (${completed.length})', 2),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator(color: primaryMaroon))
                : currentList.isEmpty
                    ? const Center(
                        child: Text(
                          'No projects found',
                          style: TextStyle(fontSize: 16, color: darkMaroonText),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: currentList.length,
                        itemBuilder: (context, index) {
                          final temple = currentList[index];
                          return _buildTempleCard(temple);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusTab(String label, int index) {
    final isActive = statusTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => statusTab = index),
        child: Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? primaryAccentGold : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isActive ? primaryAccentGold : lightGoldText.withOpacity(0.3),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isActive ? primaryMaroon : lightGoldText,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTempleCard(Map<String, dynamic> temple) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: primaryAccentGold, width: 0.5),
      ),
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(
          temple['name'],
          style: const TextStyle(fontWeight: FontWeight.bold, color: darkMaroonText),
        ),
        subtitle: Text(
          temple['userName'],
          style: TextStyle(color: darkMaroonText.withOpacity(0.7)),
        ),
        trailing: const Icon(Icons.chevron_right, color: primaryMaroon),
        onTap: () async {
          final updated = await Navigator.push<Map<String, dynamic>?>(
            context,
            MaterialPageRoute(
              builder: (_) => TempleDetailScreen(
                templeId: temple['id'],
                initialTempleData: temple,
              ),
            ),
          );

          if (updated == null) {
            setState(() {
              temples.removeWhere((t) => t['id'] == temple['id']);
            });
          } else {
            final idx = temples.indexWhere((t) => t['id'] == updated['id']);
            if (idx != -1) {
              setState(() {
                temples[idx] = updated;
              });
            }
          }
        },
      ),
    );
  }
}