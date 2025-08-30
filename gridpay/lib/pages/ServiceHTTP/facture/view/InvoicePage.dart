import 'package:flutter/material.dart';
import 'package:gridpay/pages/ServiceHTTP/facture/view/InvoiceDetailPage.dart';
import 'package:gridpay/pages/ServiceHTTP/facture/view/InvoiceService.dart';
import 'package:intl/intl.dart';

class InvoicePage extends StatefulWidget {
  const InvoicePage({super.key});

  @override
  State<InvoicePage> createState() => _InvoicePageState();
}

class _InvoicePageState extends State<InvoicePage> {
  final InvoiceService _invoiceService = InvoiceService();
  List<Map<String, dynamic>> _invoices = [];
  bool _isLoading = true;
  String? _errorMessage;

  // Statistiques calculées
  double _totalPaid = 0.0;
  double _totalPending = 0.0;
  int _paidCount = 0;
  int _pendingCount = 0;

  @override
  void initState() {
    super.initState();
    _loadInvoices();
  }

  Future<void> _loadInvoices() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final result = await _invoiceService.getUserInvoices();

      if (result['success'] == true) {
        final invoices = List<Map<String, dynamic>>.from(
          result['invoices'] ?? [],
        );

        print('Invoices loaded: ${invoices.length}');
        if (invoices.isNotEmpty) {
          print('Sample invoice keys: ${invoices[0].keys}');
          print('Sample invoice values: ${invoices[0]}');
        }

        // Calculer les statistiques
        _calculateStatistics(invoices);

        setState(() {
          _invoices = invoices;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = result['message'] ?? 'Failed to load invoices';
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

  void _calculateStatistics(List<Map<String, dynamic>> invoices) {
    _totalPaid = 0.0;
    _totalPending = 0.0;
    _paidCount = 0;
    _pendingCount = 0;

    for (var invoice in invoices) {
      final amount = invoice['amount']?.toDouble() ?? 0.0;
      final status = invoice['status']?.toString().toLowerCase() ?? 'pending';

      if (status == 'paid') {
        _totalPaid += amount;
        _paidCount++;
      } else {
        _totalPending += amount;
        _pendingCount++;
      }
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

  // Méthode pour extraire le nom du compteur
  String _getMeterDisplayName(Map<String, dynamic> invoice) {
    if (invoice['meter_name'] != null &&
        invoice['meter_name'].toString().isNotEmpty) {
      return invoice['meter_name'].toString();
    } else if (invoice['meter_number'] != null) {
      return 'Meter ${invoice['meter_number']}';
    } else if (invoice['meter_id'] != null) {
      return 'Meter #${invoice['meter_id']}';
    } else {
      return 'Unknown Meter';
    }
  }

  // Méthode pour obtenir le mois formaté
  String _getFormattedMonth(Map<String, dynamic> invoice) {
    final month = invoice['month'];
    if (month == null) return 'N/A';

    // Si le mois est au format YYYY-MM (ex: "2024-01")
    if (month is String && month.contains('-')) {
      try {
        final parts = month.split('-');
        if (parts.length == 2) {
          final year = int.tryParse(parts[0]);
          final monthNum = int.tryParse(parts[1]);
          if (year != null &&
              monthNum != null &&
              monthNum >= 1 &&
              monthNum <= 12) {
            final date = DateTime(year, monthNum);
            return DateFormat('MMMM yyyy').format(date);
          }
        }
      } catch (e) {
        return month.toString();
      }
    }

    return month.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        title: const Text(
          'Invoices',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadInvoices,
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
                    onPressed: _loadInvoices,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Statistics Row
                  _buildStatisticsRow(),
                  const SizedBox(height: 24),

                  // Invoices List
                  Expanded(
                    child: _invoices.isEmpty
                        ? const Center(
                            child: Text(
                              'No invoices found',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 16,
                              ),
                            ),
                          )
                        : ListView.builder(
                            itemCount: _invoices.length,
                            itemBuilder: (context, index) {
                              return _buildInvoiceCard(_invoices[index]);
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
          child: _buildStatItem(
            'Total Paid',
            _formatCurrency(_totalPaid),
            Colors.green,
            '$_paidCount paid',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatItem(
            'Pending',
            _formatCurrency(_totalPending),
            Colors.orange,
            '$_pendingCount pending',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatItem(
            'Total',
            _formatCurrency(_totalPaid + _totalPending),
            Colors.blue,
            '${_invoices.length} invoices',
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
              fontSize: 16,
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

  Widget _buildInvoiceCard(Map<String, dynamic> invoice) {
    // Récupération des données DYNAMIQUES de l'API
    final status = invoice['status']?.toString().toLowerCase() ?? 'pending';
    final amount = invoice['amount']?.toDouble() ?? 0.0;
    final formattedMonth = _getFormattedMonth(invoice);
    final issuedDate = _formatDate(invoice['issued_at']);
    final kwh = invoice['kwh']?.toStringAsFixed(2) ?? '0.00';
    final meterName = _getMeterDisplayName(invoice);
    final invoiceId = invoice['id']?.toString() ?? 'N/A';

    return Card(
      color: const Color(0xFF1A1A1A),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header avec numéro de facture et statut
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Invoice #$invoiceId',
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
                    status.toUpperCase(),
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

            // Informations du compteur (dynamique)
            Text(
              meterName,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),

            const SizedBox(height: 8),

            // Ligne 1: Mois et consommation (dynamique)
            Row(
              children: [
                _buildInfoItem(Icons.calendar_month, 'Period: $formattedMonth'),
                const SizedBox(width: 16),
                _buildInfoItem(Icons.bolt, 'Energy: $kwh kWh'),
              ],
            ),

            const SizedBox(height: 8),

            // Ligne 2: Date d'émission et montant (dynamique)
            Row(
              children: [
                _buildInfoItem(Icons.date_range, 'Issued: $issuedDate'),
                const Spacer(),
                Text(
                  _formatCurrency(amount),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Bouton View Details
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: () {
                  _navigateToInvoiceDetails(invoice);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text(
                  'View Details',
                  style: TextStyle(fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'paid':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'overdue':
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

  void _navigateToInvoiceDetails(Map<String, dynamic> invoice) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => InvoiceDetailPage(invoice: invoice),
      ),
    ).then((_) {
      // Rafraîchir les données après retour de la page de détails
      _loadInvoices();
    });
  }
}
