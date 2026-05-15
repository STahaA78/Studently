import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:studently/app_style.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studently/providers/feed_provider.dart';
import 'package:studently/services/firebase_auth.dart';
import 'package:studently/screens/photo_crop.dart';

class CreatePostPage extends ConsumerStatefulWidget {
  const CreatePostPage({super.key});

  @override
  ConsumerState<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends ConsumerState<CreatePostPage> {
  final TextEditingController controller = TextEditingController();

  XFile? selectedImage;
  Uint8List? selectedImageBytes;
  double? selectedImageAspectRatio;
  final ImagePicker picker = ImagePicker();

  bool isPosting = false;

  /// PICK IMAGE
  Future<void> pickImage() async {
    final picked = await picker.pickImage(source: ImageSource.gallery);

    if (picked == null || !mounted) return;

    final croppedResult = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (context) => PostPhotoCropScreen(initialImage: picked),
      ),
    );

    if (croppedResult != null && mounted) {
      final croppedImageBytes = croppedResult['bytes'] as Uint8List?;
      final aspectRatio = croppedResult['aspectRatio'] as double?;

      if (croppedImageBytes != null) {
        final fallbackName =
            'post_${DateTime.now().millisecondsSinceEpoch}.png';
        final fileName = picked.name.isNotEmpty ? picked.name : fallbackName;

        setState(() {
          selectedImageBytes = croppedImageBytes;
          selectedImageAspectRatio = aspectRatio;
          selectedImage = XFile.fromData(
            croppedImageBytes,
            name: fileName.endsWith('.png') ? fileName : '$fileName.png',
            mimeType: 'image/png',
          );
        });
      }
    }
  }

  void clearImage() {
    setState(() {
      selectedImage = null;
      selectedImageBytes = null;
      selectedImageAspectRatio = null;
    });
  }

  /// SUBMIT POST
  Future<void> submitPost() async {
    final text = controller.text.trim();

    if (text.isEmpty && selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Post must contain text or image")),
      );
      return;
    }

    setState(() {
      isPosting = true;
    });

    try {
      final repository = ref.read(postRepositoryProvider);
      await repository.createPost(text, selectedImage, selectedImageAspectRatio);

      // Trigger global refresh to sync Feed and Profile
      ref.read(feedProvider.notifier).refresh();
      final userId = authService.value.currentUser?.uid;
      if (userId != null) {
        ref.read(profileFeedProvider(userId).notifier).refresh();
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Failed to create post")));
    }

    setState(() {
      isPosting = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Create Post", style: TextStyle(color: Colors.black)),
        actions: [
          TextButton(
            onPressed: isPosting ? null : submitPost,
            child: isPosting
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    "Post",
                    style: TextStyle(
                      color: AppStyle.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
          ),

          const SizedBox(width: 10),
        ],
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              /// POST TEXT
              TextField(
                controller: controller,
                minLines: 6,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                textAlignVertical: TextAlignVertical.top,
                decoration: const InputDecoration(
                  hintText: "What's on your mind?",
                  fillColor: Colors.white,
                  filled: true,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 12),

              /// IMAGE PREVIEW
              if (selectedImageBytes != null)
                Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: kIsWeb ? 640 : double.infinity,
                    ),
                    child: Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        children: [
                          AspectRatio(
                            aspectRatio: selectedImageAspectRatio ?? 4 / 5,
                            child: Image.memory(
                              selectedImageBytes!,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            left: 8,
                            top: 8,
                            child: IconButton(
                              onPressed: clearImage,
                              icon: const Icon(Icons.close, color: Colors.white),
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.black54,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              /// IMAGE PICK BUTTON
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  icon: const Icon(
                    Icons.image,
                    color: AppStyle.textPrimary,
                    size: 28,
                  ),
                  onPressed: pickImage,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
