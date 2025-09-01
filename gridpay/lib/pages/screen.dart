import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gridpay/pages/%20EnergyUsage/%20EnergyUsagePage.dart';
import 'package:gridpay/pages/Reports/ReportPage.dart';
import 'package:gridpay/pages/ServiceHTTP/meter/ConsumptionService.dart';
import 'package:gridpay/pages/ServiceHTTP/meter/meter_service.dart';
import 'package:gridpay/pages/Settings/ProfilePage.dart';
import 'package:gridpay/pages/Settings/SettingsPage.dart';
import 'package:gridpay/pages/auth/authService.dart';
import 'package:gridpay/pages/auth/login.dart'; // Import de la page de login
import 'package:gridpay/pages/ServiceHTTP/facture/view/createInvoicePage.dart';
import 'package:gridpay/pages/ServiceHTTP/facture/view/InvoicePage.dart';
import 'package:gridpay/pages/ServiceHTTP/payment/view/PaymentHistoryPage.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final AuthService _authService = AuthService();
  final MeterService _meterService = MeterService();
  final ConsumptionService _consumptionService = ConsumptionService();

  String? _userEmail;
  String? _userName;
  String? _userPhone;
  String? _authToken;
  List<Map<String, dynamic>> _userMeters = [];
  bool _isLoading = true;
  String? _errorMessage;
  bool _redirectingToLogin = false;

  double _totalConsumption = 0.0;
  List<Map<String, dynamic>> _meterConsumptions = [];
  bool _isLoadingConsumption = false;

  Timer? _consumptionTimer;

  //int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _startConsumptionTimer();
    setState(() {
      _isLoadingConsumption = true;
    });
  }

  @override
  void dispose() {
    _consumptionTimer?.cancel();
    super.dispose();
  }

  void _startConsumptionTimer() {
    _consumptionTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_authToken != null) {
        _loadConsumptionData();
      }
    });
  }

  Future<void> _loadConsumptionData() async {
    if (_authToken == null) return;

    //setState(() {
    //  _isLoadingConsumption = true;
    //});

    try {
      final result = await _consumptionService.getAllCumulativeConsumptions();

      if (result['success'] == true) {
        setState(() {
          _meterConsumptions = List<Map<String, dynamic>>.from(
            result['data'] ?? [],
          );
          _totalConsumption =
              (result['total_consumption'] as num?)?.toDouble() ?? 0.0;
        });
      } else {
        print('Error loading consumption: ${result['message']}');
      }
    } catch (e) {
      print('Error in loadConsumptionData: $e');
    } finally {
      setState(() {
        _isLoadingConsumption = false;
      });
    }
  }

  Future<void> _loadUserData() async {
    try {
      print('Loading user data...');

      final token = await _authService.getToken();

      // Vérifier d'abord si le token existe
      if (token == null || token.isEmpty) {
        print('No token found, redirecting to login');
        _redirectToLogin();
        return;
      }

      // Charger les autres données utilisateur seulement si le token existe
      final email = await _authService.getEmail();
      final userName = await _authService.getName();
      final userPhone = await _authService.getPhone();

      await _loadUserMeters();
      await _loadConsumptionData(); // ← AJOUTEZ CET APPEL

      print(
        'User data loaded: email=$email, name=$userName, phone=$userPhone, token=exists',
      );

      setState(() {
        _userEmail = email;
        _userName = userName;
        _userPhone = userPhone;
        _authToken = token;
      });

      // Charger les compteurs
      print('Loading user meters...');
      await _loadUserMeters();
    } catch (e) {
      print('Error loading user data: $e');
      setState(() {
        _errorMessage = 'Error loading data: $e';
        _isLoading = false;
      });
    }
  }

  void _redirectToLogin() {
    if (_redirectingToLogin) return;

    _redirectingToLogin = true;
    Future.delayed(Duration.zero, () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const AuthScreen()),
      );
    });
  }

  Future<void> _loadUserMeters() async {
    try {
      final result = await _meterService.getUserMeters();

      if (result['success'] == true) {
        final meters = result['meters'];
        if (meters != null && meters is List) {
          setState(() {
            _userMeters = List<Map<String, dynamic>>.from(meters);
            _isLoading = false;
          });
          print('Loaded ${_userMeters.length} meters');
        } else {
          print('No meters data or invalid format');
          setState(() {
            _isLoading = false;
          });
        }
      } else {
        print('Error loading meters: ${result['message']}');
        // Si l'erreur est due à un token invalide, rediriger vers login
        if (result['message']?.toString().toLowerCase().contains('token') ??
            false) {
          _redirectToLogin();
        } else {
          setState(() {
            _errorMessage = result['message'] ?? 'Failed to load meters';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('Error in loadUserMeters: $e');
      setState(() {
        _errorMessage = 'Meters loading error: $e';
        _isLoading = false;
      });
    }
  }

  void _navigateToCreateInvoice(BuildContext context) {
    if (_authToken == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Authentication required. Please login again.'),
          backgroundColor: Colors.red,
        ),
      );
      _redirectToLogin();
      return;
    }

    if (_userMeters.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No meters available. Please add a meter first.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateInvoicePage(
          userName: _userName ?? 'Unknown',
          userEmail: _userEmail ?? 'Unknown',
          userPhone: _userPhone ?? 'Unknown',
          authToken: _authToken!,
          userMeters: _userMeters,
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 64),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'Unknown error occurred',
              style: const TextStyle(color: Colors.white, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _errorMessage = null;
                });
                _loadUserData();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                _redirectToLogin();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Login Again'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Si on est en train de rediriger vers le login, afficher un écran vide
    if (_redirectingToLogin) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A0A0A),
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
          ),
        ),
      );
    }

    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A0A0A),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
              ),
              SizedBox(height: 16),
              Text('Loading...', style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0A0A0A),
        body: _buildErrorWidget(),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: RefreshIndicator(
        onRefresh: _loadUserData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              _buildHeaderSection(),
              _buildQuickActions(context),
              _buildRecentActivitySection(),
              // _buildStatisticsSection(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
      // bottomNavigationBar: _buildBottomNavigationBar(context),
    );
  }

  // ... [Gardez toutes vos méthodes _buildHeaderSection, _buildQuickActions, etc. intactes] ...
  // VOUS POUVEZ COPIER-COLLER TOUTES VOS METHODES EXISTANTES ICI

  Widget _buildHeaderSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.blue.shade900.withOpacity(0.3),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 40),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome back,',
                    style: TextStyle(color: Colors.grey.shade300, fontSize: 16),
                  ),
                  Text(
                    _userName ?? "Guest",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => ProfilePage()),
                  );
                },
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.blue.shade700,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(
                    Icons.person,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildConsumptionCard(),
        ],
      ),
    );
  }

  Widget _buildConsumptionCard() {
    if (_isLoadingConsumption) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.blue.shade800.withOpacity(0.6),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Row(
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(width: 16),
            Text(
              'Loading consumption...',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade800.withOpacity(0.6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // Affichage pour un seul compteur
          if (_meterConsumptions.length == 1)
            _buildSingleMeterConsumption(_meterConsumptions[0]),

          // Affichage pour plusieurs compteurs
          if (_meterConsumptions.length > 1) _buildMultipleMetersConsumption(),

          // Aucun compteur
          if (_meterConsumptions.isEmpty) _buildNoMetersConsumption(),
        ],
      ),
    );
  }

  Widget _buildSingleMeterConsumption(Map<String, dynamic> consumption) {
    final double consumptionValue =
        (consumption['cumulative_consumption'] as num).toDouble();

    return Row(
      children: [
        const Icon(Icons.gas_meter, color: Colors.white, size: 32),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${consumption['meter_name']} Consumption',
                style: TextStyle(color: Colors.grey.shade300, fontSize: 14),
              ),
              Text(
                '${consumptionValue.toStringAsFixed(2)} kWh',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            'Meter',
            style: TextStyle(
              color: Colors.green.shade300,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMultipleMetersConsumption() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.gas_meter, color: Colors.white, size: 32),
            SizedBox(width: 16),
            Text(
              'Total Consumption',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '${_totalConsumption.toStringAsFixed(2)} kWh',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Across ${_meterConsumptions.length} meters',
          style: TextStyle(color: Colors.grey.shade300, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildNoMetersConsumption() {
    return const Row(
      children: [
        Icon(Icons.gas_meter, color: Colors.white, size: 32),
        SizedBox(width: 16),
        Text(
          'No meters available',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    final quickActions = [
      {
        'icon': Icons.receipt,
        'title': 'Invoices',
        'color': Colors.blue,
        'onTap': () {
          _leading(context);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => InvoicePage()),
          );
        },
      },
      {
        'icon': Icons.add_circle,
        'title': 'Create Invoice',
        'color': Colors.green,
        'onTap': () => _navigateToCreateInvoice(context),
      },
      {
        'icon': Icons.payment,
        'title': 'Payments',
        'color': Colors.orange,
        'onTap': () {
          _leading(context);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => PaymentHistoryPage()),
          );
        },
      },
      {
        'icon': Icons.analytics,
        'title': 'Reports',
        'color': Colors.purple,
        'onTap': () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => ReportsPage()),
          );
        },
      },
      {
        'icon': Icons.bolt,
        'title': 'Energy Usage',
        'color': Colors.red,
        'onTap': () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => EnergyUsagePage()),
          );
        },
      },
      {
        'icon': Icons.settings,
        'title': 'Settings',
        'color': Colors.grey,
        'onTap': () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => SettingsPage()),
          );
        },
      },
    ];

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick Actions',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.9,
            ),
            itemCount: quickActions.length,
            itemBuilder: (context, index) {
              final action = quickActions[index];
              return _buildActionCard(action);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(Map<String, dynamic> action) {
    final isCreateInvoice = action['title'] == 'Create Invoice';

    return GestureDetector(
      onTap: action['onTap'],
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: action['color'].withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(action['icon'], color: action['color'], size: 28),
            ),
            const SizedBox(height: 12),
            Text(
              action['title'],
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            if (isCreateInvoice && _userMeters.isEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'No meters',
                style: TextStyle(color: Colors.red.shade300, fontSize: 10),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivitySection() {
    final recentActivities = [
      {
        'type': 'Payment',
        'amount': '+ \$1,250.00',
        'time': '2 hours ago',
        'icon': Icons.arrow_downward,
        'color': Colors.green,
      },
      {
        'type': 'Invoice',
        'amount': '- \$980.00',
        'time': '1 day ago',
        'icon': Icons.arrow_upward,
        'color': Colors.blue,
      },
      {
        'type': 'Payment',
        'amount': '+ \$2,100.00',
        'time': '2 days ago',
        'icon': Icons.arrow_downward,
        'color': Colors.green,
      },
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recent Activity',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ...recentActivities.map((activity) => _buildActivityItem(activity)),
        ],
      ),
    );
  }

  Widget _buildActivityItem(Map<String, dynamic> activity) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: activity['color'].withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(activity['icon'], color: activity['color'], size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity['type'],
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  activity['time'],
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            activity['amount'],
            style: TextStyle(
              color: activity['color'],
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsSection() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Statistics',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  title: 'Total Invoices',
                  value: '24',
                  icon: Icons.receipt,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  title: 'Pending',
                  value: '3',
                  icon: Icons.pending,
                  color: Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  title: 'Paid',
                  value: '21',
                  icon: Icons.check_circle,
                  color: Colors.green,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  title: 'Revenue',
                  value: '\$45.2K',
                  icon: Icons.attach_money,
                  color: Colors.purple,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
          ),
        ],
      ),
    );
  }

  //Widget _buildBottomNavigationBar(BuildContext context) {
  //  return Container(
  //    decoration: BoxDecoration(
  //      color: const Color(0xFF1A1A1A),
  //      boxShadow: [
  //        BoxShadow(
  //          color: Colors.black.withOpacity(0.3),
  //          blurRadius: 10,
  //          offset: const Offset(0, -2),
  //        ),
  //      ],
  //    ),
  //    child: BottomNavigationBar(
  //      backgroundColor: Colors.transparent,
  //      elevation: 0,
  //      selectedItemColor: Colors.blue,
  //      unselectedItemColor: Colors.grey,
  //      currentIndex: _currentIndex,
  //      onTap: (index) {
  //        setState(() {
  //          _currentIndex = index;
  //        });
  //        switch (index) {
  //          case 0:
  //            break;
  //          case 1:
  //            Navigator.push(
  //              context,
  //              MaterialPageRoute(builder: (context) => PaymentHistoryPage()),
  //            );
  //            break;
  //          case 2:
  //            Navigator.push(
  //              context,
  //              MaterialPageRoute(builder: (context) => InvoicePage()),
  //            );
  //            break;
  //          case 3:
  //            Navigator.push(
  //              context,
  //              MaterialPageRoute(builder: (context) => ProfilePage()),
  //            );
  //            break;
  //        }
  //      },
  //      items: const [
  //        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
  //        BottomNavigationBarItem(icon: Icon(Icons.receipt), label: 'Invoices'),
  //        BottomNavigationBarItem(icon: Icon(Icons.payment), label: 'Payments'),
  //        BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
  //      ],
  //    ),
  //  );
  //}
  //
  void _leading(BuildContext context) {
    if (_authToken == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Authentication required. Please login again.'),
          backgroundColor: Colors.red,
        ),
      );
      _redirectToLogin();
      return;
    }
  }
}
