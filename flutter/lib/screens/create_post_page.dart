import 'package:flutter/material.dart';
import '../repositories/post.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';
class CreatePostPage extends StatefulWidget {
  const CreatePostPage({super.key});

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {

  final TextEditingController controller = TextEditingController();
  final PostRepository repository = PostRepository();

  XFile? selectedImage;
  final ImagePicker picker = ImagePicker();

  bool isPosting = false;

  /// PICK IMAGE
  Future<void> pickImage() async {

    final picked = await picker.pickImage(
      source: ImageSource.gallery,
    );

    if (picked != null) {
      setState(() {
        selectedImage = picked;
      });
    }

  }

  /// SUBMIT POST
  Future<void> submitPost() async {

    final text = controller.text.trim();

    if (text.isEmpty && selectedImage == null){
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text("Post must contain text or image"),
            ),
        );
        return ;
    }

    setState(() {
      isPosting = true;
    });

    try {

      await repository.createPost(text, selectedImage);

      Navigator.pop(context, true);

    } catch (e) {

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Failed to create post"),
        ),
      );

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
        title: const Text(
          "Create Post",
          style: TextStyle(color: Colors.black),
        ),
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
                      color: Color(0xFF1976D2),
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
          ),

          const SizedBox(width: 10)

        ],
      ),

      body: Padding(
        padding: const EdgeInsets.all(16),

        child: Column(
          children: [

            /// POST TEXT
            Expanded(
              child: TextField(
                controller: controller,
                maxLines: null,
                expands: true,
                keyboardType: TextInputType.multiline,
                decoration: const InputDecoration(
                  hintText: "What's on your mind?",
                  border: InputBorder.none,
                ),
                style: const TextStyle(fontSize: 18),
              ),
            ),

            /// IMAGE PREVIEW
            if (selectedImage != null)
                Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                        selectedImage!.path,
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                    ),
                    ),
                ),

            /// IMAGE PICK BUTTON
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                icon: const Icon(
                  Icons.image,
                  color: Color(0xFF1976D2),
                  size: 28,
                ),
                onPressed: pickImage,
              ),
            ),

          ],
        ),
      ),
    );
  }
}