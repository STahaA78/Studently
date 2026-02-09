import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../widgets/custom_nav_bar.dart';
import 'requests_page.dart';
import 'user_profile_page.dart';

class ConnectDiscoverPage extends StatefulWidget {
  const ConnectDiscoverPage({super.key});

  @override
  State<ConnectDiscoverPage> createState() => _ConnectDiscoverPageState();
}

class _ConnectDiscoverPageState extends State<ConnectDiscoverPage> {
  final TextEditingController _searchController = TextEditingController();
  final Color primaryBlue = const Color(0xFF0F74C5);

  /// TEMP logged-in user id
  final String currentUserId = "6989b03caf678f41033614ea";

  List<Map<String, dynamic>> filteredStudents = [];
  Map<String, String> connectionStatus = {};

  bool isLoading = false;
  int pendingRequestsCount = 0;

  // ---------------- INIT ----------------
  @override
  void initState() {
    super.initState();
    loadDiscoverUsers();
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

    if (query.isEmpty) {
      loadDiscoverUsers();
    } else if (query.length >= 2) {
      searchStudents(query);
    }
  }

  // ---------------- USER MAPPER ----------------
  Map<String, dynamic> mapUser(dynamic user) {
    return {
      "id": user["id"],
      "name": user["Name"] ?? "",
      "department": user["department"] ?? "",
      "batch": user["batch"]?.toString() ?? "",
    };
  }

  // ---------------- INITIALS ----------------
  String getInitials(String name) {
    if (name.trim().isEmpty) return "?";
    final parts = name.trim().split(RegExp(r"\s+"));
    return parts.map((e) => e[0]).take(2).join().toUpperCase();
  }

  // ---------------- CONNECTION STATUS ----------------
  Future<void> fetchConnectionStatus(String targetId) async {
    final uri = Uri.parse(
      "http://localhost:8000/profile/status"
      "?user_id=$currentUserId&target_id=$targetId",
    );

    final response = await http.get(uri);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      connectionStatus[targetId] = data["status"];
    }
  }

  // ---------------- SEND / CANCEL ----------------
  Future<void> sendConnectionRequest(String targetId) async {
    final uri = Uri.parse(
      "http://localhost:8000/profile/$currentUserId/request"
      "?target_id=$targetId",
    );

    final response = await http.post(uri);
    if (response.statusCode == 200) {
      setState(() {
        connectionStatus[targetId] = "outgoing_request";
      });
    }
  }

  Future<void> cancelConnectionRequest(String targetId) async {
    final uri = Uri.parse(
      "http://localhost:8000/profile/$currentUserId/cancel-request"
      "?target_id=$targetId",
    );

    final response = await http.post(uri);
    if (response.statusCode == 200) {
      setState(() {
        connectionStatus[targetId] = "none";
      });
    }
  }

  // ---------------- SEARCH API ----------------
  Future<void> searchStudents(String query) async {
    setState(() => isLoading = true);

    final uri =
        Uri.parse("http://localhost:8000/profile/search/?query=$query");
    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final List data = json.decode(response.body);

      final fetched = data
          .map<Map<String, dynamic>>(mapUser)
          .where((u) => u["id"] != currentUserId)
          .toList();

      connectionStatus.clear();
      for (final user in fetched) {
        await fetchConnectionStatus(user["id"]);
      }

      setState(() {
        filteredStudents = fetched;
      });
    }

    setState(() => isLoading = false);
  }

  // ---------------- DISCOVER API ----------------
  Future<void> loadDiscoverUsers() async {
    setState(() => isLoading = true);

    final uri = Uri.parse("http://localhost:8000/profile/discover");
    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final List data = json.decode(response.body);

      final fetched = data
          .map<Map<String, dynamic>>(mapUser)
          .where((u) => u["id"] != currentUserId)
          .toList();

      connectionStatus.clear();
      for (final user in fetched) {
        await fetchConnectionStatus(user["id"]);
      }

      setState(() {
        filteredStudents = fetched;
      });
    }

    setState(() => isLoading = false);
  }

  // ---------------- PENDING COUNT ----------------
  Future<void> loadPendingRequestsCount() async {
    final uri = Uri.parse(
      "http://localhost:8000/profile/$currentUserId/requests",
    );

    final response = await http.get(uri);
    if (response.statusCode == 200) {
      final List data = json.decode(response.body);
      setState(() {
        pendingRequestsCount = data.length;
      });
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
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: Stack(
              children: [
                const Icon(Icons.person_add, color: Colors.black),
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
                await loadDiscoverUsers();
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
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredStudents.isEmpty
                    ? const Center(child: Text("No students found"))
                    : ListView.builder(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: filteredStudents.length,
                        itemBuilder: (context, index) =>
                            _buildStudentCard(filteredStudents[index]),
                      ),
          ),
        ],
      ),
      bottomNavigationBar: const CustomNavBar(currentIndex: 1),
    );
  }

  // ---------------- STUDENT CARD ----------------
  Widget _buildStudentCard(Map<String, dynamic> student) {
    final status = connectionStatus[student["id"]] ?? "none";

    String buttonText = "Connect";
    VoidCallback? onPressed =
        () => sendConnectionRequest(student["id"]);

    if (status == "outgoing_request") {
      buttonText = "Pending";
      onPressed = () => cancelConnectionRequest(student["id"]);
    } else if (status == "friends") {
      buttonText = "Connected";
      onPressed = null;
    }

    return GestureDetector(
      onTap: () async {
        final changed = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                UserProfilePage(userId: student["id"]),
          ),
        );

        if (changed == true) {
          await loadDiscoverUsers();
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
                  child: Text(getInitials(student["name"])),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student["name"],
                      style:
                          const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(student["department"]),
                    Text(
                      "Batch ${student["batch"]}",
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
            ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryBlue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(buttonText),
            ),
          ],
        ),
      ),
    );
  }
}
