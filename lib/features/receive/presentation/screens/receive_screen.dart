import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../domain/receive_state.dart';
import '../../domain/sync_phase.dart';
import '../../services/camera_light_source.dart';
import '../receive_controller.dart';

/// Owns the camera source + [ReceiveController] for one receive session and
/// disposes them — mirroring SendSessionScreen. Observes app lifecycle to
/// release the camera in the background.
class ReceiveSessionScreen extends StatefulWidget {
  const ReceiveSessionScreen({super.key});

  @override
  State<ReceiveSessionScreen> createState() => _ReceiveSessionScreenState();
}

class _ReceiveSessionScreenState extends State<ReceiveSessionScreen>
    with WidgetsBindingObserver {
  late final CameraLightSource _cameraSource;
  late final ReceiveController _controller;

  @override
  void initState() {
    super.initState();
    _cameraSource = CameraLightSource();
    _controller = ReceiveController(source: _cameraSource);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      _controller.handleAppPaused();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ReceiveScreen(controller: _controller, cameraSource: _cameraSource);
  }
}

class ReceiveScreen extends StatefulWidget {
  const ReceiveScreen({
    required this.controller,
    required this.cameraSource,
    super.key,
  });

  final ReceiveController controller;
  final CameraLightSource cameraSource;

  @override
  State<ReceiveScreen> createState() => _ReceiveScreenState();
}

class _ReceiveScreenState extends State<ReceiveScreen> {
  bool _showDebug = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('RECEIVE'),
        actions: [
          if (kDebugMode)
            IconButton(
              tooltip: 'Diagnostics',
              icon: Icon(_showDebug ? Icons.bug_report : Icons.bug_report_outlined),
              onPressed: () => setState(() => _showDebug = !_showDebug),
            ),
        ],
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: widget.controller,
          builder: (context, _) {
            final state = widget.controller.state;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _PreviewArea(
                    cameraSource: widget.cameraSource,
                    state: state,
                  ),
                  const SizedBox(height: 12),
                  _StatusRow(state: state),
                  if (state.hasError) ...[
                    const SizedBox(height: 12),
                    _ErrorBanner(message: state.errorMessage ?? 'Error'),
                  ],
                  const SizedBox(height: 16),
                  _DecodedTextCard(state: state),
                  const SizedBox(height: 12),
                  _LiveMorse(morse: state.liveMorse),
                  const SizedBox(height: 16),
                  _QualityBar(
                    label: 'Signal strength',
                    pct: state.quality.signalStrengthPct,
                    color: const Color(0xFF35C759),
                  ),
                  const SizedBox(height: 8),
                  _QualityBar(
                    label: 'Decode confidence',
                    pct: state.quality.decodeConfidencePct,
                    color: const Color(0xFF0A84FF),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Estimated unit: ${state.quality.estUnitMs} ms',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 20),
                  _ControlButton(controller: widget.controller, state: state),
                  if (_showDebug) ...[
                    const SizedBox(height: 20),
                    _DiagnosticsOverlay(controller: widget.controller),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PreviewArea extends StatelessWidget {
  const _PreviewArea({required this.cameraSource, required this.state});
  final CameraLightSource cameraSource;
  final ReceiveState state;

  @override
  Widget build(BuildContext context) {
    final controller = cameraSource.controller;
    final showPreview = state.isReceiving &&
        controller != null &&
        controller.value.isInitialized;
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0E0E0E),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF262626)),
        ),
        clipBehavior: Clip.antiAlias,
        child: showPreview
            ? CameraPreview(controller)
            : Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.camera_alt_outlined,
                        size: 48, color: Color(0xFF6B6B6B)),
                    const SizedBox(height: 8),
                    Text(
                      state.status == ReceiveStatus.starting
                          ? 'Starting camera…'
                          : 'Point the camera at the sender\'s flashlight.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFF9D9D9D)),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.state});
  final ReceiveState state;

  @override
  Widget build(BuildContext context) {
    final detected = state.quality.detected;
    return Row(
      children: [
        _Chip(
          label: _statusLabel(state.status),
          color: state.hasError
              ? const Color(0xFFFF5A36)
              : (state.isReceiving
                  ? const Color(0xFF35C759)
                  : const Color(0xFF5A5A5A)),
        ),
        const SizedBox(width: 8),
        if (state.isReceiving)
          _Chip(
            label: _syncLabel(state.syncPhase),
            color: const Color(0xFF0A84FF),
          ),
        const Spacer(),
        if (state.isReceiving)
          Text(
            detected ? 'Signal' : 'No signal',
            style: TextStyle(
              color: detected ? const Color(0xFF35C759) : const Color(0xFF9D9D9D),
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    );
  }

  static String _statusLabel(ReceiveStatus s) {
    switch (s) {
      case ReceiveStatus.idle:
        return 'Idle';
      case ReceiveStatus.starting:
        return 'Starting';
      case ReceiveStatus.receiving:
        return 'Receiving';
      case ReceiveStatus.stopped:
        return 'Stopped';
      case ReceiveStatus.error:
        return 'Error';
    }
  }

  static String _syncLabel(SyncPhase p) {
    switch (p) {
      case SyncPhase.searching:
        return 'Searching';
      case SyncPhase.synchronizing:
        return 'Synchronizing';
      case SyncPhase.locked:
        return 'Locked';
    }
  }
}

class _DecodedTextCard extends StatelessWidget {
  const _DecodedTextCard({required this.state});
  final ReceiveState state;

  @override
  Widget build(BuildContext context) {
    final text = state.decodedText.isEmpty
        ? (state.isReceiving ? 'Receiving…' : '—')
        : state.decodedText;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF262626)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('DECODED',
              style: TextStyle(
                  color: Color(0xFF9D9D9D),
                  letterSpacing: 1.5,
                  fontSize: 12)),
          const SizedBox(height: 8),
          Text(
            text,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
          ),
        ],
      ),
    );
  }
}

