import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'pending_temple_detail_screen.dart';
import 'ongoing_temple_detail_screen.dart';
import 'completed_temple_detail_screen.dart';

class TempleDetailScreen extends StatefulWidget {
  final String templeId;
  final Map<String, dynamic>? initialTempleData;

  const TempleDetailScreen({
    Key? key,
    required this.templeId,
    this.initialTempleData,
  }) : super(key: key);

  @override
  State<TempleDetailScreen> createState() => _TempleDetailScreenState();
}

class _TempleDetailScreenState extends State<TempleDetailScreen> {
  Map<String, dynamic>? temple;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTemple();
  }

  Future<void> _loadTemple() async {
    setState(() => isLoading = true);

    // Start with data passed from PlaceTemplesScreen, if any.
    if (widget.initialTempleData != null) {
      temple = Map<String, dynamic>.from(widget.initialTempleData!);
    } else {
      temple = {};
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.templeId)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        temple!.addAll(data);
        temple!['id'] = widget.templeId;
      }
    } catch (e) {
      debugPrint('Error loading temple: $e');
    }

    _normalizeTempleFields();
    if (mounted) setState(() => isLoading = false);
  }

  void _normalizeTempleFields() {
    temple ??= {};
    final t = temple!;

    // derive status from isSanctioned + progress
    final bool isSanctioned = t['isSanctioned'] == true;
    final num progressNum = (t['progress'] ?? 0) as num;
    final int progress = progressNum.toInt();

    if (!isSanctioned) {
      t['status'] = 'pending';
    } else if (progress >= 100) {
      t['status'] = 'completed';
    } else {
      t['status'] = 'ongoing';
    }

    // basic fields used in header
    t['projectNumber'] =
        (t['projectNumber'] ?? t['projectId'] ?? 'P000') as String;
    t['name'] = (t['name'] ??
            (t['feature'] != null && t['feature'] != ''
                ? '${t['feature']} Project'
                : 'Temple Project')) as String;
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading || temple == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final status = (temple!['status'] ?? 'pending') as String;

    // Route to proper screen based on status
    if (status == 'pending') {
      return PendingTempleDetailScreen(
        temple: temple!,
        onUpdated: (updated) => Navigator.pop(context, updated),
        onDeleted: () => Navigator.pop(context, null),
      );
    } else if (status == 'ongoing') {
      return OngoingTempleDetailScreen(
        temple: temple!,
        onUpdated: (updated) => Navigator.pop(context, updated),
      );
    } else {
      return CompletedTempleDetailScreen(
        temple: temple!,
        onUpdated: (updated) => Navigator.pop(context, updated),
      );
    }
  }
}
