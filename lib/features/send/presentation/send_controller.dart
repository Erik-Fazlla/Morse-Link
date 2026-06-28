import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:morse/features/history/domain/transmission_history_entry.dart';
import '../../history/services/transmission_history_repository.dart';
import 'package:morse/features/library/domain/saved_message_template.dart';
import '../../library/services/saved_message_repository.dart';
import '../../morse/domain/morse_translation.dart';
import '../../morse/domain/transmission_diagnostics.dart';
import '../../morse/domain/transmission_repeat_mode.dart';
import '../../morse/domain/transmission_state.dart';
import '../../morse/services/morse_translator.dart';
import '../../morse/services/morse_transmission_service.dart';
import '../../morse/services/timing_sequence_builder.dart';
import '../../protocol/domain/transmission_payload.dart';
import '../../protocol/services/communication_protocol_service.dart';

class SendController extends ChangeNotifier {
  SendController({
    required TransmissionHistoryRepository historyRepository,
    required SavedMessageRepository savedMessageRepository,
    required CommunicationProtocolService protocolService,
    required MorseTranslator translator,
    required TimingSequenceBuilder timingBuilder,
    required MorseTransmissionService transmissionService,
    String initialMessage = 'SOS',
    int initialTimingUnitMs = 180,
    TransmissionRepeatMode initialRepeatMode = TransmissionRepeatMode.once,
    int initialCustomRepeatCount = 3,
    int initialDelayBetweenRepeatsMs = 400,
  })  : _protocolService = protocolService,
        _historyRepository = historyRepository,
        _savedMessageRepository = savedMessageRepository,
        _translator = translator,
        _timingBuilder = timingBuilder,
        _transmissionService = transmissionService,
        _message = initialMessage,
        _unitMs = initialTimingUnitMs,
        _repeatMode = initialRepeatMode,
        _customRepeatCount = initialCustomRepeatCount,
        _delayBetweenRepeatsMs = initialDelayBetweenRepeatsMs {
    _activeControllerCount++;
    _log('controller created');
    _refreshPayloadAndTranslation();
    _attachTransmissionListeners();
    unawaited(_loadSupportData());
  }

  static int _activeControllerCount = 0;

  static int get activeControllerCount => _activeControllerCount;

  final CommunicationProtocolService _protocolService;
  final TransmissionHistoryRepository _historyRepository;
  final SavedMessageRepository _savedMessageRepository;
  final MorseTranslator _translator;
  final TimingSequenceBuilder _timingBuilder;
  final MorseTransmissionService _transmissionService;

  String _message;
  int _unitMs;
  TransmissionRepeatMode _repeatMode;
  int _customRepeatCount;
  int _delayBetweenRepeatsMs;
  bool _debugOverlayEnabled = false;
  bool _isLoadingSavedMessages = true;
  bool _isLoadingHistory = true;
  bool _isSavingMessage = false;
  String? _statusMessage;
  String? _lastError;
  TransmissionStatus _previousStatus = TransmissionStatus.idle;
  int _lastElapsedMs = 0;
  int _lastRepeatCount = 1;
  List<SavedMessageTemplate> _savedMessages = const [];
  List<TransmissionHistoryEntry> _recentHistory = const [];
  TransmissionPayload _payload = const TransmissionPayload(
    type: TransmissionPayloadType.freeText,
    userMessage: '',
    normalizedText: '',
    packetLabel: 'EMPTY',
  );
  MorseTranslation _translation = const MorseTranslation(
    sourceText: '',
    words: [],
    unsupportedCharacters: [],
  );
  bool _isDisposed = false;
  bool _listenersAttached = false;
  int _controllerListenerCount = 0;

  String get message => _message;
  int get unitMs => _unitMs;
  TransmissionRepeatMode get repeatMode => _repeatMode;
  int get customRepeatCount => _customRepeatCount;
  int get delayBetweenRepeatsMs => _delayBetweenRepeatsMs;
  bool get debugOverlayEnabled => _debugOverlayEnabled;
  bool get isLoadingSavedMessages => _isLoadingSavedMessages;
  bool get isLoadingHistory => _isLoadingHistory;
  bool get isSavingMessage => _isSavingMessage;
  bool get isTransmitting =>
      transmissionState.status == TransmissionStatus.transmitting;
  bool get hasActiveTransmission => transmissionState.isActive;
  String? get statusMessage => _statusMessage;
  String? get lastError => _lastError;
  int get activeControllerInstances => SendController.activeControllerCount;
  int get activeTransmissionServiceInstances =>
      MorseTransmissionService.activeServiceCount;
  List<SavedMessageTemplate> get savedMessages => _savedMessages;
  List<TransmissionHistoryEntry> get recentHistory => _recentHistory;
  TransmissionPayload get payload => _payload;
  MorseTranslation get translation => _translation;
  TransmissionState get transmissionState => _transmissionService.state.value;
  ValueListenable<TransmissionState> get transmissionStateListenable =>
      _transmissionService.state;
  ValueListenable<TransmissionDiagnostics> get diagnosticsListenable =>
      _transmissionService.diagnostics;
  int get activeListenerCount =>
      _controllerListenerCount + _transmissionService.totalListenerCount;

