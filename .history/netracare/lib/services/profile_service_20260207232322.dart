import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/user_model.dart';
import '../config/api_config.dart';
import 'api_service.dart';

/// Service for handling profile-related API calls
class ProfileService {
  /// Update user profile with extended fields
  static Future<User> updateProfile({
    String? name,
    String? email,
    int? age,
    String? sex,
    String? phone,
    String? address,
    String? emergencyContact,
    String? medicalHistory,
    String? profileImageUrl,
  }) async {
    final token = await ApiService.getToken();

    if (token == null || token.isEmpty) {
      throw Exception('Session expired. Please login again.');
    }

    final Map<String, dynamic> body = {};
    if (name != null) body['name'] = name;
    if (email != null) body['email'] = email;
    if (age != null) body['age'] = age;
    if (sex != null) body['sex'] = sex;
    if (phone != null) body['phone'] = phone;
    if (address != null) body['address'] = address;
    if (emergencyContact != null) body['emergency_contact'] = emergencyContact;
    if (medicalHistory != null) body['medical_history'] = medicalHistory;
    if (profileImageUrl != null) body['profile_image_url'] = profileImageUrl;

    final response = await http.put(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.profileEndpoint}'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return User.fromJson(data['user'] as Map<String, dynamic>);
    }

    if (response.statusCode == 401) {
      await ApiService.deleteToken();
      throw Exception('Session expired. Please login again.');
    }

    throw Exception(_getErrorMessage(response));
  }

  /// Upload profile image
  static Future<String> uploadProfileImage(File imageFile) async {
    final token = await ApiService.getToken();

    if (token == null || token.isEmpty) {
      throw Exception('Session expired. Please login again.');
    }

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${ApiConfig.baseUrl}/user/profile/image'),
    );

    request.headers['Authorization'] = 'Bearer $token';
    request.files.add(
      await http.MultipartFile.fromPath('profile_image', imageFile.path),
    );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['image_url'] as String;
    }

    if (response.statusCode == 401) {
      await ApiService.deleteToken();
      throw Exception('Session expired. Please login again.');
    }

    throw Exception(_getErrorMessage(response));
  }

  /// Get profile information
  static Future<User> getProfile() async {
    return await ApiService.getProfile();
  }

  /// Extract error message from response
  static String _getErrorMessage(http.Response response) {
    try {
      final data = jsonDecode(response.body);
      if (data is Map && data.containsKey('error')) {
        return data['error'].toString();
      }
      if (data is Map && data.containsKey('message')) {
        return data['message'].toString();
      }
      return 'Failed to update profile (${response.statusCode})';
    } catch (_) {
      return 'Failed to update profile (${response.statusCode})';
    }
  }
}
