import 'package:flutter/material.dart';
import '../widgets/custom_nav_bar.dart';
import 'package:studently/models/user.dart';
import 'package:studently/repositories/user.dart';
import 'package:studently/logger.dart';
import 'package:studently/screens/profile_edit.dart';
import 'package:studently/services/api.dart';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studently/providers/auth_provider.dart';
import 'package:studently/utils/authenticated_image.dart';

class ProfilePage extends ConsumerStatefulWidget {
  final String? userId;

  const ProfilePage({super.key, this.userId});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  final Color blue = const Color(0xFF1976D2);
  final apiService = ApiService();
  List<Map<String, dynamic>> posts = [];
  bool hasLoadedPosts = false;

  User? otherUser;
  bool isLoadingOtherUser = true;
  String connectionStatus = "none";
  bool isStatusLoading = true;
  final userRepository = UserRepository();
  bool isLoadingPosts = false;
  final Set<String> failedProfileImages = {};
  @override
  void initState() {
    super.initState();
    if (widget.userId != null) {
      // 1. Viewing someone else: Fetch from API
      _loadOtherUserProfile();
      _loadConnectionStatus();
    } else {
      // 2. Viewing MY profile: Provider already has my info! Just load my posts.
      final myUser = ref.read(authProvider).value;
      if (myUser != null) {
        _loadUserPosts(myUser.id);
      }
    }
  }

  Future<void> _loadOtherUserProfile() async {
    setState(() => isLoadingOtherUser = true);
    try {
      final fetchedUser = await userRepository.fetchUserProfile(widget.userId!);
      setState(() {
        otherUser = fetchedUser;
        isLoadingOtherUser = false;
      });
      _loadUserPosts(widget.userId!);
    } catch (e) {
      setState(() => isLoadingOtherUser = false);
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

  Future<void> _loadUserPosts(String targetId) async {
    if (isLoadingPosts) return;
    setState(() => isLoadingPosts = true);

    try {
      final response = await apiService.get('/feed?limit=50&skip=0');
      final List<dynamic> data = jsonDecode(response.body);

      final filteredPosts = data.where((post) {
        return post['author_id'] == targetId;
      }).toList();

      setState(() {
        posts = List<Map<String, dynamic>>.from(filteredPosts);
        hasLoadedPosts = true;
        isLoadingPosts = false; // Reset loading state
      });
    } catch (e) {
      logger.e("Error loading posts: $e");
      setState(() {
        hasLoadedPosts = true;
        isLoadingPosts = false;
      });
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
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (_) {}
  }

  Future<void> _rejectRequest() async {
    try {
      await userRepository.respondRequest(widget.userId!, "reject");
      setState(() => connectionStatus = "none");
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (_) {}
  }

  Future<void> _unfriendUser() async {
    try {
      await userRepository.unfriendUser(widget.userId!);
      setState(() => connectionStatus = "none");
    } catch (_) {}
  }

  Future<void> _refreshProfile() async {
    if (widget.userId != null) {
      // Viewing someone else's profile
      await _loadOtherUserProfile();
      await _loadConnectionStatus();
    } else {
      // Viewing my profile
      final myUser = ref.read(authProvider).value;
      if (myUser != null) {
        await _loadUserPosts(myUser.id);
      }
    }
  }

  Future<void> _showDisconnectDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          "Remove Friend",
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
        ),
        content: const Text(
          "Are you sure you want to remove this connection?",
          style: TextStyle(fontSize: 14, color: Colors.grey),
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: const Text(
              "Cancel",
              style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              "Unfriend",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
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
    User? displayUser;
    if (isMyProfile) {
      displayUser = ref.watch(authProvider).value;
    } else {
      displayUser = otherUser;
    }
    final bool isScreenLoading = isMyProfile
        ? displayUser == null
        : isLoadingOtherUser;
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
      body: isScreenLoading
          ? const Center(child: CircularProgressIndicator())
          : displayUser == null
          ? const Center(child: Text("Error Loading Profile"))
          : RefreshIndicator(
              onRefresh: _refreshProfile,
              child: SingleChildScrollView(
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
                      _buildProfilePhoto(displayUser),
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
                                displayUser.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 12),
                              // Stats row: Posts, Friends
                              Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  _buildStatColumn(
                                    "Friends",
                                    displayUser.friendsCount.toString(),
                                  ),
                                  const SizedBox(width: 35),
                                  _buildStatColumn(
                                    "Posts",
                                    posts.length.toString(),
                                  ),
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
                    "${displayUser.department}, Batch ${displayUser.batch}",
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
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  EditProfilePage(user: displayUser!),
                            ),
                          );
                        },
                        child: Text(
                          "Edit Profile",
                          style: TextStyle(color: blue, fontSize: 14),
                        ),
                      ),
                    )
                  else if (connectionStatus == "friends")
                    SizedBox(
                      height: 40,
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: !isMyProfile ? _showDisconnectDialog : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                        child: const Text(
                          "Unfriend",
                          style: TextStyle(color: Colors.white, fontSize: 13),
                        ),
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
                          style: TextStyle(
                            color: blue,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    )
                  else if (!isMyProfile &&
                      connectionStatus != "incoming_request")
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _sendConnectionRequest,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: blue,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        child: const Text(
                          "Add Friend",
                          style: TextStyle(color: Colors.white, fontSize: 13),
                        ),
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

                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: (displayUser.interests)
                        .map(
                          (interest) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
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
                                Text(
                                  interest.emoji,
                                  style: const TextStyle(fontSize: 14),
                                ),
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
                          ),
                        )
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
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
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
            ),
      bottomNavigationBar: isMyProfile
          ? const CustomNavBar(currentIndex: 4)
          : null,
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
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Widget _buildProfilePhoto(User? user) {
    if (user == null || (user.profilePhotoUrl?.isEmpty ?? true)) {
      return CircleAvatar(
        radius: 45,
        backgroundColor: Colors.grey.shade400,
        child: const Icon(Icons.person, size: 40, color: Colors.white),
      );
    }
    final bool imageFailed = failedProfileImages.contains(user.profilePhotoUrl);
    return CircleAvatar(
      key: ValueKey<String>(user.profilePhotoUrl!),
      radius: 45,
      backgroundColor: Colors.grey.shade400,
      backgroundImage: AuthenticatedNetworkImage(user.profilePhotoUrl!),
      onBackgroundImageError: (exception, stackTrace) {
        setState(() => failedProfileImages.add(user.profilePhotoUrl!));
      },
      child: imageFailed
          ? const Icon(Icons.person, size: 40, color: Colors.white)
          : null,
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
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey.shade200,
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.image_not_supported_outlined,
                          size: 48,
                          color: Colors.grey.shade400,
                        ),
                      );
                    },
                  ),
                ),

                /// 🔥 CAPTION OVERLAY (Instagram style)
                if (caption.isNotEmpty)
                  Positioned(
                    bottom: 6,
                    left: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
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
