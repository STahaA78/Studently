import 'package:flutter/material.dart';
import '../widgets/custom_nav_bar.dart';
import 'package:studently/models/user.dart';
import 'package:studently/repositories/user.dart';
import 'package:studently/logger.dart';
import 'package:studently/screens/profile_edit.dart';
import 'package:studently/services/api.dart';
import 'dart:convert';
class ProfilePage extends StatefulWidget {
  final String? userId;

  const ProfilePage({super.key, this.userId});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final Color blue = const Color(0xFF1976D2);
  final apiService = ApiService();
  List<Map<String, dynamic>> posts = [];
  bool hasLoadedPosts = false;

  User? user;
  bool isLoading = true;
  String connectionStatus = "none";
  bool isStatusLoading = true;
  final userRepository = UserRepository();

  @override
  void initState() {
    logger.i("[ProfilePage] initState called with userId: ${widget.userId}");
    super.initState();
    _loadUserProfile();
    _loadConnectionStatus();
  }

  Future<void> _loadUserProfile() async {
    setState(() => isLoading = true);
    try {
      final fetchedUser = await userRepository.fetchUserProfile(widget.userId ?? "0");
      setState(() {
        user = fetchedUser;
        isLoading = false;
      });
      _loadUserPosts();
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  Future<void> _loadConnectionStatus() async {
    // Only load status for other users
    if (widget.userId == null) return;
    setState(() => isStatusLoading = true);
    try {
      final status = await userRepository.fetchConnectionStatus(widget.userId!);
      setState(() {
        connectionStatus = status;
        isStatusLoading = false;
      });
    } catch (e) {
      setState(() => isStatusLoading = false);
    }
  }
  Future<void> _loadUserPosts() async {
    try {
      final response = await apiService.get('/feed?limit=50&skip=0');

      final List<dynamic> data = jsonDecode(response.body);

      final String userId = widget.userId ?? user?.id ?? "";

      final filteredPosts = data.where((post) {
        return post['author_id'] == userId;
      }).toList();

      setState(() {
        posts = List<Map<String, dynamic>>.from(filteredPosts);
        hasLoadedPosts = true;
      });

    } catch (e) {
      logger.e("Error loading posts: $e");
      setState(() => hasLoadedPosts = true);
    }
  }
  Future<void> _sendConnectionRequest() async {
    try {
      await userRepository.sendConnectionRequest(widget.userId!);
      setState(() => connectionStatus = "outgoing_request");
    } catch (_) {}
  }

  Future<void> _cancelConnectionRequest() async {
    try {
      await userRepository.cancelConnectionRequest(widget.userId!);
      setState(() => connectionStatus = "none");
    } catch (_) {}
  }

  Future<void> _acceptRequest() async {
    try {
      await userRepository.respondRequest(widget.userId!, "accept");
      setState(() => connectionStatus = "friends");
    } catch (_) {}
  }

  Future<void> _rejectRequest() async {
    try {
      await userRepository.respondRequest(widget.userId!, "reject");
      setState(() => connectionStatus = "none");
    } catch (_) {}
  }

  Future<void> _unfriendUser() async {
    try {
      await userRepository.unfriendUser(widget.userId!);
      setState(() => connectionStatus = "none");
    } catch (_) {}
  }

  Future<void> _showDisconnectDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Disconnect"),
        content: const Text("Are you sure you want to remove this connection?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Disconnect"),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _unfriendUser();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isMyProfile = widget.userId == null;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        centerTitle: true,
        title: const Text(
          "Profile",
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        leading: widget.userId != null
            ? IconButton(
                icon: const Icon(Icons.chevron_left, color: Colors.black),
                onPressed: () => Navigator.pop(context),
              )
            : null,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : user == null
              ? const Center(child: Text("Error Loading Profile"))
              : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),
                      // Instagram-style profile header
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Profile picture on the left
                          _buildProfilePhoto(user!),
                          const SizedBox(width: 16),
                          // Info column on the right
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(left: 10.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  // Name
                                  Text(
                                    user!.name,
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 12),
                                  // Stats row: Posts, Friends
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    children: [
                                      _buildStatColumn("Friends", user!.friendsCount.toString()),
                                      const SizedBox(width: 35),
                                      _buildStatColumn("Posts", posts.length.toString()),
                                      const SizedBox(width: 35),
                                      _buildStatColumn("Resources", "0"),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Batch info
                      Text(
                        "${user!.department}, Batch ${user!.batch}",
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 12),
                      // Edit Profile / Connect buttons - full width
                      if (isMyProfile)
                        SizedBox(
                          height: 40,
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: () async {
                              final updatedUser = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => EditProfilePage(user: user!)
                                ),
                              );
                              if (updatedUser != null && mounted) {
                                setState(() {
                                  user = updatedUser;
                                });
                              }
                            },
                            child: Text(
                              "Edit Profile",
                              style: TextStyle(color: blue, fontSize: 14),
                            ),
                          ),
                        )
                      else if (connectionStatus == "friends")
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: blue,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            child: const Text("Connected", style: TextStyle(color: Colors.white, fontSize: 13)),
                          ),
                        )
                      else if (connectionStatus == "outgoing_request")
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: _cancelConnectionRequest,
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: blue),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            child: Text(
                              "Pending",
                              style: TextStyle(color: blue, fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                          ),
                        )
                      else
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _sendConnectionRequest,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: blue,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            child: const Text("Connect", style: TextStyle(color: Colors.white, fontSize: 13)),
                          ),
                        ),
                      const SizedBox(height: 16),
                      // Reject button for incoming requests
                      if (!isMyProfile && connectionStatus == "incoming_request")
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _rejectRequest,
                                child: const Text("Decline"),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _acceptRequest,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: blue,
                                ),
                                child: const Text("Accept"),
                              ),
                            ),
                          ],
                        ),
                      // Disconnect button for friends
                      if (!isMyProfile && connectionStatus == "friends")
                        GestureDetector(
                          onTap: _showDisconnectDialog,
                          child: const Text(
                            "Disconnect",
                            style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
                          ),
                        ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: (user!.interests)
                            .map((interest) => Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: const Color(0xFFE0E6ED),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(interest.emoji, style: const TextStyle(fontSize: 14)),
                                      const SizedBox(width: 6),
                                      Text(
                                        interest.name,
                                        style: const TextStyle(
                                          color: Color(0xFF334155),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ))
                            .toList(),
                      ),
                      const SizedBox(height: 20),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "Posts",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (!hasLoadedPosts)
                        const Center(child: CircularProgressIndicator())
                      else if (posts.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.image_not_supported_outlined,
                                  size: 48,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  "No posts yet",
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                            childAspectRatio: 1, // 🔥 dynamic height
                          ),
                          itemCount: posts.length,
                          itemBuilder: (context, index) {
                            return _buildPostCard(context, posts[index]);
                          },
                        ),
                    ],
                  ),
                ),
      bottomNavigationBar:
          isMyProfile ? const CustomNavBar(currentIndex: 4) : null,
    );
  }

  Widget _buildStatColumn(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildProfilePhoto(User user) {
    if (user.profilePhotoUrl?.isEmpty ?? true) {
      return CircleAvatar(
        radius: 45,
        backgroundColor: Colors.grey.shade400,
        child: const Icon(Icons.person, size: 40, color: Colors.white),
      );
    }
    return CircleAvatar(
      radius: 45,
      backgroundColor: Colors.grey.shade400,
      backgroundImage: NetworkImage(user.profilePhotoUrl!),
      onBackgroundImageError: (_, _) {},
      child: Container(),
    );
  }

  Widget _buildPostCard(BuildContext context, Map<String, dynamic> post) {
    final mediaUrls = post["media_urls"];

    String imageUrl = "";
    if (mediaUrls != null && mediaUrls is List && mediaUrls.isNotEmpty) {
      imageUrl = mediaUrls[0] ?? "";
    }

    final String caption = post["content"] ?? post["title"] ?? "";
    final bool hasImage = imageUrl.isNotEmpty;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: hasImage

          /// 🔥 IMAGE TILE WITH CAPTION OVERLAY
          ? Stack(
              children: [
                Positioned.fill(
                  child: Image.network(
                    apiService.getCompleteUrl(imageUrl),
                    fit: BoxFit.cover,
                  ),
                ),

                /// 🔥 CAPTION OVERLAY (Instagram style)
                if (caption.isNotEmpty)
                  Positioned(
                    bottom: 6,
                    left: 6,
                    right: 6,
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
              ],
            )

          /// 🔥 TEXT-ONLY TILE (CLEAN GRID STYLE)
          : Container(
              color: Colors.grey.shade200,
              alignment: Alignment.center,
              padding: const EdgeInsets.all(10),
              child: Text(
                caption.isNotEmpty ? caption : "No content",
                textAlign: TextAlign.center,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
    );
  }
}
