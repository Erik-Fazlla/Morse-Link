/// One measured light interval. `isOn` = light was on; `durationMs` = length.
class Pulse {
  const Pulse({required this.isOn, required this.durationMs});
  final bool isOn;
  final int durationMs;
}
