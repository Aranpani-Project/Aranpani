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

  // Modern Color Palette
  final Color primaryDark = const Color(0xFF1E293B); // Slate 800
  final Color accentIndigo = const Color(0xFF6366F1); // Indigo 500
  final Color backgroundGray = const Color(0xFFF8FAFC); // Slate 50

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
          'aadhar': data['aadharNumber'] ?? '',
          'address': data['address'] ?? '',
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

      districts = byDistrict.values.map((e) {
        e.remove('_placeSet');
        return e;
      }).toList();

      notifications = [
        {'id': '1', 'message': 'New project request from Ravi Kumar', 'time': '2 hours ago', 'read': false},
        {'id': '2', 'message': 'Bill uploaded for Ongoing Temple', 'time': '1 day ago', 'read': true},
      ];
    } catch (e) {
      debugPrint('Error: $e');
    }
    setState(() => isLoading = false);
  }

  int get unreadCount => notifications.where((n) => n['read'] == false).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundGray,
      endDrawer: _buildNotificationsDrawer(),
      body: Builder(
        builder: (innerContext) {
          return Column(
            children: [
              _buildModernHeader(innerContext),
              _buildModernTabs(),
              Expanded(
                child: isLoading
                    ? Center(child: CircularProgressIndicator(color: accentIndigo))
                    : Column(
                        children: [
                          _buildModernSearchBar(),
                          Expanded(
                            child: activeTab == 0 ? _buildDistrictsList() : _buildUsersList(),
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

  Widget _buildModernHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 60, left: 24, right: 24, bottom: 20),
      decoration: BoxDecoration(
        color: primaryDark,
        borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.grid_view_rounded, color: Colors.white, size: 28),
                onPressed: _showAdminMenu,
              ),
              const Text(
                'DASHBOARD',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: 1.5),
              ),
              Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_none_rounded, color: Colors.white, size: 28),
                    onPressed: () => Scaffold.of(context).openEndDrawer(),
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: 12,
                      top: 12,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
                        constraints: const BoxConstraints(minWidth: 8, minHeight: 8),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModernTabs() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          _buildTabItem('Projects', 0),
          _buildTabItem('Users', 1),
        ],
      ),
    );
  }

  Widget _buildTabItem(String title, int index) {
    bool isActive = activeTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => activeTab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? accentIndigo : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isActive ? Colors.white : Colors.slate,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: TextField(
        onChanged: (value) => setState(() => searchQuery = value),
        decoration: InputDecoration(
          hintText: activeTab == 0 ? 'Search districts...' : 'Search users...',
          prefixIcon: Icon(Icons.search, color: accentIndigo),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.slate.shade100),
          ),
        ),
      ),
    );
  }

  Widget _buildDistrictsList() {
    final filtered = districts.where((d) => d['name'].toString().toLowerCase().contains(searchQuery.toLowerCase())).toList();
    
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final district = filtered[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 5))],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DistrictPlacesScreen(districtId: district['id']))),
            leading: CircleAvatar(
              backgroundColor: accentIndigo.withOpacity(0.1),
              child: Icon(Icons.location_on, color: accentIndigo),
            ),
            title: Text(district['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            subtitle: Text('${district['places']} Active Sites', style: TextStyle(color: Colors.slate.shade400)),
            trailing: district['newRequests'] > 0 
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                    child: Text('${district['newRequests']} NEW', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 10)),
                  )
                : const Icon(Icons.chevron_right, color: Colors.slate),
          ),
        );
      },
    );
  }

  // ... (Keep existing logic for _buildUsersList, _showAdminMenu, etc., using similar styling patterns as above)

  Drawer _buildNotificationsDrawer() {
    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: primaryDark),
            child: Center(child: Text('NOTIFICATIONS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1))),
          ),
          // ... Notification logic
        ],
      ),
    );
  }

  void _showAdminMenu() { /* Same as your original modal logic */ }
}