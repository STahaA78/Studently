import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../widgets/custom_nav_bar.dart';
import 'user_profile_page.dart';

class RequestsPage extends StatefulWidget {
  const RequestsPage({super.key});

  @override
  State<RequestsPage> createState() => _RequestsPageState();
}

class _RequestsPageState extends State<RequestsPage> {
  final Color primaryBlue = const Color(0xFF0F74C5);

  /// TEMP logged-in user id
  final String currentUserId = "6989b03caf678f41033614ea";

  List<Map<String, dynamic>> requests = [];
  bool isLoading = false;

  // ---------------- INIT ----------------
  @override
  void initState() {
    super.initState();
    loadPendingRequests();
  }

  // ---------------- FETCH REQUESTS ----------------
  Future<void> loadPendingRequests() async {
    setState(() => isLoading = true);

    try {
      final uri = Uri.parse(
        "http://localhost:8000/profile/$currentUserId/requests",
      );

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);

        final fetched = data.map<Map<String, dynamic>>((user) {
          return {
            "id": user["id"],
            "name": user["Name"] ?? "",
            "department": user["department"] ?? "",
            "batch": user["batch"]?.toString() ?? "",
          };
        }).toList();

        setState(() => requests = fetched);
      }
    } catch (e) {
      debugPrint("Load requests error: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  // ---------------- RESPOND REQUEST ----------------
  Future<void> respondRequest(String requesterId, String action) async {
    try {
      final uri = Uri.parse(
        "http://localhost:8000/profile/$currentUserId/respond",
      );

      final response = await http.post(
        uri,
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "requester_id": requesterId,
          "action": action,
        }),
      );

      if (response.statusCode == 200) {
        setState(() {
          requests.removeWhere((r) => r["id"] == requesterId);
        });

        // ✅ Notify previous page to refresh
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint("Respond error: $e");
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
      backgroundColor: const Color(0xFFF2F2F7),
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
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : requests.isEmpty
              ? const Center(
                  child: Text(
                    "No pending requests",
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: requests.length,
                  itemBuilder: (context, index) {
                    return _buildRequestCard(requests[index]);
                  },
                ),
      bottomNavigationBar: const CustomNavBar(currentIndex: 1),
    );
  }

  // ---------------- REQUEST CARD ----------------
  Widget _buildRequestCard(Map<String, dynamic> user) {
    return GestureDetector(
      onTap: () async {
        final bool? changed = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => UserProfilePage(
              userId: user["id"],
            ),
          ),
        );

        // 🔁 Refresh list if profile action happened
        if (changed == true) {
          loadPendingRequests();
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.grey.shade300,
                  child: Text(
                    getInitials(user["name"]),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user["name"],
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      user["department"],
                      style: const TextStyle(fontSize: 13),
                    ),
                    Text(
                      "Batch ${user["batch"]}",
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () =>
                        respondRequest(user["id"], "reject"),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text("Decline"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () =>
                        respondRequest(user["id"], "accept"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryBlue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text("Accept"),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
