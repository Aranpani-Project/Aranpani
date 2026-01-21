// ... (Imports remain the same)

  // ===================== FINANCES TAB (FIXED LOGIC & AUTOMATION) =====================

  Widget _transactionsTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _firestore
          .collection('transactions')
          .where('projectId', isEqualTo: _projectId)
          .orderBy('date', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        double paidTotal = 0.0;
        double pendingTotal = 0.0;

        if (snapshot.hasData) {
          for (var doc in snapshot.data!.docs) {
            final d = doc.data();
            final amt = (d['amount'] ?? 0).toDouble();
            final stat = d['status'] ?? 'pending';
            
            if (stat == 'paid' || stat == 'approved') {
              paidTotal += amt;
            } else if (stat == 'pending') {
              pendingTotal += amt;
            }
          }
        }

        return Column(
          children: [
            // Summary Cards Logic
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem("Paid", "₹$paidTotal", Colors.green),
                    Container(width: 1, height: 40, color: Colors.grey[200]),
                    _buildStatItem("Pending", "₹$pendingTotal", Colors.orange),
                  ],
                ),
              ),
            ),

            // Action Buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                children: [
                  ElevatedButton.icon(
                    onPressed: _showRequestAmountDialog,
                    icon: const Icon(Icons.add_card),
                    label: const Text('Request Amount from Admin'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryMaroon,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _isCompletionRequesting ? null : _requestProjectCompletion,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: _isCompletionRequesting
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.flag),
                    label: Text(_isCompletionRequesting ? 'Sending...' : 'Request Project Completion'),
                  ),
                ],
              ),
            ),

            const Padding(
              padding: EdgeInsets.only(left: 16, top: 20, bottom: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text("Transaction History", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: primaryMaroon)),
              ),
            ),

            // Transaction History List
            Expanded(
              child: snapshot.hasData && snapshot.data!.docs.isNotEmpty
                  ? ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: snapshot.data!.docs.length,
                      itemBuilder: (context, index) {
                        final data = snapshot.data!.docs[index].data();
                        final status = data['status'] ?? 'pending';
                        final amount = data['amount'] ?? 0.0;
                        final title = data['title'] ?? 'Request';
                        final date = data['date'] as Timestamp?;

                        Color statusColor = Colors.orange;
                        IconData statusIcon = Icons.hourglass_empty;

                        if (status == 'paid' || status == 'approved') {
                          statusColor = Colors.green;
                          statusIcon = Icons.check_circle;
                        } else if (status == 'rejected') {
                          statusColor = Colors.red;
                          statusIcon = Icons.cancel;
                        }

                        return Card(
                          elevation: 0,
                          margin: const EdgeInsets.only(bottom: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(color: Colors.grey.shade200),
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: statusColor.withOpacity(0.1),
                              child: Icon(statusIcon, color: statusColor, size: 20),
                            ),
                            title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(_formatTimestamp(date), style: const TextStyle(fontSize: 12)),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text("₹$amount", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: primaryMaroon)),
                                Text(status.toUpperCase(), style: TextStyle(fontSize: 9, color: statusColor, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            onTap: () => _showTransactionDetail(data),
                          ),
                        );
                      },
                    )
                  : Center(
                      child: Text("No requests found", style: TextStyle(color: Colors.grey[400])),
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600])),
        Text(value, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  // ===================== HEADER WITH LIVE BUDGET FETCH =====================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundCream,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: StreamBuilder<DocumentSnapshot>(
                stream: _firestore.collection('projects').doc(_projectId).snapshots(),
                builder: (context, snapshot) {
                  // This pulls the totalAmount assigned during the proposal phase
                  String totalBudget = "0";
                  String projectName = widget.project['projectName'] ?? 'Project Overview';
                  
                  if (snapshot.hasData && snapshot.data!.exists) {
                    final data = snapshot.data!.data() as Map<String, dynamic>;
                    totalBudget = (data['totalAmount'] ?? "0").toString();
                    projectName = data['projectName'] ?? projectName;
                  }

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                    color: primaryMaroon,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back, color: Colors.white),
                              onPressed: () => Navigator.pop(context),
                            ),
                            Expanded(
                              child: Text(
                                projectName,
                                style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 48.0),
                          child: Text(
                            "Total Project Budget: ₹$totalBudget",
                            style: const TextStyle(color: Colors.white70, fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            _buildTabBar(),
            SliverFillRemaining(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _activitiesTab(),
                  _transactionsTab(),
                  _billsTabWrapper(),
                  _feedbackTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

// ... (Rest of the code like _showTransactionDetail, _TabBarDelegate, OngoingTaskCard etc. remains the same)