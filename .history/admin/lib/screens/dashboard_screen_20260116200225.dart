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

  List<Map<String, dynamic>> districts = [];
  List<Map<String, dynamic>> usersWithOngoingProjects = [];
  List<Map<String, dynamic>> notifications = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // Filter: ONLY show Chennai in the Districts tab
  bool _isAllowedDistrict(String name) {
    return name.trim().toLowerCase() == 'chennai';
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);

    try {
      // 1. Load Projects (Filter for Chennai and identify Ongoing Users)
      final projectsSnap = await FirebaseFirestore.instance.collection('projects').get();
      final Map<String, Map<String, dynamic>> byDistrict = {};
      final Set<String> ongoingUserNames = {};

      for (final doc in projectsSnap.docs) {
        final data = doc.data();
        final districtName = (data['district'] ?? '').toString().trim();
        final status = (data['status'] ?? 'pending').toString().toLowerCase();
        final userName = (data['userName'] ?? '').toString().trim();

        // Check for Ongoing Projects (Anything not pending is considered active/ongoing)
        if (status != 'pending' && userName.isNotEmpty) {
          ongoingUserNames.add(userName);
        }

        // Projects Tab Logic (Chennai Only)
        if (_isAllowedDistrict(districtName)) {
          final entry = byDistrict.putIfAbsent(districtName, () {
            return <String, dynamic>{
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

          if (data['isSanctioned'] != true && status == 'pending') {
            entry['newRequests'] = (entry['newRequests'] as int) + 1;
          }
        }
      }

      districts = byDistrict.values.toList();

      // 2. Load Users and Filter only those with Ongoing Projects
      final usersSnap = await FirebaseFirestore.instance.collection('users').get();
      usersWithOngoingProjects = usersSnap.docs
          .map((doc) {
            final data = doc.data();
            return {
              'id': doc.id,
              'name': data['name'] ?? 'Unknown User',
              'phone': data['phoneNumber'] ?? data['phone'] ?? 'No Number',
              'district': data['district'] ?? 'Not Set',
              'taluk': data['taluk'] ?? 'Not Set',
            };
          })
          .where((user) => ongoingUserNames.contains(user['name'])) // Only users with ongoing projects
          .toList();

      // Sort Users Ascending (A-Z)
      usersWithOngoingProjects.sort((a, b) =>
          a['name'].toString().toLowerCase().compareTo(b['name'].toString().toLowerCase()));

      // Mock Notifications
      notifications = [
        {'id': '1', 'message': 'New request in Chennai', 'time': '2h ago', 'read': false},
      ];
    } catch (e) {
      debugPrint('Error: $e');
    }

    setState(() => isLoading = false);
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
                child: isLoading
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFF6D1B1B)))
                    : Column(
                        children: [
                          _buildSearchBar(),
                          Expanded(
                              child: activeTab == 0
                                  ? _buildDistrictsList()
                                  : _buildUsersList()),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(bottom: 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [Color(0xFF6D1B1B), Color(0xFF4A1010)]),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Admin Dashboard',
                      style: TextStyle(color: Color(0xFFFFF4D6), fontSize: 20, fontWeight: FontWeight.bold)),
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
                  Expanded(child: _buildTab('Projects (Chennai)', Icons.location_on, 0)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildTab('Ongoing Users', Icons.people, 1)),
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
          hintText: activeTab == 0 ? 'Search Chennai...' : 'Search Name or Contact...',
          prefixIcon: const Icon(Icons.search, color: Color(0xFF6D1B1B)),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
          color: isActive ? const Color(0xFFD4AF37) : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: isActive ? const Color(0xFF6D1B1B) : Colors.white),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: isActive ? const Color(0xFF6D1B1B) : Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildDistrictsList() {
    final filtered = districts.where((d) => d['name'].toLowerCase().contains(searchQuery.toLowerCase())).toList();
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final d = filtered[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            title: Text(d['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('${d['places']} Registered Places'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DistrictPlacesScreen(districtId: d['id']))),
          ),
        );
      },
    );
  }

  Widget _buildUsersList() {
    final filtered = usersWithOngoingProjects.where((u) =>
        u['name'].toLowerCase().contains(searchQuery.toLowerCase()) ||
        u['phone'].contains(searchQuery)).toList();

    if (filtered.isEmpty) {
      return const Center(child: Text("No users with ongoing projects found."));
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final user = filtered[index];
        return Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
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
                    Text("${user['taluk']}, ${user['district']}", style: const TextStyle(fontSize: 13)),
                  ],
                ),
                const Divider(height: 20),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Chip(
                    label: Text("ONGOING PROJECT", style: TextStyle(fontSize: 10, color: Colors.white)),
                    backgroundColor: Colors.green,
                  ),
                )
              ],
            ),
          ),
        );
      },
    );
  }

  Drawer _buildNotificationsDrawer() {
    return Drawer(
      child: Column(
        children: [
          Container(
              padding: const EdgeInsets.all(16),
              color: const Color(0xFF6D1B1B),
              child: const SafeArea(child: Center(child: Text('Notifications', style: TextStyle(color: Colors.white, fontSize: 18))))),
          const Expanded(child: Center(child: Text('No new notifications'))),
        ],
      ),
    );
  }
}