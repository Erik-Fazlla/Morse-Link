# RECEIVE Mode — Design Spec

**Date:** 2026-06-28
**Status:** Approved (design); implementation pending
**Scope:** Phase 2 — implement the RECEIVE feature. Receive Morse transmitted by another phone's flashlight and decode it to readable text. Do not modify SEND behavior.

---

## 1. Goal

Point the camera at another phone's flashlight, detect flashes, classify them into Morse, decode into text. Offline only (no internet / cellular / Bluetooth / Wi-Fi). Correctness, modularity, and maintainability over speed.

## 2. Constraints

- **Do not modify the SEND system's behavior.** The shared-domain refactor (Section 4) is additive: it relocates constants and updates imports, with no behavioral change. Existing tests must stay green.
- Reuse existing Morse + timing logic via the shared domain.
- Preserve the existing controller/notifier lifecycle discipline (dispose guards, listener accounting, `_isDisposed` checks, static instance counters).
- Each pipeline stage is a separate service. No god-class.
- No timing hardcoded in classification — driven by an estimated unit.

## 3. Module Layout (new `lib/features/receive/`)

```
domain/
  light_reading.dart      // {double luminance, int timestampMs}
  pulse.dart              // {bool isOn, int durationMs}
  pulse_symbol.dart       // enum dot|dash|symbolGap|letterGap|wordGap|unknown
  sync_phase.dart         // enum searching|synchronizing|locked
  signal_quality.dart     // {bool detected, int estUnitMs, double signalStrengthPct, double decodeConfidencePct}
  receive_state.dart      // {ReceiveStatus status, SyncPhase syncPhase, SignalQuality quality, String morse, String text, String? errorMessage}
  decoded_message.dart    // {String text, String morse, DateTime receivedAt, SignalQuality quality}
services/
  light_source.dart       // abstract LightSource (interface) + later CameraLightSource
  light_detector.dart     // luminance stream -> ON/OFF transitions (adaptive threshold + hysteresis)
  pulse_timer.dart        // transitions -> Pulse{isOn,durationMs} (the "ON 160ms / OFF 480ms" events)
  unit_estimator.dart     // adaptive timing-unit estimator (calibration hook)
  transmission_synchronizer.dart  // sync state machine; owns UnitEstimator; gates decoding
  pulse_classifier.dart   // Pulse + estUnit -> PulseSymbol (ratios from morse_timing, not hardcoded ms)
  morse_accumulator.dart  // symbol stream -> running "... --- ..." + letter/word flush
  morse_decoder.dart      // morse string -> text (inverse of shared alphabet)
presentation/
  receive_controller.dart            // ChangeNotifier orchestrator (mirrors SendController)
  screens/receive_screen.dart
```

## 4. Shared Morse Domain Refactor (additive)

Single source of truth, consumed by both SEND and RECEIVE.

- `lib/features/morse/domain/morse_alphabet.dart` — the 50-entry `Map<String,String>` alphabet, lifted out of `MorseTranslator._alphabet`. Translator imports it; `translate()` logic unchanged.
- `lib/features/morse/domain/morse_timing.dart` — unit ratios as named constants: `dotUnits=1, dashUnits=3, symbolGapUnits=1, letterGapUnits=3, wordGapUnits=7`. `TimingSequenceBuilder` references them (replacing inline `unitMs * 3` etc.); RECEIVE classifier references the same.

`MorseDecoder` builds the inverse map (`morse -> char`) from `morse_alphabet`. Drift impossible — one table.

**SEND files touched (imports/constants only, no behavior change):** `morse_translator.dart`, `timing_sequence_builder.dart`.

## 5. Data Flow

```
CameraLightSource (LightSource)
  -> LightReading{luminance, timestampMs}
  -> LightDetector            (adaptive threshold + hysteresis) -> ON/OFF transition
  -> PulseTimer               -> Pulse{isOn, durationMs}
  -> TransmissionSynchronizer (searching -> synchronizing -> locked; owns UnitEstimator)
        | (only when LOCKED)
        v
     PulseClassifier          (duration vs estUnitMs, ratios from morse_timing) -> PulseSymbol
  -> MorseAccumulator         (builds running morse; flush letter on letterGap, word on wordGap)
  -> MorseDecoder             -> growing text
  -> ReceiveController.notify -> UI
```

Push-based. Classification fires only on transitions, not per frame. Luminance is computed by sampling every Nth pixel of the camera Y-plane — low CPU, no UI freeze (image stream runs off the main isolate/thread).

## 6. TransmissionSynchronizer (new stage)

Sits between `PulseTimer` and `PulseClassifier`. Owns the `UnitEstimator`. Runs a state machine and **gates decoding** so symbols are only emitted once timing is locked.

- **searching** — waiting for real signal activity above the noise floor. No symbols emitted.
- **synchronizing** — signal seen; feed initial pulses to `UnitEstimator` until the estimated unit is stable (variance under threshold across a small window). No symbols emitted yet.
- **locked** — unit stable; pass pulses through to `PulseClassifier`; decoding proceeds. Continues refining the estimate.
- **loss of sync** — prolonged idle or erratic timing returns the machine to `searching`; pending letter is flushed.

This is the seam for future preamble detection, message acknowledgements, and bidirectional handshakes — they slot into the synchronizer without touching detection or classification.

