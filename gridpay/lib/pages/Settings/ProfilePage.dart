import 'package:flutter/material.dart';
import 'package:gridpay/pages/ServiceHTTP/meter/view/meters_page.dart';
import 'package:gridpay/pages/auth/authService.dart';

class ProfilePage extends StatefulWidget {
  ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final AuthService _authService = AuthService();
  String? _userEmail;
  // String? _userId;
  String? _userName;
  String? _userPhone;
  String? _userCreatedAt;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final email = await _authService.getEmail();
    //final userId = await _authService.getUserId();
    final userName = await _authService.getName();
    final userPhone = await _authService.getPhone();
    final usercreatedAt = await _authService.getUserCreatedAt();

    setState(() {
      _userEmail = email;
      //_userId = userId;
      _userName = userName;
      _userPhone = userPhone;
      _userCreatedAt = usercreatedAt;

      _isLoading = false;
    });
  }

  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        title: const Text(
          'My Profile',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => MetersPage()),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Profile Card
                  _buildProfileCard(context),
                  const SizedBox(height: 24),

                  // Account Information
                  _buildInfoSection('Account Information', [
                    _buildInfoItem(
                      'Email',
                      _userEmail ?? 'invalide',
                      Icons.email,
                    ),
                    _buildInfoItem('Phone', '+$_userPhone', Icons.phone),
                    _buildInfoItem('Meters', 'CNT-452-985', Icons.gas_meter),
                    _buildInfoItem(
                      'Member Since',
                      _userCreatedAt ?? 'invalide',
                      Icons.calendar_today,
                    ),
                  ]),

                  const SizedBox(height: 24),

                  // Billing Information
                  _buildInfoSection('Billing Information', [
                    // _buildInfoItem(
                    //   'Address',
                    //   '123 Energy Street, Kinshasa',
                    //   Icons.location_on,
                    // ),
                    _buildInfoItem(
                      'Payment Method',
                      'Mobile Money',
                      Icons.payment,
                    ),
                    _buildInfoItem(
                      'Billing Cycle',
                      'Energy Kwh',
                      Icons.calendar_month,
                    ),
                  ]),

                  const SizedBox(height: 24),

                  // Statistics
                  //_buildStatsGrid(context),
                  SizedBox(height: 30),
                  SizedBox(
                    width: 300,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        _authService.logout(context);
                      },
                      child: Text("logout", style: TextStyle(fontSize: 17)),
                    ),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildProfileCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.blue.shade700,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: const Icon(Icons.person, color: Colors.white, size: 40),
          ),
          const SizedBox(height: 16),
          Text(
            _userName ?? 'Non disponible',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _userEmail ?? 'invalide',
            style: TextStyle(color: Colors.blue.shade300, fontSize: 14),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              //_buildProfileStat('24', 'Invoices'),
              //_buildProfileStat('21', 'Paid'),
              //_buildProfileStat('3', 'Pending'),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildProfileStat(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }

  Widget _buildInfoSection(String title, List<Widget> children) {
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
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoItem(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                Text(
                  value,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildStatsGrid(BuildContext context) {
    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.5,
      ),
      children: [
        _buildStatCard(
          'Total Spent',
          '\$45,200',
          Icons.attach_money,
          Colors.green,
        ),
        _buildStatCard('Energy Used', '187.5 kWh', Icons.bolt, Colors.blue),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }
}
