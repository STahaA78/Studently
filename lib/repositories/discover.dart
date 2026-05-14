import 'dart:convert';
import 'package:studently/logger.dart';
import 'package:studently/models/user.dart';
import 'package:studently/repositories/user.dart';
import 'package:studently/services/api.dart';

class DiscoverRepository {
  final ApiService _apiService = ApiService();
  final UserRepository _userRepository;

  DiscoverRepository({UserRepository? userRepository})
      : _userRepository = userRepository ?? UserRepository();

  Future<List<User>> discoverUsers() async {
    logger.i('[DiscoverRepository] Discover Users Initiated');
    try {
      final response = await _apiService.get('/users/discover');
      final List<dynamic> data = jsonDecode(response.body);
      logger.d('[DiscoverRepository] Raw API Response: $data');
      logger.i('[DiscoverRepository] Discover Users Completed Successfully');
      return data.map((item) => User.fromJson(item)).toList();
    } catch (e) {
      logger.e('[DiscoverRepository] Discover Users Failed with error: $e');
      rethrow;
    }
  }

  Future<List<User>> searchUsers(String query) async {
    logger.i('[DiscoverRepository] Search Users Initiated for query: $query');
    try {
      final response = await _apiService.get('/users/search/?query=$query');
      final List<dynamic> data = jsonDecode(response.body);
      logger.d('[DiscoverRepository] Fetched ${data.length} users from API');
      logger.i('[DiscoverRepository] Search Users Completed Successfully');
      return data.map((item) => User.fromJson(item)).toList();
    } catch (e) {
      logger.e('[DiscoverRepository] Search Users Failed with error: $e');
      rethrow;
    }
  }

  Future<Map<String, String>> fetchConnectionStatuses(
    List<String> targetIds,
  ) async {
    logger.i(
      '[DiscoverRepository] Fetch Connection Statuses Initiated for ${targetIds.length} targets',
    );
    try {
      final response = await _apiService.post(
        '/users/0/status',
        body: {'target_ids': targetIds},
      );
      final List<dynamic> data = jsonDecode(response.body);
      final Map<String, String> statusMap = {};

      for (var item in data) {
        final friendStatus = FriendStatus.fromJson(item);
        if (friendStatus.status != 'error') {
          statusMap[friendStatus.id] = friendStatus.status;
        }
      }

      logger.i(
        '[DiscoverRepository] Fetch Connection Statuses Completed Successfully',
      );
      return statusMap;
    } catch (e) {
      logger.e(
        '[DiscoverRepository] Fetch Connection Statuses Failed with error: $e',
      );
      rethrow;
    }
  }

  Future<List<User>> fetchPendingRequests() async {
    logger.i('[DiscoverRepository] Fetch Pending Requests Initiated');
    try {
      final response = await _apiService.get('/users/0/requests');
      final List<dynamic> data = jsonDecode(response.body);
      logger.i('[DiscoverRepository] Fetch Pending Requests Completed Successfully');
      return data.map((item) => User.fromJson(item)).toList();
    } catch (e) {
      logger.e('[DiscoverRepository] Fetch Pending Requests Failed with error: $e');
      rethrow;
    }
  }

  Future<void> sendConnectionRequest(String targetId) async {
    await _userRepository.sendConnectionRequest(targetId);
  }

  Future<void> cancelConnectionRequest(String targetId) async {
    await _userRepository.cancelConnectionRequest(targetId);
  }
}
