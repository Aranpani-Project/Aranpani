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
  // --- Aranpani Theme Colors ---
  static const Color primaryMaroon = Color(0xFF6D1B1B);
  static const Color primaryGold = Color(0xFFD4AF37);
  static const Color backgroundCream = Color(0xFFFFF7E8);
  static const Color darkMaroonText = Color(0xFF4A1010);

  late Map<String, dynamic> temple;
  int selectedTab = 0;

  // Controllers
  final TextEditingController _godNameController = TextEditingController();
  final TextEditingController _visitorsController = TextEditingController();
  final TextEditingController _donatedController = TextEditingController();
  final TextEditingController _feedbackInputController = TextEditingController();

  List<Map<String, dynamic>> _transactions = [];

  @override
  void initState() {
    super.initState();
    // Deep copy the temple data
    temple = Map<String, dynamic>.from(widget.temple);
    _normalizeData();
  }

  void _normalizeData() {
    // Sync transactions
    final txData = temple['transactions'];
    if (txData is List) {
      _transactions = List<Map<String, dynamic>>.from(txData);
    }
    // Ensure feedback list exists
    if (temple['feedback'] == null) {
      temple['feedback'] = [];
    }
  }

  void _handleBackNavigation() {
    // Save all local state back into the temple map before returning
    temple['transactions'] = _transactions;
    widget.onUpdated(temple);
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _godNameController.dispose();
    _visitorsController.dispose();
    _donatedController.dispose();
    _feedbackInputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundCream,
      appBar: AppBar(
        backgroundColor: primaryMaroon,
        elevation: 0,
        centerTitle: false,
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
              'Project ID: ${temple['projectNumber'] ?? 'N/A'}',
              style: const TextStyle(color: primaryGold, fontSize: 12),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // CUSTOM TAB BAR
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(color: Colors.black12, blurRadius: 4, offset: const Offset(0, 2)),
              ],
            ),
            child: Row(
              children: [
                _buildTabItem('Work', 0),
                _buildTabItem('Finance', 1),
                _buildTabItem('Feedback', 2),
              ],
            ),
          ),
          
          // SCROLLABLE CONTENT
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              children: [
                if (selectedTab == 0) ..._buildWorkTab(),
                if (selectedTab == 1) ..._buildFinanceTab(),
                if (selectedTab == 2) ..._buildFeedbackTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabItem(String label, int index) {
    bool isActive = selectedTab == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => selectedTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: isActive ? primaryGold : Colors.transparent, width: 3)),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isActive ? primaryMaroon : Colors.grey,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  // --- TAB 1: WORK DETAILS ---
  List<Widget> _buildWorkTab() {
    return [
      const Text('Update Daily Progress', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: darkMaroonText)),
      const SizedBox(height: 20),
      _buildInputField(_godNameController, 'Deity Name', Icons.temple_hindu),
      const SizedBox(height: 15),
      _buildInputField(_visitorsController, 'Visitors', Icons.people, isNum: true),
      const SizedBox(height: 15),
      _buildInputField(_donatedController, 'Donation Received', Icons.currency_rupee, isNum: true),
    ];
  }

  // --- TAB 2: FINANCE ---
  List<Widget> _buildFinanceTab() {
    return [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Transaction History', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          IconButton(icon: const Icon(Icons.add_box, color: primaryMaroon), onPressed: () {}),
        ],
      ),
      if (_transactions.isEmpty) 
        const Center(child: Text('\nNo transactions found.'))
      else
        ..._transactions.map((tx) => Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            title: Text('₹${tx['amount']}'),
            subtitle: Text(tx['description'] ?? ''),
          ),
        )),
    ];
  }

  // --- TAB 3: FEEDBACK (THE NEW PART) ---
  List<Widget> _buildFeedbackTab() {
    List<dynamic> feedbackList = temple['feedback'] ?? [];

    return [
      const Text('Communication Log', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: darkMaroonText)),
      const SizedBox(height: 10),
      
      // Feedback Bubble List
      Container(
        height: 300,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: feedbackList.isEmpty
            ? const Center(child: Text('No messages yet'))
            : ListView.builder(
                padding: const EdgeInsets.all(10),
                itemCount: feedbackList.length,
                itemBuilder: (context, index) {
                  final msg = feedbackList[index];
                  bool isAdmin = msg['role'] == 'admin';
                  return Align(
                    alignment: isAdmin ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.symmetric(vertical: 5),
                      decoration: BoxDecoration(
                        color: isAdmin ? primaryMaroon : Colors.grey[300],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        msg['text'] ?? '',
                        style: TextStyle(color: isAdmin ? Colors.white : Colors.black),
                      ),
                    ),
                  );
                },
              ),
      ),
      const SizedBox(height: 15),
      
      // Send Feedback Input
      Row(
        children: [
          Expanded(
            child: TextField(
              controller: _feedbackInputController,
              decoration: InputDecoration(
                hintText: 'Type message to user...',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
              ),
            ),
          ),
          const SizedBox(width: 10),
          CircleAvatar(
            backgroundColor: primaryMaroon,
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white),
              onPressed: () {
                if (_feedbackInputController.text.isEmpty) return;
                setState(() {
                  (temple['feedback'] as List).add({
                    'role': 'admin',
                    'text': _feedbackInputController.text,
                    'time': DateTime.now().toString(),
                  });
                  _feedbackInputController.clear();
                });
              },
            ),
          )
        ],
      )
    ];
  }

  Widget _buildInputField(TextEditingController ctrl, String label, IconData icon, {bool isNum = false}) {
    return TextField(
      controller: ctrl,
      keyboardType: isNum ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: primaryMaroon),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}