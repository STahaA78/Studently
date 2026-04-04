import 'dart:convert';
import 'package:studently/models/user.dart';
import 'package:studently/models/backend_config.dart';
import 'package:studently/services/api.dart';
import 'package:studently/logger.dart';
import 'dart:io';

class UserRepository {
  final ApiService _apiService = ApiService();
	/// Registers a new user in the backend database.
	/// Returns true if registration is successful, false otherwise.
	Future<bool> registerUser({
		required String uid,
		required String name,
		required String email,
		required String birthday,
		required String department,
		required String batch,
		required List<Interest> interests,
	}) async {
		logger.i("[$runtimeType] Register User Initiated for email: $email");
		final Map<String, dynamic> payload = {
			"uid": uid,
			"name": name,
			"email": email,
			"birthday": birthday,
			"department": department,
			"batch": batch,
			"interests": interests.map((e) => e.toJson()).toList(),
		};
		try {
			final response = await _apiService.post(
				'/users/register',
				body: payload,
			);
			if (response.statusCode == 201 || response.statusCode == 200) {
				logger.i("[$runtimeType] Register User Completed Successfully");
				return true;
			} else {
				logger.e("[$runtimeType] Register User Failed: ${response.body}");
				return false;
			}
		} catch (e) {
			logger.e("[$runtimeType] Register User Exception: $e");
			return false;
		}
	}
	// Fetch User Profile for Profile Page and User Requests
	//(userId is optional, defaults to "0" for logged in user)

	Future<User> fetchUserProfile(String userId) async {
		logger.i("[$runtimeType] Fetch User Profile Initiated for userId: $userId");
		try {
			final response = await _apiService.get('/users/$userId/profile');
			final data = jsonDecode(response.body);
      logger.d( "[$runtimeType] Raw API Response: $data");
			logger.i("[$runtimeType] Fetch User Profile Completed Successfully");
			return User.fromJson(data);
		} catch (e) {
			logger.e("[$runtimeType] Fetch User Profile Failed with error: $e");
			rethrow;
		}
	}
	// Profile Update for Logged in User
	Future<User> updateUserProfile(Map<String, dynamic> updatedData) async {
		logger.i("[$runtimeType] Update User Profile Initiated");
		try {
			final response = await _apiService.patch('/users/0/update', body: updatedData);
			final data = jsonDecode(response.body);
			logger.i("[$runtimeType] Update User Profile Completed Successfully");
			return User.fromJson(data);
		} catch (e) {
			logger.e("[$runtimeType] Update User Profile Failed with error: $e");
			rethrow;
		}
	}

	Future<List<User>> fetchPendingRequests() async {
		logger.i("[$runtimeType] Fetch Pending Requests Initiated");
		try {
		final response = await _apiService.get('/users/0/requests');
		final List<dynamic> data = jsonDecode(response.body);
		logger.i("[$runtimeType] Fetch Pending Requests Completed Successfully");
		return data.map((item) => User.fromJson(item)).toList();
		} catch (e) {
		logger.e("[$runtimeType] Fetch Pending Requests Failed with error: $e");
		rethrow;
		}
	}

	Future<void> respondRequest(String requesterId, String action) async {
		logger.i("[$runtimeType] Respond Request Initiated for requesterId: $requesterId, action: $action");
		try {
		await _apiService.post('/users/0/respond', body: {
			'requester_id': requesterId,
			'action': action,
		});
		logger.i("[$runtimeType] Respond Request Completed Successfully");
		} catch (e) {
		logger.e("[$runtimeType] Respond Request Failed with error: $e");
		rethrow;
		}
	}

	Future<void> unfriendUser(String friendId) async {
		logger.i("[$runtimeType] Unfriend User Initiated for friendId: $friendId");
		try {
			await _apiService.post('/users/0/unfriend', body: {
				'friend_id': friendId,
			});
			logger.i("[$runtimeType] Unfriend User Completed Successfully");
		} catch (e) {
			logger.e("[$runtimeType] Unfriend User Failed with error: $e");
			rethrow;
		}
	}

	Future<List<User>> discoverUsers() async {
		logger.i("[$runtimeType] Discover Users Initiated");
		try {
			final response = await _apiService.get('/users/discover');
			final List<dynamic> data = jsonDecode(response.body);
			logger.d("[$runtimeType] Raw API Response: $data");
			//logger.d("[$runtimeType] Fetched ${data.length} users from API");
			logger.i("[$runtimeType] Discover Users Completed Successfully");
			return data.map((item) => User.fromJson(item)).toList();
		} catch (e) {
			logger.e("[$runtimeType] Discover Users Failed with error: $e");
			rethrow;
		}
	}

