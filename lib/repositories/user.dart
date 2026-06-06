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
    required Department department,
    required String batch,
    required List<Interest> interests,
    String? gender,
    bool extractedFields = true,
  }) async {
    logger.i("[$runtimeType] Register User Initiated for email: $email");
    final Map<String, dynamic> payload = {
      "uid": uid,
      "name": name,
      "email": email,
      "birthday": birthday,
      "department": {"name": department.name, "code": department.code},
      "batch": batch,
      "interests": interests.map((e) => e.toJson()).toList(),
      "gender": gender,
      "extracted_fields": extractedFields,
    };
    try {
      final response = await _apiService.post('/users/register', body: payload);
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

  Future<UserProfileResponse> fetchUserProfile({String userId = "0"}) async {
    logger.i("[$runtimeType] Fetch User Profile Initiated for userId: $userId");
    try {
      final response = await _apiService.get('/users/$userId/profile');
      logger.d(
        "[$runtimeType] Raw Response Status: ${response.statusCode}, Body Length: ${response.body.length}",
      );

      try {
        final data = jsonDecode(response.body);
        logger.d("[$runtimeType] Decoded JSON successfully");
        logger.i("[$runtimeType] Fetch User Profile Completed Successfully");
        return UserProfileResponse.fromJson(data);
      } on FormatException catch (e) {
        final bodyPreview = response.body.length > 200
            ? response.body.substring(0, 200)
            : response.body;
        logger.e("[$runtimeType] JSON Parse Error: $e, Body: $bodyPreview");
        rethrow;
      }
    } catch (e) {
      logger.e("[$runtimeType] Fetch User Profile Failed: $e");
      rethrow;
    }
  }

  // Profile Update for Logged in User
  Future<User> updateUserProfile(Map<String, dynamic> updatedData) async {
    logger.i("[$runtimeType] Update User Profile Initiated");
    try {
      final response = await _apiService.patch(
        '/users/0/update',
        body: updatedData,
      );
      final data = jsonDecode(response.body);
      logger.i("[$runtimeType] Update User Profile Completed Successfully");
      return User.fromJson(data);
    } catch (e) {
      logger.e("[$runtimeType] Update User Profile Failed with error: $e");
      rethrow;
    }
  }

  Future<void> respondRequest(String requesterId, String action) async {
    logger.i(
      "[$runtimeType] Respond Request Initiated for requesterId: $requesterId, action: $action",
    );
    try {
      await _apiService.post(
        '/users/0/respond',
        body: {'requester_id': requesterId, 'action': action},
      );
      logger.i("[$runtimeType] Respond Request Completed Successfully");
    } catch (e) {
      logger.e("[$runtimeType] Respond Request Failed with error: $e");
      rethrow;
    }
  }

  Future<void> unfriendUser(String friendId) async {
    logger.i("[$runtimeType] Unfriend User Initiated for friendId: $friendId");
    try {
      await _apiService.post(
        '/users/0/unfriend',
        body: {'friend_id': friendId},
      );
      logger.i("[$runtimeType] Unfriend User Completed Successfully");
    } catch (e) {
      logger.e("[$runtimeType] Unfriend User Failed with error: $e");
      rethrow;
    }
  }

  // Single fetch wrapper for backward compatibility
  Future<String> fetchConnectionStatus(String targetId) async {
    logger.i(
      "[$runtimeType] Fetch Connection Status Initiated for targetId: $targetId",
    );
    try {
      final response = await _apiService.post(
        '/users/0/status',
        body: {
          "target_ids": [targetId],
        },
      );
      final List<dynamic> data = jsonDecode(response.body);
      if (data.isEmpty) {
        return "error";
      }
      final friendStatus = FriendStatus.fromJson(data.first);
      logger.i("[$runtimeType] Fetch Connection Status Completed Successfully");
      return friendStatus.status;
    } catch (e) {
      logger.e("[$runtimeType] Fetch Connection Status Failed with error: $e");
      rethrow;
    }
  }

  Future<void> sendConnectionRequest(String targetId) async {
    logger.i(
      "[$runtimeType] Send Connection Request Initiated for targetId: $targetId",
    );
    try {
      await _apiService.post('/users/0/request?target_id=$targetId');
      logger.i("[$runtimeType] Send Connection Request Completed Successfully");
    } catch (e) {
      logger.e("[$runtimeType] Send Connection Request Failed with error: $e");
      rethrow;
    }
  }

  Future<void> cancelConnectionRequest(String targetId) async {
    logger.i(
      "[$runtimeType] Cancel Connection Request Initiated for targetId: $targetId",
    );
    try {
      await _apiService.post('/users/0/cancel-request?target_id=$targetId');
      logger.i(
        "[$runtimeType] Cancel Connection Request Completed Successfully",
      );
    } catch (e) {
      logger.e(
        "[$runtimeType] Cancel Connection Request Failed with error: $e",
      );
      rethrow;
    }
  }

  // Upload profile photo (web-compatible with bytes support)
  Future<void> uploadProfilePhoto({
    required String filePath,
    List<int>? fileBytes,
    String? filename,
    Map<String, dynamic>? cropData,
  }) async {
    logger.i("[$runtimeType] Upload Profile Photo Initiated");
    try {
      // Use provided bytes if available (web), otherwise read from file path (native)
      var bytes = fileBytes ?? await File(filePath).readAsBytes();
      final fname = filename ?? filePath.split('/').last;

      // Build metadata with crop data if provided
      final metadata = {"userId": "0"};
      if (cropData != null) {
        metadata['cropData'] = jsonEncode(cropData);
      }

      // No compression for profile photos - backend handles variant generation
      await _apiService.multiPartFromBytes(
        endpoint: '/users/0/profile/photo/add',
        fileBytes: bytes,
        filename: fname,
        metadata: metadata,
        fieldName: 'photo', // Backend expects 'photo' field name
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
    return data
        .map(
          (f) => {
            "id": f['_id']?.toString() ?? f['id']?.toString() ?? "",
            "Name": f['name']?.toString() ?? "",
            "picture": f['picture']?.toString() ?? "",
          },
        )
        .toList();
  }

  Future<bool> submitErrorReport({
    required String subject,
    required String description,
  }) async {
    logger.i("[$runtimeType] Submit Error Report Initiated");
    final payload = {"subject": subject, "description": description};
    try {
      final response = await _apiService.post('/users/0/report', body: payload);
      if (response.statusCode == 200 || response.statusCode == 201) {
        logger.i("[$runtimeType] Submit Error Report Completed Successfully");
        return true;
      } else {
        logger.e("[$runtimeType] Submit Error Report Failed: ${response.body}");
        return false;
      }
    } catch (e) {
      logger.e("[$runtimeType] Submit Error Report Exception: $e");
      return false;
    }
  }
}
