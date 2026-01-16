import 'package:flutter/material.dart';
import 'district_places_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

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

  // Stream subscriptions for real-time updates
  StreamSubscription? _projectsSubscription;
  StreamSubscription? _usersSubscription;

  @override
  void initState() {
    super.initState();
    _startRealTimeListeners();
  }

  @override
  void dispose() {
    _projectsSubscription?.cancel();
    _usersSubscription?.cancel();
    super.dispose();
  }

  void _startRealTimeListeners() {
    setState(() => isLoading = true);

    // Listen to Projects and Users simultaneously
    _projectsSubscription = FirebaseFirestore.instance
        .collection('projects')
        .snapshots()
        .listen((projectsSnap) {
      
      FirebaseFirestore.instance
          .collection('users')
          .snapshots()
          .listen((usersSnap) {
        
        _processData(projectsSnap, usersSnap);
      });
    });
  }

  void _processData(QuerySnapshot projectsSnap, QuerySnapshot usersSnap) {
    try {
      final Set<String> usersWithOngoing = {};
      final Set<String> usersWithProposals = {};
      final Map<String, Map<String, dynamic>> byDistrict = {};

      for (final doc in projectsSnap.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final districtName = (data['district'] ?? '').toString().trim();
        final userName = (data['userName'] ?? '').toString().trim();
        final status = (data['status'] ?? 'pending').toString().toLowerCase();
        final bool isSanctioned = data['isSanctioned'] == true;

        if (userName.isNotEmpty) {
          usersWithProposals.add(userName);
          // Ongoing if not pending
          if (isSanctioned || status != 'pending') {
            usersWithOngoing.add(userName);
          }
        }

        if (districtName.isEmpty || districtName.toLowerCase() == 'null') continue;

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

        if (!isSanctioned && status == 'pending') {
          entry['newRequests'] = (entry['newRequests'] as int) + 1;
        }
      }

      // Process Users
      final List<Map<String, dynamic>> processedUsers = usersSnap.docs
          .map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final name = data['name'] ?? '';
            return {
              'id': doc.id,
              'name': name,
              'email': data['email'] ?? '',
              'phone': data['phoneNumber'] ?? data['phone'] ?? 'N/A',
              'district': data['district'] ?? 'Not Specified',
              'taluk': data['taluk'] ?? 'Not Specified',
              'isOngoing': usersWithOngoing.contains(name),
              'hasProposal': usersWithProposals.contains(name),
            };
          })
          .where((u) => u['hasProposal'] == true)
          .toList();

      setState(() {
        districts = byDistrict.values.toList();
        districts.sort((a, b) => (b['newRequests'] as int).compareTo(a['newRequests'] as int));
        users = processedUsers;
        isLoading = false;
        
        // Mock notifications for UI consistency
        notifications = [
          {'id': '1', 'message': 'Live Sync Active', 'time': 'Just now', 'read': false},
        ];
      });
    } catch (e) {
      debugPrint('Error processing real-time data: $e');
    }
  }

  int get unreadCount => notifications.where((n) => n['read'] == false).length;

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

  Widget _buildHeader(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [Color(0xFF6D1B1B), Color(0xFF4A1010)]),
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
                      IconButton(icon: const Icon(Icons.menu, color: Color(0xFFFFF4D6)), onPressed: _showAdminMenu),
                      const SizedBox(width: 8),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Admin Dashboard', style: TextStyle(color: Color(0xFFFFF4D6), fontSize: 20, fontWeight: FontWeight.bold)),
                          Text('Live Proposal Tracking', style: TextStyle(color: Color(0xFFD4AF37), fontSize: 13)),
                        ],
                      ),
                    ],
                  ),
                  _buildNotificationIcon(context),
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

  Widget _buildNotificationIcon(BuildContext context) {
    return Stack(
      children: [
        IconButton(
          icon: const Icon(Icons.notifications, color: Color(0xFFFFF4D6)),
          onPressed: () {
            setState(() => showNotifications = true);
            Scaffold.of(context).openEndDrawer();
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
              child: Text('$unreadCount', style: const TextStyle(color: Color(0xFF6D1B1B), fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        onChanged: (value) => setState(() => searchQuery = value),
        decoration: InputDecoration(
          hintText: activeTab == 0 ? 'Search districts...' : 'Search by name or email...',
          hintStyle: const TextStyle(color: Color(0xFF4A1010)),
          prefixIcon: const Icon(Icons.search, color: Color(0xFF6D1B1B)),
          filled: true,
          fillColor: const Color(0xFFFFFBF2),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFB8962E))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFD4AF37), width: 2)),
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
            Text(label, style: TextStyle(color: isActive ? const Color(0xFF6D1B1B) : Colors.white, fontWeight: FontWeight.w600)),
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
                const Icon(Icons.chevron_right, color: Color(0xFFD4AF37)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildUsersList() {
    final filtered = users.where((u) => u['name'].toString().toLowerCase().contains(searchQuery.toLowerCase()) || u['email'].toString().toLowerCase().contains(searchQuery.toLowerCase())).toList();
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final user = filtered[index];
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
                    Row(
                      children: [
                        Text(user['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF4A1010))),
                        if (user['isOngoing'] == true) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.flag, color: Colors.green, size: 20),
                        ]
                      ],
                    ),
                    Text(user['phone'], style: const TextStyle(color: Color(0xFF6D1B1B), fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(user['email'], style: const TextStyle(color: Colors.grey, fontSize: 13)),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 16, color: Color(0xFFB8962E)),
                        const SizedBox(width: 6),
                        Text("${user['taluk']}, ${user['district']}", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                      ],
                    ),
                    TextButton.icon(
                      onPressed: () => _confirmRemoveUser(user),
                      icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                      label: const Text("Remove", style: TextStyle(color: Colors.red, fontSize: 12)),
                    )
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _confirmRemoveUser(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Remove User?"),
        content: Text("Delete ${user['name']}? This is permanent."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('users').doc(user['id']).delete();
              Navigator.pop(context);
            },
            child: const Text("Remove", style: TextStyle(color: Colors.red)),
          ),
        ],
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
            child: SafeArea(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Notifications', style: TextStyle(color: Color(0xFFFFF4D6), fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),
          ),
          Expanded(child: ListView.builder(itemCount: notifications.length, itemBuilder: (context, index) => ListTile(title: Text(notifications[index]['message'])))),
        ],
      ),
    );
  }

  void _showAdminMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(leading: const Icon(Icons.logout, color: Colors.red), title: const Text('Logout'), onTap: () => Navigator.pop(context)),
          ],
        ),
      ),
    );
  }
}