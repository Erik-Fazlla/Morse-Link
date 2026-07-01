import 'package:flutter/material.dart';

import 'experiments/e1_timing_probe.dart';

/// V2 Lab — debug-only host for the risk-reduction experiments (E1–E4) and,
/// later, V2 subsystem test harnesses. Reachable only from a debug build.
/// Nothing here touches the V1 (Morse) system.
class V2LabScreen extends StatelessWidget {
  const V2LabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final experiments = <_LabEntry>[
      _LabEntry(
        id: 'E1',
        title: 'Frame timing & FPS',
        subtitle: 'Interval jitter, delivered FPS, processing latency',
        builder: (_) => const E1TimingProbeScreen(),
      ),
      const _LabEntry(
        id: 'E2',
        title: 'Gyro ↔ camera sync',
        subtitle: 'Pending (after E1 review)',
      ),
      const _LabEntry(
        id: 'E3',
        title: 'SNR weak-source range',
        subtitle: 'Pending (after E1 review)',
      ),
      const _LabEntry(
        id: 'E4',
        title: 'Flicker separability',
        subtitle: 'Pending (after E1 review)',
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('V2 Lab')),
      body: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: experiments.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final e = experiments[i];
            final enabled = e.builder != null;
            return ListTile(
              tileColor: const Color(0xFF141414),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              leading: CircleAvatar(
                backgroundColor: enabled
                    ? const Color(0xFF0A84FF)
                    : const Color(0xFF3A3A3A),
                child: Text(e.id, style: const TextStyle(fontSize: 12)),
              ),
              title: Text(e.title),
              subtitle: Text(e.subtitle),
              trailing: enabled ? const Icon(Icons.chevron_right) : null,
              enabled: enabled,
              onTap: enabled
                  ? () => Navigator.of(context).push(
                        MaterialPageRoute<void>(builder: e.builder!),
                      )
                  : null,
            );
          },
        ),
      ),
    );
  }
}

class _LabEntry {
  const _LabEntry({
    required this.id,
    required this.title,
    required this.subtitle,
    this.builder,
  });
  final String id;
  final String title;
  final String subtitle;
  final WidgetBuilder? builder;
}
