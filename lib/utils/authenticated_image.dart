import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:studently/services/firebase_auth.dart';
import 'package:studently/logger.dart';

/// Custom Image Provider that includes authentication headers
class AuthenticatedNetworkImage
    extends ImageProvider<AuthenticatedNetworkImage> {
  final String url;
  final double scale;

  const AuthenticatedNetworkImage(this.url, {this.scale = 1.0});

  @override
  Future<AuthenticatedNetworkImage> obtainKey(
    ImageConfiguration configuration,
  ) {
    return Future<AuthenticatedNetworkImage>.value(this);
  }

  @override
  ImageStreamCompleter loadImage(
    AuthenticatedNetworkImage key,
    ImageDecoderCallback decode,
  ) {
    return OneFrameImageStreamCompleter(_loadImageAsync(key, decode));
  }

  Future<ImageInfo> _loadImageAsync(
    AuthenticatedNetworkImage key,
    ImageDecoderCallback decode,
  ) async {
    try {
      // Check if this is a public URL (like Google CDN) that doesn't need auth
      final isPublicUrl = _isPublicUrl(key.url);
      
      // Get auth headers only for non-public URLs
      final headers = isPublicUrl ? {} : await _getAuthHeaders();

      // Make HTTP request with auth headers (if needed)
      final response = await http.get(Uri.parse(key.url), headers: headers);

      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
        final imageDescriptor = await ui.ImageDescriptor.encoded(buffer);
        final codec = await imageDescriptor.instantiateCodec();
        final frame = await codec.getNextFrame();

        return ImageInfo(image: frame.image, scale: key.scale);
      } else {
        throw NetworkImageLoadException(
          statusCode: response.statusCode,
          uri: Uri.parse(key.url),
        );
      }
    } catch (e) {
      logger.e("Error loading authenticated image: $e");
      rethrow;
    }
  }

  /// Check if URL is from a public CDN that doesn't need authentication
  bool _isPublicUrl(String url) {
    final publicDomains = [
      'lh3.googleusercontent.com',  // Google profile photos
      'googleapis.com',
      'gstatic.com',
      'cloudflare.com',
    ];
    
    return publicDomains.any((domain) => url.contains(domain));
  }

  Future<Map<String, String>> _getAuthHeaders() async {
    final user = authService.value.currentUser;

    if (user == null) {
      return {"Content-Type": "application/json"};
    }

    final token = await user.getIdToken();

    return {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthenticatedNetworkImage &&
          runtimeType == other.runtimeType &&
          url == other.url &&
          scale == other.scale;

  @override
  int get hashCode => url.hashCode ^ scale.hashCode;

  @override
  String toString() => '$runtimeType("$url", scale: $scale)';
}