  TransmissionRepeatConfig get repeatConfig => TransmissionRepeatConfig(
        mode: _repeatMode,
        customRepeatCount: _customRepeatCount,
        delayBetweenRepeatsMs: _delayBetweenRepeatsMs,
      );

  void updateMessage(String value) {
    if (_isDisposed) {
      return;
    }

    _message = value;
    _lastError = null;
    _statusMessage = null;
    _refreshPayloadAndTranslation();
    _notifySafely();
  }

  void updateUnitMs(double value) {
    if (_isDisposed) {
      return;
    }

    _unitMs = value.round();
    _notifySafely();
  }

  void updateRepeatMode(TransmissionRepeatMode mode) {
    if (_isDisposed) {
      return;
    }

    _repeatMode = mode;
    _notifySafely();
  }

  void updateCustomRepeatCount(double value) {
    if (_isDisposed) {
      return;
    }

    _customRepeatCount = value.round();
    _notifySafely();
  }

  void updateDelayBetweenRepeatsMs(double value) {
    if (_isDisposed) {
      return;
    }

    _delayBetweenRepeatsMs = value.round();
    _notifySafely();
  }

  void toggleDebugOverlay() {
    if (_isDisposed) {
      return;
    }

    _debugOverlayEnabled = !_debugOverlayEnabled;
    _notifySafely();
  }

  void applyPreset(String preset) {
    if (_isDisposed) {
      return;
    }

    _message = preset;
    _lastError = null;
    _statusMessage = null;
    _refreshPayloadAndTranslation();
    _notifySafely();
  }

  void applySavedMessage(SavedMessageTemplate template) {
    if (_isDisposed || hasActiveTransmission) {
      return;
    }

    _log('applying saved message ${template.id}');
    _message = template.messageText;
    _lastError = null;
    _statusMessage = 'Loaded saved message: ${template.title}';
    _refreshPayloadAndTranslation();
    _notifySafely();
  }

  Future<void> sendSavedMessage(SavedMessageTemplate template) async {
    if (_isDisposed || hasActiveTransmission) {
      return;
    }

    applySavedMessage(template);
    await startTransmission();
  }

  void populateFromHistoryEntry(TransmissionHistoryEntry entry) {
    if (_isDisposed || hasActiveTransmission) {
      return;
    }

    _log('restoring history entry ${entry.timestampIso}');
    _message = entry.messageText;
    _unitMs = entry.timingUnitMs;
    _repeatMode = _repeatModeFromStoredValue(entry.repeatMode);
    _customRepeatCount = entry.repeatCount < 2 ? 2 : entry.repeatCount;
    _delayBetweenRepeatsMs = entry.delayBetweenRepeatsMs;
    _lastError = null;
    _statusMessage = 'Loaded history message.';
    _refreshPayloadAndTranslation();
    _notifySafely();
  }

  Future<void> resendHistoryEntry(TransmissionHistoryEntry entry) async {
    if (_isDisposed || hasActiveTransmission) {
      return;
    }

    populateFromHistoryEntry(entry);
    await startTransmission();
  }

  Future<void> refreshSavedMessages() async {
    if (_isDisposed) {
      return;
    }

    _isLoadingSavedMessages = true;
    _notifySafely();
    await _reloadSavedMessages();
  }

  Future<void> refreshHistory() async {
    if (_isDisposed) {
      return;
    }

    _isLoadingHistory = true;
    _notifySafely();
    await _reloadRecentHistory();
  }

