import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:studently/repositories/user.dart';
import 'package:studently/logger.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'dart:typed_data';


class ProfilePhotoCropScreen extends StatefulWidget {
  final XFile initialImage;

  const ProfilePhotoCropScreen({
    Key? key,
    required this.initialImage,
  }) : super(key: key);

  @override
  State<ProfilePhotoCropScreen> createState() => _ProfilePhotoCropScreenState();
}

class _ProfilePhotoCropScreenState extends State<ProfilePhotoCropScreen> {
  late XFile? _croppedImage;
  late Uint8List? _imageBytes;
  bool _isUploading = false;
  Offset _imageOffset = const Offset(-50, -50); // Centered offset for 350x350 image in 250x250 circle

  @override
  void initState() {
    super.initState();
    _croppedImage = widget.initialImage;
    _imageBytes = null;
    _initializeImage();
  }

  Future<void> _initializeImage() async {
    try {
      final bytes = await widget.initialImage.readAsBytes();
      setState(() {
        _imageBytes = bytes;
        _imageOffset = const Offset(-50, -50); // Reset to centered position
      });
      
      // Only crop on native platforms, skip on web
      if (!kIsWeb) {
        await _cropImage();
      }
    } catch (e) {
      logger.e("Error initializing image: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error loading image: $e")),
        );
      }
    }
  }

  Future<void> _cropImage() async {
    // Skip cropping on web
    if (kIsWeb) {
      logger.i("Skipping image crop on web platform");
      return;
    }

    logger.i("Starting image crop");
    try {
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: widget.initialImage.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Profile Photo',
            toolbarColor: const Color(0xFF1976D2),
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
            hideBottomControls: false,
          ),
          IOSUiSettings(
            title: 'Crop Profile Photo',
            resetAspectRatioEnabled: false,
          ),
        ],
      );

      if (croppedFile != null) {
        final croppedBytes = await XFile(croppedFile.path).readAsBytes();
        setState(() {
          _croppedImage = XFile(croppedFile.path);
          _imageBytes = croppedBytes;
          _imageOffset = const Offset(-50, -50); // Reset to centered position
        });
        logger.i("Image cropped successfully");
      }
    } catch (e) {
      logger.e("Error cropping image: $e");
      // On web or if crop fails, just use the original image
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Crop cancelled, using original image")),
        );
      }
    }
  }

  Future<void> _uploadPhoto() async {
    if (_croppedImage == null || _imageBytes == null) return;

    setState(() {
      _isUploading = true;
    });

    try {
      await UserRepository().uploadProfilePhoto(
        filePath: _croppedImage!.path,
        fileBytes: _imageBytes,
        filename: _croppedImage!.name,
      );

      logger.i("Profile photo uploaded successfully");

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Profile photo updated successfully!"),
          duration: Duration(seconds: 2),
        ),
      );

      // Return to previous screen with success
      Navigator.of(context).pop(true);
    } catch (e) {
      logger.e("Error uploading photo: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error uploading photo: $e")),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    setState(() {
      // Clamp between -150 and 50 to keep image visible in the 250x250 circle
      _imageOffset = Offset(
        (_imageOffset.dx + details.delta.dx).clamp(-150.0, 50.0),
        (_imageOffset.dy + details.delta.dy).clamp(-150.0, 50.0),
      );
    });
  }

  void _handlePanEnd(DragEndDetails details) {
    // Optionally add snap-back animation or deceleration
    // For now, we keep the offset where it was released
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Edit Profile Photo"),
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _imageBytes == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Preview circle showing how it will look (Instagram-style circular mask)
                Expanded(
                  child: Center(
                    child: GestureDetector(
                      onPanUpdate: _handlePanUpdate,
                      onPanEnd: _handlePanEnd,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Layer 1: Full image that can be dragged
                          Transform.translate(
                            offset: _imageOffset,
                            child: kIsWeb
                                ? Image.memory(
                                    _imageBytes!,
                                    width: 350,
                                    height: 350,
                                    fit: BoxFit.cover,
                                  )
                                : Image.file(
                                    File(_croppedImage!.path),
                                    width: 350,
                                    height: 350,
                                    fit: BoxFit.cover,
                                  ),
                          ),
                          // Layer 2: Dark overlay with circular hole (greyed out area)
                          IgnorePointer(
                            child: CustomPaint(
                              painter: CircularMaskPainter(
                                circleRadius: 125, // radius of the visible circle
                              ),
                              size: const Size(350, 350),
                            ),
                          ),
                          // Layer 3: White border circle frame
                          IgnorePointer(
                            child: Container(
                              width: 250,
                              height: 250,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Helper text
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Text(
                    'Drag to reposition your photo',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
                // Action buttons
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // Re-crop button (only on native platforms)
                      if (!kIsWeb)
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _isUploading ? null : _cropImage,
                            icon: const Icon(Icons.crop),
                            label: const Text("Adjust Photo"),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              foregroundColor: const Color(0xFF1976D2),
                              side: const BorderSide(
                                color: Color(0xFF1976D2),
                              ),
                            ),
                          ),
                        ),
                      if (!kIsWeb) const SizedBox(height: 12),
                      // Upload button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isUploading ? null : _uploadPhoto,
                          icon: _isUploading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : const Icon(Icons.cloud_upload),
                          label: Text(_isUploading
                              ? "Uploading..."
                              : "Upload & Save"),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            backgroundColor: const Color(0xFF1976D2),
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

/// CustomPainter that creates a circular mask with greyed out area around it
class CircularMaskPainter extends CustomPainter {
  final double circleRadius;

  CircularMaskPainter({required this.circleRadius});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    
    // Use saveLayer for proper compositing
    canvas.saveLayer(Rect.fromLTWH(0, 0, size.width, size.height), Paint());
    
    // Draw grey overlay on entire canvas
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = Colors.black.withOpacity(0.6),
    );
    
    // Clear the circle area by drawing a transparent circle
    canvas.drawCircle(
      center,
      circleRadius,
      Paint()..blendMode = BlendMode.clear,
    );
    
    canvas.restore();
  }

  @override
  bool shouldRepaint(CircularMaskPainter oldDelegate) {
    return oldDelegate.circleRadius != circleRadius;
  }
}
