import 'package:flutter/material.dart';
import 'district_places_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int activeTab = 0; // 0: Projects, 1: Users
  String searchQuery = '';
  bool showNotifications = false;
  List<Map<String, dynamic>> notifications = [];

  // Helper to check if a district name is valid/real
  bool _isValidDistrict(String name) {
    final cleanName = name.trim().toLowerCase();
    
    // List of unwanted names to be filtered out and deleted from DB
    const unwanted = {
      'district3', 
      'sample', 
      'dis2', 
      'new1', 
      'coimbatore', 
      'tiruvallur', 
      'test', 
      'null', 
      'undefined'
    };
    
    if (cleanName.length < 3) return false;
    if (unwanted.contains(cleanName)) return false;
    
    return true;
  }

  // Optimized Sorting Logic
  void _sortDistricts(List<Map<String, dynamic>> list) {
    list.sort((a, b) {
      int aRequests = a['newRequests'] as int;
      int bRequests = b['newRequests'] as int;

      // 1. Priority: Show districts with new requests first
      if (aRequests > 0 && bRequests == 0) return -1;
      if (aRequests == 0 && bRequests > 0) return 1;

      // 2. Secondary: If both have requests or both have 0 (Sanctioned), sort alphabetically
      return a['name'].toString().toLowerCase().compareTo(b['name'].toString().toLowerCase());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7E8),
      endDrawer: showNotifications ? _buildNotificationsDrawer() : null,
      body: Builder(
        builder: (innerContext) {
          return Column(
            children: [
              _buildHeader(innerContext),
              Expanded(
                child: Column(
                  children: [
                    _buildSearchBar(),
                    Expanded(
                      child: activeTab == 0 
                        ? _buildProjectsStream() 
                        : _buildUsersStream(),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // Real-time Stream for Projects/Districts (Handles Auto-Refresh)
  Widget _buildProjectsStream() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('projects').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const Center(child: Text("Error loading data"));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Color(0xFF6D1B1B)));

        final docs = snapshot.data!.docs;
        final Map<String, Map<String, dynamic>> byDistrict = {};
        final WriteBatch cleanupBatch = FirebaseFirestore.instance.batch();
        bool needsCleanup = false;

        for (var doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          final districtName = (data['district'] ?? '').toString().trim();

          // Firebase Cleanup for unwanted district names
          if (!_isValidDistrict(districtName)) {
            cleanupBatch.delete(doc.reference);
            needsCleanup = true;
            continue;
          }

          final entry = byDistrict.putIfAbsent(districtName, () {
            return {
              'id': districtName,
              'name': districtName,
              'places': 0,
              'newRequests': 0,
              '_placeSet': <String>{},
            };
          });

          final placeName = (data['place'] ?? '').toString();
          if (placeName.isNotEmpty) {
            (entry['_placeSet'] as Set<String>).add(placeName);
            entry['places'] = (entry['_placeSet'] as Set<String>).length;
          }

          final bool isSanctioned = data['isSanctioned'] == true;
          final String status = (data['status'] ?? 'pending').toString().toLowerCase();
          
          // Count as new request ONLY if not sanctioned and status is pending
          if (!isSanctioned && status == 'pending') {
            entry['newRequests'] = (entry['newRequests'] as int) + 1;
          }
        }

        // Auto-delete invalid districts from Firestore
        if (needsCleanup) cleanupBatch.commit();

        List<Map<String, dynamic>> districtList = byDistrict.values.toList();
        
        // Filter by Search Bar
        if (searchQuery.isNotEmpty) {
          districtList = districtList.where((d) => 
            d['name'].toString().toLowerCase().contains(searchQuery.toLowerCase())).toList();
        }

        // Apply Custom Sorting (New Requests first, then Alphabetical)
        _sortDistricts(districtList);

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: districtList.length,
          itemBuilder: (context, index) => _buildDistrictCard(districtList[index]),
        );
      },
    );
  }

  // Real-time Stream for Users
  Widget _buildUsersStream() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        final userList = snapshot.data!.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return {
            'id': doc.id,
            'name': data['name'] ?? 'Unknown User',
            'phone': data['phoneNumber'] ?? data['phone'] ?? 'No Number',
            'district': data['district'] ?? 'Not Set',
            'taluk': data['taluk'] ?? 'Not Set',
          };
        }).toList();

        // Sort users alphabetically
        userList.sort((a, b) => a['name'].toString().toLowerCase().compareTo(b['name'].toString().toLowerCase()));

        final filtered = userList.where((u) => 
          u['name'].toString().toLowerCase().contains(searchQuery.toLowerCase()) || 
          u['phone'].toString().contains(searchQuery)).toList();

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: filtered.length,
          itemBuilder: (context, index) => _buildUserCard(filtered[index]),
        );
      },
    );
  }

  Widget _buildDistrictCard(Map<String, dynamic> district) {
    return Card(
      color: Colors.white,
      elevation: (district['newRequests'] ?? 0) > 0 ? 4 : 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DistrictPlacesScreen(districtId: district['id']))),
        title: Text(district['name'], style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4A1010))),
        subtitle: Text('${district['places']} Places Registered'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if ((district['newRequests'] ?? 0) > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: const Color(0xFF6D1B1B), borderRadius: BorderRadius.circular(12)),
                child: Text('${district['newRequests']} NEW', style: const TextStyle(color: Color(0xFFFFF4D6), fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: Color(0xFFD4AF37)),
          ],
        ),
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(user['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF4A1010))),
                Text(user['phone'], style: const TextStyle(color: Color(0xFF6D1B1B), fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.location_on, size: 14, color: Color(0xFFB8962E)),
                const SizedBox(width: 6),
                Text("${user['taluk']}, ${user['district']}", style: const TextStyle(fontSize: 13, color: Color(0xFF4A1010))),
              ],
            ),
            const Divider(height: 16, color: Color(0xFFFFF4D6)),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _handleRemoveUser(user),
                icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                label: const Text('Remove User', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF6D1B1B), Color(0xFF4A1010)])),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      IconButton(icon: const Icon(Icons.menu, color: Color(0xFFFFF4D6)), onPressed: _showAdminMenu),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Admin Dashboard', style: TextStyle(color: Color(0xFFFFF4D6), fontSize: 20, fontWeight: FontWeight.bold)),
                          Text('Manage Projects & Users', style: TextStyle(color: Color(0xFFD4AF37), fontSize: 13)),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.notifications, color: Color(0xFFFFF4D6)),
                    onPressed: () {
                      setState(() => showNotifications = true);
                      Scaffold.of(context).openEndDrawer();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildTab('Projects', Icons.location_on, 0)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildTab('Users', Icons.people, 1)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        onChanged: (value) => setState(() => searchQuery = value),
        decoration: InputDecoration(
          hintText: activeTab == 0 ? 'Search districts...' : 'Search by name or phone...',
          prefixIcon: const Icon(Icons.search, color: Color(0xFF6D1B1B)),
          filled: true,
          fillColor: const Color(0xFFFFFBF2),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFB8962E))),
        ),
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
          color: isActive ? const Color(0xFFD4AF37) : const Color(0xFFB8962E).withOpacity(0.3),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: isActive ? const Color(0xFF6D1B1B) : Colors.white),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: isActive ? const Color(0xFF6D1B1B) : Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Future<void> _handleRemoveUser(Map<String, dynamic> user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm'),
        content: Text('Remove ${user['name']} and all projects?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remove', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      final batch = FirebaseFirestore.instance.batch();
      final projects = await FirebaseFirestore.instance.collection('projects').where('userName', isEqualTo: user['name']).get();
      for (var d in projects.docs) { batch.delete(d.reference); }
      batch.delete(FirebaseFirestore.instance.collection('users').doc(user['id']));
      await batch.commit();
    }
  }

  Drawer _buildNotificationsDrawer() {
    return Drawer(
      backgroundColor: const Color(0xFFFFF7E8),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(color: Color(0xFF6D1B1B)),
            child: const SafeArea(child: Text('Notifications', style: TextStyle(color: Colors.white, fontSize: 18))),
          ),
          const Expanded(child: Center(child: Text('No new notifications'))),
        ],
      ),
    );
  }

  void _showAdminMenu() {
    // Basic Admin Menu trigger
  }
}