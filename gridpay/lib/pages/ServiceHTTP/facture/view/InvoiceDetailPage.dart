import 'package:flutter/material.dart';
import 'package:gridpay/pages/ServiceHTTP/facture/InvoiceService.dart';
import 'package:gridpay/pages/ServiceHTTP/payment/paymentService.dart';
import 'package:intl/intl.dart';

class InvoiceDetailPage extends StatefulWidget {
  final Map<String, dynamic> invoice;

  const InvoiceDetailPage({super.key, required this.invoice});

  @override
  State<InvoiceDetailPage> createState() => _InvoiceDetailPageState();
}

class _InvoiceDetailPageState extends State<InvoiceDetailPage> {
  final InvoiceService _invoiceService = InvoiceService();
  final PaymentService _paymentService = PaymentService();
  bool _isLoading = false;
  Map<String, dynamic>? _invoiceDetails;

  @override
  void initState() {
    super.initState();
    _loadInvoiceDetails();
  }

  Future<void> _loadInvoiceDetails() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _invoiceService.getInvoice(widget.invoice['id']);

      if (result['success'] == true) {
        setState(() {
          _invoiceDetails = result['invoice'];
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${result['message']}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading invoice details: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'N/A';
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('dd/MM/yyyy').format(date);
    } catch (e) {
      return dateString;
    }
  }

  String _formatCurrency(double amount) {
    return NumberFormat.currency(symbol: '\$', decimalDigits: 2).format(amount);
  }

  @override
  Widget build(BuildContext context) {
    final invoice = _invoiceDetails ?? widget.invoice;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        title: const Text(
          'Invoice Details',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadInvoiceDetails,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInvoiceHeader(invoice),
                  const SizedBox(height: 24),
                  _buildInvoiceDetails(invoice),
                  const SizedBox(height: 24),
                  _buildMeterInfo(invoice),
                  const Spacer(),
                  _buildActionButtons(context, invoice),
                ],
              ),
            ),
    );
  }

  Widget _buildInvoiceHeader(Map<String, dynamic> invoice) {
    return Card(
      color: const Color(0xFF1A1A1A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total Amount',
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
                Text(
                  _formatCurrency(invoice['amount']?.toDouble() ?? 0.0),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Status',
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: invoice['status'] == 'paid'
                        ? Colors.green.withOpacity(0.2)
                        : invoice['status'] == 'pending'
                        ? Colors.orange.withOpacity(0.2)
                        : Colors.red.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    invoice['status']?.toString().toUpperCase() ?? 'UNKNOWN',
                    style: TextStyle(
                      color: invoice['status'] == 'paid'
                          ? Colors.green
                          : invoice['status'] == 'pending'
                          ? Colors.orange
                          : Colors.red,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInvoiceDetails(Map<String, dynamic> invoice) {
    return Card(
      color: const Color(0xFF1A1A1A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Invoice Details',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            _buildDetailRow('Invoice Number', '#${invoice['id']}'),
            _buildDetailRow(
              'Energy Consumption',
              '${invoice['kwh']?.toStringAsFixed(2) ?? '0.00'} kWh',
            ),
            _buildDetailRow('Month', invoice['month'] ?? 'N/A'),
            _buildDetailRow('Issued Date', _formatDate(invoice['issued_at'])),
            _buildDetailRow('Rate per kWh', '\$0.25'),
          ],
        ),
      ),
    );
  }

  Widget _buildMeterInfo(Map<String, dynamic> invoice) {
    return Card(
      color: const Color(0xFF1A1A1A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Meter Information',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            if (invoice['meter_number'] != null)
              _buildDetailRow('Meter Number', invoice['meter_number']),
            if (invoice['meter_name'] != null)
              _buildDetailRow('Meter Name', invoice['meter_name']),
            _buildDetailRow(
              'Consumption',
              '${invoice['kwh']?.toStringAsFixed(2) ?? '0.00'} kWh',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildActionButtons(
    BuildContext context,
    Map<String, dynamic> invoice,
  ) {
    return Row(
      children: [
        if (invoice['status'] != 'paid')
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                _processPayment(invoice);
                //Navigator.push(
                //  context,
                //  MaterialPageRoute(
                //    builder: (context) => PaymentPage(invoice: invoice),
                //  ),
                //);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Pay Now',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ),
        if (invoice['status'] != 'paid') const SizedBox(width: 12),
        ElevatedButton(
          onPressed: () {
            _shareInvoice(invoice);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2A2A2A),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Icon(Icons.share, color: Colors.white),
        ),
      ],
    );
  }

  String _generateTransactionId() {
    return 'TXN${DateTime.now().millisecondsSinceEpoch}';
  }

  void _processPayment(Map<String, dynamic> invoice) {
    // Implémentez la logique de paiement ici
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Process Payment'),
        content: Text('Process payment for invoice #${invoice['id']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() {
                _isLoading = true;
              });

              try {
                final result = await _paymentService.addPayment(
                  invoiceId: invoice['id']!,
                  amount: invoice['amount'],
                  paymentMethod: "Mobile money",
                  transactionId: _generateTransactionId(),
                );

                if (result['success'] == true) {
                  // Afficher un message de succès
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(result['message']),
                      backgroundColor: Colors.green,
                    ),
                  );
                  _loadInvoiceDetails();
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Payment error: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              } finally {
                setState(() {
                  _isLoading = false;
                });
              }
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  void _shareInvoice(Map<String, dynamic> invoice) {
    // Implémentez la logique de partage ici
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Share functionality coming soon!'),
        backgroundColor: Colors.blue,
      ),
    );
  }
}
