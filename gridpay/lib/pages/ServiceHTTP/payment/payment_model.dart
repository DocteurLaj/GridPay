// models/payment_model.dart
class Payment {
  final int id;
  final int invoiceId;
  final double amount;
  final String paymentMethod;
  final String? transactionId;
  final String status;
  final DateTime paidAt;
  final double invoiceAmount;
  final String invoiceMonth;
  final String invoiceStatus;
  final String meterNumber;
  final String meterName;

  Payment({
    required this.id,
    required this.invoiceId,
    required this.amount,
    required this.paymentMethod,
    this.transactionId,
    required this.status,
    required this.paidAt,
    required this.invoiceAmount,
    required this.invoiceMonth,
    required this.invoiceStatus,
    required this.meterNumber,
    required this.meterName,
  });

  factory Payment.fromJson(Map<String, dynamic> json) {
    return Payment(
      id: json['id'],
      invoiceId: json['invoice_id'],
      amount: json['amount'] is int
          ? (json['amount'] as int).toDouble()
          : json['amount'],
      paymentMethod: json['payment_method'],
      transactionId: json['transaction_id'],
      status: json['status'],
      paidAt: DateTime.parse(json['paid_at']),
      invoiceAmount: json['invoice_amount'] is int
          ? (json['invoice_amount'] as int).toDouble()
          : json['invoice_amount'],
      invoiceMonth: json['invoice_month'],
      invoiceStatus: json['invoice_status'],
      meterNumber: json['meter_number'],
      meterName: json['meter_name'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'invoice_id': invoiceId,
      'amount': amount,
      'payment_method': paymentMethod,
      'transaction_id': transactionId,
    };
  }
}