## 7. Adaptive Timing (readiness only — no calibration UI this phase)

`PulseClassifier` never hardcodes milliseconds; it asks the synchronizer's `UnitEstimator` for the current `estUnitMs` and compares pulse durations against unit multiples using the `morse_timing` ratios.

v1 `UnitEstimator`: seed default 180 ms (matches SEND default), then refine to the median of the shortest ON pulses observed. Future auto-calibration, noise filtering, and error correction are swap-in implementations behind `UnitEstimator` / `LightDetector` / `TransmissionSynchronizer` interfaces — no rewrite.

## 8. Lifecycle (preserves existing fixes)

`ReceiveController` mirrors `SendController`: `_isDisposed` + per-method guards, `_notifySafely`, static `activeControllerCount`, listener accounting. `dispose()` stops the image stream, disposes the `CameraController`, detaches listeners. A `ReceiveSessionScreen` StatefulWidget owns and disposes the controller — identical pattern to `SendSessionScreen`. Frames processed only while `status == receiving`.

## 9. Error Handling (never crash)

`ReceiveStatus.error` carries a reason:
- **cameraUnavailable** — no camera / init failed.
- **permissionDenied** — camera permission refused.

Non-fatal degradations keep the session running:
- **weak signal** — low `signalStrengthPct`; stays in `searching`/`synchronizing`.
- **invalid pulse** — classified `unknown`, skipped; lowers `decodeConfidencePct`.
- **interrupted transmission** — idle timeout flushes the pending letter; synchronizer drops to `searching`.

## 10. Signal Quality — two distinct measures

Separated in the domain and in the UI:

- **Signal strength** (`signalStrengthPct`) — optical quality: contrast between ON luminance and OFF baseline (SNR-style). "How clearly do I see the light?"
- **Decode confidence** (`decodeConfidencePct`) — timing fit: how cleanly observed pulse durations cluster onto expected unit multiples. "How sure am I of the decode?"

Plus `signalDetected` (bool) and `estUnitMs` (estimated timing unit). The UI shows signal strength and decode confidence as two separate indicators, never merged.

## 11. RECEIVE Screen + Navigation

- New `receive_screen.dart`: live camera preview, sync-phase / detection status, **Start Receiving** / **Stop Receiving**, live Morse string (`... --- ...`), decoded text (`Receiving... -> HELLO`), and the signal-strength + decode-confidence indicators (separate).
- Navigation: enable the existing RECEIVE tile on `HomeScreen` (replace the `_DisabledPanel` "Coming Soon" with an `_ActionPanel` that pushes `ReceiveSessionScreen`). This is the only existing-UI edit; SEND logic is untouched and follows the established push-a-session-screen pattern.

## 12. Dependency

Add `camera: ^0.11.x` to `pubspec.yaml`. Android `CAMERA` permission is already present (the torch controller requests `Permission.camera`); verify `AndroidManifest.xml` during M3.

## 13. Deferred (explicitly out of this phase)

- `ReceivedHistoryRepository` + Received-History screen — deferred until the core receive pipeline is proven reliable. No persistence of received messages this phase.
- Automatic timing calibration, noise filtering, error correction, message acknowledgements, bidirectional / optical-chat mode — architecture supports them (Sections 6–7); not implemented.

## 14. Testing Strategy

Validates success criteria offline, without two phones:

- `FakeLightSource` replays a synthetic luminance train (e.g. an "SOS" / "HELLO" pulse sequence) through the full pipeline; assert decoded text equals the source.
- Unit tests per stage: `LightDetector` (threshold/hysteresis), `PulseTimer` (durations), `UnitEstimator` (convergence), `TransmissionSynchronizer` (phase transitions + lock/loss), `PulseClassifier` (symbol mapping), `MorseAccumulator` (flush boundaries), `MorseDecoder` (morse->text, unknown handling).
- Existing SEND tests (`morse_translator_test`, `widget_test`) must remain green after the shared refactor.

## 15. Milestones (build incrementally; validate each before the next)

- **M0 — Shared refactor.** Extract `morse_alphabet` + `morse_timing`; repoint translator/builder. **Validate:** existing tests green; SEND behavior unchanged.
- **M1 — Decode core (no camera).** Domain models + `UnitEstimator`, `TransmissionSynchronizer`, `PulseClassifier`, `MorseAccumulator`, `MorseDecoder`. **Validate:** unit tests; synthetic pulse train -> "SOS"/"HELLO".
- **M2 — Light -> pulses.** `LightSource` interface + `FakeLightSource`, `LightDetector`, `PulseTimer`. **Validate:** synthetic luminance train -> pulses -> (M1) -> text, full pipeline offline via `FakeLightSource`.
- **M3 — Camera integration.** Add `camera` dependency, manifest check, `CameraLightSource`, live preview, `ReceiveController` orchestration + lifecycle. **Validate:** runs on device; lifecycle/leak counters clean.
- **M4 — Screen + navigation.** `receive_screen` (all UI elements, strength vs confidence separate), enable HomeScreen tile. **Validate:** manual device test against a real flashlight transmission; meets success criteria.

## 16. Success Criteria

A user can: open RECEIVE -> point camera at another phone's flashlight -> detect flashes -> convert to Morse -> decode to readable text. (Save deferred per Section 13.)
