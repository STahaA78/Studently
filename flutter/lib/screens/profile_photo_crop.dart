import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:studently/logger.dart';
import 'package:flutter/foundation.dart';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

class ProfilePhotoCropScreen extends StatefulWidget {
  final XFile initialImage;

  const ProfilePhotoCropScreen({super.key, required this.initialImage});

  @override
  State<ProfilePhotoCropScreen> createState() => _ProfilePhotoCropScreenState();
}

class _ProfilePhotoCropScreenState extends State<ProfilePhotoCropScreen> {
  Uint8List? _imageBytes;
  ui.Image? _decodedImage; // decoded image for pixel-accurate cropping

  // Display constants
  static const double _displaySize = 350.0;
  static const double _circleRadius = 125.0; // visible circle = 250x250 px

  Offset _imageOffset = Offset.zero;

  @override
  void initState() {
    super.initState();
    _initializeImage();
  }

  Future<void> _initializeImage() async {
    try {
      final bytes = await widget.initialImage.readAsBytes();

      // Decode once so we can do pixel-accurate cropping later
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();

      setState(() {
        _imageBytes = bytes;
        _decodedImage = frame.image;
        _imageOffset = Offset.zero; // centered
      });
    } catch (e) {
      logger.e("Error initializing image: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error loading image: $e")),
        );
      }
    }
  }

  /// Crops the original image to the 250x250 region currently visible
  /// inside the circle, using BoxFit.cover uniform-scale math.
  Future<void> _returnCroppedImage() async {
    if (_imageBytes == null || _decodedImage == null) return;

    final img = _decodedImage!;
    final double W = img.width.toDouble();
    final double H = img.height.toDouble();

    // BoxFit.cover scales uniformly so the image fills 350x350.
    // scale = max(containerSize / imageDimension) for each axis.
    final double coverScale = math.max(_displaySize / W, _displaySize / H);

    // The scaled image may overflow the 350x350 box; Flutter centers it.
    // alignOffset is how far the scaled image extends beyond the box edge.
    final double alignOffsetX = (W * coverScale - _displaySize) / 2;
    final double alignOffsetY = (H * coverScale - _displaySize) / 2;

    // Circle centre in image-widget display space, adjusted for pan.
    const double displayCenter = _displaySize / 2; // 175
    final double imgWidgetX = displayCenter - _imageOffset.dx;
    final double imgWidgetY = displayCenter - _imageOffset.dy;

    // Map back to original image pixels using the same uniform scale.
    final double origCenterX = (imgWidgetX + alignOffsetX) / coverScale;
    final double origCenterY = (imgWidgetY + alignOffsetY) / coverScale;

    // 125 display-px radius -> original pixels (one scale, no warping).
    final double cropHalf = _circleRadius / coverScale;

    final double srcLeft   = (origCenterX - cropHalf).clamp(0.0, W);
    final double srcTop    = (origCenterY - cropHalf).clamp(0.0, H);
    final double srcRight  = (origCenterX + cropHalf).clamp(0.0, W);
    final double srcBottom = (origCenterY + cropHalf).clamp(0.0, H);

    const int outputSize = 250;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    canvas.drawImageRect(
      img,
      Rect.fromLTRB(srcLeft, srcTop, srcRight, srcBottom),
      Rect.fromLTWH(0, 0, outputSize.toDouble(), outputSize.toDouble()),
      Paint()..filterQuality = FilterQuality.high,
    );

    final picture        = recorder.endRecording();
    final croppedUiImage = await picture.toImage(outputSize, outputSize);
    final byteData =
        await croppedUiImage.toByteData(format: ui.ImageByteFormat.png);

    if (!mounted) return;
    Navigator.of(context).pop(byteData!.buffer.asUint8List());
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    // The image widget is always 350x350 with BoxFit.cover, so it exactly
    // fills the display area. The circle is 250x250 centered inside, leaving
    // 50px of image on each side -> max pan offset is ±50 in each direction.
    const double maxOffset = _displaySize / 2 - _circleRadius; // 175 - 125 = 50

    setState(() {
      _imageOffset = Offset(
        (_imageOffset.dx + details.delta.dx).clamp(-maxOffset, maxOffset),
        (_imageOffset.dy + details.delta.dy).clamp(-maxOffset, maxOffset),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Edit Profile Photo"),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _imageBytes == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // ── Pan area ──────────────────────────────────────────────
                Expanded(
                  child: Center(
                    child: GestureDetector(
                      onPanUpdate: _handlePanUpdate,
                      child: SizedBox(
                        width: _displaySize,
                        height: _displaySize,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Layer 1: full original image, draggable
                            Transform.translate(
                              offset: _imageOffset,
                              child: Image.memory(
                                _imageBytes!,
                                width: _displaySize,
                                height: _displaySize,
                                fit: BoxFit.cover,
                                gaplessPlayback: true,
                              ),
                            ),

                            // Layer 2: dark vignette with circular cutout
                            IgnorePointer(
                              child: CustomPaint(
                                painter: CircularMaskPainter(
                                  circleRadius: _circleRadius,
                                ),
                                size: const Size(_displaySize, _displaySize),
                              ),
                            ),

                            // Layer 3: thin white border ring
                            IgnorePointer(
                              child: Container(
                                width: _circleRadius * 2,
                                height: _circleRadius * 2,
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
                ),

                // ── Helper text ───────────────────────────────────────────
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Text(
                    'Drag to reposition your photo',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey[400]),
                  ),
                ),

                // ── Done button ───────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _returnCroppedImage,
                      icon: const Icon(Icons.check),
                      label: const Text("Done"),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: const Color(0xFF1976D2),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

/// Paints a semi-transparent overlay with a transparent circular cutout.
class CircularMaskPainter extends CustomPainter {
  final double circleRadius;

  const CircularMaskPainter({required this.circleRadius});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    canvas.saveLayer(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint(),
    );

    // Dark overlay
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = Colors.black.withValues(alpha: 0.55),
    );

    // Punch out the circle
    canvas.drawCircle(
      center,
      circleRadius,
      Paint()..blendMode = BlendMode.clear,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(CircularMaskPainter old) =>
      old.circleRadius != circleRadius;
}