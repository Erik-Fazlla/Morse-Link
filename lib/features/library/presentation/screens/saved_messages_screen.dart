import 'package:flutter/material.dart';

import '../../domain/saved_message_template.dart';
import '../../services/saved_message_repository.dart';

class SavedMessagesScreen extends StatefulWidget {
  const SavedMessagesScreen({
    required this.repository,
    required this.onUseMessage,
    super.key,
  });

  final SavedMessageRepository repository;
  final ValueChanged<SavedMessageTemplate> onUseMessage;

  @override
  State<SavedMessagesScreen> createState() => _SavedMessagesScreenState();
}

class _SavedMessagesScreenState extends State<SavedMessagesScreen> {
  late Future<List<SavedMessageTemplate>> _templatesFuture;

  @override
  void initState() {
    super.initState();
    _templatesFuture = widget.repository.loadTemplates();
  }

  void _refresh() {
    if (!mounted) {
      return;
    }

    setState(() {
      _templatesFuture = widget.repository.loadTemplates();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SAVED MESSAGES'),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateDialog,
        backgroundColor: const Color(0xFFFF5A36),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('ADD'),
      ),
      body: FutureBuilder<List<SavedMessageTemplate>>(
        future: _templatesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          final templates = snapshot.data ?? const [];
          if (templates.isEmpty) {
            return Center(
              child: Text(
                'No saved messages yet.',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: const Color(0xFF9D9D9D),
                    ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: templates.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final template = templates[index];
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF111111),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: template.isFavorite
                        ? const Color(0xFFFFC857)
                        : const Color(0xFF262626),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            template.title,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.w900),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          onPressed: () async {
                            try {
                              await widget.repository.setFavorite(
                                template.id,
                                !template.isFavorite,
                              );
                              _refresh();
                            } catch (_) {
                              if (!context.mounted) {
                                return;
                              }

                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Unable to update favorite status.',
                                  ),
                                ),
                              );
                            }
                          },
                          icon: Icon(
                            template.isFavorite
                                ? Icons.star
                                : Icons.star_border,
                            color: const Color(0xFFFFC857),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      template.messageText,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: const Color(0xFFD7D7D7),
                          ),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton(
                            onPressed: () {
                              widget.onUseMessage(template);
                              Navigator.of(context).pop();
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFFFF5A36),
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('USE'),
                          ),
                        ),
                        if (!template.isBuiltIn) ...[
                          const SizedBox(width: 10),
                          OutlinedButton(
                            onPressed: () => _showEditDialog(template),
                            child: const Text('EDIT'),
                          ),
                          const SizedBox(width: 10),
                          OutlinedButton(
                            onPressed: () async {
                              try {
                                await widget.repository
                                    .deleteCustomTemplate(template.id);
                                _refresh();
                              } catch (_) {
                                if (!context.mounted) {
                                  return;
                                }

                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Unable to delete saved message.',
                                    ),
                                  ),
                                );
                              }
                            },
                            child: const Text('DELETE'),
                          ),
                        ],
                      ],
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

  Future<void> _showCreateDialog() async {
    await _showTemplateDialog();
  }

  Future<void> _showEditDialog(SavedMessageTemplate template) async {
    await _showTemplateDialog(existing: template);
  }

  Future<void> _showTemplateDialog({
    SavedMessageTemplate? existing,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => _SavedMessageTemplateDialog(
        existing: existing,
        onSave: ({
          required String title,
          required String messageText,
        }) async {
          final template = SavedMessageTemplate(
            id: existing?.id ?? 'custom-${DateTime.now().microsecondsSinceEpoch}',
            title: title,
            messageText: messageText,
            isBuiltIn: false,
            isFavorite: existing?.isFavorite ?? false,
          );

          await widget.repository.saveCustomTemplate(template);
          _refresh();
        },
      ),
    );
  }
}

class _SavedMessageTemplateDialog extends StatefulWidget {
  const _SavedMessageTemplateDialog({
    required this.onSave,
    this.existing,
  });

  final SavedMessageTemplate? existing;
  final Future<void> Function({
    required String title,
    required String messageText,
  }) onSave;

  @override
  State<_SavedMessageTemplateDialog> createState() =>
      _SavedMessageTemplateDialogState();
}

class _SavedMessageTemplateDialogState
    extends State<_SavedMessageTemplateDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _messageController;
  bool _isSaving = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.existing?.title ?? '',
    );
    _messageController = TextEditingController(
      text: widget.existing?.messageText ?? '',
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (_isSaving) {
      return;
    }

    final title = _titleController.text.trim();
    final message = _messageController.text.trim();
    if (title.isEmpty || message.isEmpty) {
      setState(() {
        _errorText = 'Title and message are required.';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _errorText = null;
    });

    try {
      await widget.onSave(
        title: title,
        messageText: message,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSaving = false;
        _errorText = 'Unable to save message locally.';
      });
      return;
    }

    if (!mounted) {
      return;
    }

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      backgroundColor: const Color(0xFF111111),
      title: Text(widget.existing == null ? 'New Saved Message' : 'Edit Message'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              hintText: 'Title',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _messageController,
            minLines: 3,
            maxLines: 5,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              hintText: 'Message text',
            ),
          ),
          if (_errorText != null) ...[
            const SizedBox(height: 12),
            Text(
              _errorText!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFFFF8A6B),
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('CANCEL'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _handleSave,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFFF5A36),
            foregroundColor: Colors.white,
          ),
          child: Text(_isSaving ? 'SAVING...' : 'SAVE'),
        ),
      ],
    );
  }
}
