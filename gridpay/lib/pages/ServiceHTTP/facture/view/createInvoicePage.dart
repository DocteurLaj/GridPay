import 'package:flutter/material.dart';
import 'package:gridpay/pages/ServiceHTTP/url_config.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';

class CreateInvoicePage extends StatefulWidget {
  final String userName;
  final String userEmail;
  final String userPhone;
  final String authToken;
  final List<Map<String, dynamic>> userMeters;

  const CreateInvoicePage({
    super.key,
    required this.userName,
    required this.userEmail,
    required this.userPhone,
    required this.authToken,
    required this.userMeters,
  });

  @override
  State<CreateInvoicePage> createState() => _CreateInvoicePageState();
}

class _CreateInvoicePageState extends State<CreateInvoicePage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _kwhController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _monthController = TextEditingController();
  final double _ratePerKwh = 0.25;

  double _totalAmount = 0.0;
  int? _selectedMeterId;
  String _selectedMeterName = '';
  String baseUrl =
      globalBaseUrl; //"http://10.0.2.2:5000"; //"https://spidertric.pythonanywhere.com";

  @override
  void initState() {
    super.initState();
    // Set default month to current month
    _monthController.text = DateFormat('yyyy-MM').format(DateTime.now());

    // Select first meter by default if available
    if (widget.userMeters.isNotEmpty) {
      _selectedMeterId = widget.userMeters[0]['id'];
      _selectedMeterName =
          widget.userMeters[0]['meter_name'] ??
          widget.userMeters[0]['meter_number'];
    }
  }

  @override
  void dispose() {
    _kwhController.dispose();
    _amountController.dispose();
    _monthController.dispose();
    super.dispose();
  }

  void _calculateFromAmount() {
    final amount = double.tryParse(_amountController.text) ?? 0;
    if (amount > 0) {
      final kwh = amount / _ratePerKwh;
      setState(() {
        _kwhController.text = kwh.toStringAsFixed(2);
        _totalAmount = amount;
      });
    }
  }

  void _calculateFromKwh() {
    final kwh = double.tryParse(_kwhController.text) ?? 0;
    if (kwh > 0) {
      final amount = kwh * _ratePerKwh;
      setState(() {
        _amountController.text = amount.toStringAsFixed(2);
        _totalAmount = amount;
      });
    }
  }

  Future<void> _submitInvoice() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedMeterId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select a meter'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Prepare data for API according to your endpoint
      final invoiceData = {
        'meter_id': _selectedMeterId,
        'month': _monthController.text,
        'amount': _totalAmount,
        'kwh': double.parse(_kwhController.text),
        'status': 'unpaid', // Default status as per your API
      };

      try {
        final response = await http.post(
          Uri.parse('$baseUrl/invoices'), // Replace with your actual API URL
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${widget.authToken}',
          },
          body: json.encode(invoiceData),
        );

        if (response.statusCode == 201) {
          // Success
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Invoice created successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(
            context,
            true,
          ); // Return true to indicate refresh needed
        } else {
          // Handle API errors
          final errorData = json.decode(response.body);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${errorData['message']}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Network error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        title: const Text(
          'Create New Invoice',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _submitInvoice,
            tooltip: 'Save Invoice',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // Client Information Section (non-editable)
              _buildSectionHeader('Client Information'),
              _buildReadOnlyField('Name', widget.userName, Icons.person),
              _buildReadOnlyField('Email', widget.userEmail, Icons.email),
              _buildReadOnlyField('Phone', widget.userPhone, Icons.phone),

              const SizedBox(height: 24),

              // Meter Selection
              _buildSectionHeader('Select Meter'),
              _buildMeterDropdown(),

              const SizedBox(height: 24),

              // Invoice Details Section
              _buildSectionHeader('Invoice Details'),

              // Month selection
              _buildTextFormField(
                controller: _monthController,
                label: 'Month (YYYY-MM)',
                icon: Icons.calendar_today,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter month in YYYY-MM format';
                  }
                  if (!RegExp(r'^\d{4}-\d{2}$').hasMatch(value)) {
                    return 'Please use YYYY-MM format';
                  }
                  return null;
                },
              ),

              // Amount field with automatic kWh calculation
              _buildTextFormField(
                controller: _amountController,
                label: 'Amount (\$)',
                icon: Icons.attach_money,
                keyboardType: TextInputType.number,
                onChanged: (value) => _calculateFromAmount(),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter an amount';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),

              // kWh field with automatic amount calculation
              _buildTextFormField(
                controller: _kwhController,
                label: 'Energy Consumption (kWh)',
                icon: Icons.bolt,
                keyboardType: TextInputType.number,
                onChanged: (value) => _calculateFromKwh(),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter consumption';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 24),

              // Amount Summary Section
              _buildSectionHeader('Summary'),
              _buildAmountCard(),

              const SizedBox(height: 32),

              // Create Button
              ElevatedButton(
                onPressed: _submitInvoice,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Create Invoice',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildReadOnlyField(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        initialValue: value,
        enabled: false,
        style: const TextStyle(color: Colors.grey),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.grey),
          prefixIcon: Icon(icon, color: Colors.grey),
          filled: true,
          fillColor: const Color(0xFF1A1A1A).withOpacity(0.6),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildMeterDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: DropdownButtonFormField<int>(
        value: _selectedMeterId,
        decoration: InputDecoration(
          labelText: 'Select Meter',
          labelStyle: const TextStyle(color: Colors.grey),
          prefixIcon: const Icon(Icons.electrical_services, color: Colors.grey),
          filled: true,
          fillColor: const Color(0xFF1A1A1A),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
        style: const TextStyle(color: Colors.white),
        dropdownColor: const Color(0xFF1A1A1A),
        items: widget.userMeters.map((meter) {
          final displayName = meter['meter_name'] ?? meter['meter_number'];
          return DropdownMenuItem<int>(
            value: meter['id'],
            child: Text(
              displayName,
              style: const TextStyle(color: Colors.white),
            ),
          );
        }).toList(),
        onChanged: (value) {
          setState(() {
            _selectedMeterId = value;
            final selectedMeter = widget.userMeters.firstWhere(
              (meter) => meter['id'] == value,
              orElse: () => {},
            );
            _selectedMeterName =
                selectedMeter['meter_name'] ?? selectedMeter['meter_number'];
          });
        },
        validator: (value) {
          if (value == null) {
            return 'Please select a meter';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool readOnly = false,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        readOnly: readOnly,
        onChanged: onChanged,
        validator: validator,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.grey),
          prefixIcon: Icon(icon, color: Colors.grey),
          filled: true,
          fillColor: const Color(0xFF1A1A1A),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildAmountCard() {
    return Card(
      color: const Color(0xFF1A1A1A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (_selectedMeterName.isNotEmpty)
              _buildAmountRow('Meter', _selectedMeterName),
            _buildAmountRow('Applied Rate', '\$$_ratePerKwh/kWh'),
            const Divider(color: Colors.grey),
            _buildAmountRow(
              'Total Amount',
              '\$${_totalAmount.toStringAsFixed(2)}',
              isTotal: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountRow(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.grey, fontSize: isTotal ? 16 : 14),
          ),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: isTotal ? 18 : 16,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