	Future<List<User>> searchUsers(String query) async {
		logger.i("[$runtimeType] Search Users Initiated for query: $query");
		try {
			final response = await _apiService.get('/users/search/?query=$query');
			final List<dynamic> data = jsonDecode(response.body);
			logger.d("[$runtimeType] Fetched ${data.length} users from API");
			logger.i("[$runtimeType] Search Users Completed Successfully");
			return data
				.map((item) => User.fromJson(item)).toList();
		} catch (e) {
			logger.e("[$runtimeType] Search Users Failed with error: $e");
			rethrow;
		}
	}

	Future<Map<String, String>> fetchConnectionStatuses(List<String> targetIds) async {
		logger.i("[$runtimeType] Fetch Connection Statuses Initiated for ${targetIds.length} targets");
		try {
			final response = await _apiService.post(
				'/users/0/status',
				body: {"target_ids": targetIds},
			);
			final List<dynamic> data = jsonDecode(response.body);
			final Map<String, String> statusMap = {};
			
			for (var item in data) {
				final friendStatus = FriendStatus.fromJson(item);
				// Filter out "error" status - these users should not be displayed
				if (friendStatus.status != "error") {
					statusMap[friendStatus.id] = friendStatus.status;
				}
			}
			
			logger.i("[$runtimeType] Fetch Connection Statuses Completed Successfully");
			return statusMap;
		} catch (e) {
			logger.e("[$runtimeType] Fetch Connection Statuses Failed with error: $e");
			rethrow;
		}
	}

	// Single fetch wrapper for backward compatibility
	Future<String> fetchConnectionStatus(String targetId) async {
		logger.i("[$runtimeType] Fetch Connection Status Initiated for targetId: $targetId");
		try {
			final statuses = await fetchConnectionStatuses([targetId]);
			logger.i("[$runtimeType] Fetch Connection Status Completed Successfully");
			return statuses[targetId] ?? "error";
		} catch (e) {
			logger.e("[$runtimeType] Fetch Connection Status Failed with error: $e");
			rethrow;
		}
	}

	Future<void> sendConnectionRequest(String targetId) async {
		logger.i("[$runtimeType] Send Connection Request Initiated for targetId: $targetId");
		try {
			await _apiService.post('/users/0/request?target_id=$targetId');
			logger.i("[$runtimeType] Send Connection Request Completed Successfully");
		} catch (e) {
			logger.e("[$runtimeType] Send Connection Request Failed with error: $e");
			rethrow;
		}
	}

	Future<void> cancelConnectionRequest(String targetId) async {
		logger.i("[$runtimeType] Cancel Connection Request Initiated for targetId: $targetId");
		try {
			await _apiService.post('/users/0/cancel-request?target_id=$targetId');
			logger.i("[$runtimeType] Cancel Connection Request Completed Successfully");
		} catch (e) {
			logger.e("[$runtimeType] Cancel Connection Request Failed with error: $e");
			rethrow;
		}
	}

	Future<int> fetchPendingRequestsCount() async {
		logger.i("[$runtimeType] Fetch Pending Requests Count Initiated");
		try {
			final response = await _apiService.get('/users/0/requests');
			final List<dynamic> data = jsonDecode(response.body);
			logger.i("[$runtimeType] Fetch Pending Requests Count Completed Successfully");
			return data.length;
		} catch (e) {
			logger.e("[$runtimeType] Fetch Pending Requests Count Failed with error: $e");
			rethrow;
		}
	}
  
	// Upload profile photo using ApiService.multiPart
	Future<void> uploadProfilePhoto(String filePath) async {
		logger.i("[$runtimeType] Upload Profile Photo Initiated");
		try {
		await ApiService().multiPart(
			file: File(filePath),
			metadata: {"userId": "0"},
		);
		logger.i("[$runtimeType] Upload Profile Photo Completed Successfully");
		} catch (e) {
		logger.e("[$runtimeType] Upload Profile Photo Failed with error: $e");
		rethrow;
		}
	}

  // Remove profile photo
  Future<void> removeProfilePhoto() async {
    logger.i("[$runtimeType] Remove Profile Photo Initiated");
    try {
      await _apiService.post('/users/0/profile/photo/remove');
      logger.i("[$runtimeType] Remove Profile Photo Completed Successfully");
    } catch (e) {
      logger.e("[$runtimeType] Remove Profile Photo Failed with error: $e");
      rethrow;
    }
  }

  Future<List<Map<String, String>>> getFriendsList() async {
    final response = await _apiService.get('/users/0/friends_list');
    final List<dynamic> data = jsonDecode(response.body);
    return data.map((f) => {
      "id": f['_id'].toString(),
      "Name": f['name'].toString()
    }).toList();
  }
}
