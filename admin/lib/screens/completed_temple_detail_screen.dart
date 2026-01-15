import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class CompletedTempleDetailScreen extends StatefulWidget {
  final Map<String, dynamic> temple;
  final void Function(Map<String, dynamic>?) onUpdated;

  const CompletedTempleDetailScreen({
    Key? key,
    required this.temple,
    required this.onUpdated,
  }) : super(key: key);

  @override
  State<CompletedTempleDetailScreen> createState() =>
      _CompletedTempleDetailScreenState();
}

class _CompletedTempleDetailScreenState
    extends State<CompletedTempleDetailScreen> {
  static const Color primaryMaroon = Color(0xFF6D1B1B);
  static const Color primaryGold = Color(0xFFD4AF37);
  static const Color backgroundCream = Color(0xFFFFF7E8);
  static const Color darkMaroonText = Color(0xFF4A1010);

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  late Map<String, dynamic> temple;
  late String projectId;

  List<Map<String, dynamic>> works = [];
  List<Map<String, dynamic>> transactions = [];
  List<Map<String, dynamic>> bills = [];
  bool loadingWorks = true;
  bool loadingTransactions = true;
  bool loadingBills = true;

  String _s(dynamic v) => v?.toString() ?? '';

  num _n(dynamic v) {
    if (v is num) return v;
    if (v is String) return num.tryParse(v) ?? 0;
    return 0;
  }

  DateTime? _toDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is Timestamp) return v.toDate();
    return DateTime.tryParse(v.toString());
  }

  String _fmtDate(dynamic v) {
    final d = _toDate(v);
    if (d == null) return '';
    return '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}';
  }

  @override
  void initState() {
    super.initState();
    temple = Map<String, dynamic>.from(widget.temple);
    projectId = (temple['projectId'] ?? temple['id'] ?? '').toString();
    _loadWorks();          // now from project_tasks
    _loadTransactions();
    _loadBills();
  }

  /// LOAD COMPLETED ACTIVITIES FROM project_tasks
  Future<void> _loadWorks() async {
    setState(() => loadingWorks = true);
    try {
      final snap = await _firestore
          .collection('project_tasks')
          .where('projectId', isEqualTo: projectId)
          .where('status', isEqualTo: 'completed')
          .orderBy('completedAt', descending: true)
          .get();

      works = snap.docs.map<Map<String, dynamic>>((d) {
        final data = d.data();
        return <String, dynamic>{
          'id': d.id,
          'name': data['taskName'] ?? '',
          'description': data['description'] ?? '',
          'peopleVisited': _n(data['peopleVisited']),
          'amountDonated': _n(data['amountDonated']),
          'status': data['status'] ?? 'completed',
          'date': data['completedAt'] ??
              data['startedAt'] ??
              data['createdAt'],
          'imageUrls': (data['endImages'] as List?)
                  ?.map((e) => e.toString())
                  .toList() ??
              <String>[],
        };
      }).toList();
    } catch (e) {
      debugPrint('Error loading works from project_tasks: $e');
      works = [];
    } finally {
      if (mounted) setState(() => loadingWorks = false);
    }
  }

  Future<void> _loadTransactions() async {
    setState(() => loadingTransactions = true);
    try {
      final snap = await _firestore
          .collection('transactions')
          .where('projectId', isEqualTo: projectId)
          .get();
      transactions = snap.docs.map<Map<String, dynamic>>((d) {
        final data = d.data();
        return <String, dynamic>{
          'id': d.id,
          'amount': _n(data['amount']),
          'description': data['description'] ?? '',
          'mode': data['mode'] ?? '',
          'date': data['date'],
          'transactionId': data['transactionId'] ?? '',
        };
      }).toList();
      transactions.sort((a, b) {
        final da = _toDate(a['date']) ?? DateTime(1970);
        final db = _toDate(b['date']) ?? DateTime(1970);
        return db.compareTo(da);
      });
    } catch (e) {
      debugPrint('Error loading transactions: $e');
      transactions = [];
    } finally {
      if (mounted) setState(() => loadingTransactions = false);
    }
  }

  Future<void> _loadBills() async {
    setState(() => loadingBills = true);
    try {
      final snap = await _firestore
          .collection('bills')
          .where('projectId', isEqualTo: projectId)
          .get();
      bills = snap.docs.map<Map<String, dynamic>>((d) {
        final data = d.data();
        return <String, dynamic>{
          'id': d.id,
          'title': data['title'] ?? '',
          'amount': _n(data['amount']),
          'createdAt': data['createdAt'],
          'imageUrls': (data['imageUrls'] as List?)
                  ?.map((e) => e.toString())
                  .toList() ??
              <String>[],
        };
      }).toList();
      bills.sort((a, b) {
        final da = _toDate(a['createdAt']) ?? DateTime(1970);
        final db = _toDate(b['createdAt']) ?? DateTime(1970);
        return db.compareTo(da);
      });
    } catch (e) {
      debugPrint('Error loading bills: $e');
      bills = [];
    } finally {
      if (mounted) setState(() => loadingBills = false);
    }
  }

  void _showFullImage(String url) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.85),
      builder: (_) => GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Center(
          child: InteractiveViewer(
            minScale: 0.8,
            maxScale: 4,
            child: Image.network(url),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String status =
        _s(temple['status']).isEmpty ? 'completed' : _s(temple['status']);
    final String completedDate = temple['completedDate'] == null
        ? 'N/A'
        : _fmtDate(temple['completedDate']);
    final List<String> siteImages =
        (temple['imageUrls'] as List?)?.map((e) => e.toString()).toList() ??
            <String>[];
    final num totalDonated = _n(temple['donatedAmount']);
    final num totalBillsAmount = _n(temple['totalBillsAmount']);
    final num totalTransactionsAmount = _n(temple['totalTransactionsAmount']);

    return WillPopScope(
      onWillPop: () async {
        widget.onUpdated(temple);
        Navigator.pop(context);
        return false;
      },
      child: Scaffold(
        backgroundColor: backgroundCream,
        body: Column(
          children: [
            _buildHeader(status),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      title: const Text('Project Completed'),
                      subtitle: Text('Completed on: $completedDate'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildInfoCard(),
                  const SizedBox(height: 12),
                  if (siteImages.isNotEmpty) _buildSiteImagesCard(siteImages),
                  const SizedBox(height: 12),
                  _buildFinanceSummaryCard(
                    totalDonated,
                    totalBillsAmount,
                    totalTransactionsAmount,
                  ),
                  const SizedBox(height: 12),
                  _buildWorksCard(),
                  const SizedBox(height: 12),
                  _buildTransactionsCard(),
                  const SizedBox(height: 12),
                  _buildBillsCard(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(String status) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryMaroon, primaryGold],
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
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => widget.onUpdated(temple),
              ),
              Text(
                _s(temple['name']).isEmpty
                    ? 'Temple Project'
                    : _s(temple['name']),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Project: ${_s(temple['projectNumber'])} - ${status.toUpperCase()}',
                style: const TextStyle(
                  color: primaryGold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: const Color(0xFFFFF2D5),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'User & Project Info',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: darkMaroonText,
              ),
            ),
            const SizedBox(height: 8),
            _infoRow('User', _s(temple['userName'])),
            _infoRow('Phone', _s(temple['userPhone'])),
            _infoRow('Email', _s(temple['userEmail'])),
            const SizedBox(height: 6),
            _infoRow('Place', _s(temple['place'])),
            _infoRow('District', _s(temple['district'])),
            _infoRow('Taluk', _s(temple['taluk'])),
            const SizedBox(height: 6),
            _infoRow('Feature', _s(temple['feature'])),
            _infoRow(
              'Estimated amount',
              '₹${_n(temple['estimatedAmount'])}',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSiteImagesCard(List<String> urls) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: const Color(0xFFFFF7E8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Site Photos',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: darkMaroonText,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 110,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: urls
                    .map(
                      (url) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () => _showFullImage(url),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(
                              url,
                              width: 140,
                              height: 110,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinanceSummaryCard(
      num totalDonated, num totalBills, num totalTransactions) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: const Color(0xFFFFF2D5),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Financial Summary',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: darkMaroonText,
              ),
            ),
            const SizedBox(height: 6),
            Text('Total donations received: ₹$totalDonated'),
            Text('Total transactions: ₹$totalTransactions'),
            Text('Total bills: ₹$totalBills'),
            Text('Net remaining: ₹${totalDonated - totalBills}'),
          ],
        ),
      ),
    );
  }

  Widget _buildWorksCard() {
    if (loadingWorks) {
      return const Center(child: CircularProgressIndicator());
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: const Color(0xFFFFF7E8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Works Done',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: darkMaroonText,
              ),
            ),
            const SizedBox(height: 8),
            if (works.isEmpty)
              const Text('No works recorded.',
                  style: TextStyle(color: Colors.grey))
            else
              ...works.map((w) {
                final images =
                    (w['imageUrls'] as List?)?.cast<String>() ?? <String>[];
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFB6862C)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _s(w['name']),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      if (_s(w['description']).isNotEmpty)
                        Text(_s(w['description'])),
                      if (_fmtDate(w['date']).isNotEmpty)
                        Text('Date: ${_fmtDate(w['date'])}'),
                      Text('Status: ${_s(w['status']).toUpperCase()}'),
                      Text('People visited: ${_n(w['peopleVisited'])}'),
                      Text('Amount donated: ₹${_n(w['amountDonated'])}'),
                      if (images.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        SizedBox(
                          height: 70,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: images
                                .map(
                                  (url) => Padding(
                                    padding:
                                        const EdgeInsets.only(right: 8),
                                    child: GestureDetector(
                                      onTap: () => _showFullImage(url),
                                      child: ClipRRect(
                                        borderRadius:
                                            BorderRadius.circular(8),
                                        child: Image.network(
                                          url,
                                          width: 70,
                                          height: 70,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionsCard() {
    if (loadingTransactions) {
      return const Center(child: CircularProgressIndicator());
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: const Color(0xFFFFF2D5),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Transactions',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: darkMaroonText,
              ),
            ),
            const SizedBox(height: 8),
            if (transactions.isEmpty)
              const Text('No transactions recorded.',
                  style: TextStyle(color: Colors.grey))
            else
              ...transactions.map((t) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFB6862C)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '₹${_n(t['amount'])}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      if (_s(t['description']).isNotEmpty)
                        Text(_s(t['description'])),
                      Text('Mode: ${_s(t['mode'])}'),
                      if (_s(t['transactionId']).isNotEmpty)
                        Text('Txn ID: ${_s(t['transactionId'])}'),
                      if (_fmtDate(t['date']).isNotEmpty)
                        Text('Date: ${_fmtDate(t['date'])}'),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildBillsCard() {
    if (loadingBills) {
      return const Center(child: CircularProgressIndicator());
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: const Color(0xFFFFF7E8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Bills',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: darkMaroonText,
              ),
            ),
            const SizedBox(height: 8),
            if (bills.isEmpty)
              const Text('No bills uploaded.',
                  style: TextStyle(color: Colors.grey))
            else
              ...bills.map((b) {
                final images =
                    (b['imageUrls'] as List?)?.cast<String>() ?? <String>[];
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFB6862C)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _s(b['title']).isEmpty ? 'Bill' : _s(b['title']),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text('Amount: ₹${_n(b['amount'])}'),
                      if (_fmtDate(b['createdAt']).isNotEmpty)
                        Text('Date: ${_fmtDate(b['createdAt'])}'),
                      if (images.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        SizedBox(
                          height: 80,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: images
                                .map(
                                  (url) => Padding(
                                    padding:
                                        const EdgeInsets.only(right: 8),
                                    child: GestureDetector(
                                      onTap: () => _showFullImage(url),
                                      child: ClipRRect(
                                        borderRadius:
                                            BorderRadius.circular(8),
                                        child: Image.network(
                                          url,
                                          width: 80,
                                          height: 80,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) => _buildInfoRow(label, value);

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                  fontWeight: FontWeight.w500, color: Colors.brown),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: darkMaroonText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
