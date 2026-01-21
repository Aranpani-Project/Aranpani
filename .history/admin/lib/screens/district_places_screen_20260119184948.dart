import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'place_temples_screen.dart';

class DistrictPlacesScreen extends StatefulWidget {
  final String districtId;

  const DistrictPlacesScreen({
    Key? key,
    required this.districtId,
  }) : super(key: key);

  @override
  State<DistrictPlacesScreen> createState() => _DistrictPlacesScreenState();
}

class _DistrictPlacesScreenState extends State<DistrictPlacesScreen> {
  // --- Locked Aranpani Theme ---
  static const Color primaryMaroon = Color(0xFF6D1B1B);
  static const Color primaryAccentGold = Color(0xFFD4AF37);
  static const Color secondaryGold = Color(0xFFB8962E);
  static const Color backgroundCream = Color(0xFFFFF7E8);
  static const Color softParchment = Color(0xFFFFFBF2);
  static const Color darkMaroonText = Color(0xFF4A1010);
  static const Color lightGoldText = Color(0xFFFFF4D6);

  String searchQuery = '';
  String districtName = '';
  List<Map<String, dynamic>> places = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPlaces();
  }

  /// Fetches projects and groups them by Taluk, strictly excluding 'rejected' status.
  Future<void> _loadPlaces() async {
    if (!mounted) return;
    setState(() => isLoading = true);
    
    try {
      // 1. Fetch only projects for this district
      final snapshot = await FirebaseFirestore.instance
          .collection('projects')
          .where('district', isEqualTo: widget.districtId)
          .get();

      districtName = widget.districtId;
      final Map<String, Map<String, dynamic>> talukMap = {};

      for (final doc in snapshot.docs) {
        final data = doc.data();
        
        // STAGE 1: Status Check
        // If a proposal is rejected, it must not contribute to the taluk count or visibility
        final String status = (data['status'] ?? '').toString().toLowerCase();
        if (status == 'rejected') continue; 

        final String taluk = (data['taluk'] ?? '').toString().trim();
        if (taluk.isEmpty) continue;

        final bool isSanctioned = data['isSanctioned'] == true;

        // STAGE 2: Grouping by Taluk
        talukMap.putIfAbsent(taluk, () {
          return {
            'id': taluk,
            'name': taluk,
            'temples': 0,
            'newRequests': 0,
          };
        });

        // Only increment temple count for non-rejected items
        talukMap[taluk]!['temples'] = (talukMap[taluk]!['temples'] as int) + 1;
        
        // A project is a "New Request" only if it's pending and not sanctioned
        if (!isSanctioned && status == 'pending') {
          talukMap[taluk]!['newRequests'] = (talukMap[taluk]!['newRequests'] as int) + 1;
        }
      }

      if (mounted) {
        setState(() {
          // If all projects in a taluk were rejected, they were skipped in the loop,
          // meaning the taluk won't exist in talukMap and thus disappears from the list.
          places = talukMap.values.toList()
            ..sort((a, b) => a['name'].toString().compareTo(b['name'].toString()));
        });
      }
    } catch (e) {
      debugPrint('Error loading district places: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = places.where((p) {
      return p['name']
          .toString()
          .toLowerCase()
          .contains(searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      backgroundColor: backgroundCream,
      body: Column(
        children: [
          // --- HEADER SECTION ---
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(bottom: 20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [primaryMaroon, Color(0xFF4A1010)],
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: lightGoldText),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Text(
                        'District Details',
                        style: TextStyle(color: primaryAccentGold, fontSize: 14),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$districtName District',
                          style: const TextStyle(
                            color: lightGoldText,
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${places.length} Taluks Active',
                          style: const TextStyle(color: primaryAccentGold, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          _buildSearchField(),

          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator(color: primaryMaroon))
                : filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.location_off_outlined, size: 48, color: primaryMaroon.withOpacity(0.5)),
                            const SizedBox(height: 16),
                            const Text('No active taluks found', style: TextStyle(color: darkMaroonText)),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadPlaces,
                        color: primaryMaroon,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) => _buildTalukCard(filtered[index]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        onChanged: (v) => setState(() => searchQuery = v),
        decoration: InputDecoration(
          hintText: 'Search taluks...',
          hintStyle: TextStyle(color: darkMaroonText.withOpacity(0.5)),
          prefixIcon: const Icon(Icons.search, color: primaryMaroon),
          filled: true,
          fillColor: Colors.white,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: secondaryGold),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: primaryAccentGold, width: 2),
          ),
        ),
      ),
    );
  }

  Widget _buildTalukCard(Map<String, dynamic> place) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: secondaryGold, width: 0.5),
      ),
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: () async {
          // AWAIT the navigation. When the user clicks "Reject" in the 
          // deep details and pops back, this code continues.
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PlaceTemplesScreen(
                placeId: place['id'],
              ),
            ),
          );
          
          // Re-fetch from Firebase to ensure that if the last project 
          // in this taluk was rejected, the taluk disappears from this list.
          _loadPlaces();
        },
        title: Text(
          place['name'],
          style: const TextStyle(fontWeight: FontWeight.bold, color: darkMaroonText),
        ),
        subtitle: Text('${place['temples']} Active Projects'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if ((place['newRequests'] as int) > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: primaryMaroon,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${place['newRequests']} NEW',
                  style: const TextStyle(color: lightGoldText, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            const Icon(Icons.chevron_right, color: primaryAccentGold),
          ],
        ),
      ),
    );
  }
}