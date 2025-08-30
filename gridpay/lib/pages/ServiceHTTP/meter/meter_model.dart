class Meter {
  final int id;
  final String meterNumber;
  final String meterName;
  final String status;
  final String createdAt;
  final String updatedAt;

  Meter({
    required this.id,
    required this.meterNumber,
    required this.meterName,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Meter.fromJson(Map<String, dynamic> json) {
    return Meter(
      id: json['id'],
      meterNumber: json['meter_number'],
      meterName: json['meter_name'] ?? '',
      status: json['status'],
      createdAt: json['created_at'],
      updatedAt: json['updated_at'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'meter_number': meterNumber,
      'meter_name': meterName,
      'status': status,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }
}