import 'dart:convert'; // Required for base64Decode
import 'dart:typed_data'; // Required for Uint8List
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PendingTempleDetailScreen extends StatelessWidget {
  final Map<String, dynamic> temple;
  final void Function(Map<String, dynamic>?) onUpdated;
  final VoidCallback onDeleted;

  const PendingTempleDetailScreen({
    Key? key,
    required this.temple,
    required this.onUpdated,
    required this.onDeleted,
  }) : super(key: key);

  static const Color maroonDeep = Color(0xFF6A1B1A);
  static const Color maroonLight = Color(0xFF8E3D2C);
  static const Color goldAccent = Color(0xFFFFD700);
  static const Color creamBg = Color(0xFFFFFBF2);
  static const Color textDark = Color(0xFF2D2D2D);

  @override
  Widget build(BuildContext context) {
    final status = (temple['status'] ?? 'pending').toString();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        onUpdated(temple);
        Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: creamBg,
        body: Column(
          children: [
            _buildHeader(context, status),
            Expanded(
              child: ListView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                children: [
                  _buildSectionCard(
                    icon: Icons.person_outline_rounded,
                    title: 'User Information',
                    child: Column(
                      children: [
                        _buildInfoRow(
                          'Name',
                          (temple['userName'] ??
                                  temple['name'] ??
                                  'N/A')
                              .toString(),
                        ),
                        _buildInfoRow(
                          'Email',
                          (temple['userEmail'] ??
                                  temple['email'] ??
                                  'N/A')
                              .toString(),
                        ),
                        _buildInfoRow(
                          'Phone',
                          (temple['userPhone'] ??
                                  temple['phone'] ??
                                  'N/A')
                              .toString(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildSiteImagesCard(context),
                  const SizedBox(height: 16),
                  _buildSectionCard(
                    icon: Icons.location_on_outlined,
                    title: 'Location Details',
                    child: Column(
                      children: [
                        _buildInfoRow(
                            'Place', (temple['place'] ?? '').toString()),
                        _buildInfoRow(
                            'District', (temple['district'] ?? '').toString()),
                        _buildInfoRow(
                            'Taluk', (temple['taluk'] ?? '').toString()),
                        _buildInfoRow(
                          'Map Link',
                          (temple['mapLocation'] ?? 'Not provided')
                              .toString(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // NEW: Requested Features section
                  _buildFeaturesCard(),

                  const SizedBox(height: 16),
                  _buildContactBudgetCard(),
                  const SizedBox(height: 24),
                  _buildActionButtons(context),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, String status) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [maroonDeep, maroonLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new,
                  color: goldAccent,
                  size: 20,
                ),
                onPressed: () => onUpdated(temple),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (temple['name'] ?? 'Temple Project').toString(),
                      style: GoogleFonts.philosopher(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ID: ${temple['projectNumber'] ?? temple['projectId'] ?? 'P000'} • ${status.toUpperCase()}',
                      style: GoogleFonts.poppins(
                        color: goldAccent.withOpacity(0.9),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: maroonDeep.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Icon(icon, color: maroonLight, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: GoogleFonts.philosopher(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                    color: maroonDeep,
                  ),
                ),
              ],
            ),
          ),
          const Divider(indent: 16, endIndent: 16),
          Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
    );
  }

  // NEW: features card
  Widget _buildFeaturesCard() {
    final raw = temple['features'];
    List<Map<String, dynamic>> features = [];
    if (raw is List) {
      features = raw
          .map((e) => (e as Map).map(
                (k, v) => MapEntry(k.toString(), v),
              ))
          .toList();
    }

    return _buildSectionCard(
      icon: Icons.list_alt,
      title: 'Requested Features',
      child: features.isEmpty
          ? const Text(
              'No feature details submitted.',
              style: TextStyle(color: Colors.grey),
            )
          : Column(
              children: features.map((f) {
                final label = (f['label'] ?? f['key'] ?? 'Feature').toString();
                final condition =
                    (f['condition'] ?? 'old').toString().toLowerCase();
                final dimension = (f['dimension'] ?? '').toString();
                final amount = (f['amount'] ?? '').toString();
                final customSize = (f['customSize'] ?? '').toString();

                final isNew = condition == 'new';
                final statusText = isNew ? 'New' : 'Old / Existing';

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: maroonDeep.withOpacity(0.02),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isNew
                          ? const Color(0xFF2D6A4F)
                          : Colors.grey.shade300,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        isNew
                            ? Icons.fiber_new_rounded
                            : Icons.history_rounded,
                        size: 18,
                        color: isNew
                            ? const Color(0xFF2D6A4F)
                            : Colors.grey.shade700,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              label,
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: maroonDeep,
                              ),
                            ),
                            Text(
                              statusText,
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: isNew
                                    ? const Color(0xFF2D6A4F)
                                    : Colors.grey,
                              ),
                            ),
                            if (isNew && dimension.isNotEmpty)
                              Text(
                                'Size: ${dimension == 'custom' && customSize.isNotEmpty ? customSize : dimension}',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: textDark,
                                ),
                              ),
                            if (isNew && amount.isNotEmpty)
                              Text(
                                'Required amount: ₹$amount',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: textDark,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  // --- IMAGE CARD WITH BASE64 + URL SUPPORT + FULLSCREEN ON TAP ---
  Widget _buildSiteImagesCard(BuildContext context) {
    List<String> imageData = [];
    final rawData =
        temple['imageUrls'] ?? temple['images'] ?? temple['siteImages'];

    if (rawData != null) {
      if (rawData is List) {
        imageData = rawData.map((e) => e.toString()).toList();
      } else if (rawData is String) {
        imageData = [rawData];
      }
    }

    return _buildSectionCard(
      icon: Icons.camera_alt_outlined,
      title: 'Site Gallery',
      child: imageData.isEmpty
          ? const Center(
              child: Text(
                'No site images found',
                style: TextStyle(
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
              ),
            )
          : SizedBox(
              height: 200,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: imageData.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final String source = imageData[index];

                  final bool isUrl = source.startsWith('http');
                  final bool isDataUri = source.startsWith('data:image');

                  return GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => FullscreenImageViewer(
                            source: source,
                          ),
                        ),
                      );
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 280,
                        color: Colors.grey[200],
                        child: isUrl
                            ? _buildNetworkImage(source)
                            : _buildBase64Image(
                                source,
                                isDataUri: isDataUri,
                              ),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }

  /// Handles both plain base64 and data URLs like data:image/jpeg;base64,/9j/4AAQ...
  Widget _buildBase64Image(
    String base64String, {
    bool isDataUri = false,
  }) {
    try {
      String cleanHash = base64String;

      if (isDataUri || base64String.contains(',')) {
        cleanHash = base64String.split(',').last;
      }

      cleanHash = cleanHash.replaceAll('\n', '').replaceAll('\r', '').trim();

      if (cleanHash.length > 50) {
        debugPrint(
            'Base64 image (first 50 chars): ${cleanHash.substring(0, 50)}');
      } else {
        debugPrint('Base64 image (len=${cleanHash.length}): $cleanHash');
      }

      final Uint8List bytes = base64Decode(cleanHash);

      return Image.memory(
        bytes,
        fit: BoxFit.cover,
        width: 280,
        height: 200,
        errorBuilder: (context, error, stackTrace) {
          debugPrint('Image.memory error: $error');
          return const Center(
            child: Icon(
              Icons.broken_image,
              color: Colors.grey,
            ),
          );
        },
      );
    } catch (e, st) {
      debugPrint('Base64 decode error: $e');
      debugPrint(st.toString());
      return const Center(
        child: Icon(
          Icons.error_outline,
          color: Colors.red,
        ),
      );
    }
  }

  Widget _buildNetworkImage(String url) {
    return Image.network(
      url,
      fit: BoxFit.cover,
      width: 280,
      height: 200,
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : const Center(child: CircularProgressIndicator()),
      errorBuilder: (context, error, stackTrace) =>
          const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
    );
  }


  Widget _buildContactBudgetCard() {
    final double amount =
        double.tryParse((temple['estimatedAmount'] ?? '0').toString()) ?? 0.0;
    return _buildSectionCard(
      icon: Icons.account_balance_wallet_outlined,
      title: 'Budget & Contact',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow(
            'Local POC',
            (temple['contactName'] ??
                    temple['userName'] ??
                    'N/A')
                .toString(),
          ),
          const SizedBox(height: 12),
          Text(
            'ESTIMATED BUDGET',
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: Colors.grey,
              letterSpacing: 1.2,
            ),
          ),
          Text(
            '₹${amount.toStringAsFixed(0)}',
            style: GoogleFonts.philosopher(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: maroonDeep,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: GoogleFonts.poppins(
                color: Colors.grey,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w500,
                fontSize: 13,
                color: textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: () => _handleSanction(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2D6A4F),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'SANCTION',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton(
            onPressed: () => onDeleted(),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'REJECT',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _handleSanction(BuildContext context) async {
    final confirm = await _showDialog(
      context,
      'Sanction Project',
      'Move this project to the ongoing phase?',
      Colors.green,
    );
    if (confirm == true) {
      final docId = (temple['id'] ?? temple['projectId'] ?? '').toString();
      if (docId.isEmpty) return;
      await FirebaseFirestore.instance
          .collection('projects')
          .doc(docId)
          .update({'isSanctioned': true, 'status': 'ongoing'});
      temple['isSanctioned'] = true;
      temple['status'] = 'ongoing';
      onUpdated(temple);
    }
  }

  Future<bool?> _showDialog(
    BuildContext context,
    String title,
    String msg,
    Color color,
  ) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          title,
          style: GoogleFonts.philosopher(fontWeight: FontWeight.bold),
        ),
        content: Text(msg),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: color),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }
}

// ---------------- FULLSCREEN IMAGE VIEWER ----------------

class FullscreenImageViewer extends StatelessWidget {
  final String source;

  const FullscreenImageViewer({Key? key, required this.source})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bool isUrl = source.startsWith('http');
    final bool isDataUri = source.startsWith('data:image');

    Widget child;
    if (isUrl) {
      child = InteractiveViewer(
        child: Image.network(
          source,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const Center(
            child: Icon(Icons.broken_image, color: Colors.white),
          ),
        ),
      );
    } else {
      String clean = source;
      if (isDataUri || source.contains(',')) {
        clean = source.split(',').last;
      }
      clean = clean.replaceAll('\n', '').replaceAll('\r', '').trim();

      try {
        final bytes = base64Decode(clean);
        child = InteractiveViewer(
          child: Image.memory(
            bytes,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Center(
              child: Icon(Icons.broken_image, color: Colors.white),
            ),
          ),
        );
      } catch (_) {
        child = const Center(
          child: Icon(Icons.error_outline, color: Colors.white),
        );
      }
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(child: child),
    );
  }
}
