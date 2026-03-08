import 'package:flutter/material.dart';
import 'package:studently/models/user.dart';
import 'package:studently/repositories/user.dart';
import 'package:studently/logger.dart';

class UserProfilePage extends StatefulWidget {
  final String userId;

  const UserProfilePage({super.key, required this.userId});

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  final Color primaryBlue = const Color(0xFF0F74C5);

  /// TEMP logged-in user id
  final String currentUserId = "6989b03caf678f41033614ea";

  User? user;
  bool isLoading = true;

  /// none / outgoing_request / incoming_request / friends
  String connectionStatus = "none";
  bool isStatusLoading = true;
  final UserRepository userRepository = UserRepository();

  // ---------------- INITIALS ----------------
  String getInitials(String name) {
    if (name.trim().isEmpty) return "?";
    final parts = name.trim().split(RegExp(r"\s+"));
    return parts.map((e) => e[0]).take(2).join().toUpperCase();
  }

  // ---------------- LOAD USER PROFILE ----------------
  Future<void> loadUserProfile() async {
    try {
      logger.i("[$runtimeType] Loading user profile");
      final fetchedUser = await userRepository.fetchUserProfile(widget.userId);
      setState(() {
        user = fetchedUser;
        isLoading = false;
      });
      logger.i("[$runtimeType] User profile loaded successfully");
    } catch (e) {
      logger.e("[$runtimeType] User profile error: $e");
      setState(() => isLoading = false);
    }
  }

  // ---------------- LOAD CONNECTION STATUS ----------------
  Future<void> loadConnectionStatus() async {
    try {
      logger.i("[$runtimeType] Loading connection status.");
      final status = await userRepository.fetchConnectionStatus(currentUserId, widget.userId);
      setState(() {
        connectionStatus = status;
        isStatusLoading = false;
      });
      logger.i("[$runtimeType] Connection status loaded successfully: $status");
    } catch (e) {
      logger.e("[$runtimeType] Connection status error: $e");
      setState(() => isStatusLoading = false);
    }
  }

  // ---------------- SEND REQUEST ----------------
  Future<void> sendConnectionRequest() async {
    try {
      logger.i("[$runtimeType] Sending connection request to User");
      await userRepository.sendConnectionRequest(currentUserId, widget.userId);
      setState(() => connectionStatus = "outgoing_request");
      logger.i("[$runtimeType] Connection request sent successfully");
    } catch (e) {
      logger.e("[$runtimeType] Send request error: $e");
    }
  }

  // ---------------- CANCEL REQUEST ----------------
  Future<void> cancelConnectionRequest() async {
    try {

      await userRepository.cancelConnectionRequest(currentUserId, widget.userId);
      setState(() => connectionStatus = "none");
    } catch (e) {
      logger.e("[$runtimeType] Cancel request error: $e");
    }
  }

  // ---------------- ACCEPT REQUEST ----------------
  Future<void> acceptRequest() async {
    try {
      logger.i("[$runtimeType] Accepting connection request from User");
      await userRepository.respondRequest(currentUserId, widget.userId, "accept");
      setState(() => connectionStatus = "friends");
      logger.i("[$runtimeType] Connection request accepted successfully");
    } catch (e) {
      logger.e("[$runtimeType] Accept request error: $e");
    }
  }

  // ---------------- REJECT REQUEST ----------------
  Future<void> rejectRequest() async {
    try {
      logger.i("[$runtimeType] Rejecting connection request from User");
      await userRepository.respondRequest(currentUserId, widget.userId, "reject");
      setState(() => connectionStatus = "none");
      logger.i("[$runtimeType] Connection request rejected successfully");
    } catch (e) {
      logger.e("[$runtimeType] Reject request error: $e");
    }
  }

  // ---------------- UNFRIEND ----------------
  Future<void> unfriendUser() async {
    try {
      logger.i("[$runtimeType] Unfriending user");
      await userRepository.unfriendUser(currentUserId, widget.userId);
      setState(() => connectionStatus = "none");
      logger.i("[$runtimeType] User unfriended successfully");
    } catch (e) {
      logger.e("[$runtimeType] Unfriend error: $e");
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
    final User profileUser = user!;
    final String name = profileUser.name;
    final String department = profileUser.department;
    final String batch = profileUser.batch;
    final List<String> interests = profileUser.interests ?? [];

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