class _LiveMorse extends StatelessWidget {
  const _LiveMorse({required this.morse});
  final String morse;

  @override
  Widget build(BuildContext context) {
    return Text(
      morse.isEmpty ? '· · ·' : morse,
      style: const TextStyle(
        fontFamily: 'monospace',
        fontSize: 18,
        letterSpacing: 2,
        color: Color(0xFFE0E0E0),
      ),
    );
  }
}

class _QualityBar extends StatelessWidget {
  const _QualityBar({required this.label, required this.pct, required this.color});
  final String label;
  final double pct;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final clamped = (pct / 100).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: Color(0xFF9D9D9D))),
            Text('${pct.round()}%',
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: clamped,
            minHeight: 8,
            backgroundColor: const Color(0xFF222222),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({required this.controller, required this.state});
  final ReceiveController controller;
  final ReceiveState state;

  @override
  Widget build(BuildContext context) {
    final isActive = state.isReceiving || state.status == ReceiveStatus.starting;
    return SizedBox(
      height: 56,
      child: FilledButton(
        onPressed: isActive
            ? controller.stopReceiving
            : controller.startReceiving,
        style: FilledButton.styleFrom(
          backgroundColor:
              isActive ? const Color(0xFFB12600) : const Color(0xFFFF5A36),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
        ),
        child: Text(
          isActive ? 'Stop Receiving' : 'Start Receiving',
          style: const TextStyle(
              fontWeight: FontWeight.w800, letterSpacing: 1.1, fontSize: 16),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0x33FF5A36),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFF5A36)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFFF5A36)),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
      ),
      child: Text(label,
          style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12)),
    );
  }
}

// --------------------------------------------------------------------------
// Developer diagnostics (debug builds only)
// --------------------------------------------------------------------------

class _DiagnosticsOverlay extends StatelessWidget {
  const _DiagnosticsOverlay({required this.controller});
  final ReceiveController controller;

