import 'dart:convert';
import 'package:studently/models/user.dart';
import 'package:studently/services/api.dart';
import 'package:studently/logger.dart';

class UserRepository {
		Future<User> fetchUserProfile(String userId) async {
			logger.i("[$runtimeType] Fetch User Profile Initiated for userId: $userId");
			try {
				final response = await _apiService.get('/profile/$userId');
				final data = jsonDecode(response.body);
				logger.i("[$runtimeType] Fetch User Profile Completed Successfully");
				return User.fromJson(data);
			} catch (e) {
				logger.e("[$runtimeType] Fetch User Profile Failed with error: $e");
				rethrow;
			}
		}

		Future<List<User>> fetchPendingRequests(String currentUserId) async {
			logger.i("[$runtimeType] Fetch Pending Requests Initiated");
			try {
				final response = await _apiService.get('/profile/$currentUserId/requests');
				final List<dynamic> data = jsonDecode(response.body);
				logger.i("[$runtimeType] Fetch Pending Requests Completed Successfully");
				return data.map((item) => User.fromJson(item)).toList();
			} catch (e) {
				logger.e("[$runtimeType] Fetch Pending Requests Failed with error: $e");
				rethrow;
			}
		}

		Future<void> respondRequest(String currentUserId, String requesterId, String action) async {
			logger.i("[$runtimeType] Respond Request Initiated for requesterId: $requesterId, action: $action");
			try {
				await _apiService.post('/profile/$currentUserId/respond', body: {
					'requester_id': requesterId,
					'action': action,
				});
				logger.i("[$runtimeType] Respond Request Completed Successfully");
			} catch (e) {
				logger.e("[$runtimeType] Respond Request Failed with error: $e");
				rethrow;
			}
		}

		Future<void> unfriendUser(String currentUserId, String friendId) async {
			logger.i("[$runtimeType] Unfriend User Initiated for friendId: $friendId");
			try {
				await _apiService.post('/profile/$currentUserId/unfriend', body: {
					'friend_id': friendId,
				});
				logger.i("[$runtimeType] Unfriend User Completed Successfully");
			} catch (e) {
				logger.e("[$runtimeType] Unfriend User Failed with error: $e");
				rethrow;
			}
		}
	final ApiService _apiService = ApiService();

	Future<List<User>> discoverUsers(String currentUserId) async {
		logger.i("[$runtimeType] Discover Users Initiated");
		try {
			final response = await _apiService.get('/profile/discover');
			final List<dynamic> data = jsonDecode(response.body);
			logger.d("[$runtimeType] Fetched ${data.length} users from API");
			logger.i("[$runtimeType] Discover Users Completed Successfully");
			return data
				.map((item) => User.fromJson(item))
				.where((u) => u.id != currentUserId)
				.toList();
		} catch (e) {
			logger.e("[$runtimeType] Discover Users Failed with error: $e");
			rethrow;
		}
	}

	Future<List<User>> searchUsers(String query, String currentUserId) async {
		logger.i("[$runtimeType] Search Users Initiated for query: $query");
		try {
			final response = await _apiService.get('/profile/search/?query=$query');
			final List<dynamic> data = jsonDecode(response.body);
			logger.d("[$runtimeType] Fetched ${data.length} users from API");
			logger.i("[$runtimeType] Search Users Completed Successfully");
			return data
				.map((item) => User.fromJson(item))
				.where((u) => u.id != currentUserId)
				.toList();
		} catch (e) {
			logger.e("[$runtimeType] Search Users Failed with error: $e");
			rethrow;
		}
	}

	Future<String> fetchConnectionStatus(String currentUserId, String targetId) async {
		logger.i("[$runtimeType] Fetch Connection Status Initiated for targetId: $targetId");
		try {
			final response = await _apiService.get('/profile/status?user_id=$currentUserId&target_id=$targetId');
			final data = jsonDecode(response.body);
			logger.i("[$runtimeType] Fetch Connection Status Completed Successfully");
			return data["status"];
		} catch (e) {
			logger.e("[$runtimeType] Fetch Connection Status Failed with error: $e");
			rethrow;
		}
	}

	Future<void> sendConnectionRequest(String currentUserId, String targetId) async {
		logger.i("[$runtimeType] Send Connection Request Initiated for targetId: $targetId");
		try {
			await _apiService.post('/profile/$currentUserId/request?target_id=$targetId');
			logger.i("[$runtimeType] Send Connection Request Completed Successfully");
		} catch (e) {
			logger.e("[$runtimeType] Send Connection Request Failed with error: $e");
			rethrow;
		}
	}

	Future<void> cancelConnectionRequest(String currentUserId, String targetId) async {
		logger.i("[$runtimeType] Cancel Connection Request Initiated for targetId: $targetId");
		try {
			await _apiService.post('/profile/$currentUserId/cancel-request?target_id=$targetId');
			logger.i("[$runtimeType] Cancel Connection Request Completed Successfully");
		} catch (e) {
			logger.e("[$runtimeType] Cancel Connection Request Failed with error: $e");
			rethrow;
		}
	}

	Future<int> fetchPendingRequestsCount(String currentUserId) async {
		logger.i("[$runtimeType] Fetch Pending Requests Count Initiated");
		try {
			final response = await _apiService.get('/profile/$currentUserId/requests');
			final List<dynamic> data = jsonDecode(response.body);
			logger.i("[$runtimeType] Fetch Pending Requests Count Completed Successfully");
			return data.length;
		} catch (e) {
			logger.e("[$runtimeType] Fetch Pending Requests Count Failed with error: $e");
			rethrow;
		}
	}
}
