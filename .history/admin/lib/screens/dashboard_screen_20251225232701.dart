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

  // Theme Colors
  final Color primaryDark = const Color(0xFF00695C);
  final Color primaryLight = const Color(0xFF00897B);
  final Color accentColor = const Color(0xFFFFB300); // Amber accent
  final Color backgroundColor = const Color(0xFFF1F5F9);

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
      backgroundColor: backgroundColor,
      endDrawer: showNotifications ? _buildNotificationsDrawer() : null,
      body: Builder(
        builder: (innerContext) {
          return Column(
            children: [
              // Updated Header with Teal Gradient
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [primaryDark, primaryLight]),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))
                  ],
                ],
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
                                IconButton(
                                  icon: const Icon(Icons.menu_open, color: Colors.white),
                                  onPressed: _showAdminMenu,
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: const [
                                    Text('Admin Dashboard', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                                    Text('System Overview', style: TextStyle(color: Colors.white70, fontSize: 13)),
                                  ],
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.account_circle_outlined, color: Colors.white),
                                  onPressed: _showAccountSettings,
                                ),
                                Stack(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.notifications_none, color: Colors.white),
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
                                          decoration: BoxDecoration(color: accentColor, shape: BoxShape.circle),
                                          constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                                          child: Text('$unreadCount', style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        // Modern Tab Toggle
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(color: Colors.black.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                          child: Row(
                            children: [
                              Expanded(child: _buildTab('Projects', Icons.map_outlined, 0)),
                              const SizedBox(width: 4),
                              Expanded(child: _buildTab('Users', Icons.people_outline, 1)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              Expanded(
                child: isLoading
                    ? Center(child: CircularProgressIndicator(color: primaryDark))
                    : Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                            child: TextField(
                              onChanged: (value) => setState(() => searchQuery = value),
                              decoration: InputDecoration(
                                hintText: activeTab == 0 ? 'Search districts...' : 'Search by name or email...',
                                prefixIcon: Icon(Icons.search, color: primaryDark),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                filled: true,
                                fillColor: Colors.white,
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: isActive ? primaryDark : Colors.white),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: isActive ? primaryDark : Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildDistrictsList() {
    final filtered = districts.where((d) => d['name'].toString().toLowerCase().contains(searchQuery.toLowerCase())).toList();
    if (filtered.isEmpty) return const Center(child: Text('No results found'));

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final district = filtered[index];
        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DistrictPlacesScreen(districtId: district['id']))),
            leading: CircleAvatar(backgroundColor: primaryLight.withOpacity(0.1), child: Icon(Icons.location_on, color: primaryLight)),
            title: Text(district['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('${district['places']} Active Places'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if ((district['newRequests'] ?? 0) > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: accentColor, borderRadius: BorderRadius.circular(20)),
                    child: Text('${district['newRequests']} New', style: const TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                const Icon(Icons.chevron_right, color: Colors.grey),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildUsersList() {
    final filtered = users.where((u) => u['name'].toString().toLowerCase().contains(searchQuery.toLowerCase())).toList();
    if (filtered.isEmpty) return const Center(child: Text('No users found'));

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final user = filtered[index];
        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            onTap: () => _showUserDetail(user),
            leading: CircleAvatar(backgroundColor: Colors.grey.shade100, child: const Icon(Icons.person, color: Colors.blueGrey)),
            title: Text(user['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(user['email']),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: primaryLight.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: Text('${user['activeProjects']} Active', style: TextStyle(color: primaryDark, fontSize: 11, fontWeight: FontWeight.bold)),
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
            padding: const EdgeInsets.all(20),
            width: double.infinity,
            color: primaryDark,
            child: const SafeArea(child: Text('Notifications', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold))),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                final notif = notifications[index];
                return ListTile(
                  tileColor: notif['read'] ? Colors.transparent : accentColor.withOpacity(0.05),
                  leading: Icon(Icons.circle, size: 12, color: notif['read'] ? Colors.grey.shade300 : accentColor),
                  title: Text(notif['message'], style: TextStyle(fontWeight: notif['read'] ? FontWeight.normal : FontWeight.bold)),
                  subtitle: Text(notif['time']),
                  onTap: () => setState(() => notifications[index]['read'] = true),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // --- Utility functions (Unchanged Logic, added color context) ---
  void _showAdminMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(leading: const Icon(Icons.settings_outlined), title: const Text('Account Settings'), onTap: () => Navigator.pop(context)),
            ListTile(leading: const Icon(Icons.logout, color: Colors.red), title: const Text('Sign Out', style: TextStyle(color: Colors.red)), onTap: () => Navigator.pop(context)),
          ],
        ),
      ),
    );
  }

  void _showAccountSettings() {}
  void _showPersonalInfo() {}
  void _performLogout() {}
  void _showUserDetail(Map<String, dynamic> user) {
     showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(user['name'] ?? ''),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Email: ${user['email']}'),
            const SizedBox(height: 8),
            Text('Phone: ${user['phone']}'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade50, foregroundColor: Colors.red, elevation: 0),
            onPressed: () => Navigator.pop(context), 
            child: const Text('Delete User')
          ),
        ],
      ),
    );
  }
}