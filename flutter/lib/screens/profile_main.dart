import 'package:flutter/material.dart';
import '../widgets/custom_nav_bar.dart';
import 'post_details_page.dart';
import 'package:studently/models/user.dart';
import 'package:studently/repositories/user.dart';
import 'package:studently/logger.dart';
import 'package:studently/screens/profile_edit.dart';

class ProfilePage extends StatefulWidget {
  final String? userId;

  const ProfilePage({super.key, this.userId});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final Color blue = const Color(0xFF1976D2);

  final List<Map<String, dynamic>> posts = [
    {
      "title": "Join me for Group Study Session",
      "image": "assets/images/group_study.jpg",
      "likes": 123,
      "comments": 2,
      "isLiked": false,
    },
    {
      "title": "AI Research Collaboration",
      "image": "assets/images/group_study.jpg",
      "likes": 98,
      "comments": 5,
      "isLiked": false,
    },
  ];

  User? user;
  bool isLoading = true;
  String connectionStatus = "none";
  bool isStatusLoading = true;
  final userRepository = UserRepository();
  final String currentUserId = "6989b03caf678f41033614ea";

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
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : user == null
              ? const Center(child: Text("User not found"))
              : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 12),
                      _buildProfilePhoto(user!),
                      const SizedBox(height: 12),
                      Text(
                        user!.name,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        "${user!.department}, Batch ${user!.batch}",
                        style: const TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: null,
                        icon: const Icon(Icons.people, color: Colors.blue),
                        label: Text(
                          "${user!.friendsCount} Friends",
                          style: const TextStyle(color: Colors.blue),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: (user!.interests)
                            .map((interest) => Chip(
                                  label: Text(
                                    interest,
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                  backgroundColor: blue,
                                ))
                            .toList(),
                      ),
                      const SizedBox(height: 16),
                      if (isMyProfile)
                        OutlinedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => EditProfilePage(user: user!)
                              ),
                            );
                          },
                          icon: Icon(Icons.edit, color: blue),
                          label: Text(
                            "Edit Profile",
                            style: TextStyle(color: blue),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: blue),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      if (!isMyProfile) _buildConnectionActions(),
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
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: posts.length,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.85,
                        ),
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

  Widget _buildConnectionActions() {
    String buttonText = "Connect";
    VoidCallback? onPressed = _sendConnectionRequest;
    bool showReject = false;
    if (connectionStatus == "incoming_request") {
      buttonText = "Accept";
      onPressed = _acceptRequest;
      showReject = true;
    } else if (connectionStatus == "outgoing_request") {
      buttonText = "Pending";
      onPressed = _cancelConnectionRequest;
    } else if (connectionStatus == "friends") {
      buttonText = "Connected";
      onPressed = null;
    }
    return Column(
      children: [
        Row(
          children: [
            if (showReject)
              Expanded(
                child: OutlinedButton(
                  onPressed: _rejectRequest,
                  child: const Text("Decline"),
                ),
              ),
            if (showReject) const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: isStatusLoading ? null : onPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: blue,
                ),
                child: Text(buttonText),
              ),
            ),
          ],
        ),
        if (connectionStatus == "friends") ...[
          const SizedBox(height: 14),
          GestureDetector(
            onTap: _showDisconnectDialog,
            child: const Text(
              "Disconnect",
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildProfilePhoto(User user) {
    if (user.profilePhotoUrl.isEmpty) {
      return CircleAvatar(
        radius: 45,
        backgroundColor: Colors.grey.shade400,
        child: const Icon(Icons.person, size: 40, color: Colors.white),
      );
    }
    return CircleAvatar(
      radius: 45,
      backgroundColor: Colors.grey.shade400,
      backgroundImage: NetworkImage(user.profilePhotoUrl),
      onBackgroundImageError: (_, _) {
        // fallback to icon if image fails
      },
      child: Container(),
    );
  }

  Widget _buildPostCard(BuildContext context, Map<String, dynamic> post) {
    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PostDetailsPage(postData: post),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.15),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              child: Image.asset(
                post["image"],
                height: 100,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                post["title"],
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
