import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

import '../domain/light_reading.dart';
import 'light_source.dart';

/// Mean luminance of the brightest [brightFraction] of pixels within the
/// central [centerFraction] region of a Y (luminance) plane.
///
/// This isolates a small bright source (a distant flashlight) from a dark
/// background far better than a whole-frame average: the blob dominates the
/// bright tail even when it covers a tiny fraction of the frame, and cropping
/// to the centre ignores peripheral lights and background motion when the
/// camera is roughly aimed at the sender. Pure and deterministic — unit tested.
@visibleForTesting
double brightRegionLuminance(
  Uint8List y,
  int width,
  int height,
  int bytesPerRow, {
  double centerFraction = 0.5,
  double brightFraction = 0.2,
  int stride = 4,
}) {
  if (y.isEmpty || width <= 0 || height <= 0) return 0;
  final cw = (width * centerFraction).round().clamp(1, width);
  final ch = (height * centerFraction).round().clamp(1, height);
  final x0 = ((width - cw) / 2).floor();
  final y0 = ((height - ch) / 2).floor();
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
/// feed and converts each frame into a [LightReading] via
/// [brightRegionLuminance].
///
/// Intentionally minimal: initialize → stream → dispose, with NO exposure or
/// focus mode changes. Earlier exposure/focus locking caused both a
/// cross-session darkening bug and intermittent "camera unavailable" failures
/// after repeated Start/Stop cycles; the adaptive detector already handles
/// absolute brightness, so the locks are not needed.
///
/// The decode pipeline never sees this class — it only emits [LightReading]s.
/// [controller] is exposed solely so the screen can render a preview.
class CameraLightSource implements LightSource {
  CameraLightSource({
    this.sampleStride = 4,
    this.centerFraction = 0.5,
    this.brightFraction = 0.2,
  });

  final int sampleStride;
  final double centerFraction;
  final double brightFraction;

  CameraController? _controller;
  LightSourceError _lastError = LightSourceError.none;
  bool _streaming = false;
  bool _processing = false;

  CameraController? get controller => _controller;
  bool get isInitialized => _controller?.value.isInitialized ?? false;

  @override
  LightSourceError get lastError => _lastError;

  @override
  Future<bool> start(LightReadingCallback onReading) async {
    _lastError = LightSourceError.none;
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
          final plane = image.planes[0];
          final luminance = brightRegionLuminance(
            plane.bytes,
            image.width,
            image.height,
            plane.bytesPerRow,
            centerFraction: centerFraction,
            brightFraction: brightFraction,
            stride: sampleStride,
          );
          onReading(LightReading(
            luminance: luminance,
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
