import 'package:flutter/material.dart';

import '../../domain/transmission_history_entry.dart';
import '../../services/transmission_history_repository.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({
    required this.repository,
    required this.onResend,
    super.key,
  });

  final TransmissionHistoryRepository repository;
  final ValueChanged<TransmissionHistoryEntry> onResend;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late Future<List<TransmissionHistoryEntry>> _historyFuture;

  @override
  void initState() {
    super.initState();
    _historyFuture = widget.repository.loadHistory();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('HISTORY'),
        centerTitle: true,
      ),
      body: FutureBuilder<List<TransmissionHistoryEntry>>(
        future: _historyFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          final entries = snapshot.data ?? const [];
          if (entries.isEmpty) {
            return Center(
              child: Text(
                'No local transmissions yet.',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: const Color(0xFF9D9D9D),
                    ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: entries.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final entry = entries[index];
              final localTimestamp = entry.timestamp.toLocal();

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF111111),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF262626)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.messageText,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _formatTimestamp(localTimestamp),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFF9D9D9D),
                          ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _HistoryChip(label: 'Duration ${entry.durationMs} ms'),
                        _HistoryChip(label: 'Repeat ${entry.repeatCount}'),
                        _HistoryChip(label: 'Unit ${entry.timingUnitMs} ms'),
                        _HistoryChip(label: 'Mode ${entry.repeatMode}'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton(
                        onPressed: () {
                          widget.onResend(entry);
                          Navigator.of(context).pop();
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFFF5A36),
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('RESEND'),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _formatTimestamp(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');

    return '${value.year}-$month-$day $hour:$minute';
  }
}

class _HistoryChip extends StatelessWidget {
  const _HistoryChip({
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF2D2D2D)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: const Color(0xFFD7D7D7),
            ),
      ),
    );
  }
}
