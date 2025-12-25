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

        final entry = byDistrict.putIfAbsent(districtName, () {
          return <String, dynamic>{
            'id': districtName,
            'name': districtName,
            'places': 0,
            'newRequests': 0,
          };
        });

        final placeName = (data['place'] ?? '').toString();
        if (placeName.isNotEmpty) {
          final set = (entry['_placeSet'] as Set<String>? ?? <String>{})..add(placeName);
          entry['_placeSet'] = set;
          entry['places'] = set.length;
        }

        final bool isSanctioned = data['isSanctioned'] == true;
        if (!isSanctioned) {
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
      debugPrint('Error loading data: $e');
    }
    setState(() => isLoading = false);
  }

  int get unreadCount => notifications.where((n) => n['read'] == false).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7E8), // Sacred Cream Background
      endDrawer: showNotifications ? _buildNotificationsDrawer() : null,
      body: Builder(
        builder: (innerContext) {
          return Column(
            children: [
              // Header with Temple Maroon Gradient
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF6D1B1B), Color(0xFF4A1010)],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.menu, color: Color(0xFFFFF4D6)),
                                  onPressed: _showAdminMenu,
                                ),
                                const SizedBox(width: 8),
                                const Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Admin Dashboard',
                                      style: TextStyle(
                                        color: Color(0xFFFFF4D6), // Creamy Gold
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Manage Projects & Users',
                                      style: TextStyle(
                                        color: Color(0xFFD4AF37), // Deep Gold
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.account_circle, color: Color(0xFFFFF4D6)),
                                  onPressed: _showAccountSettings,
                                ),
                                Stack(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.notifications, color: Color(0xFFFFF4D6)),
                                      onPressed: () {
                                        setState(() => showNotifications = true);
                                        Scaffold.of(innerContext).openEndDrawer();
                                      },
                                    ),
                                    if (unreadCount > 0)
                                      Positioned(
                                        right: 8,
                                        top: 8,
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: const BoxDecoration(color: Color(0xFFD4AF37), shape: BoxShape.circle),
                                          constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                                          child: Text(
                                            '$unreadCount',
                                            style: const TextStyle(color: Color(0xFF6D1B1B), fontSize: 10, fontWeight: FontWeight.bold),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
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
              ),

              Expanded(
                child: isLoading
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFF6D1B1B)))
                    : Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: TextField(
                              onChanged: (value) => setState(() => searchQuery = value),
                              decoration: InputDecoration(
                                hintText: activeTab == 0 ? 'Search districts...' : 'Search users...',
                                hintStyle: const TextStyle(color: Color(0xFF4A1010)),
                                prefixIcon: const Icon(Icons.search, color: Color(0xFF6D1B1B)),
                                filled: true,
                                fillColor: const Color(0xFFFFFBF2), // Soft Parchment
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16), // Smooth Organic
                                  borderSide: const BorderSide(color: Color(0xFFB8962E)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(color: Color(0xFFD4AF37), width: 2),
                                ),
                              ),
                            ),
                          ),
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
            Text(
              label,
              style: TextStyle(
                color: isActive ? const Color(0xFF6D1B1B) : Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDistrictsList() {
    final filtered = districts.where((d) => d['name'].toString().toLowerCase().contains(searchQuery.toLowerCase())).toList();
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final district = filtered[index];
        return Card(
          color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DistrictPlacesScreen(districtId: district['id']))),
            title: Text(district['name'], style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4A1010))),
            subtitle: Text('${district['places']} Places'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if ((district['newRequests'] ?? 0) > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: const Color(0xFF6D1B1B), borderRadius: BorderRadius.circular(12)),
                    child: Text('${district['newRequests']} New', style: const TextStyle(color: Color(0xFFFFF4D6), fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right, color: Color(0xFFD4AF37)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildUsersList() {
    final filtered = users.where((u) => u['name'].toString().toLowerCase().contains(searchQuery.toLowerCase())).toList();
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final user = filtered[index];
        return Card(
          color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          margin: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: () => _showUserDetail(user),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(user['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF4A1010))),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(color: const Color(0xFFFFF7E8), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFD4AF37))),
                        child: Text('${user['activeProjects']} Projects', style: const TextStyle(color: Color(0xFF6D1B1B), fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(user['email'], style: const TextStyle(color: Color(0xFF4A1010))),
                  Text(user['phone'], style: const TextStyle(color: Color(0xFF4A1010))),
                ],
              ),
            ),
          ),
        );
      },
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
            child: SafeArea(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Notifications', style: TextStyle(color: Color(0xFFFFF4D6), fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),
          ),
          Expanded(child: const Center(child: Text('No new notifications', style: TextStyle(color: Color(0xFF4A1010))))),
        ],
      ),
    );
  }

  void _showAdminMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFFFFF7E8),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(leading: const Icon(Icons.account_circle, color: Color(0xFF6D1B1B)), title: const Text('Account Settings')),
          ListTile(leading: const Icon(Icons.logout, color: Colors.red), title: const Text('Logout')),
        ],
      ),
    );
  }

  void _showAccountSettings() {}
  void _showUserDetail(Map<String, dynamic> user) {}
}