import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

import '../domain/light_reading.dart';
import 'light_source.dart';

/// Normalized centroid (0..1) of the brightest blob in a Y plane, or null when
/// there is no clear bright spot (too dark, or too few bright pixels).
///
/// The threshold is relative to the frame's own peak ([peakFraction] of it),
/// so it locks onto whatever the brightest source is — a flashlight — at any
/// distance, and returns null on a dark/uniform frame so callers can fall back.
/// Pure and deterministic — unit tested.
({double x, double y})? brightCentroid(
  Uint8List y,
  int width,
  int height,
  int bytesPerRow, {
  int stride = 4,
  double peakFraction = 0.8,
  int minBrightPixels = 4,
  int minPeak = 40,
}) {
  if (y.isEmpty || width <= 0 || height <= 0) return null;
  final step = stride < 1 ? 1 : stride;

  var maxV = 0;
  for (var row = 0; row < height; row += step) {
    final base = row * bytesPerRow;
    for (var col = 0; col < width; col += step) {
      final idx = base + col;
      if (idx < y.length && y[idx] > maxV) maxV = y[idx];
    }
  }
  if (maxV < minPeak) return null; // no bright source present

  final thr = maxV * peakFraction;
  var sumX = 0.0, sumY = 0.0;
  var n = 0;
  for (var row = 0; row < height; row += step) {
    final base = row * bytesPerRow;
    for (var col = 0; col < width; col += step) {
      final idx = base + col;
      if (idx < y.length && y[idx] >= thr) {
        sumX += col;
        sumY += row;
        n++;
      }
    }
  }
  if (n < minBrightPixels) return null;
  return (x: (sumX / n) / width, y: (sumY / n) / height);
}

/// Mean luminance of the brightest [brightFraction] of pixels within a window
/// of size [centerFraction] of the frame, centred on ([centerX], [centerY])
/// (both normalized 0..1; default 0.5 = frame centre). The window is clamped
/// to stay in bounds.
///
/// Sampling the brightest tail of a small window isolates a flashlight blob
/// from a dark background; centring the window on the tracked blob (rather than
/// a fixed centre) keeps it sampled as the camera moves. Pure and
/// deterministic — unit tested.
@visibleForTesting
double brightRegionLuminance(
  Uint8List y,
  int width,
  int height,
  int bytesPerRow, {
  double centerFraction = 0.5,
  double brightFraction = 0.2,
  int stride = 4,
  double centerX = 0.5,
  double centerY = 0.5,
}) {
  if (y.isEmpty || width <= 0 || height <= 0) return 0;
  final cw = (width * centerFraction).round().clamp(1, width);
  final ch = (height * centerFraction).round().clamp(1, height);
  final x0 = (centerX * width - cw / 2).round().clamp(0, width - cw);
  final y0 = (centerY * height - ch / 2).round().clamp(0, height - ch);
  final step = stride < 1 ? 1 : stride;

  final hist = List<int>.filled(256, 0);
  var total = 0;
  for (var row = y0; row < y0 + ch; row += step) {
    final base = row * bytesPerRow;
    for (var col = x0; col < x0 + cw; col += step) {
      final idx = base + col;
      if (idx >= 0 && idx < y.length) {
        hist[y[idx]]++;
        total++;
      }
    }
  }
  if (total == 0) return 0;

  final want = (total * brightFraction).ceil().clamp(1, total);
  var counted = 0;
  var sum = 0;
  for (var v = 255; v >= 0 && counted < want; v--) {
    final c = hist[v];
    if (c == 0) continue;
    final take = (counted + c <= want) ? c : (want - counted);
    sum += v * take;
    counted += take;
  }
  return counted == 0 ? 0 : sum / counted;
}

/// Camera-backed [LightSource]. Streams a low-resolution rear-camera image
/// feed and converts each frame into a [LightReading] using
/// [brightRegionLuminance], with the sampling window tracking the brightest
/// blob ([brightCentroid]) between frames so it follows the flashlight as the
/// camera moves. Falls back to the frame centre when no clear spot is found.
///
/// Intentionally minimal lifecycle: initialize → stream → dispose, with NO
/// exposure or focus mode changes (those previously caused darkening and
/// "camera unavailable" regressions; the adaptive detector handles absolute
/// brightness).
///
/// The decode pipeline never sees this class — it only emits [LightReading]s.
/// [controller] is exposed solely so the screen can render a preview.
class CameraLightSource implements LightSource {
  CameraLightSource({
    this.sampleStride = 4,
    this.centerFraction = 0.5,
    this.brightFraction = 0.2,
    this.trackingAlpha = 0.3,
  });

  final int sampleStride;
  final double centerFraction;
  final double brightFraction;

  /// EMA factor for the tracked spot: higher = follows motion faster, lower =
  /// smoother. 0 disables tracking (always frame centre).
  final double trackingAlpha;

  CameraController? _controller;
  LightSourceError _lastError = LightSourceError.none;
  bool _streaming = false;
  bool _processing = false;

  // Smoothed normalized location of the tracked bright spot.
  double _trackX = 0.5;
  double _trackY = 0.5;

  CameraController? get controller => _controller;
  bool get isInitialized => _controller?.value.isInitialized ?? false;

  @override
  LightSourceError get lastError => _lastError;

  @override
  Future<bool> start(LightReadingCallback onReading) async {
    _lastError = LightSourceError.none;
    _trackX = 0.5;
    _trackY = 0.5;
    try {
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        _lastError = LightSourceError.permissionDenied;
        return false;
      }

      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        _lastError = LightSourceError.unavailable;
        return false;
      }
      final rear = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        rear,
        ResolutionPreset.low,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
      _controller = controller;
      await controller.initialize();

      await controller.startImageStream((image) {
        if (!_streaming || _processing) return; // drop frames if behind
        _processing = true;
        try {
          onReading(LightReading(
            luminance: _sampleLuminance(image),
            timestampMs: DateTime.now().millisecondsSinceEpoch,
          ));
        } finally {
          _processing = false;
        }
      });
      _streaming = true;
      return true;
    } on CameraException catch (e) {
      _lastError = e.code.toLowerCase().contains('permission')
          ? LightSourceError.permissionDenied
          : LightSourceError.unavailable;
      return false;
    } catch (_) {
      _lastError = LightSourceError.unavailable;
      return false;
    }
  }

  /// Track the brightest spot, then sample the window around it. When no spot
  /// is found (e.g. light OFF between pulses) the tracked position is held so
  /// the window stays on the blob's last location.
  double _sampleLuminance(CameraImage image) {
    final plane = image.planes[0];
    final spot = brightCentroid(
      plane.bytes,
      image.width,
      image.height,
      plane.bytesPerRow,
      stride: sampleStride,
    );
    if (spot != null) {
      _trackX += (spot.x - _trackX) * trackingAlpha;
      _trackY += (spot.y - _trackY) * trackingAlpha;
    }
    return brightRegionLuminance(
      plane.bytes,
      image.width,
      image.height,
      plane.bytesPerRow,
      centerFraction: centerFraction,
      brightFraction: brightFraction,
      stride: sampleStride,
      centerX: _trackX,
      centerY: _trackY,
    );
  }

  @override
  Future<void> stop() async {
    _streaming = false;
    final controller = _controller;
    _controller = null;
    if (controller == null) return;
    try {
      if (controller.value.isStreamingImages) {
        await controller.stopImageStream();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[CameraLightSource] stopImageStream: $e');
    }
    try {
      await controller.dispose();
    } catch (e) {
      if (kDebugMode) debugPrint('[CameraLightSource] dispose: $e');
    }
  }
}
