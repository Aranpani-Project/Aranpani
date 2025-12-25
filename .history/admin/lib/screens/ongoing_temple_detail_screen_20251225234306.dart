import 'package:flutter/material.dart';

class OngoingTempleDetailScreen extends StatefulWidget {
  final Map<String, dynamic> temple;
  final void Function(Map<String, dynamic>?) onUpdated;

  const OngoingTempleDetailScreen({
    Key? key,
    required this.temple,
    required this.onUpdated,
  }) : super(key: key);

  @override
  State<OngoingTempleDetailScreen> createState() =>
      _OngoingTempleDetailScreenState();
}

class _OngoingTempleDetailScreenState extends State<OngoingTempleDetailScreen> {
  // --- Standardized Theme Colors ---
  static const Color primaryMaroon = Color(0xFF6D1B1B);
  static const Color primaryGold = Color(0xFFD4AF37);
  static const Color backgroundCream = Color(0xFFFFF7E8);
  static const Color darkMaroonText = Color(0xFF4A1010);
  static const Color softParchment = Color(0xFFFFFBF2);

  late Map<String, dynamic> temple;
  int selectedTab = 0;

  final TextEditingController _godNameController = TextEditingController();
  final TextEditingController _visitorsController = TextEditingController();
  final TextEditingController _donatedController = TextEditingController();
  final TextEditingController _billingController = TextEditingController();
  final TextEditingController _suggestionController = TextEditingController();

  String _selectedPartOfWork = 'Lingam';
  final List<Map<String, dynamic>> _transactions = [];
  final List<String> _suggestions = [];

  @override
  void initState() {
    super.initState();
    temple = Map<String, dynamic>.from(widget.temple);
    _normalizeTransactions();
  }

  void _normalizeTransactions() {
    final existing = temple['transactions'];
    if (existing is List) {
      for (final t in existing) {
        if (t is Map) {
          final raw = t['amount'];
          _transactions.add({
            'amount': raw is num ? raw.toDouble() : double.tryParse(raw.toString()) ?? 0.0,
            'description': t['description']?.toString() ?? '',
            'mode': t['mode']?.toString() ?? '',
            'date': t['date']?.toString() ?? '',
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _godNameController.dispose();
    _visitorsController.dispose();
    _donatedController.dispose();
    _billingController.dispose();
    _suggestionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = (temple['status'] ?? 'ongoing') as String;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        temple['transactions'] = _transactions;
        widget.onUpdated(temple);
      },
      child: Scaffold(
        backgroundColor: backgroundCream,
        body: Column(
          children: [
            _buildHeader(context, status),
            // FIXED TAB BAR ALIGNMENT
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  _buildTab('Activities', 0),
                  _buildTab('Finances', 1),
                  _buildTab('Bills', 2),
                  _buildTab('Feedback', 3),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  if (selectedTab == 0) ..._buildActivitiesTab(),
                  if (selectedTab == 1) ..._buildTransactionsTab(),
                  if (selectedTab == 2) ..._buildBillsTab(),
                  if (selectedTab == 3) ..._buildSuggestionsTab(),
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
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primaryMaroon, Color(0xFF4A1010)],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () {
                  temple['transactions'] = _transactions;
                  widget.onUpdated(temple);
                },
              ),
              Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (temple['name'] ?? '') as String,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: primaryGold,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            status.toUpperCase(),
                            style: const TextStyle(
                              color: primaryMaroon,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Project: ${temple['projectNumber']}',
                          style: const TextStyle(color: Color(0xFFFDEBD0), fontSize: 13),
                        ),
                      ],
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

  Widget _buildTab(String label, int index) {
    final isActive = selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => selectedTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isActive ? primaryGold : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isActive ? primaryMaroon : Colors.grey[600],
              fontSize: 13,
              fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  // --- ACTIVITIES TAB ---
  List<Widget> _buildActivitiesTab() {
    return [
      const Text(
        'Daily Progress Report',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: darkMaroonText),
      ),
      const SizedBox(height: 20),
      _buildTextField(_godNameController, 'Primary Deity Name', Icons.temple_hindu),
      const SizedBox(height: 20),
      const Text('Current Part of Work', style: TextStyle(fontWeight: FontWeight.bold, color: darkMaroonText)),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        children: ['Lingam', 'Avudai', 'Nandhi', 'Shed'].map((type) {
          final isSel = _selectedPartOfWork == type;
          return ChoiceChip(
            label: Text(type),
            selected: isSel,
            selectedColor: primaryGold,
            onSelected: (val) => setState(() => _selectedPartOfWork = type),
          );
        }).toList(),
      ),
      const SizedBox(height: 20),
      _buildTextField(_visitorsController, 'Visitors Count', Icons.people, isNum: true),
      const SizedBox(height: 12),
      _buildTextField(_donatedController, 'Total Donations Received', Icons.currency_rupee, isNum: true),
      const SizedBox(height: 24),
      ElevatedButton(
        onPressed: () {},
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryMaroon,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: const Text('Save Progress Update'),
      ),
    ];
  }

  Widget _buildTextField(TextEditingController ctrl, String hint, IconData icon, {bool isNum = false}) {
    return TextField(
      controller: ctrl,
      keyboardType: isNum ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: primaryMaroon),
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryGold, width: 2),
        ),
      ),
    );
  }

  // --- TRANSACTIONS TAB ---
  List<Widget> _buildTransactionsTab() {
    return [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Financial Log', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: darkMaroonText)),
          IconButton(onPressed: _showAddTransactionDialog, icon: const Icon(Icons.add_circle, color: primaryMaroon, size: 30)),
        ],
      ),
      const SizedBox(height: 16),
      if (_transactions.isEmpty)
        const Center(child: Text('No transaction history found.', style: TextStyle(color: Colors.grey)))
      else
        ..._transactions.map((tx) => Card(
              color: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE0E0E0)),
              ),
              child: ListTile(
                leading: const CircleAvatar(backgroundColor: backgroundCream, child: Icon(Icons.payment, color: primaryMaroon)),
                title: Text('₹${tx['amount']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('${tx['description']} • ${tx['mode']}'),
                trailing: Text(tx['date'].toString(), style: const TextStyle(fontSize: 12)),
              ),
            )),
    ];
  }

  void _showAddTransactionDialog() {
    // Standard implementation remains similar, but use primaryMaroon/Gold theme
    showDialog(context: context, builder: (context) => AlertDialog(
      title: const Text('Record Transaction'),
      backgroundColor: softParchment,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: const Text('Transaction form follows temple theme...'),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
    ));
  }

  List<Widget> _buildBillsTab() => [const Center(child: Text('Bill Upload Section'))];
  List<Widget> _buildSuggestionsTab() => [const Center(child: Text('Admin Feedback Section'))];
}