import 'package:flutter/material.dart';

import 'package:studently/widgets/custom_nav_bar.dart';
import 'package:studently/screens/profile_main.dart';
import 'discover_requests.dart';
import 'package:studently/models/user.dart';
import 'package:studently/repositories/user.dart';
import 'package:studently/logger.dart';

class ConnectDiscoverPage extends StatefulWidget {
  const ConnectDiscoverPage({super.key});

  @override
  State<ConnectDiscoverPage> createState() => _ConnectDiscoverPageState();
}

class _ConnectDiscoverPageState extends State<ConnectDiscoverPage> {
  final TextEditingController _searchController = TextEditingController();
  final Color primaryBlue = const Color(0xFF0F74C5);

  final String currentUserId = "69832e61af678f41033614e9";

  final UserRepository _userRepository = UserRepository();
  Future<List<User>>? _discoverFuture;
  List<User> filteredStudents = [];
  Map<String, String> connectionStatus = {};
  int pendingRequestsCount = 0;
  String searchQuery = '';

  // ---------------- INIT ----------------
  @override
  void initState() {
    super.initState();
    _discoverFuture = _userRepository.discoverUsers();
    loadPendingRequestsCount();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ---------------- SEARCH ----------------
  void _onSearchChanged() {
    final query = _searchController.text.trim();
    setState(() {
      searchQuery = query;
      if (query.isEmpty) {
        _discoverFuture = _userRepository.discoverUsers();
      } else if (query.length >= 2) {
        _discoverFuture = _userRepository.searchUsers(query);
      }
    });
  }

  // ---------------- INITIALS ----------------
  String getInitials(String name) {
    if (name.trim().isEmpty) return "?";
    final parts = name.trim().split(RegExp(r"\s+"));
    return parts.map((e) => e[0]).take(2).join().toUpperCase();
  }

  // ---------------- CONNECTION STATUS ----------------
  Future<void> fetchConnectionStatus(String targetId) async {
    try {
      final status = await _userRepository.fetchConnectionStatus(targetId);
      setState(() {
        connectionStatus[targetId] = status;
      });
    } catch (e) {
      logger.e("[ConnectDiscoverPage] fetchConnectionStatus failed: $e");
    }
  }

  // ---------------- SEND / CANCEL ----------------
  Future<void> sendConnectionRequest(String targetId) async {
    try {
      await _userRepository.sendConnectionRequest(targetId);
      setState(() {
        connectionStatus[targetId] = "outgoing_request";
      });
    } catch (e) {
      logger.e("[ConnectDiscoverPage] sendConnectionRequest failed: $e");
    }
  }

  Future<void> cancelConnectionRequest(String targetId) async {
    try {
      await _userRepository.cancelConnectionRequest(targetId);
      setState(() {
        connectionStatus[targetId] = "none";
      });
    } catch (e) {
      logger.e("[ConnectDiscoverPage] cancelConnectionRequest failed: $e");
    }
  }

  // ---------------- PENDING COUNT ----------------
  Future<void> loadPendingRequestsCount() async {
    try {
      final count = await _userRepository.fetchPendingRequestsCount();
      setState(() {
        pendingRequestsCount = count;
      });
    } catch (e) {
      logger.e("[ConnectDiscoverPage] loadPendingRequestsCount failed: $e");
    }
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "Connect",
          style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: Stack(
              children: [
                const Icon(Icons.person_add,
                    color: Colors.black),
                if (pendingRequestsCount > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: CircleAvatar(
                      radius: 9,
                      backgroundColor: Colors.red,
                      child: Text(
                        pendingRequestsCount.toString(),
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const RequestsPage(),
                ),
              );

              if (result == true) {
                await loadPendingRequestsCount();
                setState(() {
                  _discoverFuture = _userRepository.discoverUsers();
                });
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Search students...",
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: const Color(0xFFF1F1F1),
                border: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<User>>(
              future: _discoverFuture,
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
                                  _discoverFuture = _userRepository.discoverUsers();
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
                final students = snapshot.data ?? [];
                if (students.isEmpty) {
                  return const Center(child: Text("No students found"));
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: students.length,
                  itemBuilder: (context, index) => _buildStudentCard(students[index]),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: const CustomNavBar(currentIndex: 1),
    );
  }

  // ---------------- STUDENT CARD ----------------
  Widget _buildStudentCard(User student) {
    logger.d("[ConnectDiscoverPage] Building card for student: ${student.name} with id: ${student.id}");
    final status = connectionStatus[student.id] ?? "none";

    Widget actionWidget;

    if (status == "none") {
      actionWidget = GestureDetector(
        onTap: () => sendConnectionRequest(student.id),
        child: Container(
          height: 40,
          width: 40,
          decoration: BoxDecoration(
            color: primaryBlue,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.add, color: Colors.white),
        ),
      );
    } else if (status == "outgoing_request") {
      actionWidget = GestureDetector(
        onTap: () => cancelConnectionRequest(student.id),
        child: Container(
          height: 40,
          width: 40,
          decoration: BoxDecoration(
            color: Colors.orange.shade100,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.access_time,
              color: Colors.orange),
        ),
      );
    } else {
      actionWidget = Container(
        height: 40,
        width: 40,
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check,
            color: Colors.grey),
      );
    }

    return GestureDetector(
      onTap: () async {
        final changed = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProfilePage(userId: student.id),
          ),
        );
        if (changed == true) {
          setState(() {
            _discoverFuture = _userRepository.discoverUsers();
          });
          await loadPendingRequestsCount();
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  child: Text(getInitials(student.name)),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(student.department),
                    Text(
                      "Batch ${student.batch}",
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
            actionWidget,
          ],
        ),
      ),
    );
  }
}
