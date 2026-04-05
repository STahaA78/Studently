import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:studently/services/firebase_auth.dart'; 
import '../services/api.dart';

class UserProfilePage extends StatefulWidget {
  final String userId;

  const UserProfilePage({super.key, required this.userId});

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  final Color primaryBlue = const Color(0xFF0F74C5);
  final ApiService api = ApiService();

  /// TEMP logged-in user id
  String get currentUserId => authService.value.currentUser!.uid;
  Map<String, dynamic>? user;
  bool isLoading = true;

  /// none / outgoing_request / incoming_request / friends
  String connectionStatus = "none";
  bool isStatusLoading = true;

  // ---------------- INITIALS ----------------
  String getInitials(String name) {
    if (name.trim().isEmpty) return "?";
    final parts = name.trim().split(RegExp(r"\s+"));
    return parts.map((e) => e[0]).take(2).join().toUpperCase();
  }

  // ---------------- LOAD USER PROFILE ----------------


  Future<void> loadUserProfile() async {
    try {

      final token = await authService.value.getIdToken();

      final uri =
          Uri.parse(api.getCompleteUrl("/profile/${widget.userId}"));

      final response = await http.get(
        uri,
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json"
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          user = json.decode(response.body);
          isLoading = false;
        });
      } else {
        debugPrint("User fetch failed: ${response.body}");
        setState(() => isLoading = false);
      }

    } catch (e) {
      debugPrint("User profile error: $e");
      setState(() => isLoading = false);
    }
  }
  // ---------------- LOAD CONNECTION STATUS ----------------
  Future<void> loadConnectionStatus() async {
    try {
      final uri = Uri.parse(
        "${api.getCompleteUrl('/profile/status')}"
        "?user_id=$currentUserId&target_id=${widget.userId}",
      );

      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          connectionStatus = data["status"];
          isStatusLoading = false;
        });
      }
    } catch (e) {
      setState(() => isStatusLoading = false);
    }
  }

  // ---------------- SEND REQUEST ----------------
  Future<void> sendConnectionRequest() async {
    final uri = Uri.parse(
      "${api.getCompleteUrl('/profile/$currentUserId/request')}"
      "?target_id=${widget.userId}",
    );

    final response = await http.post(uri);
    if (response.statusCode == 200) {
      setState(() => connectionStatus = "outgoing_request");
    }
  }

  // ---------------- CANCEL REQUEST ----------------
  Future<void> cancelConnectionRequest() async {
    final uri = Uri.parse(
      "${api.getCompleteUrl('/profile/$currentUserId/cancel-request')}"
      "?target_id=${widget.userId}",
    );

    final response = await http.post(uri);
    if (response.statusCode == 200) {
      setState(() => connectionStatus = "none");
    }
  }

  // ---------------- ACCEPT REQUEST ----------------
  Future<void> acceptRequest() async {
    final uri = Uri.parse(
      "${api.getCompleteUrl('/profile/$currentUserId/respond')}",
    );

    final response = await http.post(
      uri,
      headers: {"Content-Type": "application/json"},
      body: json.encode({
        "requester_id": widget.userId,
        "action": "accept",
      }),
    );

    if (response.statusCode == 200) {
      setState(() => connectionStatus = "friends");
    }
  }

  // ---------------- REJECT REQUEST ----------------
  Future<void> rejectRequest() async {
    final uri = Uri.parse(
      "${api.getCompleteUrl('/profile/$currentUserId/respond')}",
    );

    final response = await http.post(
      uri,
      headers: {"Content-Type": "application/json"},
      body: json.encode({
        "requester_id": widget.userId,
        "action": "reject",
      }),
    );

    if (response.statusCode == 200) {
      setState(() => connectionStatus = "none");
    }
  }

  // ---------------- UNFRIEND ----------------
  Future<void> unfriendUser() async {
    final uri = Uri.parse(
      "${api.getCompleteUrl('/profile/$currentUserId/unfriend')}",
    );

    final response = await http.post(
      uri,
      headers: {"Content-Type": "application/json"},
      body: json.encode({
        "friend_id": widget.userId,
      }),
    );

    if (response.statusCode == 200) {
      setState(() => connectionStatus = "none");
    }
  }

  // ---------------- CONFIRM DISCONNECT ----------------
  Future<void> showDisconnectDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Disconnect"),
        content:
            const Text("Are you sure you want to remove this connection?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Disconnect"),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await unfriendUser();
    }
  }

  @override
  void initState() {
    super.initState();
    loadUserProfile();
    loadConnectionStatus();
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: Colors.black),
          onPressed: () => Navigator.pop(context, true),
        ),
        centerTitle: true,
        title: const Text(
          "Profile",
          style:
              TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
        ),
      ),

      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : user == null
              ? const Center(child: Text("User not found"))
              : _buildProfile(),
    );
  }

  // ---------------- PROFILE BODY ----------------
  Widget _buildProfile() {
    final String name = user!["Name"] ?? "";
    final String department = user!["department"] ?? "";
    final String batch = user!["batch"]?.toString() ?? "";
    final List<String> interests =
        (user!["interests"] ?? []).cast<String>();

    String buttonText = "Connect";
    VoidCallback? onPressed = sendConnectionRequest;
    bool showReject = false;

    if (connectionStatus == "incoming_request") {
      buttonText = "Accept";
      onPressed = acceptRequest;
      showReject = true;
    } else if (connectionStatus == "outgoing_request") {
      buttonText = "Pending";
      onPressed = cancelConnectionRequest;
    } else if (connectionStatus == "friends") {
      buttonText = "Connected";
      onPressed = null;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        children: [
          CircleAvatar(
            radius: 50,
            backgroundColor: Colors.grey.shade300,
            child: Text(getInitials(name),
                style: const TextStyle(
                    fontSize: 26, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 14),
          Text(name,
              style:
                  const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          Text("$department • Batch $batch",
              style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 18),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: interests
                .map((i) => Chip(
                      label: Text(i),
                      backgroundColor: primaryBlue,
                      labelStyle:
                          const TextStyle(color: Colors.white),
                    ))
                .toList(),
          ),

          const SizedBox(height: 30),

          Row(
            children: [
              if (showReject)
                Expanded(
                  child: OutlinedButton(
                    onPressed: rejectRequest,
                    child: const Text("Decline"),
                  ),
                ),

              if (showReject) const SizedBox(width: 12),

              Expanded(
                child: ElevatedButton(
                  onPressed: isStatusLoading ? null : onPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                  ),
                  child: Text(buttonText),
                ),
              ),
            ],
          ),

          if (connectionStatus == "friends") ...[
            const SizedBox(height: 14),
            GestureDetector(
              onTap: showDisconnectDialog,
              child: const Text(
                "Disconnect",
                style: TextStyle(
                    color: Colors.red, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
