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

  /// Real-time listeners automatically "refresh" the screen whenever 
  /// data in Firebase changes because of the setState inside the listener.
  void _startRealTimeListeners() {
    setState(() => isLoading = true);

    _projectsSubscription = FirebaseFirestore.instance
        .collection('projects')
        .snapshots()
        .listen((projectsSnap) {
      
      _usersSubscription?.cancel(); 
      _usersSubscription = FirebaseFirestore.instance
          .collection('users')
          .snapshots()
          .listen((usersSnap) {
        _processData(projectsSnap, usersSnap);
      });
    });
  }

  void _processData(QuerySnapshot projectsSnap, QuerySnapshot usersSnap) {
    try {
      // We use Sets of User IDs for reliable mapping
      final Set<String> idsWithOngoing = {};
      final Set<String> idsWithProposals = {};
      final Map<String, Map<String, dynamic>> byDistrict = {};

      // 1. Process Projects
      for (final doc in projectsSnap.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final String dName = (data['district'] ?? '').toString().trim();
        final String uId = (data['userId'] ?? '').toString().trim();
        final String status = (data['status'] ?? 'pending').toString().toLowerCase();
        final bool isSanctioned = data['isSanctioned'] == true;

        if (uId.isNotEmpty) {
          idsWithProposals.add(uId);
          // Flag as ongoing if sanctioned OR status is specifically 'ongoing'
          if (isSanctioned || status == 'ongoing') {
            idsWithOngoing.add(uId);
          }
        }

        if (dName.isEmpty || dName.toLowerCase() == 'null') continue;

        final entry = byDistrict.putIfAbsent(dName, () {
          return <String, dynamic>{
            'id': dName,
            'name': dName,
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

      // 2. Process Users
      final List<Map<String, dynamic>> allUsers = usersSnap.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final String currentUserId = doc.id;
        
        // Helper to sanitize "null" or empty strings
        String sanitize(dynamic value) {
          if (value == null) return 'Not Assigned';
          String valStr = value.toString().trim();
          if (valStr.isEmpty || valStr.toLowerCase() == 'null') return 'Not Assigned';
          return valStr;
        }

        return {
          'id': currentUserId,
          'name': data['name'] ?? data['contactName'] ?? 'Unknown User',
          'phone': data['phone'] ?? data['phoneNumber'] ?? data['contactPhone'] ?? 'N/A',
          'district': sanitize(data['district']),
          'taluk': sanitize(data['taluk']),
          'isOngoing': idsWithOngoing.contains(currentUserId),
          'hasProposal': idsWithProposals.contains(currentUserId),
        };
      }).toList();

      // Sort Users A-Z
      allUsers.sort((a, b) => a['name'].toString().toLowerCase().compareTo(b['name'].toString().toLowerCase()));

      setState(() {
        districts = byDistrict.values.toList();
        districts.sort((a, b) {
          int countA = a['newRequests'] as int;
          int countB = b['newRequests'] as int;
          if (countB != countA) return countB.compareTo(countA);
          return a['name'].toString().compareTo(b['name'].toString());
        });

        users = allUsers; 
        isLoading = false;
        notifications = [{'id': '1', 'message': 'Database Updated', 'time': 'Just now', 'read': false}];
      });
    } catch (e) {
      debugPrint('Error processing data: $e');
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
                          Text('Real-time Monitoring', style: TextStyle(color: Color(0xFFD4AF37), fontSize: 13)),
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
          hintText: activeTab == 0 ? 'Search districts...' : 'Search name or phone...',
          hintStyle: const TextStyle(color: Color(0xFF4A1010), fontSize: 14),
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
      onTap: () => setState(() {
        activeTab = index;
        searchQuery = '';
      }),
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
    if (filtered.isEmpty) return const Center(child: Text("No districts found"));

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
    final filtered = users.where((u) => 
      u['name'].toString().toLowerCase().contains(searchQuery.toLowerCase()) || 
      u['phone'].toString().toLowerCase().contains(searchQuery.toLowerCase())
    ).toList();

    if (filtered.isEmpty) return const Center(child: Text("No users found"));

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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(user['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Color(0xFF4A1010))),
                              const SizedBox(width: 8),
                              if (user['isOngoing'] == true) 
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.green.shade700),
                                  ),
                                  child: Text("ONGOING", style: TextStyle(color: Colors.green.shade700, fontSize: 10, fontWeight: FontWeight.bold)),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(user['phone'], style: const TextStyle(color: Color(0xFF6D1B1B), fontWeight: FontWeight.bold, fontSize: 14)),
                        ],
                      ),
                    ),
                    if (user['hasProposal'] == false)
                      const Text("(No Proposal)", style: TextStyle(color: Colors.grey, fontSize: 11, fontStyle: FontStyle.italic)),
                  ],
                ),
                const Divider(height: 24, thickness: 0.5),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildUserDetailRow(Icons.map, "District: ", user['district']),
                          const SizedBox(height: 6),
                          _buildUserDetailRow(Icons.location_city, "Taluk: ", user['taluk']),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => _confirmRemoveUser(user),
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 22),
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

  Widget _buildUserDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFFB8962E)),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 13, color: Colors.black87), overflow: TextOverflow.ellipsis)),
      ],
    );
  }

  void _confirmRemoveUser(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete User?"),
        content: Text("Permanently delete ${user['name']}?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('users').doc(user['id']).delete();
              Navigator.pop(context);
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
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
          Expanded(
            child: notifications.isEmpty 
              ? const Center(child: Text("No new updates"))
              : ListView.builder(
                  itemCount: notifications.length, 
                  itemBuilder: (context, index) => ListTile(
                    leading: const Icon(Icons.info_outline, color: Color(0xFF6D1B1B)),
                    title: Text(notifications[index]['message']),
                    subtitle: Text(notifications[index]['time']),
                  )
                )
          ),
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
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red), 
              title: const Text('Logout'), 
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}