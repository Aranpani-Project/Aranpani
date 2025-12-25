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
  late Map<String, dynamic> temple;
  int selectedTab = 0; // 0=activities, 1=transactions, 2=bills, 3=suggestions

  // Activities form
  String _selectedPartOfWork = 'Lingam';
  final TextEditingController _godNameController = TextEditingController();
  final TextEditingController _visitorsController = TextEditingController();
  final TextEditingController _donatedController = TextEditingController();
  final TextEditingController _billingController = TextEditingController();

  // Transactions
  final List<Map<String, dynamic>> _transactions = [];
  // Suggestions
  final List<String> _suggestions = [];
  final TextEditingController _suggestionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    temple = Map<String, dynamic>.from(widget.temple);
    _normalizeTransactions();
  }

  void _normalizeTransactions() {
    // If temple already has transactions (maybe from Firestore or previous screen),
    // copy them into _transactions ensuring amount is num, not String.
    final existing = temple['transactions'];
    if (existing is List) {
      for (final t in existing) {
        if (t is Map) {
          final raw = t['amount'];
          final amount =
              raw is num ? raw.toDouble() : double.tryParse(raw.toString()) ?? 0.0;
          _transactions.add({
            'amount': amount,
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

    return WillPopScope(
      onWillPop: () async {
        // write back normalized transactions into temple before popping
        temple['transactions'] = _transactions;
        widget.onUpdated(temple);
        return false;
      },
      child: Scaffold(
        body: Column(
          children: [
            _buildHeader(context, status),
            Container(
              color: const Color(0xFFF4F2FF),
              child: Row(
                children: [
                  _buildTab('Activities', 0),
                  _buildTab('Transactions', 1),
                  _buildTab('Bills', 2),
                  _buildTab('Feedback', 3),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
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
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFB3541E), Color(0xFFD4AF37)],
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
                onPressed: () {
                  temple['transactions'] = _transactions;
                  widget.onUpdated(temple);
                },
              ),
              Text(
                (temple['name'] ?? '') as String,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${temple['projectNumber']} - ${status.toUpperCase()}',
                style: const TextStyle(
                  color: Color(0xFFFDEBD0),
                  fontSize: 14,
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
      child: InkWell(
        onTap: () => setState(() => selectedTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isActive ? const Color(0xFFB3541E) : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isActive ? const Color(0xFFB3541E) : Colors.grey,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  // ---------- ACTIVITIES TAB (Work details) ----------
  List<Widget> _buildActivitiesTab() {
    return [
      const SizedBox(height: 8),
      const Text(
        'Work Details',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Color(0xFF6B1F1F),
        ),
      ),
      const SizedBox(height: 16),

      // Name of God
      TextField(
        controller: _godNameController,
        decoration: _yellowFieldDecoration('Name of God'),
        style: const TextStyle(color: Colors.black),
      ),
      const SizedBox(height: 20),

      const Text(
        'Part of work',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Color(0xFF6B1F1F),
        ),
      ),
      _buildPartOfWorkRadio('Lingam'),
      _buildPartOfWorkRadio('Avudai'),
      _buildPartOfWorkRadio('Nandhi'),
      _buildPartOfWorkRadio('Shed'),
      const SizedBox(height: 16),

      TextField(
        controller: _visitorsController,
        keyboardType: TextInputType.number,
        decoration: _yellowFieldDecoration('Number of people visited'),
        style: const TextStyle(color: Colors.black),
      ),
      const SizedBox(height: 12),

      TextField(
        controller: _donatedController,
        keyboardType: TextInputType.number,
        decoration: _yellowFieldDecoration('Amount donated'),
        style: const TextStyle(color: Colors.black),
      ),
      const SizedBox(height: 12),

      TextField(
        controller: _billingController,
        keyboardType: TextInputType.number,
        decoration:
            _yellowFieldDecoration('Billing: current amount received'),
        style: const TextStyle(color: Colors.black),
      ),
      const SizedBox(height: 24),

      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () {
            // later: push this to Firestore activities collection
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Work details saved (local only).')),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFB3541E),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text('Save activity'),
        ),
      ),
    ];
  }

  InputDecoration _yellowFieldDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: const Color(0xFFFFF3C4),
      hintStyle: const TextStyle(color: Color(0xFF7C5E2A)),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFF3C77B), width: 2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFB3541E), width: 2),
      ),
    );
  }

  Widget _buildPartOfWorkRadio(String label) {
    return RadioListTile<String>(
      value: label,
      groupValue: _selectedPartOfWork,
      activeColor: const Color(0xFFB3541E),
      contentPadding: EdgeInsets.zero,
      title: Text(
        label,
        style: const TextStyle(
          color: Colors.black,
          fontSize: 15,
        ),
      ),
      onChanged: (value) {
        if (value == null) return;
        setState(() => _selectedPartOfWork = value);
      },
    );
  }

  // ---------- TRANSACTIONS TAB ----------
  List<Widget> _buildTransactionsTab() {
    final total = _transactions.fold<double>(
      0,
      (prev, t) {
        final raw = t['amount'];
        final doubleAmount =
            raw is num ? raw.toDouble() : double.tryParse(raw.toString()) ?? 0.0;
        return prev + doubleAmount;
      },
    );

    return [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Transactions',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF6B1F1F),
            ),
          ),
          Text(
            'Total: ₹${total.toStringAsFixed(0)}',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Color(0xFFB3541E),
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      if (_transactions.isEmpty)
        const Text(
          'No transactions yet.',
          style: TextStyle(color: Colors.grey),
        )
      else
        ..._transactions.map(_buildTransactionTile),
      const SizedBox(height: 16),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _showAddTransactionDialog,
          icon: const Icon(Icons.add),
          label: const Text('Add transaction'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFB3541E),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    ];
  }

  Widget _buildTransactionTile(Map<String, dynamic> tx) {
    final raw = tx['amount'];
    final amount =
        raw is num ? raw.toDouble() : double.tryParse(raw.toString()) ?? 0.0;
    final description = tx['description'] as String;
    final mode = tx['mode'] as String;
    final date = tx['date'] as String;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.account_balance_wallet,
            color: Color(0xFFB3541E)),
        title: Text('₹${amount.toStringAsFixed(0)} - $description'),
        subtitle: Text('$mode • $date'),
      ),
    );
  }

  void _showAddTransactionDialog() {
    final amountController = TextEditingController();
    final descController = TextEditingController();
    String mode = 'Cash';
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Transaction'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Amount (₹)',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                  ),
                ),
                const SizedBox(height: 12),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Mode',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                RadioListTile<String>(
                  title: const Text('Cash'),
                  value: 'Cash',
                  groupValue: mode,
                  onChanged: (v) =>
                      setDialogState(() => mode = v ?? 'Cash'),
                ),
                RadioListTile<String>(
                  title: const Text('Online'),
                  value: 'Online',
                  groupValue: mode,
                  onChanged: (v) =>
                      setDialogState(() => mode = v ?? 'Online'),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Date'),
                  subtitle: Text(
                      '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}'),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setDialogState(() => selectedDate = picked);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final amount =
                    double.tryParse(amountController.text.trim());
                if (amount == null ||
                    amount <= 0 ||
                    descController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Enter valid amount and description')),
                  );
                  return;
                }

                setState(() {
                  _transactions.add({
                    'amount': amount,
                    'description': descController.text.trim(),
                    'mode': mode,
                    'date':
                        '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                  });
                });
                Navigator.pop(context);
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- BILLS TAB (placeholder) ----------
  List<Widget> _buildBillsTab() {
    return const [
      Text(
        'Bills',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Color(0xFF6B1F1F),
        ),
      ),
      SizedBox(height: 16),
      Text(
        'Bills UI can be added here (upload bill photo, amount, date, etc.).',
        style: TextStyle(color: Colors.grey),
      ),
    ];
  }

  // ---------- SUGGESTIONS TAB ----------
  List<Widget> _buildSuggestionsTab() {
    return [
      const Text(
        'Feedback to User',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Color(0xFF6B1F1F),
        ),
      ),
      const SizedBox(height: 16),
      if (_suggestions.isEmpty)
        const Text(
          'No suggestions yet.',
          style: TextStyle(color: Colors.grey),
        )
      else
        ..._suggestions.map((s) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.message,
                      size: 18, color: Color(0xFFB3541E)),
                  const SizedBox(width: 6),
                  Expanded(child: Text(s)),
                ],
              ),
            )),
      const SizedBox(height: 16),
      TextField(
        controller: _suggestionController,
        maxLines: 3,
        decoration: const InputDecoration(
          labelText: 'Add suggestion for the user',
          border: OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 12),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () {
            final text = _suggestionController.text.trim();
            if (text.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Enter some suggestion')),
              );
              return;
            }
            setState(() {
              _suggestions.add(text);
            });
            _suggestionController.clear();
            // later: write _suggestions to Firestore so user app can read.
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFB3541E),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text('Send suggestion'),
        ),
      ),
    ];
  }
}
