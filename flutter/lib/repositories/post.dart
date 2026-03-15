import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../models/post.dart';
import '../services/api.dart';
import '../auth_service.dart';

class PostRepository {

  final ApiService api = ApiService();

  /// GET FEED
Future<List<Post>> getFeed({int skip = 0, int limit = 10}) async {

  final token = await authService.value.getIdToken();

  final uri = Uri.parse(
    api.getCompleteUrl("/feed"),
  ).replace(
    queryParameters: {
      "skip": skip.toString(),
      "limit": limit.toString(),
    },
  );

  final response = await http.get(
    uri,
    headers: {
      "Authorization": "Bearer $token",
      "Content-Type": "application/json",
    },
  );

  final List data = jsonDecode(response.body);

  return data.map((e) => Post.fromJson(e)).toList();
}

  /// LIKE POST
  Future<void> likePost(String postId) async {

    final token = await authService.value.getIdToken();

    await http.post(
      Uri.parse(api.getCompleteUrl("/feed/$postId/like")),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json"
      },
    );
  }

  /// ADD COMMENT
  Future<void> addComment(String postId, String text) async {

    final token = await authService.value.getIdToken();

    await http.post(
      Uri.parse(api.getCompleteUrl("/feed/$postId/comment")),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json"
      },
      body: jsonEncode({
        "content": text
      }),
    );
  }

  /// DELETE COMMENT
  Future<void> deleteComment(String postId, int commentIndex) async {

    final token = await authService.value.getIdToken();

    final response = await http.delete(
      Uri.parse(api.getCompleteUrl("/feed/$postId/comment/$commentIndex")),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json"
      },
    );

    if (response.statusCode != 200) {
      throw Exception("Failed to delete comment");
    }
  }

  /// CREATE POST (TEXT + IMAGE)
Future<void> createPost(String content, XFile? image) async {

  final token = await authService.value.getIdToken();

  var request = http.MultipartRequest(
    "POST",
    Uri.parse(api.getCompleteUrl("/feed/")),
  );

  request.headers["Authorization"] = "Bearer $token";

  request.fields["content"] = content;

  if (image != null) {
    request.files.add(
      await http.MultipartFile.fromBytes(
        "file",
        await image.readAsBytes(),
        filename: image.name,
      ),
    );
  }

  final response = await request.send();

  if (response.statusCode != 200) {
    final resp = await http.Response.fromStream(response);
    print(resp.body);
    throw Exception("Failed to create post");
  }
}

//Delete post 
Future<void> deletePost(String postId) async {

  final token = await authService.value.getIdToken();

  final response = await http.delete(
    Uri.parse(api.getCompleteUrl("/feed/$postId")),
    headers: {
      "Authorization": "Bearer $token",
      "Content-Type": "application/json"
    },
  );

  if (response.statusCode != 200) {
    throw Exception("Failed to delete post");
  }

}
//Edit post
Future<void> editPost(String postId, String content) async {

  final token = await authService.value.getIdToken();

  final response = await http.put(
    Uri.parse(api.getCompleteUrl("/feed/$postId")),
    headers: {
      "Authorization": "Bearer $token",
      "Content-Type": "application/json",
    },
    body: jsonEncode({
      "content": content
    }),
  );

  if (response.statusCode != 200) {
    throw Exception("Failed to update post");
  }

}
}