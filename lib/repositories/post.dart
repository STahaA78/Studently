import 'dart:convert';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import '../models/post.dart';
import '../services/api.dart';
import 'package:studently/logger.dart';
import 'package:studently/utils/image_compression.dart';

/// Repository for handling all Post and Feed related API operations
class PostRepository {
  final ApiService _apiService = ApiService();

  /// Retrieves the social feed with pagination
  Future<List<Post>> getFeed({int skip = 0, int limit = 10}) async {
    logger.i("[$runtimeType] Get Feed Initiated (skip: $skip, limit: $limit)");
    try {
      final response = await _apiService.get('/feed/?limit=$limit&skip=$skip');

      final List<dynamic> jsonData = jsonDecode(response.body);

      logger.i("[$runtimeType] Get Feed Completed Successfully");
      return jsonData
          .map((e) => Post.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      logger.e("[$runtimeType] Get Feed Failed with error: $e");
      rethrow;
    }
  }

  Future<Post> getPostById(String postId) async {
    final response = await _apiService.get('/feed/$postId');
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return Post.fromJson(data);
  }

  /// Likes a specific post by its ID
  Future<void> likePost(String postId) async {
    logger.i("[$runtimeType] Like Post Initiated for postId: $postId");
    try {
      await _apiService.post("/feed/$postId/like");
      logger.i("[$runtimeType] Like Post Completed Successfully");
    } catch (e) {
      logger.e("[$runtimeType] Like Post Failed with error: $e");
      rethrow;
    }
  }

  /// Adds a comment to a specific post
  Future<void> addComment(String postId, String text) async {
    logger.i("[$runtimeType] Add Comment Initiated for postId: $postId");
    try {
      await _apiService.post("/feed/$postId/comment", body: {"content": text});
      logger.i("[$runtimeType] Add Comment Completed Successfully");
    } catch (e) {
      logger.e("[$runtimeType] Add Comment Failed with error: $e");
      rethrow;
    }
  }

  /// Deletes a specific comment from a post
  Future<void> deleteComment(String postId, int commentIndex) async {
    logger.i(
      "[$runtimeType] Delete Comment Initiated for postId: $postId, index: $commentIndex",
    );
    try {
      await _apiService.delete("/feed/$postId/comment/$commentIndex");
      logger.i("[$runtimeType] Delete Comment Completed Successfully");
    } catch (e) {
      logger.e("[$runtimeType] Delete Comment Failed with error: $e");
      rethrow;
    }
  }

  /// Creates a new post with optional image content
  Future<void> createPost(String content, XFile? image, double? aspectRatio) async {
    logger.i("[$runtimeType] Create Post Initiated");
    try {
      if (image != null) {
        final originalBytes = await image.readAsBytes();
        final compressedBytes = await ImageCompressionUtil.compressImage(
          Uint8List.fromList(originalBytes),
          quality: 85,
        );

        final rawName = image.name.isNotEmpty ? image.name : 'post.jpg';
        final filename = rawName.endsWith('.jpg') || rawName.endsWith('.jpeg')
            ? rawName
            : '${rawName.split('.').first}.jpg';

        final formFields = {
          'content': content,
          if (aspectRatio != null) 'media_aspect_ratio': aspectRatio.toString(),
        };

        final response = await _apiService.multiPartFromBytes(
          endpoint: "/feed/",
          fileBytes: compressedBytes,
          filename: filename,
          formFields: formFields,
        );

        if (response.statusCode != 200 && response.statusCode != 201) {
          logger.e(
            "[$runtimeType] Create Post Request failed ${response.statusCode} body: ${response.body}",
          );
          throw Exception("Failed to create post: ${response.statusCode}");
        }

        logger.i("[$runtimeType] Create Post (with image) Completed Successfully");
      } else {
        // FIXED: Handle text-only posts
        final response = await _apiService.post(
          "/feed/", 
          body: {"content": content}
        );
        
        if (response.statusCode != 200 && response.statusCode != 201) {
          logger.e(
            "[$runtimeType] Create text Post Request failed ${response.statusCode}",
          );
          throw Exception("Failed to create text post: ${response.statusCode}");
        }
        
        logger.i("[$runtimeType] Create Post (text-only) Completed Successfully");
      }
    } catch (e) {
      logger.e("[$runtimeType] Create Post Failed with error: $e");
      rethrow;
    }
  }

  /// Deletes a specific post by its ID
  Future<void> deletePost(String postId) async {
    logger.i("[$runtimeType] Delete Post Initiated for postId: $postId");
    try {
      await _apiService.delete("/feed/$postId");
      logger.i("[$runtimeType] Delete Post Completed Successfully");
    } catch (e) {
      logger.e("[$runtimeType] Delete Post Failed with error: $e");
      rethrow;
    }
  }

  /// Edits the content of an existing post
  Future<void> editPost(String postId, String content) async {
    logger.i("[$runtimeType] Edit Post Initiated for postId: $postId");
    try {
      await _apiService.put("/feed/$postId", body: {"content": content});
      logger.i("[$runtimeType] Edit Post Completed Successfully");
    } catch (e) {
      logger.e("[$runtimeType] Edit Post Failed with error: $e");
      rethrow;
    }
  }
}