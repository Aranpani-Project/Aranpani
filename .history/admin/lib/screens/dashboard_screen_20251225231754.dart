import 'package:flutter/material.dart';
import 'district_places_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int activeTab = 0; 
  String searchQuery = '';
  bool showNotifications = false;

  List<Map<String, dynamic>> districts = [];
  List<Map<String, dynamic>> users = [];
  List<Map<String, dynamic>> notifications = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);
    try {
      final usersSnap = await FirebaseFirestore.instance.collection('users').get();
      users = usersSnap.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['name'] ?? '',
          'email': data['email'] ?? '',
          'phone': data['phoneNumber'] ?? '',
          'activeProjects': 0,
        };
      }).toList();

      final projectsSnap = await FirebaseFirestore.instance.collection('projects').get();
      final Map<String, Map<String, dynamic>> byDistrict = {};

      for (final doc in projectsSnap.docs) {
        final data = doc.data();
        final districtName = (data['district'] ?? '').toString();
        if (districtName.isEmpty) continue;

        final entry = byDistrict.putIfAbsent(districtName, () => {
          'id': districtName,
          'name': districtName,
          'places': 0,
          'newRequests': 0,
        });

        final placeName = (data['place'] ?? '').toString();
        if (placeName.isNotEmpty) {
          final set = (entry['_placeSet'] as Set<String>? ?? <String>{})..add(placeName);
          entry['_placeSet'] = set;
          entry['places'] = set.length;
        }
        if (data['isSanctioned'] != true) {
          entry['newRequests'] = (entry['newRequests'] as int) + 1;
        }
      }

      districts = byDistrict.values.toList();
    } catch (e) {
      debugPrint('Error: $e');
    }
    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    // Theme Colors
    const maroon = Color(0xFF6D1B1B);
    const gold = Color(0xFFD4AF37);
    const background = Color(0xFFFFF7E8);

    return Scaffold(
      backgroundColor: background,
      body: Column(
        children: [
          // Header with Maroon/Gold Theme
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [maroon, Color(0xFF4A1212)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Aranpani Admin',
                          style: TextStyle(color: Color(0xFFFFF4D6), fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.account_circle, color: gold),
                          onPressed: () {},
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(child: _buildTab('Districts', Icons.map, 0)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildTab('Users', Icons.people, 1)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator(color: maroon))
                : Column(
                    children: [
                      _buildSearchBar(maroon),
                      Expanded(child: activeTab == 0 ? _buildDistrictsList(maroon, gold) : _buildUsersList(maroon, gold)),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(String label, IconData icon, int index) {
    final isActive = activeTab == index;
    return GestureDetector(
      onTap: () => setState(() => activeTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFD4AF37) : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: isActive ? Colors.white : const Color(0xFFD4AF37)),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: isActive ? Colors.white : Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(Color primary) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        onChanged: (value) => setState(() => searchQuery = value),
        decoration: InputDecoration(
          hintText: 'Search...',
          prefixIcon: Icon(Icons.search, color: primary),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFD4AF37))),
        ),
      ),
    );
  }

  Widget _buildDistrictsList(Color maroon, Color gold) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: districts.length,
      itemBuilder: (context, index) {
        final d = districts[index];
        return Card(
          color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: gold.withOpacity(0.3))),
          child: ListTile(
            leading: CircleAvatar(backgroundColor: background, child: Icon(Icons.location_city, color: maroon)),
            title: Text(d['name'], style: const TextStyle(fontWeight: FontWeight.bold, color: maroon)),
            subtitle: Text('${d['places']} Areas Identified'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            onTap: () {},
          ),
        );
      },
    );
  }

  Widget _buildUsersList(Color maroon, Color gold) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: users.length,
      itemBuilder: (context, index) {
        final u = users[index];
        return Card(
          color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: CircleAvatar(backgroundColor: maroon, child: Text(u['name'][0], style: const TextStyle(color: Colors.white))),
            title: Text(u['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(u['phone']),
            trailing: Icon(Icons.info_outline, color: gold),
          ),
        );
      },
    );
  }
}