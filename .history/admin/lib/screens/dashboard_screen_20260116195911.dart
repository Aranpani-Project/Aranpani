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

  // Helper to filter out test/junk data
  bool _isValidDistrict(String name) {
    final cleanName = name.trim().toLowerCase();
    const unwanted = {
      'district3', 'sample', 'dis2', 'new1', 'test', 'null', 
      'undefined', 'coimbatore', 'tiruvallur'
    };
    if (cleanName.length < 3) return false;
    if (unwanted.contains(cleanName)) return false;
    return true;
  }

  // Sorting for Districts: New Requests first, then Alphabetical
  void _sortDistricts(List<Map<String, dynamic>> list) {
    list.sort((a, b) {
      int aRequests = a['newRequests'] as int;
      int bRequests = b['newRequests'] as int;
      if (aRequests > 0 && bRequests == 0) return -1;
      if (aRequests == 0 && bRequests > 0) return 1;
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
                        : _buildUsersFromProposalsStream(),
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

  // TAB 1: DISTRICTS/PROJECTS
  Widget _buildProjectsStream() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('projects').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const Center(child: Text("Error loading data"));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Color(0xFF6D1B1B)));

        final docs = snapshot.data!.docs;
        final Map<String, Map<String, dynamic>> byDistrict = {};

        for (var doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          final districtName = (data['district'] ?? '').toString().trim();

          if (!_isValidDistrict(districtName)) continue;

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

          if (data['isSanctioned'] != true && data['status'] == 'pending') {
            entry['newRequests'] = (entry['newRequests'] as int) + 1;
          }
        }

        List<Map<String, dynamic>> districtList = byDistrict.values.toList();
        if (searchQuery.isNotEmpty) {
          districtList = districtList.where((d) => 
            d['name'].toString().toLowerCase().contains(searchQuery.toLowerCase())).toList();
        }
        _sortDistricts(districtList);

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: districtList.length,
          itemBuilder: (context, index) => _buildDistrictCard(districtList[index]),
        );
      },
    );
  }

  // TAB 2: USERS (Derived from Proposals/Projects)
  Widget _buildUsersFromProposalsStream() {
    return StreamBuilder<QuerySnapshot>(
      // We listen to 'projects' to get details of everyone who submitted a proposal
      stream: FirebaseFirestore.instance.collection('projects').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const Center(child: Text("Error"));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        // Map to keep unique users (Key: phoneNumber or Name)
        final Map<String, Map<String, dynamic>> uniqueUsers = {};

        for (var doc in snapshot.data!.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final String phone = (data['phoneNumber'] ?? data['phone'] ?? 'No Number').toString();
          final String name = (data['userName'] ?? data['name'] ?? 'Unknown').toString();
          
          // Use Phone as key to avoid duplicate cards for the same person with multiple proposals
          uniqueUsers.putIfAbsent(phone, () => {
            'name': name,
            'phone': phone,
            'district': data['district'] ?? 'N/A',
            'taluk': data['taluk'] ?? 'N/A',
          });
        }

        // Convert map to list
        List<Map<String, dynamic>> userList = uniqueUsers.values.toList();

        // 1. Filter by search query
        if (searchQuery.isNotEmpty) {
          userList = userList.where((u) => 
            u['name'].toString().toLowerCase().contains(searchQuery.toLowerCase()) || 
            u['phone'].toString().contains(searchQuery)
          ).toList();
        }

        // 2. Sort Ascending by Name
        userList.sort((a, b) => a['name'].toString().toLowerCase().compareTo(b['name'].toString().toLowerCase()));

        if (userList.isEmpty) {
          return const Center(child: Text("No users with proposals found."));
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: userList.length,
          itemBuilder: (context, index) => _buildUserCard(userList[index]),
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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(user['name'], 
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF4A1010))),
                ),
                Text(user['phone'], 
                  style: const TextStyle(color: Color(0xFF6D1B1B), fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.location_on, size: 16, color: Color(0xFFB8962E)),
                const SizedBox(width: 6),
                Text("District: ${user['district']}", style: const TextStyle(fontSize: 13, color: Color(0xFF4A1010))),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.map, size: 16, color: Color(0xFFB8962E)),
                const SizedBox(width: 6),
                Text("Taluk: ${user['taluk']}", style: const TextStyle(fontSize: 13, color: Color(0xFF4A1010))),
              ],
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
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Admin Dashboard', style: TextStyle(color: Color(0xFFFFF4D6), fontSize: 20, fontWeight: FontWeight.bold)),
                      Text('Manage Projects & Users', style: TextStyle(color: Color(0xFFD4AF37), fontSize: 13)),
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
          hintText: activeTab == 0 ? 'Search districts...' : 'Search Name or Contact...',
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

  void _showAdminMenu() {}
}