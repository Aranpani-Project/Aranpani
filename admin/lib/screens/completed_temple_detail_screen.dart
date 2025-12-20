import 'package:flutter/material.dart';

class CompletedTempleDetailScreen extends StatelessWidget {
  final Map<String, dynamic> temple;
  final void Function(Map<String, dynamic>?) onUpdated;

  const CompletedTempleDetailScreen({
    Key? key,
    required this.temple,
    required this.onUpdated,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final status = (temple['status'] ?? 'completed') as String;
    final completedDate =
        (temple['completedDate'] ?? 'N/A')?.toString() ?? 'N/A';

    return WillPopScope(
      onWillPop: () async {
        onUpdated(temple);
        return false;
      },
      child: Scaffold(
        body: Column(
          children: [
            _buildHeader(context, status),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // site images card
                  // project summary, completed activities, etc.
                  Card(
                    child: ListTile(
                      title: const Text('Project Completed'),
                      subtitle: Text('Completed on: $completedDate'),
                    ),
                  ),
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
          colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => onUpdated(temple),
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
                  color: Color(0xFFC7D2FE),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
