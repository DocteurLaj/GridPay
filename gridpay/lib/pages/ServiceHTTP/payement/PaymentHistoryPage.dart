import 'package:flutter/material.dart';
import 'package:gridpay/pages/ServiceHTTP/payement/paymentService.dart';
import 'package:intl/intl.dart';

class PaymentHistoryPage extends StatefulWidget {
  const PaymentHistoryPage({super.key});

  @override
  State<PaymentHistoryPage> createState() => _PaymentHistoryPageState();
}

class _PaymentHistoryPageState extends State<PaymentHistoryPage> {
  final PaymentService _paymentService = PaymentService();
  List<Map<String, dynamic>> _payments = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadPayments();
  }

  Future<void> _loadPayments() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final result = await _paymentService.getUserPayments();

      if (result['success'] == true) {
        final payments = List<Map<String, dynamic>>.from(
          result['payments'] ?? [],
        );

        print('Payments loaded: ${payments.length}');
        if (payments.isNotEmpty) {
          print('Sample payment: ${payments[0]}');
        }

        setState(() {
          _payments = payments;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = result['message'] ?? 'Failed to load payments';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Network error: $e';
        _isLoading = false;
      });
    }
  }

  String _formatCurrency(double amount) {
    return NumberFormat.currency(symbol: '\$', decimalDigits: 2).format(amount);
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'N/A';
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('MMM dd, yyyy').format(date);
    } catch (e) {
      return dateString;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
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

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return 'Completed';
      case 'pending':
        return 'Pending';
      case 'failed':
        return 'Failed';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        title: const Text(
          'Payment History',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPayments,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
              ),
            )
          : _errorMessage != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 64),
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _loadPayments,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Statistics Row
                  _buildStatisticsRow(),
                  const SizedBox(height: 16),

                  const Text(
                    'Recent Payments',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: _payments.isEmpty
                        ? const Center(
                            child: Text(
                              'No payments found',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 16,
                              ),
                            ),
                          )
                        : ListView.builder(
                            itemCount: _payments.length,
                            itemBuilder: (context, index) {
                              return _buildPaymentCard(_payments[index]);
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatisticsRow() {
    double totalPaid = 0;
    int completedCount = 0;
    int pendingCount = 0;

    for (var payment in _payments) {
      final amount = payment['amount']?.toDouble() ?? 0.0;
      final status = payment['status']?.toString().toLowerCase() ?? '';

      if (status == 'completed') {
        totalPaid += amount;
        completedCount++;
      } else if (status == 'pending') {
        pendingCount++;
      }
    }

    return Row(
      children: [
        Expanded(
          child: _buildStatItem(
            'Total Paid',
            _formatCurrency(totalPaid),
            Colors.green,
            '$completedCount completed',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatItem(
            'Pending',
            '$pendingCount payments',
            Colors.orange,
            'Awaiting confirmation',
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem(
    String title,
    String value,
    Color color,
    String subtitle,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
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
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(color: Colors.grey, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentCard(Map<String, dynamic> payment) {
    final status = payment['status']?.toString().toLowerCase() ?? 'pending';
    final amount = payment['amount']?.toDouble() ?? 0.0;
    final paidAt = _formatDate(payment['paid_at']);
    final paymentMethod = payment['payment_method']?.toString() ?? 'N/A';
    final transactionId = payment['transaction_id']?.toString() ?? 'N/A';
    final invoiceId = payment['invoice_id']?.toString() ?? 'N/A';
    final invoiceAmount = payment['invoice_amount']?.toDouble() ?? 0.0;
    final meterName = payment['meter_name']?.toString() ?? 'Unknown Meter';
    final invoiceMonth = payment['invoice_month']?.toString() ?? 'N/A';

    return Card(
      color: const Color(0xFF1A1A1A),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header avec ID de transaction et statut
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Payment #${payment['id']}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _getStatusText(status),
                    style: TextStyle(
                      color: _getStatusColor(status),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Informations du compteur et facture
            Text(
              meterName,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Invoice #$invoiceId • $invoiceMonth',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),

            const SizedBox(height: 12),

            // Ligne 1: Méthode de paiement et date
            Row(
              children: [
                _buildInfoItem(
                  Icons.payment,
                  'Method: ${paymentMethod.toUpperCase()}',
                ),
                const SizedBox(width: 16),
                _buildInfoItem(Icons.date_range, 'Paid: $paidAt'),
              ],
            ),

            const SizedBox(height: 8),

            // Ligne 2: Transaction ID et montant
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Transaction: ${transactionId != 'N/A' ? transactionId : 'Not provided'}',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatCurrency(amount),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (invoiceAmount > 0)
                      Text(
                        'of ${_formatCurrency(invoiceAmount)}',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Barre de progression pour les paiements partiels
            if (invoiceAmount > 0 &&
                amount < invoiceAmount &&
                status == 'completed')
              Column(
                children: [
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: amount / invoiceAmount,
                    backgroundColor: Colors.grey.shade800,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.blue.shade400,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Partial payment (${((amount / invoiceAmount) * 100).toStringAsFixed(1)}%)',
                    style: const TextStyle(color: Colors.grey, fontSize: 10),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: Colors.grey, size: 14),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }
}