  @override
  Widget build(BuildContext context) {
    final state = controller.state;
    final q = state.quality;
    final rows = <(String, String)>[
      ('Sync phase', state.syncPhase.name),
      ('Luminance', controller.currentLuminance.toStringAsFixed(1)),
      ('Threshold', controller.currentThreshold?.toStringAsFixed(1) ?? '—'),
      ('Light', controller.isLightOn ? 'ON' : 'OFF'),
      ('Est. unit', '${q.estUnitMs} ms'),
      ('Signal', '${q.signalStrengthPct.toStringAsFixed(0)} %'),
      ('Confidence', '${q.decodeConfidencePct.toStringAsFixed(0)} %'),
      ('FPS', controller.fps.toStringAsFixed(1)),
      ('Latency', '${controller.avgLatencyMs.toStringAsFixed(2)} ms'),
      ('Morse', state.liveMorse.isEmpty ? '—' : state.liveMorse),
      ('Text', state.decodedText.isEmpty ? '—' : state.decodedText),
    ];
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0B0B0B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF333333)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('DIAGNOSTICS',
              style: TextStyle(
                  color: Color(0xFF9D9D9D), letterSpacing: 1.5, fontSize: 11)),
          const SizedBox(height: 8),
          ...rows.map((r) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(r.$1,
                        style: const TextStyle(
                            color: Color(0xFF8A8A8A), fontSize: 12)),
                    Flexible(
                      child: Text(
                        r.$2,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                            fontFamily: 'monospace', fontSize: 12),
                      ),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: 12),
          const Text('LUMINANCE / THRESHOLD / ON-OFF',
              style: TextStyle(
                  color: Color(0xFF9D9D9D), letterSpacing: 1.2, fontSize: 10)),
          const SizedBox(height: 6),
          SizedBox(
            height: 120,
            child: CustomPaint(
              painter: _LuminanceChartPainter(controller.history),
              size: Size.infinite,
            ),
          ),
        ],
      ),
    );
  }
}

/// Plots raw luminance (white), the adaptive threshold (amber), and ON/OFF
/// decisions (green band at the bottom) over the recent sample window.
class _LuminanceChartPainter extends CustomPainter {
  _LuminanceChartPainter(this.samples);
  final List<LumSample> samples;

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = const Color(0xFF050505);
    canvas.drawRect(Offset.zero & size, bg);
    if (samples.length < 2) return;

    final n = samples.length;
    double x(int i) => size.width * i / (n - 1);
    double y(double lum) => size.height * (1 - (lum.clamp(0, 255) / 255));

    // ON/OFF strip
    final onPaint = Paint()..color = const Color(0x3335C759);
    for (var i = 0; i < n; i++) {
      if (samples[i].isOn) {
        final left = x(i) - (size.width / (n - 1)) / 2;
        canvas.drawRect(
          Rect.fromLTWH(left.clamp(0, size.width), size.height - 10,
              (size.width / (n - 1)).clamp(1, size.width), 10),
          onPaint,
        );
      }
    }

    // threshold line
    final thr = Paint()
      ..color = const Color(0xFFFFB020)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final thrPath = Path();
    var started = false;
    for (var i = 0; i < n; i++) {
      final t = samples[i].threshold;
      if (t == null) continue;
      final px = x(i), py = y(t);
      if (!started) {
        thrPath.moveTo(px, py);
        started = true;
      } else {
        thrPath.lineTo(px, py);
      }
    }
    canvas.drawPath(thrPath, thr);

    // luminance line
    final lum = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final lumPath = Path()..moveTo(x(0), y(samples[0].luminance));
    for (var i = 1; i < n; i++) {
      lumPath.lineTo(x(i), y(samples[i].luminance));
    }
    canvas.drawPath(lumPath, lum);
  }

  @override
  bool shouldRepaint(covariant _LuminanceChartPainter old) => true;
}