  Future<bool> saveCustomMessage({
    String? existingId,
    bool isFavorite = false,
    required String title,
    required String messageText,
  }) async {
    final normalizedTitle = title.trim();
    final normalizedMessage = messageText.trim().toUpperCase();
    if (_isDisposed ||
        normalizedTitle.isEmpty ||
        normalizedMessage.isEmpty ||
        hasActiveTransmission ||
        _isSavingMessage) {
      return false;
    }

    _isSavingMessage = true;
    _lastError = null;
    _notifySafely();

    try {
      final template = SavedMessageTemplate(
        id: existingId ?? 'custom-${DateTime.now().microsecondsSinceEpoch}',
        title: normalizedTitle,
        messageText: normalizedMessage,
        isBuiltIn: false,
        isFavorite: isFavorite,
      );

      await _savedMessageRepository.saveCustomTemplate(template);
      _statusMessage = existingId == null
          ? 'Saved custom message.'
          : 'Updated saved message.';
      await _reloadSavedMessages();
      return true;
    } catch (error) {
      _reportError(
        userMessage: 'Unable to save message locally.',
        debugDetails: '$error',
      );
      return false;
    } finally {
      _isSavingMessage = false;
      _notifySafely();
    }
  }

  Future<void> deleteSavedMessage(SavedMessageTemplate template) async {
    if (_isDisposed || template.isBuiltIn || hasActiveTransmission) {
      return;
    }

    try {
      await _savedMessageRepository.deleteCustomTemplate(template.id);
      _statusMessage = 'Deleted saved message.';
      await _reloadSavedMessages();
    } catch (error) {
      _reportError(
        userMessage: 'Unable to delete saved message.',
        debugDetails: '$error',
      );
    }
  }

  Future<void> toggleSavedMessageFavorite(SavedMessageTemplate template) async {
    if (_isDisposed) {
      return;
    }

    try {
      await _savedMessageRepository.setFavorite(
        template.id,
        !template.isFavorite,
      );
      await _reloadSavedMessages();
    } catch (error) {
      _reportError(
        userMessage: 'Unable to update favorite status.',
        debugDetails: '$error',
      );
    }
  }

  Future<void> startTransmission() async {
    if (_isDisposed) {
      return;
    }

    if (!transmissionState.canStart) {
      return;
    }

    _refreshPayloadAndTranslation();
    final sequence = _timingBuilder.build(
      translation: _translation,
      unitMs: _unitMs,
    );

    if (sequence.isEmpty) {
      _statusMessage = 'Enter a supported message before transmitting.';
      _notifySafely();
      return;
    }

    _lastError = null;
    _statusMessage = 'Preparing transmission...';
    _notifySafely();

    unawaited(_runTransmission());
  }

  Future<void> stopTransmission() async {
    if (_isDisposed) {
      return;
    }

    await _transmissionService.stop();
  }

  Future<void> _runTransmission() async {
    try {
      await _transmissionService.transmit(
        buildSequence: () => _timingBuilder.build(
          translation: _translation,
          unitMs: _unitMs,
        ),
        repeatConfig: repeatConfig,
        timingUnitMs: _unitMs,
      );
    } catch (error) {
      _reportError(
        userMessage: 'Transmission failed unexpectedly.',
        debugDetails: '$error',
      );
    }
  }

  Future<void> _loadSupportData() async {
    await Future.wait<void>([
      _reloadSavedMessages(),
      _reloadRecentHistory(),
    ], eagerError: false);
  }

  void _refreshPayloadAndTranslation() {
    _payload = _protocolService.buildPayloadFromUserMessage(_message);
    _translation = _translator.translate(_payload.normalizedText);
  }

  void _handleDiagnosticsChanged() {
    if (_isDisposed) {
      return;
    }

    final diagnostics = _transmissionService.diagnostics.value;
    _lastElapsedMs = diagnostics.elapsedMs;
    if (diagnostics.currentRepeat > 0) {
      _lastRepeatCount = diagnostics.currentRepeat;
    }
  }

  void _handleTransmissionStateChanged() {
    if (_isDisposed) {
      return;
    }

    final current = transmissionState;

    switch (current.status) {
      case TransmissionStatus.idle:
        if (_previousStatus == TransmissionStatus.transmitting ||
            _previousStatus == TransmissionStatus.paused) {
          _statusMessage = 'Transmission complete.';
          unawaited(_saveHistoryEntry());
        }
        break;
      case TransmissionStatus.transmitting:
        final repeatLabel = current.totalRepeats == null
            ? 'Repeat ${current.currentRepeat} of forever'
            : 'Repeat ${current.currentRepeat} of ${current.totalRepeats}';
        _statusMessage = current.isWaitingBetweenRepeats
            ? '$repeatLabel - waiting ${_delayBetweenRepeatsMs} ms'
            : '$repeatLabel - transmitting...';
        break;
      case TransmissionStatus.paused:
        _statusMessage = 'Transmission paused.';
        break;
      case TransmissionStatus.stopped:
        _statusMessage = 'Transmission stopped.';
        break;
      case TransmissionStatus.error:
        _lastError = current.errorMessage ?? _transmissionService.lastError;
        _statusMessage = current.errorMessage ??
            'Flashlight unavailable or transmission interrupted.';
        break;
    }

    _previousStatus = current.status;
    _notifySafely();
  }

