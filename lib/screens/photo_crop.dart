import 'package:studently/app_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:studently/logger.dart';
import 'package:studently/utils/web_utils.dart' as web_utils;
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

enum PhotoCropMode { circle, ratio4x5 }

class PhotoCropScreen extends StatefulWidget {
  final XFile initialImage;
  final PhotoCropMode mode;
  final String title;

  const PhotoCropScreen({
    super.key,
    required this.initialImage,
    required this.mode,
    required this.title,
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
  bool _isInitializing = true;
  String? _initErrorMessage;
  Offset _cropCenter = Offset.zero;

  double _zoomScale = 1.0;
  double _baseZoomScale = 1.0;

  static const double _minZoom = 1.0;
  static const double _maxZoom = 5.0;
  static const double _maxViewportWide = 680.0;
  static const double _circleToViewportRatio = 0.82;
  static const double _maskOpacity = 0.32;
  static const double _portraitAspect = 4 / 5;
  static const double _landscapeAspect = 1080 / 566;
  static const int _portraitOutputWidth = 1080;
  static const int _portraitOutputHeight = 1350;
  static const int _landscapeOutputWidth = 1080;
  static const int _landscapeOutputHeight = 566;

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
    setState(() {
      _isInitializing = true;
      _initErrorMessage = null;
    });

    try {
      final bytes = await widget.initialImage.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      setState(() {
        _imageBytes = bytes;
        _decodedImage = frame.image;
        _cropCenter = Offset(frame.image.width / 2, frame.image.height / 2);
        _zoomScale = 1.0;
        _isInitializing = false;
      });
    } catch (e) {
      logger.e('Error initializing image: $e');
      if (!mounted) return;

      setState(() {
        _isInitializing = false;
        _imageBytes = null;
        _decodedImage = null;
        _initErrorMessage =
            'This image format is not supported on this device/browser. '
            'Please choose a JPG or PNG image.';
      });
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
    final double maxWidth = constraints.maxWidth >= 900
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

  Size _resolveViewportForConstraints(
    BoxConstraints constraints, {
    required bool includeWebZoomBar,
  }) {
    final double reservedHeight = includeWebZoomBar ? 96.0 : 0.0;
    final double maxHeight = math.max(
      0.0,
      constraints.maxHeight - reservedHeight,
    );
    final adjustedConstraints = BoxConstraints(
      maxWidth: constraints.maxWidth,
      maxHeight: maxHeight,
    );

    return _isCircle
        ? Size.square(_resolveViewportSize(adjustedConstraints))
        : _resolveRectViewport(adjustedConstraints);
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

    double clampValue(double value, double min, double max) {
      if (min > max) {
        return (min + max) / 2;
      }

      return value.clamp(min, max).toDouble();
    }

    return Offset(
      clampValue(center.dx, minX, maxX),
      clampValue(center.dy, minY, maxY),
    );
  }

  void _toggleAspectRatio() {
    if (_isCircle) return;

    setState(() {
      _rectAspectRatio = _isLandscape ? _portraitAspect : _landscapeAspect;
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
        ? _landscapeOutputWidth
        : _portraitOutputWidth;
    final int outHeight = _isCircle
        ? 250
        : _isLandscape
        ? _landscapeOutputHeight
        : _portraitOutputHeight;

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

    final result = <String, dynamic>{
      // Keep this key for create_post pipeline compatibility.
      'bytes': byteData!.buffer.asUint8List(),
      'aspectRatio': _rectAspectRatio,
    };

    // Profile edit path needs original bytes + crop box for backend avatar crop.
    if (_isCircle) {
      result['originalBytes'] = _imageBytes;
      result['cropData'] = {
        'x': src.left.toInt(),
        'y': src.top.toInt(),
        'width': src.width.toInt(),
        'height': src.height.toInt(),
      };
    }

    Navigator.of(context).pop(result);
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
        title: Center(
          child: Text(
            widget.title,
            style: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.w600,
              fontSize: AppStyle.appBarTitleSize,
            ),
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Cancel',
        ),
      ),
      body: _isInitializing
          ? const Center(child: CircularProgressIndicator())
          : _initErrorMessage != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.broken_image_outlined,
                      size: 56,
                      color: Colors.grey.shade500,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _initErrorMessage!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 18),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Go Back'),
                    ),
                  ],
                ),
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final showWebZoomBar =
                          kIsWeb && !web_utils.isStandalonePwa();
                      final viewportRect = _resolveViewportForConstraints(
                        constraints,
                        includeWebZoomBar: showWebZoomBar,
                      );
                      final cropSize = _isCircle
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

                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Center(
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
                                                .withValues(
                                                  alpha: _maskOpacity,
                                                ),
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
                                          tooltip: _isLandscape
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
                          ),
                          // Web-only zoom bar (not PWA) aligned to viewport width
                          if (showWebZoomBar)
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: SizedBox(
                                width: viewportRect.width,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Center(
                                      child: Text(
                                        'Zoom: ${(_zoomScale * 100).toStringAsFixed(0)}%',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    Slider(
                                      value: _zoomScale,
                                      min: _minZoom,
                                      max: _maxZoom,
                                      divisions: 40,
                                      onChanged: (value) {
                                        setState(() {
                                          _zoomScale = value;
                                          _cropCenter = _clampCenterForZoom(
                                            center: _cropCenter,
                                            zoom: _zoomScale,
                                          );
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(20),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
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
