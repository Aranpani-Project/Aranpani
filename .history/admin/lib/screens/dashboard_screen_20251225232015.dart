import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'district_places_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int activeTab = 0; // 0: Projects, 1: Users
  String searchQuery = '';

  // EXACT COLORS FROM LOGIN SCREEN
  final Color primaryMaroon = const Color(0xFF800000); 
  final Color goldAccent = const Color(0xFFD4AF37);
  final Color lightBg = const Color(0xFFF9F9F9);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightBg,
      endDrawer: _buildNotificationsDrawer(),
      body: Column(
        children: [
          _buildHeader(),
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
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.only(top: 50, bottom: 25, left: 20, right: 20),
      decoration: BoxDecoration(
        color: primaryMaroon,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: Icon(Icons.menu, color: goldAccent),
                onPressed: _showAdminMenu,
              ),
              Column(
                children: [
                  Text(
                    'ARANPANI',
                    style: TextStyle(
                      color: goldAccent,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                  const Text(
                    'Admin Portal',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
              Builder(
                builder: (context) => IconButton(
                  icon: Icon(Icons.notifications, color: goldAccent),
                  onPressed: () => Scaffold.of(context).openEndDrawer(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 25),
          // Custom Tab Bar
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.black24,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Row(
              children: [
                Expanded(child: _buildTabItem('Districts', 0)),
                Expanded(child: _buildTabItem('Volunteers', 1)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabItem(String label, int index) {
    bool isSelected = activeTab == index;
    return GestureDetector(
      onTap: () => setState(() => activeTab = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? goldAccent : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? primaryMaroon : Colors.white60,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      child: TextField(
        onChanged: (val) => setState(() => searchQuery = val.toLowerCase()),
        cursorColor: primaryMaroon,
        decoration: InputDecoration(
          hintText: activeTab == 0 ? 'Filter by District...' : 'Search by Name...',
          prefixIcon: Icon(Icons.search, color: primaryMaroon),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: goldAccent.withOpacity(0.5)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: goldAccent, width: 2),
          ),
        ),
      ),
    );
  }

  Widget _buildProjectsStream() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('projects').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return Center(child: CircularProgressIndicator(color: goldAccent));

        Map<String, Map<String, dynamic>> grouped = {};
        for (var doc in snapshot.data!.docs) {
          var data = doc.data() as Map<String, dynamic>;
          String dName = data['district'] ?? 'Unknown';
          if (!dName.toLowerCase().contains(searchQuery)) continue;

          if (!grouped.containsKey(dName)) {
            grouped[dName] = {'name': dName, 'count': 0, 'pending': 0};
          }
          grouped[dName]!['count'] += 1;
          if (data['isSanctioned'] == false) {
            grouped[dName]!['pending'] += 1;
          }
        }

        var districtList = grouped.values.toList();

        return ListView.builder(
          itemCount: districtList.length,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemBuilder: (context, i) {
            var item = districtList[i];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
                side: BorderSide(color: goldAccent.withOpacity(0.2)),
              ),
              child: ListTile(
                leading: Icon(Icons.temple_hindu, color: primaryMaroon),
                title: Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('${item['count']} Sites Recorded'),
                trailing: item['pending'] > 0 
                  ? CircleAvatar(
                      radius: 12,
                      backgroundColor: Colors.red,
                      child: Text('${item['pending']}', style: const TextStyle(color: Colors.white, fontSize: 10)),
                    )
                  : Icon(Icons.arrow_forward_ios, size: 14, color: goldAccent),
                onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => DistrictPlacesScreen(districtId: item['name']),
                )),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildUsersStream() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return Center(child: CircularProgressIndicator(color: goldAccent));

        var userDocs = snapshot.data!.docs.where((doc) {
          var name = (doc['name'] ?? '').toString().toLowerCase();
          return name.contains(searchQuery);
        }).toList();

        return ListView.builder(
          itemCount: userDocs.length,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemBuilder: (context, i) {
            var user = userDocs[i];
            return Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: goldAccent,
                  child: Text(user['name'][0].toUpperCase(), style: TextStyle(color: primaryMaroon)),
                ),
                title: Text(user['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(user['email']),
                onTap: () => _showUserDetail(user.id, user.data() as Map<String, dynamic>),
              ),
            );
          },
        );
      },
    );
  }

  void _showUserDetail(String id, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(data['name'], style: TextStyle(color: primaryMaroon)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _detailRow(Icons.phone, data['phoneNumber'] ?? 'N/A'),
            _detailRow(Icons.credit_card, data['aadharNumber'] ?? 'N/A'),
            _detailRow(Icons.home, data['address'] ?? 'N/A'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Close', style: TextStyle(color: Colors.grey[600]))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red[900]),
            onPressed: () async {
              await FirebaseFirestore.instance.collection('users').doc(id).delete();
              Navigator.pop(context);
            },
            child: const Text('Remove User', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [Icon(icon, size: 18, color: goldAccent), const SizedBox(width: 10), Expanded(child: Text(text))]),
    );
  }

  void _showAdminMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.logout, color: primaryMaroon),
              title: const Text('Logout from Admin'),
              onTap: () async {
                await FirebaseAuth.instance.signOut();
                Navigator.of(context).pushReplacementNamed('/login');
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationsDrawer() {
    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: primaryMaroon),
            child: Center(child: Text('Notifications', style: TextStyle(color: goldAccent, fontSize: 20))),
          ),
          const Expanded(child: Center(child: Text('All systems operational'))),
        ],
      ),
    );
  }
}