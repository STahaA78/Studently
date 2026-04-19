import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/custom_nav_bar.dart';
import 'package:studently/models/user.dart';
import 'package:studently/repositories/user.dart';
import 'package:studently/logger.dart';
import 'package:studently/screens/profile_main.dart';
import 'package:studently/providers/auth_provider.dart';
class RequestsPage extends ConsumerStatefulWidget {
  const RequestsPage({super.key});

  @override
  ConsumerState<RequestsPage> createState() => _RequestsPageState();
}

class _RequestsPageState extends ConsumerState<RequestsPage> {
  final Color primaryBlue = const Color(0xFF0F74C5);

  /// TEMP logged-in user id
  final String currentUserId = "6989b03caf678f41033614ea";

  Future<List<User>>? _requestsFuture;

  // ---------------- INIT ----------------
  @override
  void initState() {
    super.initState();
    _requestsFuture = _loadAndCacheRequests();
    
    // Background refresh: fetch fresh data in the background
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshRequestsInBackground();
    });
  }

  Future<List<User>> _loadAndCacheRequests() async {
    _currentRequests = await UserRepository().fetchPendingRequests();
    return _currentRequests;
  }

  Future<void> _refreshRequestsInBackground() async {
    try {
      final freshRequests = await UserRepository().fetchPendingRequests();
      if (!mounted) return;
      setState(() {
        _currentRequests = freshRequests;
      });
      logger.i("[RequestsPage] Background refresh completed");
    } catch (e) {
      logger.e("[RequestsPage] Background refresh failed: $e");
    }
  }

  // Store current requests in memory
  late List<User> _currentRequests = [];

 // ---------------- RESPOND REQUEST ----------------
  Future<void> respondRequest(String requesterId, String action) async {
    try {
      // 1. OPTIMISTIC UPDATE: Remove the card immediately from the list
      setState(() {
        _currentRequests.removeWhere((user) => user.id == requesterId);
      });

      // 2. Tell Riverpod to handle the API call (in the background)
      await ref.read(authProvider.notifier).respondToFriendRequest(requesterId, action);
      
      logger.i("[RequestsPage] respondRequest successful for $requesterId");

    } catch (e) {
      logger.e("[RequestsPage] respondRequest failed: $e");
      
      // 3. ROLLBACK: If API fails, reload the list to restore the card
      if (!mounted) return;
      setState(() {
        _requestsFuture = UserRepository().fetchPendingRequests();
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to respond to request."), backgroundColor: Colors.red),
      );
    }
  }
  // ---------------- INITIALS ----------------
  String getInitials(String name) {
    if (name.trim().isEmpty) return "?";
    final parts = name.trim().split(RegExp(r"\s+"));
    return parts.map((e) => e[0]).take(2).join().toUpperCase();
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
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text(
          "Pending Requests",
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: FutureBuilder<List<User>>(
        future: _requestsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.cloud_off_rounded, size: 80, color: Colors.grey[400]),
                    const SizedBox(height: 24),
                    const Text(
                      "Connection Issue",
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "We couldn't reach our Backend. Please check your internet and try again.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _requestsFuture = _loadAndCacheRequests();
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                        ),
                        child: const Text("Try Again", style: TextStyle(fontSize: 18, color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          final requests = _currentRequests.isNotEmpty ? _currentRequests : snapshot.data ?? [];
          if (requests.isEmpty) {
            return const Center(
              child: Text(
                "No pending requests",
                style: TextStyle(color: Colors.grey),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            itemCount: requests.length,
            itemBuilder: (context, index) {
              return _buildRequestCard(requests[index]);
            },
          );
        },
      ),
      bottomNavigationBar: const CustomNavBar(currentIndex: 1),
    );
  }

  // ---------------- REQUEST CARD ----------------
  Widget _buildRequestCard(User user) {
    return GestureDetector(
      onTap: () async {
        final bool? changed = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProfilePage(
              userId: user.id,
            ),
          ),
        );
        if (changed == true) {
          // Reload only if connection status was changed in profile
          setState(() {
            _requestsFuture = _loadAndCacheRequests();
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 25,
              backgroundColor: Colors.grey[300],
              backgroundImage: user.picture != null &&
                      user.picture!.isNotEmpty
                  ? NetworkImage(user.picture!)
                  : null,
              child: user.picture == null ||
                      user.picture!.isEmpty
                  ? const Icon(Icons.person, size: 32, color: Colors.grey)
                  : null,
            ),
            const SizedBox(width: 12),
            // Name and Department/Batch
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 15,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "${user.department} • Batch ${user.batch}",
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Decline button (X)
            GestureDetector(
              onTap: () => respondRequest(user.id, "reject"),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.red, width: 2),
                ),
                child: const Icon(Icons.close, color: Colors.red, size: 18),
              ),
            ),
            const SizedBox(width: 8),
            // Accept button (checkmark)
            GestureDetector(
              onTap: () => respondRequest(user.id, "accept"),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: primaryBlue,
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
