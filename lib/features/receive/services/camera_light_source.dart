import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

import '../domain/light_reading.dart';
import 'light_source.dart';

/// Camera-backed [LightSource]. Initializes a low-resolution rear-camera image
/// stream and converts each frame's Y (luminance) plane into a [LightReading]
/// by averaging a strided sample of pixels — cheap enough to run per frame.
///
/// All decode logic stays outside this class; it only emits [LightReading]s.
/// The [controller] is exposed solely so the screen can render a preview.
class CameraLightSource implements LightSource {
  CameraLightSource({this.sampleStride = 16});

  /// Sample every Nth byte of the Y plane. Higher = cheaper, coarser.
  final int sampleStride;

  CameraController? _controller;
  LightSourceError _lastError = LightSourceError.none;
  bool _streaming = false;
  bool _processing = false;

  /// The underlying controller, once initialized — for [CameraPreview].
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
          final luminance = _meanLuminance(image);
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

  /// Average luminance (0–255) over a strided sample of the Y plane.
  double _meanLuminance(CameraImage image) {
    final yPlane = image.planes[0];
    final bytes = yPlane.bytes;
    if (bytes.isEmpty) return 0;
    var sum = 0;
    var count = 0;
    for (var i = 0; i < bytes.length; i += sampleStride) {
      sum += bytes[i];
      count++;
    }
    return count == 0 ? 0 : sum / count;
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
      _lastError = LightSourceError.interrupted;
      if (kDebugMode) debugPrint('[CameraLightSource] stopImageStream: $e');
    }
    try {
      await controller.dispose();
    } catch (e) {
      if (kDebugMode) debugPrint('[CameraLightSource] dispose: $e');
    }
  }
}
