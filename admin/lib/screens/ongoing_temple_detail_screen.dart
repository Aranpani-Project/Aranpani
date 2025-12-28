import 'package:flutter/material.dart';
import 'project_chat_section.dart';
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
  // --- Aranpani Theme Colors ---
  static const Color primaryMaroon = Color(0xFF6D1B1B);
  static const Color primaryGold = Color(0xFFD4AF37);
  static const Color backgroundCream = Color(0xFFFFF7E8);
  static const Color darkMaroonText = Color(0xFF4A1010);

  late Map<String, dynamic> temple;
  int selectedTab = 0;

  final TextEditingController _godNameController = TextEditingController();
  final TextEditingController _visitorsController = TextEditingController();
  final TextEditingController _donatedController = TextEditingController();
  final TextEditingController _billingController = TextEditingController();
  final TextEditingController _suggestionController = TextEditingController();

  String _selectedPartOfWork = 'Lingam';
  final List<Map<String, dynamic>> _transactions = [];

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

  void _handleBackNavigation() {
    temple['transactions'] = _transactions;
    widget.onUpdated(temple);
    Navigator.pop(context);
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
    return Scaffold(
      backgroundColor: backgroundCream,
      appBar: AppBar(
        backgroundColor: primaryMaroon,
        elevation: 0,
        centerTitle: false, // Ensures title stays left-aligned
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: _handleBackNavigation,
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              (temple['name'] ?? 'Temple Project').toString(),
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              'Project: ${temple['projectNumber'] ?? 'N/A'}',
              style: const TextStyle(color: primaryGold, fontSize: 12),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // SUB-HEADER TAB BAR
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                _buildTab('Activities', 0),
                _buildTab('Finances', 1),
                _buildTab('Feedback', 2),
              ],
            ),
          ),
          Expanded(
            child: selectedTab == 2
                // IF Feedback tab is selected, show the Chat
                ? ProjectChatSection(
                    projectId: temple['id'],
                    currentRole: 'admin',
                  )
                // ELSE show the normal scrolling list for other tabs
                : ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                    children: [
                      if (selectedTab == 0) ..._buildActivitiesTab(),
                      if (selectedTab == 1) ..._buildTransactionsTab(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(String label, int index) {
    final isActive = selectedTab == index;
    return Expanded(
      child: InkWell(
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
              fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildActivitiesTab() {
    return [
      const Text(
        'Daily Work Update',
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: darkMaroonText),
      ),
      const SizedBox(height: 20),
      _buildInputField(_godNameController, 'Name of God', Icons.auto_awesome),
      const SizedBox(height: 16),
      _buildInputField(_visitorsController, 'Visitors Count', Icons.people, isNum: true),
      const SizedBox(height: 16),
      _buildInputField(_donatedController, 'Amount Donated (₹)', Icons.currency_rupee, isNum: true),
      const SizedBox(height: 30),
      ElevatedButton(
        onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Activity saved successfully')),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryMaroon,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: const Text('SAVE ACTIVITY', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.1)),
      ),
    ];
  }

  Widget _buildInputField(TextEditingController ctrl, String label, IconData icon, {bool isNum = false}) {
    return TextField(
      controller: ctrl,
      keyboardType: isNum ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey),
        prefixIcon: Icon(icon, color: primaryMaroon),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFDEE2E6)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryGold, width: 2),
        ),
      ),
    );
  }

  List<Widget> _buildTransactionsTab() {
    return [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Finances', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: darkMaroonText)),
          TextButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.add, color: primaryMaroon),
            label: const Text('Add', style: TextStyle(color: primaryMaroon)),
          )
        ],
      ),
      const SizedBox(height: 10),
      if (_transactions.isEmpty)
        const Center(child: Padding(
          padding: EdgeInsets.only(top: 40),
          child: Text('No transactions recorded.'),
        ))
      else
        ..._transactions.map((tx) => Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          // FIXED: Changed 'border' to 'side'
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12), 
            side: BorderSide(color: Colors.grey.shade300),
          ),
          child: ListTile(
            title: Text('₹${tx['amount']}', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(tx['description']),
            trailing: const Icon(Icons.chevron_right),
          ),
        )),
    ];
  }

  List<Widget> _buildSuggestionsTab() {
    return [
      const Text('Feedback', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: darkMaroonText)),
      const SizedBox(height: 16),
      const Text('Admin suggestions will appear here.', style: TextStyle(color: Colors.grey)),
    ];
  }
}