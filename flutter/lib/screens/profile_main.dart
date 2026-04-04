import 'package:flutter/material.dart';
import '../widgets/custom_nav_bar.dart';
import 'package:studently/models/user.dart';
import 'package:studently/repositories/user.dart';
import 'package:studently/logger.dart';
import 'package:studently/screens/profile_edit.dart';
import 'package:studently/services/api.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; 
import 'package:studently/providers/auth_provider.dart'; 
import 'package:studently/providers/feed_provider.dart';
import 'package:studently/models/post.dart';
import 'package:studently/screens/post_details_page.dart';

class ProfilePage extends ConsumerStatefulWidget {
  final String? userId;

  const ProfilePage({super.key, this.userId});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  final Color blue = const Color(0xFF1976D2);
  final apiService = ApiService();

  User? otherUser;
  bool isLoadingOtherUser = true;
  String connectionStatus = "none";
  bool isStatusLoading = true;
  final userRepository = UserRepository();

  @override
  void initState() {
    super.initState();
    if (widget.userId != null) {
      _loadOtherUserProfile();
      _loadConnectionStatus();
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
    } catch (e) {
      setState(() => isLoadingOtherUser = false);
    }
  }

  Future<void> _loadConnectionStatus() async {
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              "Unfriend",
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
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
    
    final String targetUserId = widget.userId ?? displayUser?.id ?? "";
    final profileFeedAsync = targetUserId.isNotEmpty 
        ? ref.watch(profileFeedProvider(targetUserId))
        : const AsyncValue<List<Post>>.data([]);

    final bool isScreenLoading = isMyProfile ? displayUser == null : isLoadingOtherUser;
    
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
                  onRefresh: () async {
                    if (targetUserId.isNotEmpty) {
                      await ref.read(profileFeedProvider(targetUserId).notifier).refresh();
                    }
                  },
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildProfilePhoto(displayUser!),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(left: 10.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    Text(
                                      displayUser!.name,
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.start,
                                      children: [
                                        _buildStatColumn("Friends", displayUser!.friendsCount.toString()),
                                        const SizedBox(width: 35),
                                        profileFeedAsync.when(
                                          data: (posts) => _buildStatColumn("Posts", posts.length.toString()),
                                          loading: () => _buildStatColumn("Posts", "..."),
                                          error: (_, __) => _buildStatColumn("Posts", "0"),
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
                        Text(
                          "${displayUser!.department}, Batch ${displayUser.batch}",
                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 12),
                        if (isMyProfile)
                          SizedBox(
                            height: 40,
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => EditProfilePage(user: displayUser!)
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
                              child: const Text("Unfriend", style: TextStyle(color: Colors.white, fontSize: 13)),
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
                        else if (!isMyProfile && connectionStatus != "incoming_request")
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _sendConnectionRequest,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: blue,
                                padding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                              child: const Text("Add Friend", style: TextStyle(color: Colors.white, fontSize: 13)),
                            ),
                          ),
                        const SizedBox(height: 16),
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
                          children: (displayUser!.interests)
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
                        profileFeedAsync.when(
                          data: (posts) {
                            if (posts.isEmpty) {
                              return Padding(
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
                              );
                            }
                            return GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 8,
                                childAspectRatio: 1,
                              ),
                              itemCount: posts.length,
                              itemBuilder: (context, index) {
                                return _buildPostCard(context, posts[index]);
                              },
                            );
                          },
                          loading: () => const Center(child: CircularProgressIndicator()),
                          error: (err, __) => Center(child: Text("Error loading posts: $err")),
                        ),
                      ],
                    ),
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

  Widget _buildPostCard(BuildContext context, Post post) {
    final mediaUrls = post.mediaUrls;
    String imageUrl = "";
    if (mediaUrls.isNotEmpty) {
      imageUrl = mediaUrls[0];
    }

    final String caption = post.content;
    final bool hasImage = imageUrl.isNotEmpty;

    return GestureDetector(
      onTap: () async {
        final updatedPost = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PostDetailsPage(postData: post),
          ),
        );
        if (updatedPost != null && updatedPost is Post) {
           ref.read(feedProvider.notifier).updatePostLocally(updatedPost);
           ref.read(profileFeedProvider(post.authorId).notifier).syncPostUpdate(updatedPost);
        }
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: hasImage
            ? Stack(
                children: [
                  Positioned.fill(
                    child: Image.network(
                      apiService.getCompleteUrl(imageUrl),
                      fit: BoxFit.cover,
                    ),
                  ),
                  if (caption.isNotEmpty)
                    Positioned(
                      bottom: 6,
                      left: 6,
                      right: 6,
                      child: Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
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
      ),
    );
  }
}
