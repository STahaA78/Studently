import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:studently/logger.dart';
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
  Uint8List?  _imageBytes;
  ui.Image?   _decodedImage;
  Offset      _imageOffset = Offset.zero;

  // The circular frame is 250 × 250 px, centred in a 350 × 350 display area.
  static const double _circleDiameter = 250.0;
  static const double _circleRadius   = _circleDiameter / 2;
  static const double _displaySize    = 350.0;

  // ── init ────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _initializeImage();
  }

  Future<void> _initializeImage() async {
    try {
      final bytes = await widget.initialImage.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      setState(() {
        _imageBytes   = bytes;
        _decodedImage = frame.image;
        _imageOffset  = Offset.zero;
      });
    } catch (e) {
      logger.e('Error initializing image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error loading image: $e')));
      }
    }
  }

  // ── scale helpers ────────────────────────────────────────────────────────

  /// Scale the image so its shortest side == circle diameter (250 px).
  /// This guarantees the circle is always fully covered by the image.
  double get _imageScale {
    final img = _decodedImage!;
    return math.max(_circleDiameter / img.width, _circleDiameter / img.height);
  }

  double get _displayW => _decodedImage!.width  * _imageScale;
  double get _displayH => _decodedImage!.height * _imageScale;

  // ── crop ─────────────────────────────────────────────────────────────────

  Future<void> _returnCroppedImage() async {
    if (_imageBytes == null || _decodedImage == null) return;

    final img = _decodedImage!;
    final s   = _imageScale;
    final dW  = _displayW;
    final dH  = _displayH;

    // The circle is fixed at center (175, 175) in the 350×350 stack.
    // The image (size dW × dH) is centered, then offset by user's drag.
    // Image top-left in stack space:
    //   x = (350 - dW) / 2 + _imageOffset.dx
    //   y = (350 - dH) / 2 + _imageOffset.dy
    //
    // Circle center relative to image top-left:
    //   imgX = 175 - ((350 - dW) / 2 + _imageOffset.dx)
    //   imgX = dW / 2 - _imageOffset.dx
    //   (similarly for imgY)

    final double imgX = dW / 2 - _imageOffset.dx;
    final double imgY = dH / 2 - _imageOffset.dy;

    // Map to original image pixels.
    final double origCX = imgX / s;
    final double origCY = imgY / s;
    final double half   = _circleRadius / s;

    final double W = img.width.toDouble();
    final double H = img.height.toDouble();

    final srcLeft   = (origCX - half).clamp(0.0, W);
    final srcTop    = (origCY - half).clamp(0.0, H);
    final srcRight  = (origCX + half).clamp(0.0, W);
    final srcBottom = (origCY + half).clamp(0.0, H);

    const int out = 250;
    final recorder = ui.PictureRecorder();
    final canvas   = Canvas(recorder);

    canvas.drawImageRect(
      img,
      Rect.fromLTRB(srcLeft, srcTop, srcRight, srcBottom),
      Rect.fromLTWH(0, 0, out.toDouble(), out.toDouble()),
      Paint()..filterQuality = FilterQuality.high,
    );

    final picture  = recorder.endRecording();
    final uiImg    = await picture.toImage(out, out);
    final byteData = await uiImg.toByteData(format: ui.ImageByteFormat.png);

    if (!mounted) return;
    Navigator.of(context).pop(byteData!.buffer.asUint8List());
  }

  // ── pan ──────────────────────────────────────────────────────────────────

  void _handlePanUpdate(DragUpdateDetails details) {
    if (_decodedImage == null) return;

    final double dW = _displayW;
    final double dH = _displayH;

    // The circle is fixed at the center (175, 175) with radius 125,
    // spanning pixel range [50, 300] in both x and y.
    //
    // The image is centered in the 350×350 area, then offset by the user's drag.
    // To keep the circle always within the image bounds:
    //
    // Image position: x = (350 - dW) / 2 + dx
    // Circle bounds: [50, 300]
    //
    // For circle to stay within image bounds:
    //   dx in [-(dW - 250)/2, (dW - 250)/2]
    // 
    // When dW == 250 (square image), range is [0, 0] (no pan)
    // When dW > 250 (larger image), there's room to pan

    final double maxDx = math.max(0, (dW - _displaySize) / 2);
    final double maxDy = math.max(0, (dH - _displaySize) / 2);

    setState(() {
      _imageOffset = Offset(
        (_imageOffset.dx + details.delta.dx).clamp(-maxDx, maxDx),
        (_imageOffset.dy + details.delta.dy).clamp(-maxDy, maxDy),
      );
    });
  }

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Edit Profile Photo'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _imageBytes == null || _decodedImage == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // ── pan area ──────────────────────────────────────────────
                Expanded(
                  child: Stack(
                    children: [
                      // Center the draggable image
                      Center(
                        child: GestureDetector(
                          onPanUpdate: _handlePanUpdate,
                          child: SizedBox(
                            width:  _displaySize,
                            height: _displaySize,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // White background in case image has transparency
                                Container(
                                  color: Colors.white,
                                ),

                                // Layer 1 ── image at its computed display size,
                                // translated by the user's pan offset.
                                Transform.translate(
                                  offset: _imageOffset,
                                  child: Image.memory(
                                    _imageBytes!,
                                    width:  _displayW,
                                    height: _displayH,
                                    fit: BoxFit.fill, // dimensions are exact — no extra scaling
                                    gaplessPlayback: true,
                                  ),
                                ),

                                // Layer 3 ── white border ring
                                IgnorePointer(
                                  child: Container(
                                    width:  _circleDiameter,
                                    height: _circleDiameter,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: Colors.white, width: 2),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Layer 2 ── full-screen dark overlay with circular cutout
                      IgnorePointer(
                        child: CustomPaint(
                          painter: CircularMaskPainter(
                              circleRadius: _circleRadius),
                          size: Size.infinite,
                        ),
                      ),
                    ],
                  ),
                ),

                // ── hint ────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 10),
                  child: Text(
                    'Drag to reposition your photo',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey[400]),
                  ),
                ),

                // ── done ────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _returnCroppedImage,
                      icon: const Icon(Icons.check),
                      label: const Text('Done'),
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

/// Semi-transparent overlay with a transparent circular cutout.
class CircularMaskPainter extends CustomPainter {
  final double circleRadius;
  const CircularMaskPainter({required this.circleRadius});

  @override
  void paint(Canvas canvas, Size size) {
    // Use saveLayer to create a compositing layer for proper alpha blending
    canvas.saveLayer(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint(),
    );

    // Draw semi-transparent black overlay
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = Colors.black.withValues(alpha: 0.55),
    );

    // Draw transparent circular cutout at center (clears the overlay in that area)
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      circleRadius,
      Paint()..blendMode = BlendMode.clear,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(CircularMaskPainter old) =>
      old.circleRadius != circleRadius;
}