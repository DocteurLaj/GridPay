import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:gridpay/pages/auth/login.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthService {
  static const String baseUrl = "http://10.0.2.2:5000";
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email, 'password': password}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Stocker les données de base
        await _storage.write(key: 'token', value: data['token']);
        await _storage.write(key: 'user_id', value: data['user_id'].toString());
        await _storage.write(key: 'email', value: data['email']);

        // Stocker les données supplémentaires SI elles existent dans la réponse
        if (data['name'] != null) {
          await _storage.write(key: 'name', value: data['name']);
        }
        if (data['created_at'] != null) {
          await _storage.write(key: 'created_at', value: data['created_at']);
        }
        if (data['phone'] != null) {
          await _storage.write(key: 'phone', value: data['phone']);
        }

        return {'success': true, 'message': 'Connexion réussie'};
      } else {
        final error = json.decode(response.body);
        return {'success': false, 'message': error['message']};
      }
    } catch (e) {
      return {'success': false, 'message': 'Erreur de connexion: $e'};
    }
  }

  Future<Map<String, dynamic>> register(
    String email,
    String password,
    String phone,
    String name,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/register'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': email,
          'password': password,
          'phone': phone,
          'name': name,
        }),
      );

      if (response.statusCode == 201) {
        // Après l'inscription, vous pouvez aussi stocker les données
        final data = json.decode(response.body);
        if (data['name'] != null) {
          await _storage.write(key: 'name', value: data['name']);
        }
        if (data['phone'] != null) {
          await _storage.write(key: 'phone', value: data['phone']);
        }

        return {'success': true, 'message': 'Inscription réussie'};
      } else {
        final error = json.decode(response.body);
        return {'success': false, 'message': error['message']};
      }
    } catch (e) {
      return {'success': false, 'message': 'Erreur d\'inscription: $e'};
    }
  }

  Future<String?> getToken() async {
    return await _storage.read(key: 'token');
  }

  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null;
  }

  Future<void> logout(BuildContext context) async {
    await _storage.deleteAll();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const AuthScreen()),
    );
  }

  Future<String?> getUserId() async {
    return await _storage.read(key: 'user_id');
  }

  Future<String?> getEmail() async {
    return await _storage.read(key: 'email');
  }

  Future<String?> getName() async {
    return await _storage.read(key: 'name');
  }

  Future<String?> getPhone() async {
    return await _storage.read(key: 'phone');
  }

  Future<String?> getUserCreatedAt() async {
    return await _storage.read(
      key: 'created_at',
    ); // Correction du nom de la clé
  }
}
