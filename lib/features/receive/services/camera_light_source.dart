import 'dart:async';

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
/// Exposure/focus discipline (the source of an earlier cross-session darkening
/// bug): every session resets the camera to a clean auto state on start, lets
/// auto-exposure settle, then locks focus + exposure at that converged setting
/// (no artificial dark bias). On stop the camera is restored to auto and zero
/// offset BEFORE disposal, so no locked/biased state leaks into the next
/// session.
///
/// The decode pipeline never sees this class — it only emits [LightReading]s.
/// [controller] is exposed solely so the screen can render a preview.
class CameraLightSource implements LightSource {
  CameraLightSource({
    this.sampleStride = 4,
    this.centerFraction = 0.5,
    this.brightFraction = 0.2,
    this.lockFocus = true,
    this.lockExposure = true,
    this.exposureOffset = 0.0,
    this.settleDuration = const Duration(milliseconds: 500),
  });

  final int sampleStride;
  final double centerFraction;
  final double brightFraction;
  final bool lockFocus;
  final bool lockExposure;

  /// Extra exposure compensation applied at lock time (0 = lock at the
  /// converged auto exposure). Kept for tuning; defaults to none.
  final double exposureOffset;

  /// How long to let auto-exposure/focus settle before locking.
  final Duration settleDuration;

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
      // Clean slate: undo any locked/biased state a previous session may have
      // left on the camera device.
      await _resetToAuto(controller);

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
      // Lock only after AE/AF have settled with real frames flowing.
      unawaited(_settleThenLock(controller));
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

  Future<void> _resetToAuto(CameraController c) async {
    await _attempt('focus->auto', () => c.setFocusMode(FocusMode.auto));
    await _attempt('exposure->auto', () => c.setExposureMode(ExposureMode.auto));
    await _attempt('exposurePoint->null', () => c.setExposurePoint(null));
    await _attempt('exposureOffset->0', () => c.setExposureOffset(0));
  }

  Future<void> _settleThenLock(CameraController c) async {
    await Future<void>.delayed(settleDuration);
    if (_controller != c || !_streaming) return; // stopped/replaced meanwhile
    if (lockFocus) {
      await _attempt('focus->locked', () => c.setFocusMode(FocusMode.locked));
    }
    if (lockExposure) {
      if (exposureOffset != 0) {
        await _attempt(
            'exposureOffset', () => c.setExposureOffset(exposureOffset));
      }
      await _attempt(
          'exposure->locked', () => c.setExposureMode(ExposureMode.locked));
    }
  }

  @override
  Future<void> stop() async {
    _streaming = false;
    final c = _controller;
    _controller = null;
    if (c == null) return;

    await _attempt('stopStream', () async {
      if (c.value.isStreamingImages) await c.stopImageStream();
    });
    // Restore a clean auto state BEFORE disposal so nothing carries over.
    await _attempt('exposure->auto', () => c.setExposureMode(ExposureMode.auto));
    await _attempt('exposureOffset->0', () => c.setExposureOffset(0));
    await _attempt('focus->auto', () => c.setFocusMode(FocusMode.auto));
    await _attempt('dispose', () => c.dispose());
  }

  /// Best-effort camera operation: failures (unsupported on some devices) are
  /// logged but never surfaced as a source error.
  Future<void> _attempt(String what, Future<void> Function() op) async {
    try {
      await op();
    } catch (e) {
      if (kDebugMode) debugPrint('[CameraLightSource] $what failed: $e');
    }
  }
}
