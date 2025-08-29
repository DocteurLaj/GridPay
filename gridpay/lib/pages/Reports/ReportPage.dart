import 'package:flutter/material.dart';

class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        title: const Text(
          'Reports & Analytics',
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
            // Time Filter
            _buildTimeFilter(),
            const SizedBox(height: 24),

            // Revenue Chart Placeholder
            _buildChartPlaceholder('Revenue Overview', Colors.blue),
            const SizedBox(height: 24),

            // Energy Usage Chart Placeholder
            _buildChartPlaceholder('Energy Consumption', Colors.green),
            const SizedBox(height: 24),

            // Report Types
            const Text(
              'Generate Reports',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            Expanded(
              child: GridView(
                shrinkWrap: true,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.5,
                ),
                children: [
                  _buildReportType(
                    'Financial Report',
                    Icons.attach_money,
                    Colors.blue,
                  ),
                  _buildReportType('Energy Report', Icons.bolt, Colors.green),
                  _buildReportType(
                    'Client Report',
                    Icons.people,
                    Colors.orange,
                  ),
                  _buildReportType(
                    'Tax Report',
                    Icons.description,
                    Colors.purple,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeFilter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: ['Today', 'Week', 'Month', 'Year'].map((period) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: period == 'Month' ? Colors.blue : const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            period,
            style: TextStyle(
              color: period == 'Month' ? Colors.white : Colors.grey,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildChartPlaceholder(String title, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            height: 150,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(child: Icon(Icons.bar_chart, color: color, size: 40)),
          ),
          const SizedBox(height: 8),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Jan', style: TextStyle(color: Colors.grey)),
              Text('Feb', style: TextStyle(color: Colors.grey)),
              Text('Mar', style: TextStyle(color: Colors.grey)),
              Text('Apr', style: TextStyle(color: Colors.grey)),
              Text('May', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReportType(String title, IconData icon, Color color) {
    return GestureDetector(
      onTap: () {},
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text('Generate PDF', style: TextStyle(color: color, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
