import 'dart:convert';
import 'package:gridpay/pages/ServiceHTTP/url_config.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class MeterService {
  static const String baseUrl = globalBaseUrl; // "http://10.0.2.2:5000";
  //"https://spidertric.pythonanywhere.com"; // "http://10.0.2.2:5000";
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<Map<String, String>> _getAuthHeaders() async {
    final token = await _storage.read(key: 'token');
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // Récupérer tous les compteurs de l'utilisateur
  Future<Map<String, dynamic>> getUserMeters() async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/meters'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {'success': true, 'meters': data['meters']};
      } else {
        final error = json.decode(response.body);
        return {'success': false, 'message': error['message']};
      }
    } catch (e) {
      return {'success': false, 'message': 'Erreur: $e'};
    }
  }

  // Ajouter un nouveau compteur
  Future<Map<String, dynamic>> addMeter(
    String meterNumber, {
    String meterName = '',
  }) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/meters'),
        headers: headers,
        body: json.encode({
          'meter_number': meterNumber,
          'meter_name': meterName,
        }),
      );

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'message': data['message'],
          'meter': data['meter'],
        };
      } else {
        final error = json.decode(response.body);
        return {'success': false, 'message': error['message']};
      }
    } catch (e) {
      return {'success': false, 'message': 'Erreur: $e'};
    }
  }

  // Modifier un compteur
  Future<Map<String, dynamic>> updateMeter(
    int meterId, {
    String? meterName,
    String? status,
  }) async {
    try {
      final headers = await _getAuthHeaders();
      final Map<String, dynamic> body = {};

      if (meterName != null) body['meter_name'] = meterName;
      if (status != null) body['status'] = status;

      final response = await http.put(
        Uri.parse('$baseUrl/meters/$meterId'),
        headers: headers,
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'message': data['message'],
          'meter': data['meter'],
        };
      } else {
        final error = json.decode(response.body);
        return {'success': false, 'message': error['message']};
      }
    } catch (e) {
      return {'success': false, 'message': 'Erreur: $e'};
    }
  }

  // Supprimer un compteur
  Future<Map<String, dynamic>> deleteMeter(int meterId) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.delete(
        Uri.parse('$baseUrl/meters/$meterId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {'success': true, 'message': data['message']};
      } else {
        final error = json.decode(response.body);
        return {'success': false, 'message': error['message']};
      }
    } catch (e) {
      return {'success': false, 'message': 'Erreur: $e'};
    }
  }

  // Récupérer un compteur spécifique
  Future<Map<String, dynamic>> getMeter(int meterId) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/meters/$meterId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {'success': true, 'meter': data['meter']};
      } else {
        final error = json.decode(response.body);
        return {'success': false, 'message': error['message']};
      }
    } catch (e) {
      return {'success': false, 'message': 'Erreur: $e'};
    }
  }
}
