import 'package:studently/app_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import '../widgets/custom_nav_bar.dart';
import 'package:studently/models/user.dart';
import 'package:studently/repositories/user.dart';
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
  final Color blue = AppStyle.primaryBlue;
  final apiService = ApiService();
  final ScrollController scrollController = ScrollController();

  User? otherUser;
  User? refreshedOwnUser; // Cache for own user when refreshed
  bool isLoadingOtherUser = true;
  String connectionStatus = "none";
  bool isStatusLoading = true;
  final userRepository = UserRepository();
  final Set<String> failedProfileImages = {};

  @override
  void initState() {
    super.initState();

    // Restore scroll position
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollController.hasClients) {
        final displayUser = ref.read(authProvider).value;
        final targetUserId = widget.userId ?? displayUser?.id ?? "";
        if (targetUserId.isNotEmpty) {
          final savedOffset = ref.read(profileScrollProvider(targetUserId));
          if (savedOffset > 0) {
            scrollController.jumpTo(savedOffset);
          }
        }
      }
    });

    scrollController.addListener(() {
      if (scrollController.hasClients) {
        final displayUser = ref.read(authProvider).value;
        final targetUserId = widget.userId ?? displayUser?.id ?? "";
        if (targetUserId.isNotEmpty) {
          ref
              .read(profileScrollProvider(targetUserId).notifier)
              .set(scrollController.offset);
        }
      }

      // Add pagination check
      if (scrollController.position.pixels >=
          scrollController.position.maxScrollExtent - 200) {
        final displayUser = ref.read(authProvider).value;
        final targetUserId = widget.userId ?? displayUser?.id ?? "";
        if (targetUserId.isNotEmpty) {
          ref.read(profileFeedProvider(targetUserId).notifier).loadMore();
        }
      }
    });

    if (widget.userId != null) {
      _loadOtherUserProfile();
      _loadConnectionStatus();
    }
  }

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadOtherUserProfile() async {
    setState(() => isLoadingOtherUser = true);
    try {
      final fetchedUser = await userRepository.fetchUserProfile(
        userId: widget.userId!,
      );
      setState(() {
        otherUser = fetchedUser;
        isLoadingOtherUser = false;
      });
    } catch (e) {
      setState(() => isLoadingOtherUser = false);
    }
  }

  Future<void> _refreshOwnUserProfile() async {
    try {
      final freshUser = await userRepository.fetchUserProfile();
      // Only update local cache via setState - don't touch authProvider
      setState(() {
        refreshedOwnUser = freshUser;
      });
      // Clear refreshedOwnUser after a brief moment to resume normal feed watching
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        setState(() {
          refreshedOwnUser = null;
        });
      }
    } catch (e) {
      // Silently fail if refresh fails
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

  Future<void> _refreshProfile() async {
    if (widget.userId != null) {
      // Viewing someone else's profile - only refresh profile data
      await _loadOtherUserProfile();
      await _loadConnectionStatus();
    } else {
      // Viewing my profile - only refresh profile data locally
      await _refreshOwnUserProfile();
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
      // For own profile: prefer refreshedOwnUser (from refresh), fall back to authProvider
      displayUser = refreshedOwnUser ?? ref.watch(authProvider).value;
    } else {
      displayUser = otherUser;
    }

    final String targetUserId = widget.userId ?? displayUser?.id ?? "";
    // Only fetch feed for display purposes (post count), not on every profile refresh
    // Use select to only watch the feed when NOT on own profile or when refreshedOwnUser is null
    final profileFeedAsync = (isMyProfile && refreshedOwnUser != null)
        ? const AsyncValue<List<Post>>.data(
            [],
          ) // Skip feed watch during own profile refresh
        : (targetUserId.isNotEmpty
              ? ref.watch(profileFeedProvider(targetUserId))
              : const AsyncValue<List<Post>>.data([]));

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
        actions: kIsWeb
            ? [
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.black),
                  onPressed: _refreshProfile,
                  tooltip: 'Refresh',
                ),
              ]
            : null,
      ),
      body: isScreenLoading
          ? const Center(child: CircularProgressIndicator())
          : displayUser == null
          ? const Center(child: Text("Error Loading Profile"))
          : RefreshIndicator(
              onRefresh: _refreshProfile,
              child: SingleChildScrollView(
                controller: scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    // Instagram-style profile header
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildProfilePhoto(displayUser),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(left: 10.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
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
                                // Stats row
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    _buildStatColumn(
                                      "Friends",
                                      displayUser.friendsCount.toString(),
                                    ),
                                    const SizedBox(width: 35),
                                    profileFeedAsync.when(
                                      data: (posts) => _buildStatColumn(
                                        "Posts",
                                        posts.length.toString(),
                                      ),
                                      loading: () =>
                                          _buildStatColumn("Posts", "..."),
                                      error: (_, _) =>
                                          _buildStatColumn("Posts", "0"),
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
                      "${displayUser.department?.name ?? 'N/A'}, Batch ${displayUser.batch}",
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),

                    // Edit Profile / Connect buttons
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
                            style: TextStyle(color: AppStyle.primaryBlue, fontSize: 14),
                          ),
                        ),
                      )
                    else if (connectionStatus == "friends")
                      SizedBox(
                        height: 40,
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: !isMyProfile
                              ? _showDisconnectDialog
                              : null,
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

                    // Reject/Accept buttons for incoming requests
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

                    // Posts Grid rendering using Riverpod AsyncValue
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
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
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
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (err, _) =>
                          Center(child: Text("Error loading posts: $err")),
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
    if (user == null || (user.picture?.isEmpty ?? true)) {
      return CircleAvatar(
        radius: 45,
        backgroundColor: Colors.grey.shade400,
        child: const Icon(Icons.person, size: 40, color: Colors.white),
      );
    }
    final bool imageFailed = failedProfileImages.contains(user.picture);
    return CircleAvatar(
      key: ValueKey<String>(user.picture!),
      radius: 45,
      backgroundColor: Colors.grey.shade400,
      backgroundImage: NetworkImage(user.picture!),
      onBackgroundImageError: (exception, stackTrace) {
        // Defer setState to avoid calling it during paint phase
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() => failedProfileImages.add(user.picture!));
          }
        });
      },
      child: imageFailed
          ? const Icon(Icons.person, size: 40, color: Colors.white)
          : null,
    );
  }

  Widget _buildPostCard(BuildContext context, Post post) {
    final String caption = post.content;
    String imageUrl = post.mediaUrl ?? "";
    final bool hasImage = imageUrl.isNotEmpty;

    // HYBRID FIX: Wrapped the beautiful development UI inside the necessary community Navigation logic
    return GestureDetector(
      onTap: () async {
        final updatedPost = await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PostDetailsPage(postData: post)),
        );
        if (updatedPost != null && updatedPost is Post) {
          ref.read(feedProvider.notifier).updatePostLocally(updatedPost);
          ref
              .read(profileFeedProvider(post.authorId).notifier)
              .syncPostUpdate(updatedPost);
        }
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: hasImage
            /// 🔥 IMAGE TILE WITH CAPTION OVERLAY
            ? Stack(
                children: [
                  Positioned.fill(
                    child: Image.network(
                      imageUrl,
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
      ),
    );
  }
}
