/// One luminance sample. `luminance` is mean Y-plane brightness (0–255).
class LightReading {
  const LightReading({required this.luminance, required this.timestampMs});
  final double luminance;
  final int timestampMs;
}
