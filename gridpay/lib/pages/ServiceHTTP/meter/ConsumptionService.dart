// lib/pages/ServiceHTTP/consumption/consumption_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:gridpay/pages/auth/authService.dart';

class ConsumptionService {
  final AuthService _authService = AuthService();
  static const String _baseUrl =
      'http://10.0.2.2:5000'; // Remplacez par votre URL

  // Récupérer la consommation cumulative pour un compteur spécifique
  Future<Map<String, dynamic>> getCumulativeConsumption(
    String meterNumber,
  ) async {
    try {
      final token = await _authService.getToken();

      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final response = await http.get(
        Uri.parse('$_baseUrl/api/meters/$meterNumber/cumulative_consumption'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {'success': true, 'data': data};
      } else {
        return {
          'success': false,
          'message': 'Failed to load consumption data: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  // Récupérer la consommation pour tous les compteurs de l'utilisateur
  Future<Map<String, dynamic>> getAllCumulativeConsumptions() async {
    try {
      final token = await _authService.getToken();

      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      // D'abord récupérer tous les compteurs
      final metersResponse = await http.get(
        Uri.parse('$_baseUrl/meters'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (metersResponse.statusCode != 200) {
        return {'success': false, 'message': 'Failed to load meters'};
      }

      final metersData = json.decode(metersResponse.body);
      final List<dynamic> meters = metersData['meters'] ?? [];

      // Pour chaque compteur, récupérer la consommation cumulative
      final List<Map<String, dynamic>> consumptions = [];

      for (var meter in meters) {
        final meterNumber = meter['meter_number'];
        final consumptionResponse = await getCumulativeConsumption(meterNumber);

        if (consumptionResponse['success'] == true) {
          consumptions.add({
            'meter_number': meterNumber,
            'meter_name': meter['meter_name'],
            'cumulative_consumption':
                consumptionResponse['data']['cumulative_consumption'],
          });
        }
      }

      return {
        'success': true,
        'data': consumptions,
        'total_consumption': _calculateTotalConsumption(consumptions),
      };
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  double _calculateTotalConsumption(List<Map<String, dynamic>> consumptions) {
    double total = 0.0;
    for (var consumption in consumptions) {
      total += (consumption['cumulative_consumption'] as num).toDouble();
    }
    return total;
  }
}
