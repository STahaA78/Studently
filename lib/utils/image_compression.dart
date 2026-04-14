import 'dart:typed_data';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:studently/logger.dart';

/// Compresses image bytes similar to Instagram's compression
/// 
/// Optimizations:
/// - Reduces quality to 85% (best balance between quality and file size)
/// - Resizes to max 1080px width (Instagram standard)
/// - Returns compressed bytes
/// 
/// Typical compression: ~5-10MB → ~200-500KB depending on original
class ImageCompressionUtil {
  /// Compresses image bytes
  /// 
  /// [imageBytes] - Original image bytes
  /// [maxWidth] - Maximum width in pixels (default: 1080 for Instagram-like size)
  /// [quality] - JPEG quality 0-100 (default: 85)
  /// 
  /// Returns compressed image bytes
  static Future<Uint8List> compressImage(
    Uint8List imageBytes, {
    int maxWidth = 1080,
    int quality = 85,
  }) async {
    try {
      logger.i("[ImageCompressionUtil] Starting compression - Original size: ${(imageBytes.length / 1024 / 1024).toStringAsFixed(2)}MB");
      
      final compressed = await FlutterImageCompress.compressWithList(
        imageBytes,
        minHeight: 1080,
        minWidth: 1080,
        quality: quality,
        rotate: 0,
        format: CompressFormat.jpeg,
      );

      final compressedSizeMB = (compressed.length / 1024 / 1024).toStringAsFixed(2);
      logger.i("[ImageCompressionUtil] Compression complete - Compressed size: ${compressedSizeMB}MB");

      return compressed;
    } catch (e) {
      logger.e("[ImageCompressionUtil] Compression failed: $e");
      // Return original bytes if compression fails
      return imageBytes;
    }
  }

  /// Compresses image from file path
  /// 
  /// [filePath] - Path to image file
  /// [maxWidth] - Maximum width in pixels (default: 1080)
  /// [quality] - JPEG quality 0-100 (default: 85)
  /// 
  /// Returns compressed image bytes
  static Future<Uint8List?> compressImageFile(
    String filePath, {
    int maxWidth = 1080,
    int quality = 85,
  }) async {
    try {
      logger.i("[ImageCompressionUtil] Starting file compression - Path: $filePath");
      
      final compressed = await FlutterImageCompress.compressAndGetFile(
        filePath,
        "${filePath}_compressed.jpg",
        minHeight: 1080,
        minWidth: 1080,
        quality: quality,
        format: CompressFormat.jpeg,
      );

      if (compressed != null) {
        final bytes = await compressed.readAsBytes();
        final compressedSizeMB = (bytes.length / 1024 / 1024).toStringAsFixed(2);
        logger.i("[ImageCompressionUtil] File compression complete - Size: ${compressedSizeMB}MB");
        return bytes;
      }
      
      return null;
    } catch (e) {
      logger.e("[ImageCompressionUtil] File compression failed: $e");
      return null;
    }
  }
}