  Future<void> _saveHistoryEntry() async {
    final messageText = _payload.userMessage.trim().isEmpty
        ? _payload.normalizedText
        : _payload.userMessage.trim();
    if (messageText.isEmpty) {
      return;
    }

    final entry = TransmissionHistoryEntry(
      messageText: messageText,
      timestampIso: DateTime.now().toUtc().toIso8601String(),
      durationMs: _lastElapsedMs,
      timingUnitMs: _unitMs,
      repeatMode: _repeatMode.name,
      repeatCount: _lastRepeatCount,
      delayBetweenRepeatsMs: _delayBetweenRepeatsMs,
    );

    try {
      await _historyRepository.saveEntry(entry);
      if (!_isDisposed) {
        await _reloadRecentHistory();
      }
    } catch (error) {
      _reportError(
        userMessage: 'Unable to save transmission history locally.',
        debugDetails: '$error',
      );
    }
  }

  Future<void> _reloadSavedMessages() async {
    try {
      final loaded = await _savedMessageRepository.loadTemplates();
      if (_isDisposed) {
        return;
      }

      _savedMessages = loaded;
      _isLoadingSavedMessages = false;
      _notifySafely();
    } catch (error) {
      _isLoadingSavedMessages = false;
      _reportError(
        userMessage: 'Unable to load saved messages.',
        debugDetails: '$error',
      );
    }
  }

  Future<void> _reloadRecentHistory() async {
    try {
      final loaded = await _historyRepository.loadHistory();
      if (_isDisposed) {
        return;
      }

      _recentHistory = loaded.take(10).toList(growable: false);
      _isLoadingHistory = false;
      _notifySafely();
    } catch (error) {
      _isLoadingHistory = false;
      _reportError(
        userMessage: 'Unable to load transmission history.',
        debugDetails: '$error',
      );
    }
  }

  TransmissionRepeatMode _repeatModeFromStoredValue(String value) {
    return TransmissionRepeatMode.values.firstWhere(
      (mode) => mode.name == value,
      orElse: () => TransmissionRepeatMode.once,
    );
  }

  @override
  void dispose() {
    if (_isDisposed) {
      _log('dispose ignored because controller is already disposed');
      return;
    }

    _isDisposed = true;
    if (_activeControllerCount > 0) {
      _activeControllerCount--;
    }
    _log('disposing controller');
    _detachTransmissionListeners();
    _transmissionService.dispose();
    super.dispose();
  }

  @override
  void addListener(VoidCallback listener) {
    _controllerListenerCount++;
    super.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    if (_controllerListenerCount > 0) {
      _controllerListenerCount--;
    }
    super.removeListener(listener);
  }

  void _attachTransmissionListeners() {
    if (_listenersAttached) {
      _log('listener attachment skipped because listeners are already attached');
      return;
    }

    _log('attaching service listeners');
    _transmissionService.state.addListener(_handleTransmissionStateChanged);
    _transmissionService.diagnostics.addListener(_handleDiagnosticsChanged);
    _listenersAttached = true;
  }

  void _detachTransmissionListeners() {
    if (!_listenersAttached) {
      _log('listener removal skipped because listeners are already detached');
      return;
    }

    _log('removing service listeners');
    _transmissionService.state.removeListener(_handleTransmissionStateChanged);
    _transmissionService.diagnostics.removeListener(_handleDiagnosticsChanged);
    _listenersAttached = false;
  }

  void _log(String message) {
    debugPrint('[SendController] $message');
  }

  void _notifySafely() {
    if (_isDisposed) {
      return;
    }

    notifyListeners();
  }

  void _reportError({
    required String userMessage,
    required String debugDetails,
  }) {
    if (_isDisposed) {
      return;
    }

    _lastError = debugDetails;
    _statusMessage = userMessage;
    _notifySafely();
  }
}
