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
  int activeTab = 0; 
  String searchQuery = '';

  // EXACT COLORS EXTRACTED FROM YOUR LOGIN SCREEN
  final Color templeMaroon = const Color(0xFF6D1B1B);
  final Color goldDark = const Color(0xFFB8962E);
  final Color goldLight = const Color(0xFFD4AF37);
  final Color screenBg = const Color(0xFFFFF7E8);
  final Color inputFill = const Color(0xFFFFFBF2);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: screenBg,
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
        color: templeMaroon,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: Icon(Icons.menu_open, color: goldLight),
                onPressed: _showAdminMenu,
              ),
              Column(
                children: [
                  Text(
                    'ARANPANI',
                    style: TextStyle(
                      color: goldLight,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const Text(
                    'ADMIN PANEL',
                    style: TextStyle(color: Colors.white70, fontSize: 10, letterSpacing: 2),
                  ),
                ],
              ),
              Builder(
                builder: (context) => IconButton(
                  icon: Icon(Icons.notifications_none, color: goldLight),
                  onPressed: () => Scaffold.of(context).openEndDrawer(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 25),
          // Tab Switcher matching Login Button style
          Container(
            height: 50,
            decoration: BoxDecoration(
              color: Colors.black12,
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
      child: Container(
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          gradient: isSelected ? LinearGradient(colors: [goldLight, goldDark]) : null,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? templeMaroon : Colors.white60,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: TextField(
        onChanged: (val) => setState(() => searchQuery = val.toLowerCase()),
        decoration: InputDecoration(
          hintText: activeTab == 0 ? 'Filter Districts...' : 'Search Volunteers...',
          prefixIcon: Icon(Icons.search, color: templeMaroon),
          filled: true,
          fillColor: inputFill,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: goldLight.withOpacity(0.5)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: templeMaroon, width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _buildProjectsStream() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('projects').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return Center(child: CircularProgressIndicator(color: goldLight));

        // Grouping logic remains the same
        Map<String, Map<String, dynamic>> grouped = {};
        for (var doc in snapshot.data!.docs) {
          var data = doc.data() as Map<String, dynamic>;
          String dName = data['district'] ?? 'Unknown';
          if (!dName.toLowerCase().contains(searchQuery)) continue;

          if (!grouped.containsKey(dName)) {
            grouped[dName] = {'name': dName, 'count': 0, 'pending': 0};
          }
          grouped[dName]!['count'] += 1;
          if (data['isSanctioned'] == false) grouped[dName]!['pending'] += 1;
        }

        var list = grouped.values.toList();

        return ListView.builder(
          itemCount: list.length,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemBuilder: (context, i) {
            return Card(
              color: Colors.white,
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
                side: BorderSide(color: goldLight.withOpacity(0.3)),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: screenBg,
                  child: Icon(Icons.temple_hindu, color: templeMaroon),
                ),
                title: Text(list[i]['name'], style: TextStyle(color: templeMaroon, fontWeight: FontWeight.bold)),
                subtitle: Text('${list[i]['count']} Total Sites'),
                trailing: list[i]['pending'] > 0 
                  ? Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                      child: Text('${list[i]['pending']}', style: const TextStyle(color: Colors.white, fontSize: 10)),
                    )
                  : Icon(Icons.arrow_forward_ios, size: 14, color: goldDark),
                onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => DistrictPlacesScreen(districtId: list[i]['name']),
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
        if (!snapshot.hasData) return Center(child: CircularProgressIndicator(color: goldLight));

        var users = snapshot.data!.docs.where((doc) => 
          doc['name'].toString().toLowerCase().contains(searchQuery)).toList();

        return ListView.builder(
          itemCount: users.length,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemBuilder: (context, i) {
            return Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: ListTile(
                leading: CircleAvatar(backgroundColor: goldLight, child: const Icon(Icons.person, color: Colors.white)),
                title: Text(users[i]['name'], style: TextStyle(color: templeMaroon, fontWeight: FontWeight.bold)),
                subtitle: Text(users[i]['email']),
                onTap: () => _showUserDetail(users[i].id, users[i].data() as Map<String, dynamic>),
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
        backgroundColor: inputFill,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: goldLight)),
        title: Text(data['name'], style: TextStyle(color: templeMaroon)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(leading: Icon(Icons.phone, color: goldDark), title: Text(data['phoneNumber'] ?? 'N/A')),
            ListTile(leading: Icon(Icons.home, color: goldDark), title: Text(data['address'] ?? 'N/A')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: templeMaroon),
            onPressed: () async {
              await FirebaseFirestore.instance.collection('users').doc(id).delete();
              Navigator.pop(context);
            },
            child: const Text('Delete User', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showAdminMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: screenBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(25.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.logout, color: templeMaroon),
              title: const Text('Sign Out'),
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
      backgroundColor: screenBg,
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: templeMaroon),
            child: Center(child: Text('NOTIFICATIONS', style: TextStyle(color: goldLight, fontSize: 18, letterSpacing: 2))),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Text('Aranpani Admin v1.0', style: TextStyle(color: templeMaroon.withOpacity(0.5))),
          )
        ],
      ),
    );
  }
}