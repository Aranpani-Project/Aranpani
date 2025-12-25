import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'pending_temple_detail_screen.dart';
import 'ongoing_temple_detail_screen.dart';
import 'completed_temple_detail_screen.dart';

class TempleDetailScreen extends StatefulWidget {
  final String templeId;
  final Map<String, dynamic> initialTempleData;

  const TempleDetailScreen({
    super.key,
    required this.templeId,
    required this.initialTempleData,
  });

  @override
  State<TempleDetailScreen> createState() => _TempleDetailScreenState();
}

class _TempleDetailScreenState extends State<TempleDetailScreen> {
  // --- Aranpani Theme Tokens ---
  static const Color primaryMaroon = Color(0xFF6D1B1B);
  static const Color backgroundCream = Color(0xFFFFF7E8);
  static const Color primaryGold = Color(0xFFD4AF37);

  Map<String, dynamic>? temple;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTemple();
  }

  Future<void> _loadTemple() async {
    if (!mounted) return;
    setState(() => isLoading = true);

    temple = Map<String, dynamic>.from(widget.initialTempleData);

    try {
      final doc = await FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.templeId)
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        temple!.addAll(data);
        temple!['id'] = widget.templeId;
      }
    } catch (e) {
      debugPrint('Error loading temple: $e');
    }

    _normalizeTempleFields();

    if (mounted) {
      setState(() => isLoading = false);
    }
  }

  void _normalizeTempleFields() {
    if (temple == null) return;
    final t = temple!;

    final bool isSanctioned = t['isSanctioned'] == true;
    final int progress = ((t['progress'] ?? 0) as num).toInt();

    if (!isSanctioned) {
      t['status'] = 'pending';
    } else if (progress >= 100) {
      t['status'] = 'completed';
    } else {
      t['status'] = 'ongoing';
    }

    t['projectNumber'] = (t['projectNumber'] ?? t['projectId'] ?? 'P000').toString();

    t['name'] = (t['name'] ??
            (t['feature'] != null && t['feature'] != ''
                ? '${t['feature']} Project'
                : 'Temple Project'))
        .toString();
  }

  @override
  Widget build(BuildContext context) {
    // FIXED: Consistent Alignment during loading to prevent "jumpy" transitions
    if (isLoading || temple == null) {
      return Scaffold(
        backgroundColor: backgroundCream,
        // Match the header height and alignment of sub-screens
        appBar: AppBar(
          backgroundColor: primaryMaroon,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'Loading Details...',
            style: TextStyle(color: Color(0xFFFFF4D6), fontSize: 18),
          ),
        ),
        body: const Center(
          child: CircularProgressIndicator(
            color: primaryMaroon,
          ),
        ),
      );
    }

    final String status = (temple!['status'] ?? 'pending').toString();

    // These screens should now handle their own Scaffolds but start 
    // from the same vertical alignment defined here.
    switch (status) {
      case 'pending':
        return PendingTempleDetailScreen(
          temple: temple!,
          onUpdated: (updated) => Navigator.pop(context, updated),
          onDeleted: () => Navigator.pop(context, null),
        );
      case 'ongoing':
        return OngoingTempleDetailScreen(
          temple: temple!,
          onUpdated: (updated) => Navigator.pop(context, updated),
        );
      case 'completed':
        return CompletedTempleDetailScreen(
          temple: temple!,
          onUpdated: (updated) => Navigator.pop(context, updated),
        );
      default:
        return const Scaffold(body: Center(child: Text('Unknown Status')));
    }
  }
}