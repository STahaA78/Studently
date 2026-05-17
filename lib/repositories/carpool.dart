import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studently/services/api.dart';
import 'package:studently/models/ride.dart';
import 'package:studently/logger.dart';

class CarpoolRepository {
  // ========== OFFERS ==========
  Future<List<RideOffer>> getActiveOffers() async {
    final response = await ApiService().get('/rides/offers');
    final List<dynamic> data = jsonDecode(response.body);
    return data.map((r) => RideOffer.fromJson(r)).toList();
  }

  Future<List<RideOffer>> getMyOffers() async {
    final response = await ApiService().get('/rides/offers/mine');
    final List<dynamic> data = jsonDecode(response.body);
    return data.map((r) => RideOffer.fromJson(r)).toList();
  }

  Future<Map<String, dynamic>> createOffer({
    required String campus,
    required String homeLocation,
    required String direction,
    required String vehicleType,
    required List<String> availableDays,
    required int totalSeats,
    required int costPerSeat,
    required String genderPreference,
    required String groupChatName,
    required String departureTime,
  }) async {
    final response = await ApiService().post('/rides/offers', body: {
      'campus': campus,
      'home_location': homeLocation,
      'direction': direction,
      'vehicle_type': vehicleType,
      'available_days': availableDays,
      'total_seats': totalSeats,
      'cost_per_seat': costPerSeat,
      'gender_preference': genderPreference,
      'group_chat_name': groupChatName,
      'departure_time': departureTime,
    });
    final data = jsonDecode(response.body);
    return {
      'offer': RideOffer.fromJson(data),
      'conversation_id': data['conversation_id'],
    };
  }

  Future<void> joinOffer(String offerId) async {
    await ApiService().post('/rides/offers/$offerId/join');
  }

  Future<void> reactivateOffer(String offerId) async {
    await ApiService().post('/rides/offers/$offerId/reactivate');
  }

  Future<void> deactivateOffer(String offerId) async {
    await ApiService().post('/rides/offers/$offerId/deactivate');
  }

  Future<void> deleteOffer(String offerId) async {
    await ApiService().delete('/rides/offers/$offerId');
  }

  // ========== REQUESTS ==========
  Future<List<RideRequest>> getActiveRequests() async {
    final response = await ApiService().get('/rides/requests');
    final List<dynamic> data = jsonDecode(response.body);
    return data.map((r) => RideRequest.fromJson(r)).toList();
  }

  Future<List<RideRequest>> getMyRequests() async {
    final response = await ApiService().get('/rides/requests/mine');
    final List<dynamic> data = jsonDecode(response.body);
    return data.map((r) => RideRequest.fromJson(r)).toList();
  }

  Future<RideRequest> createRequest({
    required String campus,
    required String otherLocation,
    required String direction,
    required String genderPreference,
    required DateTime neededDatetime,
  }) async {
    logger.i('[CarpoolRepository] createRequest neededDatetime local: $neededDatetime, utc: ${neededDatetime.toUtc().toIso8601String()}');
    final response = await ApiService().post('/rides/requests', body: {
      'campus': campus,
      'other_location': otherLocation,
      'direction': direction,
      'gender_preference': genderPreference,
      'needed_datetime': neededDatetime.toUtc().toIso8601String(),
    });
    logger.i('[CarpoolRepository] createRequest response: ${response.body}');
    return RideRequest.fromJson(jsonDecode(response.body));
  }

  Future<Map<String, dynamic>> contactRequester(String requestId) async {
    final response = await ApiService().post('/rides/requests/$requestId/contact');
    final data = jsonDecode(response.body);
    return {
      'conversation_id': data['conversation_id'],
      'requester_id': data['requester_id'],
      'requester_name': data['requester_name'],
    };
  }

  Future<void> deactivateRequest(String requestId) async {
    await ApiService().post('/rides/requests/$requestId/deactivate');
  }

  Future<void> reactivateRequest(String requestId) async {
    await ApiService().post('/rides/requests/$requestId/reactivate');
  }
}

final carpoolRepositoryProvider = Provider<CarpoolRepository>((ref) {
  return CarpoolRepository();
});
