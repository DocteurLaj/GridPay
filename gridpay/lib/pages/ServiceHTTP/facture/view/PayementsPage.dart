import 'package:flutter/material.dart';

class PaymentsPage extends StatelessWidget {
  final List<Map<String, dynamic>> payments = [
    {
      'id': 'PAY-001',
      'amount': 12500.0,
      'invoice_id': 'INV-001',
      'date': '2024-01-20',
      'status': 'completed',
      'method': 'Mobile Money'
    },
    {
      'id': 'PAY-002',
      'amount': 9800.0,
      'invoice_id': 'INV-002',
      'date': '2023-12-15',
      'status': 'completed',
      'method': 'Bank Transfer'
    },
    {
      'id': 'PAY-003',
      'amount': 15600.0,
      'invoice_id': 'INV-003',
      'date': '2023-11-10',
      'status': 'failed',
      'method': 'Credit Card'
    },
  ];

   PaymentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        title: const Text(
          'Payments',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {},
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Statistics Row
            _buildStatisticsRow(),
            const SizedBox(height: 24),
            
            // Payments List
            Expanded(
              child: ListView.builder(
                itemCount: payments.length,
                itemBuilder: (context, index) {
                  return _buildPaymentCard(payments[index]);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatisticsRow() {
    return Row(
      children: [
        Expanded(
          child: _buildStatItem('Total Paid', '\$37,900', Colors.green),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatItem('Pending', '\$15,600', Colors.orange),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatItem('Failed', '\$0', Colors.red),
        ),
      ],
    );
  }

  Widget _buildStatItem(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentCard(Map<String, dynamic> payment) {
    return Card(
      color: const Color(0xFF1A1A1A),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Payment #${payment['id']}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getStatusColor(payment['status']).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    payment['status'],
                    style: TextStyle(
                      color: _getStatusColor(payment['status']),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildInfoItem(Icons.receipt, 'Invoice: ${payment['invoice_id']}'),
                const SizedBox(width: 16),
                _buildInfoItem(Icons.calendar_today, payment['date']),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildInfoItem(Icons.payment, payment['method']),
                const Spacer(),
                Text(
                  '\$${payment['amount']}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'completed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'failed':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildInfoItem(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: Colors.grey, size: 16),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(color: Colors.grey, fontSize: 14)),
      ],
    );
  }
}