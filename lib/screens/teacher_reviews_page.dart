import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studently/app_style.dart';
import 'package:studently/logger.dart';
import 'package:studently/models/teachers.dart';
import 'package:studently/providers/teachers_provider.dart';
import 'package:studently/screens/profile_main.dart';
import 'package:studently/services/firebase_auth.dart';
import 'package:studently/services/analytics_service.dart';
import 'package:studently/utils/web_utils.dart' as web_utils;
import 'package:url_launcher/url_launcher.dart';

class TeacherReviewsPage extends ConsumerStatefulWidget {
  final String teacherId;

  const TeacherReviewsPage({super.key, required this.teacherId});

  @override
  ConsumerState<TeacherReviewsPage> createState() => _TeacherReviewsPageState();
}

class _TeacherReviewsPageState extends ConsumerState<TeacherReviewsPage> {
  final TextEditingController _reviewController = TextEditingController();
  int _rating = 0;
  bool _isSending = false;
  String? _formError;
  bool _isAnonymous = false;

  @override
  void initState() {
    super.initState();
    unawaited(
      AnalyticsService.logEvent(
        AnalyticsEvents.teacherOpen,
        parameters: {
          'teacher_id': widget.teacherId,
          'source': 'teacher_reviews_page',
        },
      ),
    );
  }

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  Future<void> _submitReview() async {
    final content = _reviewController.text.trim();
    if (content.isEmpty) {
      setState(() => _formError = 'Write a review before submitting.');
      return;
    }
    if (_rating == 0) {
      setState(() => _formError = 'Select a rating first.');
      return;
    }

    setState(() {
      _isSending = true;
      _formError = null;
    });

    try {
      await ref.read(teacherDetailProvider(widget.teacherId).notifier).addReview(
            TeacherReviewCreateRequest(
              content: content,
              rating: _rating,
              anonymous: _isAnonymous,
            ),
          );
      if (!mounted) return;
      _reviewController.clear();
      setState(() {
        _rating = 0;
        _isAnonymous = false;
      });
    } catch (e) {
      if (!mounted) return;
      final errorText = e.toString().toLowerCase();
      final friendlyMessage = errorText.contains('409') ||
              errorText.contains('already reviewed') ||
              errorText.contains('already added a review')
          ? 'You have already added a review for this teacher.'
          : 'Failed to add review. Please try again.';
      setState(() => _formError = friendlyMessage);
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  void _openProfile(String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProfilePage(userId: userId)),
    );
  }

  Future<bool?> _showDeleteConfirmation() {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete review?',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
        ),
        content: const Text(
          'This review will be removed permanently.',
          style: TextStyle(fontSize: 14, color: Colors.grey),
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openLinkedIn(String? url) async {
    if (url == null || url.trim().isEmpty) return;
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } else {
      logger.e("Could not launch $url");
    }
  }

