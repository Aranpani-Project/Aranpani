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

  // Aranpani Theme Colors
  static const Color primaryMaroon = Color(0xFF6D1B1B);
  static const Color primaryAccentGold = Color(0xFFD4AF37);
  static const Color backgroundCream = Color(0xFFFFF7E8);
  static const Color softParchment = Color(0xFFFFFBF2);
  static const Color darkMaroonText = Color(0xFF4A1010);
  static const Color lightGoldText = Color(0xFFFFF4D6);

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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load data: $e')));
    }
    setState(() => isLoading = false);
  }

  int get unreadCount => notifications.where((n) => n['read'] == false).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundCream,
      endDrawer: showNotifications ? _buildNotificationsDrawer() : null,
      body: Builder(
        builder: (innerContext) {
          return Column(
            children: [
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [primaryMaroon, Color(0xFF8B2323)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
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
                                  icon: const Icon(Icons.menu, color: lightGoldText),
                                  onPressed: _showAdminMenu,
                                  tooltip: 'Admin Menu',
                                ),
                                const SizedBox(width: 8),
                                const Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Admin Dashboard',
                                      style: TextStyle(color: lightGoldText, fontSize: 20, fontWeight: FontWeight.bold),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Manage Projects & Users',
                                      style: TextStyle(color: primaryAccentGold, fontSize: 13),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.account_circle, color: lightGoldText),
                                  onPressed: _showAccountSettings,
                                  tooltip: 'Account Settings',
                                ),
                                Stack(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.notifications, color: lightGoldText),
                                      onPressed: () {
                                        setState(() => showNotifications = true);
                                        Scaffold.of(innerContext).openEndDrawer();
                                      },
                                      tooltip: 'Notifications',
                                    ),
                                    if (unreadCount > 0)
                                      Positioned(
                                        right: 8,
                                        top: 8,
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: const BoxDecoration(color: primaryAccentGold, shape: BoxShape.circle),
                                          constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                                          child: Text(
                                            '$unreadCount',
                                            style: const TextStyle(color: primaryMaroon, fontSize: 10, fontWeight: FontWeight.bold),
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
                    ? const Center(child: CircularProgressIndicator(color: primaryMaroon))
                    : Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: TextField(
                              onChanged: (value) => setState(() => searchQuery = value),
                              decoration: InputDecoration(
                                hintText: activeTab == 0 ? 'Search districts...' : 'Search by name or email...',
                                prefixIcon: const Icon(Icons.search, color: primaryMaroon),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                                filled: true,
                                fillColor: softParchment,
                              ),
                            ),
                          ),
                          Expanded(child: activeTab == 0 ? _buildDistrictsList() : _buildUsersList()),
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
          color: isActive ? primaryAccentGold : primaryMaroon.withOpacity(0.3),
          borderRadius: BorderRadius.circular(14),
          border: isActive ? null : Border.all(color: primaryAccentGold.withOpacity(0.5)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: isActive ? primaryMaroon : primaryAccentGold),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(color: isActive ? primaryMaroon : primaryAccentGold, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDistrictsList() {
    if (districts.isEmpty) return const Center(child: Text('No districts available', style: TextStyle(color: primaryMaroon)));
    final filtered = districts.where((d) => d['name'].toString().toLowerCase().contains(searchQuery.toLowerCase())).toList();
    if (filtered.isEmpty) return const Center(child: Text('No results found'));

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final district = filtered[index];
        return Card(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: primaryAccentGold, width: 0.5)),
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DistrictPlacesScreen(districtId: district['id']))),
            title: Text(district['name'], style: const TextStyle(fontWeight: FontWeight.bold, color: darkMaroonText)),
            subtitle: Text('${district['places']} Places', style: const TextStyle(color: Colors.black54)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if ((district['newRequests'] ?? 0) > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: primaryMaroon, borderRadius: BorderRadius.circular(12)),
                    child: Text('${district['newRequests']} New', style: const TextStyle(color: lightGoldText, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right, color: primaryMaroon),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildUsersList() {
    if (users.isEmpty) return const Center(child: Text('No users available', style: TextStyle(color: primaryMaroon)));
    final filtered = users.where((u) => u['name'].toString().toLowerCase().contains(searchQuery.toLowerCase()) || u['email'].toString().toLowerCase().contains(searchQuery.toLowerCase())).toList();
    if (filtered.isEmpty) return const Center(child: Text('No results found'));

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final user = filtered[index];
        return Card(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: primaryAccentGold, width: 0.5)),
          margin: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: () => _showUserDetail(user),
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text(user['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: darkMaroonText))),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(color: backgroundCream, borderRadius: BorderRadius.circular(12)),
                        child: Text('${user['activeProjects']} Projects', style: const TextStyle(color: primaryMaroon, fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(user['email'], style: const TextStyle(fontSize: 14)),
                  Text(user['phone'], style: const TextStyle(fontSize: 14)),
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
      backgroundColor: backgroundCream,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(gradient: LinearGradient(colors: [primaryMaroon, Color(0xFF8B2323)])),
            child: SafeArea(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Notifications', style: TextStyle(color: lightGoldText, fontSize: 18, fontWeight: FontWeight.bold)),
                      Text('$unreadCount unread', style: const TextStyle(color: primaryAccentGold, fontSize: 14)),
                    ],
                  ),
                  IconButton(icon: const Icon(Icons.close, color: lightGoldText), onPressed: () => Navigator.of(context).maybePop()),
                ],
              ),
            ),
          ),
          Expanded(child: notifications.isEmpty ? const Center(child: Text('No notifications')) : ListView.builder(itemCount: notifications.length, itemBuilder: (context, index) => _buildNotificationItem(notifications[index]))),
        ],
      ),
    );
  }

  Widget _buildNotificationItem(Map<String, dynamic> notif) {
    bool read = notif['read'] == true;
    return InkWell(
      onTap: () => setState(() => notif['read'] = true),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: read ? Colors.white : softParchment, border: const Border(bottom: BorderSide(color: primaryAccentGold, width: 0.2))),
        child: Row(
          children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: read ? Colors.grey : primaryMaroon, shape: BoxShape.circle)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(notif['message'], style: TextStyle(fontSize: 14, fontWeight: read ? FontWeight.normal : FontWeight.w600, color: darkMaroonText)),
                  Text(notif['time'], style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAdminMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: backgroundCream,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(leading: const Icon(Icons.account_circle, color: primaryMaroon), title: const Text('Account Settings'), onTap: () { Navigator.pop(context); _showAccountSettings(); }),
            ListTile(leading: const Icon(Icons.logout, color: Colors.red), title: const Text('Logout'), onTap: () { Navigator.pop(context); _performLogout(); }),
          ],
        ),
      ),
    );
  }

  void _showAccountSettings() { /* Dialog implementation with primaryMaroon buttons */ }
  void _performLogout() { /* Logout implementation */ }
  void _showUserDetail(Map<String, dynamic> user) { /* Dialog implementation with primaryMaroon buttons */ }
}