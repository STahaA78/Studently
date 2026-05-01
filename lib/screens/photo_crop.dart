import 'package:studently/app_style.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:studently/logger.dart';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

enum PhotoCropMode { circle, ratio4x5 }

class PhotoCropScreen extends StatefulWidget {
  final XFile initialImage;
  final PhotoCropMode mode;
  final String title;
  final String helperText;

  const PhotoCropScreen({
    super.key,
    required this.initialImage,
    required this.mode,
    required this.title,
    this.helperText = 'Pinch to zoom · Drag to reposition',
  });

  @override
  State<PhotoCropScreen> createState() => _PhotoCropScreenState();
}

class ProfilePhotoCropScreen extends StatelessWidget {
  final XFile initialImage;

  const ProfilePhotoCropScreen({super.key, required this.initialImage});

  @override
  Widget build(BuildContext context) {
    return PhotoCropScreen(
      initialImage: initialImage,
      mode: PhotoCropMode.circle,
      title: 'Edit Profile Photo',
    );
  }
}

class PostPhotoCropScreen extends StatelessWidget {
  final XFile initialImage;

  const PostPhotoCropScreen({super.key, required this.initialImage});

  @override
  Widget build(BuildContext context) {
    return PhotoCropScreen(
      initialImage: initialImage,
      mode: PhotoCropMode.ratio4x5,
      title: 'Crop Photo',
    );
  }
}

class _PhotoCropScreenState extends State<PhotoCropScreen> {
  Uint8List? _imageBytes;
  ui.Image? _decodedImage;
  Offset _cropCenter = Offset.zero;

  double _zoomScale = 1.0;
  double _baseZoomScale = 1.0;

  static const double _minZoom = 1.0;
  static const double _maxZoom = 5.0;
  static const double _maxViewportWide = 680.0;
  static const double _circleToViewportRatio = 0.82;
  static const double _maskOpacity = 0.32;
  static const double _portraitAspect = 4 / 5;
  static const double _landscapeAspect = 1.91;
  static const int _outputLongEdge = 1350;

  double _cropWidth = 300.0;
  double _cropHeight = 300.0;
  double _rectAspectRatio = _portraitAspect;

