import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../models/post.dart';
import '../services/api.dart';
import 'package:studently/services/firebase_auth.dart'; 
import 'package:studently/logger.dart';

class PostRepository {

  final ApiService api = ApiService();

  /// GET FEED
  Future<List<Post>> getFeed({int skip = 0, int limit = 10}) async {

    final response = await api.get(
      '/feed?limit=$limit&skip=$skip',
    );

    final List<dynamic> jsonData = jsonDecode(response.body);
      
    return jsonData.map((e) => Post.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// LIKE POST
  Future<void> likePost(String postId) async {
    await api.post("/feed/$postId/like");
  }

  /// ADD COMMENT
  Future<void> addComment(String postId, String text) async {
    await api.post(
      "/feed/$postId/comment",
      body: {"content": text},
    );
  }

  /// DELETE COMMENT
  Future<void> deleteComment(String postId, int commentIndex) async {
    await api.delete("/feed/$postId/comment/$commentIndex");
  }

  /// CREATE POST (TEXT + IMAGE)
  Future<Post> createPost(String content, XFile? image, {String? currentUserName, String? currentUserPic}) async {

    final token = await authService.value.getIdToken();

    var request = http.MultipartRequest(
      "POST",
      Uri.parse(api.getCompleteUrl("/feed/")),
    );

    request.headers["Authorization"] = "Bearer $token";

    request.fields["content"] = content;

    if (image != null) {
      request.files.add(
        http.MultipartFile.fromBytes(
          "file",
          await image.readAsBytes(),
          filename: image.name,
        ),
      );
    }

    final response = await request.send();

    final responseData = await http.Response.fromStream(response);
    
    if (response.statusCode != 200 && response.statusCode != 201) {
      logger.e("[$runtimeType] Create Post Failed: ${responseData.body}");
      throw Exception("Failed to create post: ${response.statusCode}");
    }

    final Map<String, dynamic> jsonData = jsonDecode(responseData.body);
    
    // PATCH: If backend doesn't return author info, use provided current user info
    if ((jsonData["author_name"] == null || jsonData["author_name"] == "") && currentUserName != null) {
      jsonData["author_name"] = currentUserName;
    }
    if ((jsonData["author_pic"] == null || jsonData["author_pic"] == "") && currentUserPic != null) {
      jsonData["author_pic"] = currentUserPic;
    }

    return Post.fromJson(jsonData);
  }

  /// DELETE POST
  Future<void> deletePost(String postId) async {
    await api.delete("/feed/$postId");
  }

  /// EDIT POST
  Future<void> editPost(String postId, String content) async {
    await api.put(
      "/feed/$postId",
      body: {"content": content},
    );
  }
}