  String _displayName(Teacher teacher) {
    return '${teacher.title} ${teacher.name}'.trim();
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(teacherDetailProvider(widget.teacherId));

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text(
          'Reviews',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
            fontSize: AppStyle.appBarTitleSize,
          ),
        ),
        actions: [
          if (kIsWeb && !web_utils.isStandalonePwa())
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.black),
              onPressed: () => ref.read(
                teacherDetailProvider(widget.teacherId).notifier,
              ).refresh(),
            ),
        ],
      ),
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => _buildErrorState(),
        data: (state) {
          return Column(
            children: [
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () =>
                      ref.read(teacherDetailProvider(widget.teacherId).notifier).refresh(),
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 16),
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      _buildTeacherHeader(state.teacher),
                      const SizedBox(height: 4),
                      if (state.reviews.isEmpty)
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.42,
                          child: Center(
                            child: Text(
                              'No reviews yet',
                              style: TextStyle(
                                color: Colors.grey,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        )
                      else
                        ...state.reviews.map(_buildReviewTile),
                    ],
                  ),
                ),
              ),
              SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: Colors.grey.shade200)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Rating',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(width: 10),
                          ...List.generate(5, (index) {
                            final star = index + 1;
                            final selected = star <= _rating;
                            return IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              visualDensity: VisualDensity.compact,
                              onPressed: () {
                                setState(() {
                                  _rating = star;
                                  _formError = null;
                                });
                              },
                              icon: Icon(
                                selected
                                    ? Icons.star_rounded
                                    : Icons.star_border_rounded,
                                color: selected
                                    ? Colors.amber[700]
                                    : Colors.grey.shade400,
                                size: 30,
                              ),
                            );
                          }),
                          const Spacer(),
                          Switch.adaptive(
                            value: _isAnonymous,
                            activeThumbColor: AppStyle.primaryBlue,
                            activeTrackColor: Colors.white,
                            inactiveTrackColor: Colors.white,
                            inactiveThumbColor: Colors.grey.shade400,
                            trackOutlineColor: WidgetStatePropertyAll(
                              Colors.grey.shade300,
                            ),
                            onChanged: (value) {
                              setState(() {
                                _isAnonymous = value;
                                _formError = null;
                              });
                            },
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Anonymous',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      if (_formError != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          _formError!,
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _reviewController,
                              minLines: 1,
                              maxLines: 4,
                              keyboardType: TextInputType.multiline,
                              textInputAction: TextInputAction.newline,
                              onChanged: (_) {
                                if (_formError != null) {
                                  setState(() => _formError = null);
                                }
                              },
                              decoration: InputDecoration(
                                hintText: 'Add a review...',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(18),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(18),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(18),
                                  borderSide: const BorderSide(
                                    color: AppStyle.primaryBlue,
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                  horizontal: 16,
                                ),
                                filled: true,
                                fillColor: const Color(0xFFFAFAFB),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            height: 50,
                            width: 50,
                            child: ElevatedButton(
                              onPressed: _isSending ? null : _submitReview,
                              style: ElevatedButton.styleFrom(
                                padding: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: _isSending
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.send_rounded),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTeacherHeader(Teacher teacher) {
    final hasLinkedIn =
        teacher.linkedinProfile != null && teacher.linkedinProfile!.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTeacherAvatar(teacher),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _displayName(teacher),
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 20,
                          height: 1.15,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        teacher.department.name,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                        ),
                      ),
                      if (teacher.campus.name.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          teacher.campus.name,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                      if ((teacher.email ?? '').isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          teacher.email!,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: _buildRatingStars(teacher.rating, size: 30),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      teacher.rating.toStringAsFixed(1),
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (hasLinkedIn) ...[
                  OutlinedButton.icon(
                    onPressed: () => _openLinkedIn(teacher.linkedinProfile),
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: const Text('LinkedIn'),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.grey.shade300),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${teacher.reviewCount} reviews',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildRatingStars(double rating, {double size = 22}) {
    final normalized = rating.clamp(0, 5);
    final fullStars = normalized.floor();
    final hasHalf = normalized - fullStars >= 0.25;

    return List.generate(5, (index) {
      final isFull = index < fullStars;
      final isHalf = index == fullStars && hasHalf;
      final icon = isFull
          ? Icons.star_rounded
          : isHalf
              ? Icons.star_half_rounded
              : Icons.star_border_rounded;

      return Icon(
        icon,
        size: size,
        color: (isFull || isHalf) ? Colors.amber[700] : Colors.grey.shade400,
      );
    });
  }

  Widget _buildTeacherAvatar(Teacher teacher) {
    final photoUrl = teacher.profile;
    final hasPicture = photoUrl != null && photoUrl.isNotEmpty;

    return ClipOval(
      child: SizedBox(
        width: 100,
        height: 100,
        child: hasPicture
          ? CachedNetworkImage(
            imageUrl: photoUrl,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
          )
          : Container(
              color: Colors.grey[200],
              child: const Icon(
                Icons.person_rounded,
                color: Colors.grey,
              ),
            ),
      ),
    );
  }
  Widget _buildReviewTile(TeacherReview review) {
    final photoUrl = review.profile ?? review.authorPic;
    final hasPicture = photoUrl != null && photoUrl.isNotEmpty;
    final currentUid = authService.value.currentUser?.uid;
    final isOwnReview = currentUid != null && review.authorId == currentUid;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: review.anonymous ? null : () => _openProfile(review.authorId),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: Colors.grey.shade200,
                    backgroundImage: hasPicture
                        ? CachedNetworkImageProvider(photoUrl)
                        : null,
                    child: hasPicture
                        ? null
                        : const Icon(
                            Icons.person_rounded,
                            color: Colors.grey,
                            size: 20,
                          ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          review.authorName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            ...List.generate(5, (index) {
                              final filled = index < review.rating;
                              return Icon(
                                filled
                                    ? Icons.star_rounded
                                    : Icons.star_border_rounded,
                                size: 16,
                                color: filled
                                    ? Colors.amber[700]
                                : Colors.grey.shade400,
                              );
                            }),
                          ]
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _formatTime(review.timestamp),
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 12,
                            ),
                          ),
                          if (isOwnReview) ...[
                            const SizedBox(width: 4),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              icon: Icon(
                                Icons.delete_outline_rounded,
                                size: 18,
                                color: Colors.red.shade400,
                              ),
                              onPressed: () async {
                                final confirmed = await _showDeleteConfirmation();
                                if (confirmed != true) return;
                                try {
                                  await ref
                                      .read(
                                        teacherDetailProvider(widget.teacherId).notifier,
                                      )
                                      .deleteReview(review.id);
                                } catch (e) {
                                  if (!mounted) return;
                                  setState(() => _formError = 'Failed to delete review: $e');
                                }
                              },
                            ),
                          ],
                        ],
                      ),
                      if (isOwnReview) ...[
                        const SizedBox(height: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: review.approved
                                ? Colors.green.shade50
                                : Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: review.approved
                                  ? Colors.green.shade200
                                  : Colors.orange.shade200,
                            ),
                          ),
                          child: Text(
                            review.approved ? 'Approved' : 'Pending',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: review.approved
                                  ? Colors.green.shade700
                                  : Colors.orange.shade800,
                            ),
                          ),
                        ),
                      ],
                    
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                review.content,
                style: const TextStyle(fontSize: 14.5, height: 1.45),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.isNegative) return "Just now";
    if (diff.inMinutes < 60) return "${diff.inMinutes}m ago";
    if (diff.inHours < 24) return "${diff.inHours}h ago";
    return "${diff.inDays}d ago";
  }

  Widget _buildErrorState() {
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
                onPressed: () =>
                    ref.read(teacherDetailProvider(widget.teacherId).notifier).refresh(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppStyle.primaryBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                child: const Text(
                  "Try Again",
                  style: TextStyle(fontSize: 18, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