  double get _cropHalfWidth => _cropWidth / 2;
  double get _cropHalfHeight => _cropHeight / 2;
  bool get _isCircle => widget.mode == PhotoCropMode.circle;
  bool get _isLandscape => _rectAspectRatio > 1;

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
        _imageBytes = bytes;
        _decodedImage = frame.image;
        _cropCenter = Offset(frame.image.width / 2, frame.image.height / 2);
        _zoomScale = 1.0;
      });
    } catch (e) {
      logger.e('Error initializing image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading image: $e')),
        );
      }
    }
  }

  double get _fitScale {
    final img = _decodedImage!;
    return math.max(_cropWidth / img.width, _cropHeight / img.height);
  }

  double _resolveViewportSize(BoxConstraints constraints) {
    final double shortest = math.min(
      constraints.maxWidth,
      constraints.maxHeight,
    );

    if (constraints.maxWidth >= 900) {
      return math.min(shortest, _maxViewportWide);
    }

    return shortest;
  }

  Size _resolveRectViewport(BoxConstraints constraints) {
    final double maxWidth =
        constraints.maxWidth >= 900
            ? math.min(constraints.maxWidth, _maxViewportWide)
            : constraints.maxWidth;
    double width = maxWidth;
    double height = width / _rectAspectRatio;

    if (height > constraints.maxHeight) {
      height = constraints.maxHeight;
      width = height * _rectAspectRatio;
    }

    return Size(width, height);
  }

  Size _resolveCircleCropSize({
    required double viewportSize,
    required double availableWidth,
  }) {
    if (_isCircle) {
      if (availableWidth < 700) {
        return Size(viewportSize, viewportSize);
      }

      final double target = viewportSize * _circleToViewportRatio;
      final double min = math.min(320.0, viewportSize);
      final double diameter = target.clamp(min, viewportSize).toDouble();
      return Size(diameter, diameter);
    }

    return Size(viewportSize, viewportSize);
  }

  Rect _previewSourceRectFor({
    required Offset center,
    required double zoom,
    required Size viewportSize,
  }) {
    final double s = _fitScale * zoom;
    final double halfWidth = (viewportSize.width / 2) / s;
    final double halfHeight = (viewportSize.height / 2) / s;
    return Rect.fromCenter(
      center: center,
      width: halfWidth * 2,
      height: halfHeight * 2,
    );
  }

  Offset _clampCenterForZoom({required Offset center, required double zoom}) {
    final img = _decodedImage!;
    final double s = _fitScale * zoom;
    final double halfWidth = _cropHalfWidth / s;
    final double halfHeight = _cropHalfHeight / s;
    final double minX = halfWidth;
    final double maxX = img.width.toDouble() - halfWidth;
    final double minY = halfHeight;
    final double maxY = img.height.toDouble() - halfHeight;

    return Offset(
      center.dx.clamp(minX, maxX).toDouble(),
      center.dy.clamp(minY, maxY).toDouble(),
    );
  }

  void _toggleAspectRatio() {
    if (_isCircle) return;

    setState(() {
      _rectAspectRatio =
          _isLandscape ? _portraitAspect : _landscapeAspect;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _cropCenter = _clampCenterForZoom(
          center: _cropCenter,
          zoom: _zoomScale,
        );
      });
    });
  }

  Rect _sourceRectFor({required Offset center, required double zoom}) {
    final double s = _fitScale * zoom;
    final double halfWidth = _cropHalfWidth / s;
    final double halfHeight = _cropHalfHeight / s;
    return Rect.fromCenter(
      center: center,
      width: halfWidth * 2,
      height: halfHeight * 2,
    );
  }

  Future<void> _returnCroppedImage() async {
    if (_imageBytes == null || _decodedImage == null) return;

    final img = _decodedImage!;
    final clampedCenter = _clampCenterForZoom(
      center: _cropCenter,
      zoom: _zoomScale,
    );
    final src = _sourceRectFor(center: clampedCenter, zoom: _zoomScale);

    final int outWidth = _isCircle
      ? 250
      : _isLandscape
        ? _outputLongEdge
        : (_outputLongEdge * _rectAspectRatio).round();
    final int outHeight = _isCircle
      ? 250
      : _isLandscape
        ? (_outputLongEdge / _rectAspectRatio).round()
        : _outputLongEdge;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    canvas.drawImageRect(
      img,
      src,
      Rect.fromLTWH(0, 0, outWidth.toDouble(), outHeight.toDouble()),
      Paint()..filterQuality = FilterQuality.high,
    );

    final picture = recorder.endRecording();
    final uiImg = await picture.toImage(outWidth, outHeight);
    final byteData = await uiImg.toByteData(format: ui.ImageByteFormat.png);

    if (!mounted) return;
    Navigator.of(context).pop(byteData!.buffer.asUint8List());
  }

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

  @override
  Widget build(BuildContext context) {
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(widget.title),
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
                      final viewportRect =
                          _isCircle
                              ? Size.square(_resolveViewportSize(constraints))
                              : _resolveRectViewport(constraints);
                      final cropSize =
                          _isCircle
                              ? _resolveCircleCropSize(
                                  viewportSize: viewportRect.width,
                                  availableWidth: constraints.maxWidth,
                                )
                              : viewportRect;
                      _cropWidth = cropSize.width;
                      _cropHeight = cropSize.height;

                      final clampedCenter = _clampCenterForZoom(
                        center: _cropCenter,
                        zoom: _zoomScale,
                      );

                      return Center(
                        child: GestureDetector(
                          onScaleStart: _handleScaleStart,
                          onScaleUpdate: _handleScaleUpdate,
                          child: SizedBox(
                            width: viewportRect.width,
                            height: viewportRect.height,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(color: backgroundColor),
                                SizedBox(
                                  width: viewportRect.width,
                                  height: viewportRect.height,
                                  child: CustomPaint(
                                    painter: CropPreviewPainter(
                                      image: _decodedImage!,
                                      sourceRect: _previewSourceRectFor(
                                        center: clampedCenter,
                                        zoom: _zoomScale,
                                        viewportSize: viewportRect,
                                      ),
                                    ),
                                  ),
                                ),
                                if (_isCircle)
                                  IgnorePointer(
                                    child: CustomPaint(
                                      painter: CircularOverlayPainter(
                                        circleRadius: _cropHalfWidth,
                                        overlayColor: Colors.grey
                                            .withValues(alpha: _maskOpacity),
                                      ),
                                      size: viewportRect,
                                    ),
                                  ),
                                if (_isCircle)
                                  IgnorePointer(
                                    child: Container(
                                      width: _cropWidth,
                                      height: _cropHeight,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                                if (!_isCircle)
                                  Positioned(
                                    left: 16,
                                    bottom: 16,
                                    child: IconButton(
                                      onPressed: _toggleAspectRatio,
                                      icon: Icon(
                                        _isLandscape
                                            ? Icons.crop_portrait
                                            : Icons.crop_landscape,
                                      ),
                                      tooltip:
                                          _isLandscape
                                              ? 'Switch to 4:5 portrait'
                                              : 'Switch to 1.91:1 landscape',
                                      style: IconButton.styleFrom(
                                        backgroundColor: Colors.black87,
                                        foregroundColor: Colors.white,
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
                    horizontal: 20,
                    vertical: 10,
                  ),
                  child: Text(
                    widget.helperText,
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
                        backgroundColor: AppStyle.primaryBlue,
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

class CircularOverlayPainter extends CustomPainter {
  final double circleRadius;
  final Color overlayColor;

  const CircularOverlayPainter({
    required this.circleRadius,
    required this.overlayColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.saveLayer(Rect.fromLTWH(0, 0, size.width, size.height), Paint());

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = overlayColor,
    );

    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      circleRadius,
      Paint()..blendMode = BlendMode.clear,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(CircularOverlayPainter oldDelegate) {
    return oldDelegate.circleRadius != circleRadius ||
        oldDelegate.overlayColor != overlayColor;
  }
}

class RectOverlayPainter extends CustomPainter {
  final Size rectSize;
  final double borderRadius;
  final Color overlayColor;

  const RectOverlayPainter({
    required this.rectSize,
    required this.borderRadius,
    required this.overlayColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.saveLayer(Rect.fromLTWH(0, 0, size.width, size.height), Paint());

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = overlayColor,
    );

    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: rectSize.width,
      height: rectSize.height,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(borderRadius)),
      Paint()..blendMode = BlendMode.clear,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(RectOverlayPainter oldDelegate) {
    return oldDelegate.rectSize != rectSize ||
        oldDelegate.borderRadius != borderRadius ||
        oldDelegate.overlayColor != overlayColor;
  }
}

class CropPreviewPainter extends CustomPainter {
  final ui.Image image;
  final Rect sourceRect;

  const CropPreviewPainter({required this.image, required this.sourceRect});

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
