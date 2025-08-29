import 'package:flutter/material.dart';

class CreateInvoicePage extends StatefulWidget {
  const CreateInvoicePage({super.key});

  @override
  State<CreateInvoicePage> createState() => _CreateInvoicePageState();
}

class _CreateInvoicePageState extends State<CreateInvoicePage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _clientNameController = TextEditingController();
  final TextEditingController _clientEmailController = TextEditingController();
  final TextEditingController _clientPhoneController = TextEditingController();
  final TextEditingController _kwhController = TextEditingController();
  final TextEditingController _rateController = TextEditingController(
    text: '0.25',
  );
  final TextEditingController _taxRateController = TextEditingController(
    text: '18',
  );
  final TextEditingController _dueDateController = TextEditingController();

  DateTime? _dueDate;
  double _totalAmount = 0.0;
  double _taxAmount = 0.0;
  double _subTotal = 0.0;

  @override
  void initState() {
    super.initState();
    _dueDate = DateTime.now().add(const Duration(days: 30));
    _dueDateController.text = _formatDate(_dueDate!);
  }

  @override
  void dispose() {
    _clientNameController.dispose();
    _clientEmailController.dispose();
    _clientPhoneController.dispose();
    _kwhController.dispose();
    _rateController.dispose();
    _taxRateController.dispose();
    _dueDateController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _calculateTotal() {
    final kwh = double.tryParse(_kwhController.text) ?? 0;
    final rate = double.tryParse(_rateController.text) ?? 0;
    final taxRate = double.tryParse(_taxRateController.text) ?? 0;

    setState(() {
      _subTotal = kwh * rate;
      _taxAmount = _subTotal * (taxRate / 100);
      _totalAmount = _subTotal + _taxAmount;
    });
  }

  Future<void> _selectDueDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );

    if (picked != null && picked != _dueDate) {
      setState(() {
        _dueDate = picked;
        _dueDateController.text = _formatDate(picked);
      });
    }
  }

  void _submitInvoice() {
    if (_formKey.currentState!.validate()) {
      // Simuler la création de la facture
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Invoice created successfully!'),
          backgroundColor: Colors.green.shade700,
        ),
      );

      // Naviguer en arrière ou reset le formulaire
      Navigator.pop(context);
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
              // Section Client Information
              _buildSectionHeader('Client Information'),
              _buildTextFormField(
                controller: _clientNameController,
                label: 'Client Name',
                icon: Icons.person,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter client name';
                  }
                  return null;
                },
              ),
              _buildTextFormField(
                controller: _clientEmailController,
                label: 'Email Address',
                icon: Icons.email,
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter email address';
                  }
                  if (!value.contains('@')) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
              ),
              _buildTextFormField(
                controller: _clientPhoneController,
                label: 'Phone Number',
                icon: Icons.phone,
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter phone number';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 24),

              // Section Invoice Details
              _buildSectionHeader('Invoice Details'),
              _buildTextFormField(
                controller: _kwhController,
                label: 'Energy Consumption (kWh)',
                icon: Icons.bolt,
                keyboardType: TextInputType.number,
                onChanged: (value) => _calculateTotal(),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter kWh consumption';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),

              Row(
                children: [
                  Expanded(
                    child: _buildTextFormField(
                      controller: _rateController,
                      label: 'Rate per kWh (\$)',
                      icon: Icons.attach_money,
                      keyboardType: TextInputType.number,
                      onChanged: (value) => _calculateTotal(),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTextFormField(
                      controller: _taxRateController,
                      label: 'Tax Rate (%)',
                      icon: Icons.percent,
                      keyboardType: TextInputType.number,
                      onChanged: (value) => _calculateTotal(),
                    ),
                  ),
                ],
              ),

              _buildTextFormField(
                controller: _dueDateController,
                label: 'Due Date',
                icon: Icons.calendar_today,
                readOnly: true,
                onTap: _selectDueDate,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select due date';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 24),

              // Section Amount Summary
              _buildSectionHeader('Amount Summary'),
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

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool readOnly = false,
    VoidCallback? onTap,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        readOnly: readOnly,
        onTap: onTap,
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
            _buildAmountRow('Subtotal', '\$$_subTotal'),
            _buildAmountRow(
              'Tax (\${_taxRateController.text}%)',
              '\$$_taxAmount',
            ),
            const Divider(color: Colors.grey),
            _buildAmountRow('Total Amount', '\$$_totalAmount', isTotal: true),
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
