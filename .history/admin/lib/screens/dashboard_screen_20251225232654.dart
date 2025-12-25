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
      // Load USERS from Firestore (collection: users)
      final usersSnap =
          await FirebaseFirestore.instance.collection('users').get();

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

      // Load all projects and group by district
      final projectsSnap =
          await FirebaseFirestore.instance.collection('projects').get();

      final Map<String, Map<String, dynamic>> byDistrict = {};

      for (final doc in projectsSnap.docs) {
        final data = doc.data();
        final districtName = (data['district'] ?? '').toString();
        if (districtName.isEmpty) continue;

        final entry = byDistrict.putIfAbsent(districtName, () {
          return <String, dynamic>{
            'id': districtName, // use name as id for now
            'name': districtName,
            'places': 0,
            'newRequests': 0,
          };
        });

        // count distinct places in this district
        final placeName = (data['place'] ?? '').toString();
        if (placeName.isNotEmpty) {
          // maintain a Set of places inside the map
          final set =
              (entry['_placeSet'] as Set<String>? ?? <String>{})..add(placeName);
          entry['_placeSet'] = set;
          entry['places'] = set.length;
        }

        // count not‑sanctioned projects as new requests
        final bool isSanctioned = data['isSanctioned'] == true;
        if (!isSanctioned) {
          entry['newRequests'] = (entry['newRequests'] as int) + 1;
        }
      }

      districts = byDistrict.values
          .map((e) {
            e.remove('_placeSet'); // internal helper
            return e;
          })
          .toList();

      // Mock notifications (kept as before)
      notifications = [
        {
          'id': '1',
          'message': 'New project request from Ravi Kumar',
          'time': '2 hours ago',
          'read': false
        },
        {
          'id': '2',
          'message': 'Bill uploaded for Ongoing Temple',
          'time': '1 day ago',
          'read': true
        },
      ];
    } catch (e) {
      debugPrint('Error loading data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load data: $e')),
      );
    }

    setState(() => isLoading = false);
  }

  int get unreadCount => notifications.where((n) => n['read'] == false).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      endDrawer: showNotifications ? _buildNotificationsDrawer() : null,
      body: Builder(
        builder: (innerContext) {
          return Column(
            children: [
              // Header with menu + title + account + notifications
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
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
                                  icon: const Icon(Icons.menu, color: Colors.white),
                                  onPressed: _showAdminMenu,
                                  tooltip: 'Admin Menu',
                                ),
                                const SizedBox(width: 8),
                                const Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Admin Dashboard',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Manage Projects & Users',
                                      style: TextStyle(
                                        color: Color(0xFFC7D2FE),
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
                                  icon: const Icon(Icons.account_circle, color: Colors.white),
                                  onPressed: _showAccountSettings,
                                  tooltip: 'Account Settings',
                                ),
                                Stack(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.notifications, color: Colors.white),
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
                                          decoration: const BoxDecoration(
                                            color: Colors.red,
                                            shape: BoxShape.circle,
                                          ),
                                          constraints: const BoxConstraints(
                                            minWidth: 16,
                                            minHeight: 16,
                                          ),
                                          child: Text(
                                            '$unreadCount',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
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

                        // Tabs
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

              // Content
              Expanded(
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : Column(
                        children: [
                          // Search Bar
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: TextField(
                              onChanged: (value) => setState(() => searchQuery = value),
                              decoration: InputDecoration(
                                hintText: activeTab == 0
                                    ? 'Search districts...'
                                    : 'Search by name or email...',
                                prefixIcon: const Icon(Icons.search),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                            ),
                          ),

                          // List
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

  // Tabs
  Widget _buildTab(String label, IconData icon, int index) {
    final isActive = activeTab == index;
    return GestureDetector(
      onTap: () => setState(() => activeTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : const Color(0xFF6366F1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isActive ? const Color(0xFF4F46E5) : Colors.white,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isActive ? const Color(0xFF4F46E5) : Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // District list
  Widget _buildDistrictsList() {
    if (districts.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_off, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No districts available', style: TextStyle(fontSize: 16, color: Colors.grey)),
          ],
        ),
      );
    }

    final filtered = districts.where((d) {
      return d['name'].toString().toLowerCase().contains(searchQuery.toLowerCase());
    }).toList();

    if (filtered.isEmpty) {
      return const Center(child: Text('No results found'));
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final district = filtered[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DistrictPlacesScreen(districtId: district['id']),
                ),
              );
            },
            title: Text(
              district['name'],
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text('${district['places']} Places'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if ((district['newRequests'] ?? 0) > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${district['newRequests']} New',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        );
      },
    );
  }

  // Users list
  Widget _buildUsersList() {
    if (users.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No users available', style: TextStyle(fontSize: 16, color: Colors.grey)),
          ],
        ),
      );
    }

    final filtered = users.where((u) {
      return u['name'].toString().toLowerCase().contains(searchQuery.toLowerCase()) ||
          u['email'].toString().toLowerCase().contains(searchQuery.toLowerCase());
    }).toList();

    if (filtered.isEmpty) {
      return const Center(child: Text('No results found'));
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final user = filtered[index];
        return Card(
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
                      Expanded(
                        child: Text(
                          user['name'],
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF2FF),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${user['activeProjects']} Project${user['activeProjects'] != 1 ? 's' : ''}',
                          style: const TextStyle(
                            color: Color(0xFF4F46E5),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(user['email'], style: const TextStyle(fontSize: 14)),
                  Text(user['phone'], style: const TextStyle(fontSize: 14)),
                  const SizedBox(height: 4),
                  Text('Aadhar: ${user['aadhar']}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  Text(user['address'],
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Notifications drawer
  Drawer _buildNotificationsDrawer() {
    return Drawer(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
              ),
            ),
            child: SafeArea(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Notifications',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$unreadCount unread',
                        style: const TextStyle(color: Color(0xFFC7D2FE), fontSize: 14),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () {
                      setState(() => showNotifications = false);
                      Navigator.of(context).maybePop();
                    },
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: notifications.isEmpty
                ? const Center(
                    child: Text(
                      'No notifications',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: notifications.length,
                    itemBuilder: (context, index) {
                      final notif = notifications[index];
                      return _buildNotificationItem(
                        notif['id'],
                        notif['message'],
                        notif['time'],
                        notif['read'] == true,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationItem(String id, String message, String time, bool read) {
    return InkWell(
      onTap: () {
        setState(() {
          final idx = notifications.indexWhere((n) => n['id'] == id);
          if (idx != -1) notifications[idx]['read'] = true;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: read ? Colors.white : const Color(0xFFEEF2FF),
          border: const Border(
            bottom: BorderSide(color: Color(0xFFE5E7EB)),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: read ? Colors.grey : const Color(0xFF4F46E5),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: read ? FontWeight.normal : FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    time,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Admin menu (account settings, personal info, logout)
  void _showAdminMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.account_circle),
              title: const Text('Account Settings'),
              onTap: () {
                Navigator.pop(context);
                _showAccountSettings();
              },
            ),
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('Personal Info'),
              onTap: () {
                Navigator.pop(context);
                _showPersonalInfo();
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Logout'),
              onTap: () {
                Navigator.pop(context);
                _performLogout();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAccountSettings() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Account Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('• Change password'),
            Text('• Change language'),
            Text('• Enable dark mode'),
            SizedBox(height: 8),
            Text(
              'Connect these to your backend later.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showPersonalInfo() {
    // TODO: Replace with actual admin data
    showDialog(
      context: context,
      builder: (context) => const AlertDialog(
        title: Text('Personal Info'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Name: Admin User'),
            Text('Email: admin@example.com'),
            Text('Phone: +91 99999 99999'),
            Text('Role: Super Admin'),
          ],
        ),
      ),
    );
  }

  void _performLogout() {
    // TODO: Implement real logout (clear tokens, navigate to login)
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Logged out (mock). Connect real logout later')),
    );
  }

  // User detail & remove
  void _showUserDetail(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(user['name'] ?? ''),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Email: ${user['email']}'),
              Text('Phone: ${user['phone']}'),
              Text('Aadhar: ${user['aadhar']}'),
              Text('Address: ${user['address']}'),
              const SizedBox(height: 12),
              Text(
                'Active Projects: ${user['activeProjects']}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                users.removeWhere((u) => u['id'] == user['id']);
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(this.context).showSnackBar(
                SnackBar(content: Text('User ${user['name']} removed')),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove User'),
          ),
        ],
      ),
    );
  }
}
