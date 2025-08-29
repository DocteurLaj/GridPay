import 'package:flutter/material.dart';

class EnergyUsagePage extends StatelessWidget {
  final List<Map<String, dynamic>> usageData = [
    {'month': 'Jan', 'kwh': 45.8, 'cost': 12500.0},
    {'month': 'Feb', 'kwh': 42.3, 'cost': 11800.0},
    {'month': 'Mar', 'kwh': 48.1, 'cost': 13200.0},
    {'month': 'Apr', 'kwh': 38.2, 'cost': 9800.0},
    {'month': 'May', 'kwh': 52.1, 'cost': 15600.0},
  ];

  EnergyUsagePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        title: const Text(
          'Energy Usage',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Current Usage Card
            _buildCurrentUsageCard(),
            const SizedBox(height: 24),

            // Usage History
            const Text(
              'Usage History',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            Expanded(
              child: ListView.builder(
                itemCount: usageData.length,
                itemBuilder: (context, index) {
                  return _buildUsageItem(usageData[index]);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentUsageCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Current Month',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text('May 2024', style: TextStyle(color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildUsageMetric(
                  '52.1 kWh',
                  'Energy Used',
                  Colors.blue,
                ),
              ),
              Expanded(
                child: _buildUsageMetric(
                  '\$15,600',
                  'Total Cost',
                  Colors.green,
                ),
              ),
              Expanded(
                child: _buildUsageMetric(
                  '+12%',
                  'vs Last Month',
                  Colors.orange,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUsageMetric(String value, String label, Color color) {
    return Column(
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
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }

  Widget _buildUsageItem(Map<String, dynamic> data) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              data['month'],
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              '${data['kwh']} kWh',
              style: const TextStyle(color: Colors.blue),
            ),
          ),
          Expanded(
            child: Text(
              '\$${data['cost']}',
              style: const TextStyle(color: Colors.green),
            ),
          ),
        ],
      ),
    );
  }
}
