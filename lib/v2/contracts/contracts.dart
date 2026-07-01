import 'package:flutter/foundation.dart';

/// V2 layer contracts. Each boundary in the V2 stack crosses one of these
/// types / interfaces, so any subsystem can be replaced without touching its
/// neighbours (see docs/architecture/2026-06-30-v2-optical-comms-architecture.md).
///
/// Only the near-term contracts are defined concretely. The remaining
/// interfaces are declared as documented placeholders and will be given real
/// signatures at their own milestone rather than speculatively now — per the
/// governance rule "don't force implementation to match an unproven design".

/// One camera frame handed to the Vision Engine.
@immutable
class Frame {
  const Frame({
    required this.luma,
    required this.width,
    required this.height,
    required this.bytesPerRow,
    required this.tMs,
  });

  /// Y (luminance) plane, 8-bit, row-major with [bytesPerRow] stride.
  final Uint8List luma;
  final int width;
  final int height;
  final int bytesPerRow;

  /// Capture timestamp (ms). Source documented per device (see E1).
  final int tMs;
}

/// Protocol-agnostic output of the Vision Engine: where the source is and how
/// bright, plus how trustworthy. Consumed by Signal Extraction; carries no
/// symbol/protocol knowledge.
@immutable
class Track {
  const Track({
    required this.intensity,
    required this.snr,
    required this.x,
    required this.y,
    required this.size,
    required this.tMs,
    required this.locked,
    required this.confidence,
  });

  final double intensity; // background-subtracted source brightness (signal)
  final double snr; // intensity / local noise sigma
  final double x; // normalized sub-pixel position 0..1
  final double y;
  final double size; // blob extent (regime hint)
  final int tMs;
  final bool locked; // arbitration has a confident active source
  final double confidence; // composite quality 0..1
}

/// Source of frames (camera on device; a synthetic source in tests).
abstract class FrameSource {
  Future<bool> start(void Function(Frame frame) onFrame);
  Future<void> stop();
}

/// Turns frames into a protocol-agnostic [Track] stream. Emits null when there
/// is no credible source.
abstract class VisionEngine {
  Track? process(Frame frame);
  void reset();
}

// --- Deferred interfaces (defined at their milestone, not speculatively) ---
// SignalExtractor : Track      -> Chip*        (MV/extraction milestone)
// Synchronizer    : Chip       -> SymbolFrame? (preamble sync milestone)
// Demodulator     : SymbolFrame-> Block        (PHY profile milestone)
// FecCodec        : Block      <-> bytes        (FEC milestone)
// FrameCodec      : bytes      <-> Frame(msg)   (transport milestone)
// Modulator       : bytes      -> on/off plan   (PHY profile milestone)
// Emitter         : on/off plan-> light out     (PHY profile milestone)
