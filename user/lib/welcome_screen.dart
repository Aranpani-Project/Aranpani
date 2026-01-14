// lib/screens/welcome_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

import '../screens/create_project_screen.dart';
import '../screens/profile_screen.dart';
import 'splash_screen.dart';
import '../screens/project_overview_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  Map<String, dynamic>? _userData;
  Map<String, dynamic>? _project; 
  bool _loading = true;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadUserAndProjects();
  }

  Future<void> _loadUserAndProjects() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const SplashScreen()),
          (route) => false,
        );
        return;
      }

      final userDoc = await _firestore.collection('users').doc(user.uid).get();

      final projectDocs = await _firestore
          .collection('projects')
          .where('userId', isEqualTo: user.uid)
          .orderBy('dateCreated', descending: true)
          .limit(1)
          .get();

      Map<String, dynamic>? project;
      if (projectDocs.docs.isNotEmpty) {
        final d = projectDocs.docs.first;
        project = {'id': d.id, ...d.data()};
      }

      setState(() {
        _userData = userDoc.data() ?? {'name': 'User', 'email': user.email};
        _project = project;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  void _navigateToCreateProject() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CreateProjectScreen()),
    );
    if (result == true) _loadUserAndProjects();
  }

  // UPDATED LOGIC: RESTRICT ACCESS UNLESS APPROVED
  void _handleProjectTap(Map<String, dynamic> project) {
    final status = (project['status'] ?? 'pending').toString().toLowerCase();

    if (status == 'approved' || status == 'ongoing') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProjectOverviewScreen(project: project),
        ),
      );
    } else {
      // Show a polite notice that it's still pending
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Your plan is currently under review. You can access the project dashboard once it is sanctioned.',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: const Color(0xFF5D4037),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _deleteProject() async {
    if (_project == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFFFFFDF5),
        title: Text('Delete plan', style: GoogleFonts.cinzel(color: const Color(0xFF5D4037))),
        content: const Text('This will remove your proposal. This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFB71C1C)),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _firestore.collection('projects').doc(_project!['id']).delete();
      _loadUserAndProjects();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
          backgroundColor: Color(0xFFFFFDF5),
          body: Center(child: CircularProgressIndicator(color: Color(0xFF5D4037))));
    }

    final photoUrl = _userData?['photoUrl'] as String?;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFFFFDF5),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFFDF5), Color(0xFFF5E6CA)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _header(),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _welcomeCard(),
                      const SizedBox(height: 26),
                      _projectHeader(),
                      const SizedBox(height: 14),
                      _createProjectButton(),
                      const SizedBox(height: 18),
                      _projectSection(), // NEW UI HERE
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      drawer: _buildDrawer(photoUrl),
      bottomNavigationBar: _bottomNavBar(),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 18),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFFD4AF37), Color(0xFFB8962E)],
                ),
                boxShadow: [
                  BoxShadow(color: Colors.black12, blurRadius: 8, offset: const Offset(0, 4)),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: ClipOval(child: Image.asset('assets/images/shiva.png', fit: BoxFit.cover)),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Aranpani',
                    style: GoogleFonts.cinzelDecorative(
                        fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF5D4037))),
                Text('Welcome',
                    style: GoogleFonts.poppins(color: const Color(0xFF8D6E63), fontSize: 12)),
              ],
            ),
          ]),
          IconButton(
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            icon: const Icon(Icons.menu, color: Color(0xFF5D4037)),
          ),
        ],
      ),
    );
  }

  Widget _welcomeCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFEFE6D5),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: Color(0xFF5D4037),
            child: Icon(Icons.person, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Text('Welcome back, ${_userData?['name'] ?? 'User'}',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: const Color(0xFF3E2723))),
        ],
      ),
    );
  }

  Widget _projectHeader() {
    return Text('My Proposal',
        style: GoogleFonts.cinzel(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF3E2723)));
  }

  Widget _createProjectButton() {
    final hasProject = _project != null;
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        icon: const Icon(Icons.add_circle_outline),
        label: Text(hasProject ? "Plan Submitted" : "Propose a plan"),
        style: ElevatedButton.styleFrom(
          backgroundColor: hasProject ? Colors.grey[400] : const Color(0xFF5D4037),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: hasProject ? null : _navigateToCreateProject,
      ),
    );
  }

  // UPDATED UI TO SHOW PENDING VS ONGOING
  Widget _projectSection() {
    if (_project == null) return const Center(child: Text("No plans proposed yet."));

    final String status = (_project!['status'] ?? 'pending').toString().toLowerCase();
    final bool isApproved = status == 'approved' || status == 'ongoing';
    
    // UI Theme based on status
    final Color statusColor = isApproved ? Colors.green.shade700 : Colors.orange.shade800;
    final Color bgColor = isApproved ? Colors.green.shade50 : Colors.orange.shade50;
    final IconData statusIcon = isApproved ? Icons.check_circle_rounded : Icons.hourglass_empty_rounded;

    return InkWell(
      onTap: () => _handleProjectTap(_project!),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: statusColor.withOpacity(0.3), width: 1),
          boxShadow: [
            BoxShadow(color: statusColor.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 8))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    children: [
                      Icon(statusIcon, size: 14, color: statusColor),
                      const SizedBox(width: 5),
                      Text(
                        status.toUpperCase(),
                        style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor),
                      ),
                    ],
                  ),
                ),
                Text(
                  _project!['projectId'] ?? '',
                  style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              _project!['place'] ?? 'Unnamed Temple',
              style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF3E2723)),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.location_on, size: 14, color: Color(0xFF8D6E63)),
                const SizedBox(width: 4),
                Text(
                  "${_project!['taluk']}, ${_project!['district']}",
                  style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF8D6E63)),
                ),
              ],
            ),
            const Divider(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Different action label based on status
                Text(
                  isApproved ? 'Tap to view work progress' : 'Waiting for sanction...',
                  style: GoogleFonts.poppins(
                    fontSize: 12, 
                    fontWeight: FontWeight.w500, 
                    color: isApproved ? const Color(0xFF5D4037) : Colors.grey,
                    fontStyle: isApproved ? FontStyle.normal : FontStyle.italic
                  ),
                ),
                if (status == 'pending')
                  IconButton(
                    icon: const Icon(Icons.delete_sweep_outlined, color: Colors.redAccent),
                    onPressed: _deleteProject,
                  )
                else
                  const Icon(Icons.arrow_forward_ios, size: 14, color: Color(0xFF5D4037)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _bottomNavBar() {
    return BottomNavigationBar(
      backgroundColor: const Color(0xFFFFFDF5),
      currentIndex: _currentIndex,
      selectedItemColor: const Color(0xFF5D4037),
      onTap: (index) {
        if (index == 1) _openProfile();
        setState(() => _currentIndex = index);
      },
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
      ],
    );
  }

  Future<void> _openProfile() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
    _loadUserAndProjects();
    setState(() => _currentIndex = 0);
  }

  Future<void> _logout() async {
    await _auth.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const SplashScreen()), (r) => false);
  }

  Widget _buildDrawer(String? photoUrl) {
    return Drawer(
      child: ListView(
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(color: Color(0xFFF5E6CA)),
            accountName: Text(_userData?['name'] ?? 'User', style: const TextStyle(color: Color(0xFF3E2723))),
            accountEmail: Text(_userData?['email'] ?? '', style: const TextStyle(color: Color(0xFF3E2723))),
            currentAccountPicture: CircleAvatar(
              backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
              child: photoUrl == null ? const Icon(Icons.person) : null,
            ),
          ),
          ListTile(leading: const Icon(Icons.logout), title: const Text('Logout'), onTap: _logout),
        ],
      ),
    );
  }
}