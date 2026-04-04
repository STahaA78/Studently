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
  Uint8List? _imageBytes;
  ui.Image?  _decodedImage;
  Offset     _cropCenter = Offset.zero;

  // Zoom state
  double _zoomScale     = 1.0;
  double _baseZoomScale = 1.0;

  static const double _minZoom        = 1.0;
  static const double _maxZoom        = 5.0;
  static const double _maxCropDiameterWide = 560.0;

  double _circleDiameter = 300.0;
  double get _circleRadius => _circleDiameter / 2;

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
        _cropCenter   = Offset(
          frame.image.width / 2,
          frame.image.height / 2,
        );
        _zoomScale    = 1.0;
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

  /// Base scale so shortest side == circle diameter (guarantees full coverage).
  double get _fitScale {
    final img = _decodedImage!;
    return math.max(_circleDiameter / img.width, _circleDiameter / img.height);
  }

  /// Total scale (fit × user zoom) — display px per image px.
  double get _imageScale => _fitScale * _zoomScale;

  double _resolveCropDiameter(BoxConstraints constraints) {
    final double shortest = math.min(constraints.maxWidth, constraints.maxHeight);

    // On phones, use full available width so the crop circle touches edges.
    // On wide/tablet/web layouts, cap the size to avoid an oversized crop UI.
    if (constraints.maxWidth >= 700) {
      return math.min(shortest, _maxCropDiameterWide);
    }

    return shortest;
  }

  Offset _clampCenterForZoom({
    required Offset center,
    required double zoom,
  }) {
    final img = _decodedImage!;
    final double s = _fitScale * zoom;
    final double half = _circleRadius / s;
    final double minX = half;
    final double maxX = img.width.toDouble() - half;
    final double minY = half;
    final double maxY = img.height.toDouble() - half;

    return Offset(
      center.dx.clamp(minX, maxX).toDouble(),
      center.dy.clamp(minY, maxY).toDouble(),
    );
  }

  Rect _sourceRectFor({
    required Offset center,
    required double zoom,
  }) {
    final double s = _fitScale * zoom;
    final double half = _circleRadius / s;
    return Rect.fromCenter(
      center: center,
      width: half * 2,
      height: half * 2,
    );
  }

  // ── crop ─────────────────────────────────────────────────────────────────

  Future<void> _returnCroppedImage() async {
    if (_imageBytes == null || _decodedImage == null) return;

    final img = _decodedImage!;
    final clampedCenter = _clampCenterForZoom(
      center: _cropCenter,
      zoom: _zoomScale,
    );
    final src = _sourceRectFor(
      center: clampedCenter,
      zoom: _zoomScale,
    );

    const int out = 250;
    final recorder = ui.PictureRecorder();
    final canvas   = Canvas(recorder);

    canvas.drawImageRect(
      img,
      src,
      Rect.fromLTWH(0, 0, out.toDouble(), out.toDouble()),
      Paint()..filterQuality = FilterQuality.high,
    );

    final picture  = recorder.endRecording();
    final uiImg    = await picture.toImage(out, out);
    final byteData = await uiImg.toByteData(format: ui.ImageByteFormat.png);

    if (!mounted) return;
    Navigator.of(context).pop(byteData!.buffer.asUint8List());
  }

  // ── gesture handlers ─────────────────────────────────────────────────────

  void _handleScaleStart(ScaleStartDetails details) {
    _baseZoomScale = _zoomScale;
  }

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    if (_decodedImage == null) return;

    final newZoom = (_baseZoomScale * details.scale).clamp(_minZoom, _maxZoom);
    final double s = _fitScale * newZoom;
    final proposedCenter = Offset(
      _cropCenter.dx - (details.focalPointDelta.dx / s),
      _cropCenter.dy - (details.focalPointDelta.dy / s),
    );
    final clampedCenter = _clampCenterForZoom(
      center: proposedCenter,
      zoom: newZoom,
    );

    setState(() {
      _zoomScale = newZoom;
      _cropCenter = clampedCenter;
    });
  }

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: backgroundColor,
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
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      _circleDiameter = _resolveCropDiameter(constraints);
                      _cropCenter = _clampCenterForZoom(
                        center: _cropCenter,
                        zoom: _zoomScale,
                      );

                      return Center(
                        child: GestureDetector(
                          onScaleStart:  _handleScaleStart,
                          onScaleUpdate: _handleScaleUpdate,
                          child: SizedBox(
                            width:  _circleDiameter,
                            height: _circleDiameter,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(color: backgroundColor),

                                ClipOval(
                                  child: SizedBox(
                                    width: _circleDiameter,
                                    height: _circleDiameter,
                                    child: CustomPaint(
                                      painter: CropPreviewPainter(
                                        image: _decodedImage!,
                                        sourceRect: _sourceRectFor(
                                          center: _cropCenter,
                                          zoom: _zoomScale,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),

                                IgnorePointer(
                                  child: Container(
                                    width:  _circleDiameter,
                                    height: _circleDiameter,
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
                      );
                    },
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 10),
                  child: Text(
                    'Pinch to zoom · Drag to reposition',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey[400]),
                  ),
                ),

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

class CropPreviewPainter extends CustomPainter {
  final ui.Image image;
  final Rect sourceRect;

  const CropPreviewPainter({
    required this.image,
    required this.sourceRect,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawImageRect(
      image,
      sourceRect,
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..filterQuality = FilterQuality.high,
    );
  }

  @override
  bool shouldRepaint(CropPreviewPainter oldDelegate) {
    return oldDelegate.image != image || oldDelegate.sourceRect != sourceRect;
  }
}