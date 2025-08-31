// widgets/payment_history_card.dart
import 'package:flutter/material.dart';
import 'package:gridpay/pages/ServiceHTTP/payment/payment_model.dart';
import 'package:intl/intl.dart';

class PaymentHistoryCard extends StatelessWidget {
  final Payment payment;

  const PaymentHistoryCard({super.key, required this.payment});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Facture #${payment.invoiceId}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Chip(
                  label: Text(
                    payment.status.toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                  backgroundColor: payment.status == 'completed'
                      ? Colors.green
                      : payment.status == 'pending'
                      ? Colors.orange
                      : Colors.red,
                ),
              ],
            ),

            const SizedBox(height: 8),

            Text(
              'Montant: \$${payment.amount.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 14),
            ),

            const SizedBox(height: 4),

            Text(
              'Méthode: ${_formatPaymentMethod(payment.paymentMethod)}',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),

            if (payment.transactionId != null) ...[
              const SizedBox(height: 4),
              Text(
                'Transaction: ${payment.transactionId}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],

            const SizedBox(height: 4),

            Text(
              'Date: ${DateFormat('dd/MM/yyyy HH:mm').format(payment.paidAt)}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  String _formatPaymentMethod(String method) {
    switch (method) {
      case 'carte':
        return 'Carte Bancaire';
      case 'paypal':
        return 'PayPal';
      case 'virement':
        return 'Virement Bancaire';
      case 'especes':
        return 'Espèces';
      case 'mobile_money':
        return 'Mobile Money';
      default:
        return method;
    }
  }
}
