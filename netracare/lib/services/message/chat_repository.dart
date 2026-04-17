import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config/api_config.dart';
import '../../models/consultation/chat_message_model.dart';
import '../doctor_api_service.dart';

class ChatRepository {
  Future<String?> _token({required bool isDoctor}) async {
    if (isDoctor) {
      return DoctorApiService.getDoctorToken();
    }
    return DoctorApiService.getToken();
  }

  Future<Map<String, String>> _headers({required bool isDoctor}) async {
    final token = await _token(isDoctor: isDoctor);
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<int> createOrFetchRoom({
    required bool isDoctor,
    int? consultationId,
    int? doctorId,
    int? patientId,
  }) async {
    final headers = await _headers(isDoctor: isDoctor);

    final body = <String, dynamic>{
      if (consultationId != null) 'consultation_id': consultationId,
      if (!isDoctor && doctorId != null) 'doctor_id': doctorId,
      if (isDoctor && patientId != null) 'patient_id': patientId,
    };

    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/chat/rooms'),
      headers: headers,
      body: jsonEncode(body),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Unable to create/fetch room');
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final room = payload['room'] as Map<String, dynamic>? ?? {};
    final resolvedId = room['consultation_id'];
    if (resolvedId == null) {
      throw Exception('Missing consultation_id in room response');
    }

    return int.parse(resolvedId.toString());
  }

  Future<List<ChatMessage>> loadHistory({
    required bool isDoctor,
    required int consultationId,
  }) async {
    final headers = await _headers(isDoctor: isDoctor);
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/chat/rooms/$consultationId/messages'),
      headers: headers,
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Unable to load messages');
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final rows = List<Map<String, dynamic>>.from(
      payload['messages'] ?? const [],
    );
    return rows.map(ChatMessage.fromJson).toList();
  }

  Future<ChatMessage> sendFallback({
    required bool isDoctor,
    required int consultationId,
    required String content,
  }) async {
    final response = isDoctor
        ? await DoctorApiService.sendDoctorMessage(
            consultationId: consultationId.toString(),
            message: content,
          )
        : await DoctorApiService.sendPatientMessage(
            consultationId: consultationId.toString(),
            message: content,
          );

    return ChatMessage.fromJson(response);
  }

  Future<String?> getSocketToken({required bool isDoctor}) {
    return _token(isDoctor: isDoctor);
  }
}
