// pages/payment/payment_page.dart
import 'package:flutter/material.dart';
import 'package:gridpay/pages/ServiceHTTP/payment/paymentService.dart';
import 'package:gridpay/pages/ServiceHTTP/payment/payment_model.dart';
import 'package:gridpay/pages/ServiceHTTP/payment/view/payment_history.dart';

class PaymentPage extends StatefulWidget {
  final Map<String, dynamic>? invoice;

  const PaymentPage({super.key, this.invoice});

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  final PaymentService _paymentService = PaymentService();
  final _formKey = GlobalKey<FormState>();

  // Variables du formulaire
  int? _selectedInvoiceId;
  double _amount = 0.0;
  String _selectedMethod = 'carte';
  String? _transactionId;

  // États
  bool _isLoading = false;
  bool _isProcessing = false;
  String? _errorMessage;
  List<Payment> _payments = [];

  @override
  void initState() {
    super.initState();
    _initializeForm();
    _loadPaymentHistory();
  }

  void _initializeForm() {
    if (widget.invoice != null) {
      _selectedInvoiceId = widget.invoice!['id'];
      _amount = widget.invoice!['amount'] is int
          ? (widget.invoice!['amount'] as int).toDouble()
          : widget.invoice!['amount'];
    }
  }

  Future<void> _loadPaymentHistory() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _paymentService.getUserPayments();

      if (result['success'] == true) {
        final paymentsData = result['payments'] as List;
        setState(() {
          _payments = paymentsData
              .map((json) => Payment.fromJson(json))
              .toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = result['message'];
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur de chargement: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _submitPayment() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      if (_selectedInvoiceId == null) {
        setState(() {
          _errorMessage = 'Veuillez sélectionner une facture';
        });
        return;
      }

      setState(() {
        _isProcessing = true;
        _errorMessage = null;
      });

      try {
        final result = await _paymentService.addPayment(
          invoiceId: _selectedInvoiceId!,
          amount: _amount,
          paymentMethod: _selectedMethod,
          transactionId: _transactionId,
        );

        if (result['success'] == true) {
          // Réinitialiser le formulaire
          _formKey.currentState!.reset();
          if (widget.invoice == null) {
            _selectedInvoiceId = null;
            _amount = 0.0;
          } else {
            _amount = widget.invoice!['amount'];
          }

          // Recharger l'historique
          await _loadPaymentHistory();

          // Afficher un message de succès
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message']),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          setState(() {
            _errorMessage = result['message'];
          });
        }
      } catch (e) {
        setState(() {
          _errorMessage = 'Erreur lors du paiement: $e';
        });
      } finally {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  String _generateTransactionId() {
    return 'TXN${DateTime.now().millisecondsSinceEpoch}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Paiement'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Formulaire de paiement
            _buildPaymentForm(),

            const SizedBox(height: 24),

            // Historique des paiements
            _buildPaymentHistory(),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentForm() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Nouveau Paiement',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 16),

              // ID de la facture (modifiable seulement si pas passé en paramètre)
              if (widget.invoice == null) ...[
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'ID de la Facture',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Veuillez entrer l\'ID de la facture';
                    }
                    if (int.tryParse(value) == null) {
                      return 'ID invalide';
                    }
                    return null;
                  },
                  onSaved: (value) {
                    _selectedInvoiceId = int.tryParse(value!);
                  },
                ),
                const SizedBox(height: 16),
              ],

              // Montant
              TextFormField(
                initialValue: _amount.toString(),
                decoration: const InputDecoration(
                  labelText: 'Montant',
                  prefixText: '\$ ',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Veuillez entrer un montant';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Montant invalide';
                  }
                  return null;
                },
                onSaved: (value) {
                  _amount = double.parse(value!);
                },
              ),

              const SizedBox(height: 16),

              // Méthode de paiement
              DropdownButtonFormField<String>(
                value: _selectedMethod,
                decoration: const InputDecoration(
                  labelText: 'Méthode de Paiement',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'carte',
                    child: Text('Carte Bancaire'),
                  ),
                  DropdownMenuItem(value: 'paypal', child: Text('PayPal')),
                  DropdownMenuItem(
                    value: 'virement',
                    child: Text('Virement Bancaire'),
                  ),
                  DropdownMenuItem(value: 'especes', child: Text('Espèces')),
                  DropdownMenuItem(
                    value: 'mobile_money',
                    child: Text('Mobile Money'),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedMethod = value!;
                  });
                },
              ),

              const SizedBox(height: 16),

              // ID de transaction (optionnel)
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'ID de Transaction (optionnel)',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  _transactionId = value.isEmpty ? null : value;
                },
              ),

              const SizedBox(height: 16),

              // Bouton pour générer un ID de transaction
              OutlinedButton(
                onPressed: () {
                  setState(() {
                    _transactionId = _generateTransactionId();
                  });
                },
                child: const Text('Générer un ID de Transaction'),
              ),

              const SizedBox(height: 16),

              // Message d'erreur
              if (_errorMessage != null)
                Text(_errorMessage!, style: const TextStyle(color: Colors.red)),

              const SizedBox(height: 16),

              // Bouton de soumission
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isProcessing ? null : _submitPayment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isProcessing
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Effectuer le Paiement',
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentHistory() {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Historique des Paiements',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 16),

          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _payments.isEmpty
              ? const Center(
                  child: Text(
                    'Aucun paiement trouvé',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : Expanded(
                  child: ListView.builder(
                    itemCount: _payments.length,
                    itemBuilder: (context, index) {
                      final payment = _payments[index];
                      return PaymentHistoryCard(payment: payment);
                    },
                  ),
                ),
        ],
      ),
    );
  }
}
