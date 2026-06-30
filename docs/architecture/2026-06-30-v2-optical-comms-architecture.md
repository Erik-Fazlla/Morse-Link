# Version 2 — Offline Long-Range Optical Communication System

**Status:** Architecture draft for review. No implementation.
**Date:** 2026-06-30
**Supersedes (scope):** the Morse-only product framing. V1 is frozen as proof-of-concept baseline (bug fixes only).
**Source study:** the V2 research study (physics, OCC/VLC, CV, protocol analysis).

> Design goal: the best architecture for the next ~5 years. Every subsystem must be **independently replaceable**. The document therefore specifies **interfaces (contracts) between layers**, not just boxes.

---

## 1. Product Vision

An **offline, light-only communication system** between two smartphones — no cellular, Wi-Fi, Bluetooth, or internet. One phone's light source transmits; another phone's camera receives and decodes.

- **Primary use:** reliable short-message communication for emergencies and off-grid scenarios.
- **Range goal:** tens of meters handheld at night today; **hundreds of meters** with accessories (collimator + tripod), as physics allows. Daylight is a gated stretch goal.
- **Reliability over rate:** correctness and graceful degradation beat throughput. A message that arrives slowly but intact wins.
- **Human-survivable fallback:** a person must still be able to read an SOS by eye if software fails — Morse remains as a fallback mode, not the core.
- **Hardware-aware:** the product treats optics/mounts as part of the system, with an aiming UI and accessory support.

Non-goals (v2): high-bandwidth data transfer, multi-party broadcast networks, non-line-of-sight operation.

---

## 2. Design Principles

1. **Layered PHY/Link/Transport stack with strict interfaces.** Any layer swappable without touching its neighbors.
2. **Profile-driven, negotiated link.** A *Link Profile* bundles {modulation, symbol rate, FEC, framing}. The preamble carries a profile ID; the receiver self-configures. New profiles ship without breaking old ones.
3. **Two optical regimes**, auto-selected: rolling-shutter OCC (source fills sensor, short range, high rate) and integrated frame-OOK/PPM (point source, long range).
4. **Graceful degradation.** Weak signal → lower rate / stronger FEC / Morse fallback, never a crash.
5. **Offline & private by construction.** No network code paths exist.
6. **Testable in isolation.** Every layer accepts synthetic inputs; pure logic separated from I/O (camera/torch) behind interfaces.
7. **Safety first** for any future high-power/laser accessory (hard-gated, eye-safety reviewed).
8. **V1 preserved.** Morse mode is a registered profile + human fallback, not deleted.

---

## 3. System Architecture

### Layer stack

```
 TX PHONE                                   RX PHONE
 ┌─────────────┐                            ┌─────────────┐
 │ App / UI    │   compose, status, aim     │ App / UI    │
 ├─────────────┤                            ├─────────────┤
 │ Session     │   pairing, ARQ, retries    │ Session     │
 ├─────────────┤                            ├─────────────┤
 │ Transport   │   framing, fragmentation   │ Transport   │
 ├─────────────┤                            ├─────────────┤
 │ Link / FEC  │   FEC encode, CRC, intlv   │ Link / FEC  │
 ├─────────────┤                            ├─────────────┤
 │ PHY-Modem   │   modulate (OOK/Manch/PPM) │ PHY-Modem   │
 │ + Sync(pre) │   + preamble               │ + Sync      │
 ├─────────────┤                            ├─────────────┤
 │ Emitter     │   torch/LED driver         │ Vision +    │
 │ (light out) │ ─────────  photons  ─────▶ │ Extraction  │
 └─────────────┘                            └─────────────┘
```

### RX pipeline (the hard side) and module boundaries

```
Camera ─▶ VISION ENGINE ─▶ SIGNAL EXTRACTION ─▶ SYNCHRONIZATION ─▶ DECODER(demod+FEC) ─▶ TRANSPORT ─▶ SESSION ─▶ UI
          (where/bright)     (intensity→chips)    (preamble/clock)   (chips→bytes,correct)  (frames)   (msgs)
```

### Interface contracts (the core of replaceability)

| Boundary | Data type crossing it | Abstract interface (RX) |
|---|---|---|
| Camera → Vision | `Frame { planes, width, height, tMs }` | `FrameSource.frames()` |
| Vision → Extraction | `Track { intensity, x, y, size, snr, tMs, regimeHint }` | `VisionEngine.process(Frame) → Track?` |
| Extraction → Sync | `Chip { value:double, soft:double, tMs }` (soft = confidence/LLR) | `SignalExtractor.push(Track) → Chip*` |
| Sync → Decoder | `SymbolFrame { symbols, symbolRateHz, phase, profileId }` | `Synchronizer.push(Chip) → SymbolFrame?` |
| Decoder → Transport | `Block { bytes, crcOk, fecStats }` | `Demodulator.decode(SymbolFrame)`, `FecCodec.decode(...)` |
| Transport → Session | `Frame { type, seq, payload, flags }` | `FrameCodec.parse(bytes)` |
| Session → UI | `Message { payload, peer, seq, status }` | `Session.inbox()` |

TX mirrors these (`Modulator`, `Emitter/TorchDriver`, `FrameCodec.build`, `FecCodec.encode`).

**Why this matters:** swapping Manchester→PPM touches only `Modulator`/`Demodulator`; swapping centroid→Kalman touches only `VisionEngine`; adding LDPC touches only `FecCodec`. Contracts stay fixed.

---

## 4. Physical Layer (PHY)

### Transmit
- **Emitter abstraction** (`Emitter`): torch today; future external/USB-C LED or filtered source behind the same interface.
- **Torch driver:** precise on/off timing engine (V1 already has an accurate one — reuse the concept). Timing unit and duty configurable per profile.
- **Modulation schemes** (selectable per profile):
  - **OOK** (on-off keying) — baseline.
  - **Manchester** — edge every symbol → self-clocking, drift-immune (mid-range default).
  - **PPM** — bits encoded in pulse *position*; few photons/symbol → best long-range/low-light.
- **Preamble** prepended by PHY (see §6) carrying profile ID + sync pattern.

### Receive — two regimes (auto-selected by Extraction)
| Regime | When | Mechanism | Rate | Range |
|---|---|---|---|---|
| **Rolling-shutter OCC** | source spans many sensor rows (near) | decode banding within a frame | high (≫ fps) | short |
| **Frame-OOK/PPM (integrated)** | source is a point (far) | one intensity sample/frame + temporal integration | ≤ fps | long |

### Optical parameters (design knobs, not software-fixable)
- Beam divergence (Lambertian torch) = dominant range ceiling → addressed by optics (§10).
- Background light (daylight) = SNR ceiling → addressed by narrowband filter + matched emitter (§10).
- Frame rate = symbol-rate ceiling for the far regime; integration time = range-vs-rate trade.

### Safety
- Phone torch: inherently eye-safe.
- **Any future laser/high-power accessory is hard-gated** behind explicit safety review and user acknowledgment; not enabled by default.

---

## 5. Vision Engine

Answers only: *where is the light and how bright*, per frame. No protocol knowledge.

| Module | Responsibility | Replaceable with |
|---|---|---|
| Acquisition | pull frames, expose Y-plane, lock exposure/focus *(safely)* | plugin/native source |
| ROI manager | restrict processing to a predicted window | full-frame fallback |
| Blob detector | find candidate bright source(s) | threshold / connected-components / OpenCV |
| **Tracker** | **Kalman** predict-update on spot position; ride dropouts/motion | centroid-only / particle filter |
| Sub-pixel centroid | PSF-weighted center for precise aim & weak-signal localization | intensity-weighted centroid |
| Multi-source arbiter | pick "our" source (blink signature) vs ambient lights | lighthouse-style period match |
| Calibration/AGC hook | feed exposure/gain state to Extraction | — |

**Output contract:** `Track { intensity, x, y, size, snr, tMs, regimeHint }`. Emits `null` when no credible source (so downstream can stay idle — near-zero false-positive principle from V1 carried forward).

**Carry-over from V1:** the bright-region extraction + EMA spot tracking become the *first implementation* of this layer; Kalman + sub-pixel + multi-source are the planned upgrades behind the same contract.

---

## 6. Signal Extraction

Turns `Track` (intensity vs time) into `Chip`s (raw symbol estimates). No semantics.

- **AGC / adaptive baseline:** adaptive floor/peak envelope (V1's `LightDetector` concept) → contrast-invariant.
- **Temporal integration:** stack N frames (matched/boxcar filter) for weak far signals — range gain, at a rate cost.
- **Regime selector:** decide OCC vs frame-OOK from `Track.size`/snr; route accordingly.
- **Demod front-end:** produce **soft** values (confidence / log-likelihood), not just hard bits — lets FEC use soft-decision decoding (big coding-gain win).
- **Min-pulse / hysteresis debounce:** reject sub-symbol glitches (V1 concept retained).

**Output:** `Chip { value, soft, tMs }` stream.

---

## 7. Synchronization

Replaces V1's heuristic confidence gating with **deterministic, preamble-based acquisition** — this structurally resolves the "lock fast vs avoid false locks" tension that dominated V1.

- **Preamble pattern:** a known sequence (e.g. alternating/Barker-like) prepended to every frame. Detected by correlation.
- **Acquisition:** correlate incoming chips against the known preamble → declares lock only on a strong correlation peak → near-zero false lock *and* fast lock (no "needs several letters of evidence" heuristic).
- **Clock / symbol-rate recovery:** estimate symbol rate & phase from the preamble (and maintain via edges if Manchester). Tolerates sender/receiver clock mismatch and frame-rate jitter.
- **States:** `SEARCHING → ACQUIRED(tracking phase) → FRAME_SYNC`. Loss of correlation → back to SEARCHING.
- **Profile read:** preamble encodes the **Link Profile ID** → configures modulation/rate/FEC for the rest of the frame.

**Output:** `SymbolFrame { symbols, symbolRateHz, phase, profileId }`.

---

## 8. Communication Protocol

A small layered stack, each layer independently versioned.

| Layer | Function |
|---|---|
| **PHY-Modem** | modulation + preamble + sync (above) |
| **Link** | per-frame FEC + CRC + interleaving (§9) |
| **Transport** | message framing, fragmentation/reassembly, sequence numbers (§10) |
| **Session** | pairing/handshake, **ARQ** (ACK + retransmit) when a back-channel exists, one-way beacon mode when not |

### Link Profiles (the extensibility core)
A profile = `{ id, modulation, symbolRateHz, fecScheme, framingVersion }`. Examples:
- `0` = **Morse legacy** (V1 compatibility).
- `1` = OOK + CRC, slow, robust.
- `2` = Manchester + Reed-Solomon (mid-range default).
- `3` = PPM + RS, long-range/low-light.
- Future ids add OCC high-rate, LDPC, adaptive, etc.

**Adaptive link:** Session may negotiate/step the profile to measured SNR (start robust, climb if conditions allow; fall back on errors). One-way mode picks a fixed conservative profile.

---

## 9. Error Correction

Light links are bursty and dropout-prone → FEC is essential (recovers without retransmission — vital for one-way beacons).

| Mechanism | Role | Notes |
|---|---|---|
| **CRC-16/32** | error *detection* per frame | cheap, mandatory |
| **Reed-Solomon** | burst-error *correction* | strong vs dropouts; default |
| Convolutional / **LDPC** (optional) | soft-decision coding gain | uses Extraction's soft outputs; future profile |
| **Interleaving** | spread bursts across the codeword | turns long dropouts into correctable scattered errors |
| **ARQ** | retransmit on CRC fail | only when back-channel exists (two-way) |

**Soft-decision path:** Extraction emits LLRs → FEC decodes with them → meaningful range/reliability gain over hard decisions. Reuse a proven FEC library; never hand-roll.

---

## 10. Message Framing

Versioned, self-describing frame so decoders can evolve.

```
+----------+----------+---------+---------+--------+-----------+--------+
| PREAMBLE | PROFILE  | VERSION | LENGTH  | SEQ    | PAYLOAD   | CRC    |
| + sync   | ID (1B)  | (1B)    | (1-2B)  | (1-2B) | (FEC-enc) | (2-4B) |
+----------+----------+---------+---------+--------+-----------+--------+
            \___________________ FEC-protected ___________________/
```

- **Profile ID** → how to demodulate/decode the rest.
- **Version** → frame-format evolution without breaking old receivers.
- **Length** → bounds the payload; enables reassembly.
- **Seq** → fragmentation/reassembly + ARQ + duplicate suppression.
- **Payload** → FEC-encoded user bytes; fragmented across frames if large.
- **CRC** → final integrity gate.

Fragmentation/reassembly lives in Transport; a message = ordered frames keyed by seq.

---

## 11. Future Hardware Support

An **Accessory/Capability abstraction** so hardware extends the system without code forks.

- **Capability flags** on each side: `{ collimated, telephoto, externalEmitter, narrowbandFilter, mountStabilized, maxOpticalPower }`. Negotiated/known per device; influence default profile, integration time, and aiming UI.
- **Aiming UI** (software, hardware-enabling): on-screen reticle + live signal/SNR meter + spot-lock indicator → makes long-range pointing feasible.
- **Emitter abstraction:** torch / external USB-C LED / filtered source — one interface.

| Accessory | System hook | Est. range effect |
|---|---|---|
| Collimator/clip optic (TX) | profile picks tighter integration; aiming UI required | ×10–50 |
| Tripod/mount (both) | enables longer integration + stable tracking + precise aim | ×2–5 (enabler) |
| Telephoto (RX) | more pixels/photons on spot → SNR | ×2–4 |
| External high-power LED | Emitter capability; power-aware | ×3–10 |
| Narrowband filter + matched emitter | daylight background rejection | daylight enabler |
| (Laser) | **safety-gated**, opt-in only | huge / ⚠ hazard |

---

## 12. Compatibility with Version 1 (Morse Mode)

- **Morse = Link Profile 0**, a first-class registered profile in the V2 stack. The V1 translator/timing/decode logic is wrapped behind the V2 `Modulator`/`Demodulator` interfaces — reused, not rewritten.
- **Human fallback mode:** a dedicated UI mode that transmits/recognizes Morse with no framing/FEC, so a person can read SOS by eye and the app degrades to "just a signaling light" if everything else fails.
- **Interop:** a V2 receiver detecting a Morse-pattern (or profile 0 preamble) decodes it via the Morse profile. V1 devices remain usable as Morse-only peers.

---

## 13. Migration Strategy V1 → V2

Incremental, each step shippable; V1 stays frozen and runnable throughout.

1. **Freeze V1** as the `morse-v1` baseline (done conceptually). Tag it. Only critical bug fixes.
2. **Introduce the V2 interfaces** (`FrameSource`, `VisionEngine`, `SignalExtractor`, `Synchronizer`, `Demodulator`, `FecCodec`, `FrameCodec`, `Modulator`, `Emitter`) as empty contracts. No behavior change.
3. **Wrap V1 inside them** as Profile 0 (Morse): existing camera/detector/sync/decoder become the first implementations behind the new contracts. Proves the abstractions with known-good code.
4. **Add Profile 1 (framed OOK + preamble + CRC)** end-to-end — the first *new* PHY. Deterministic sync replaces heuristic gating. Validate TX↔RX between two phones.
5. **Add FEC (Profile 2: Manchester + Reed-Solomon)** + interleaving. Reliability/range step.
6. **Vision upgrade** (Kalman + sub-pixel + temporal integration) behind the unchanged `VisionEngine` contract — benefits all profiles.
7. **PPM + adaptive link + soft-decision** (Profile 3) for long range/low light.
8. **OCC rolling-shutter regime** + regime auto-select for short-range high rate.
9. **Hardware/accessory support + aiming UI + daylight path.**

**Code-reuse map:** V1 `MorseTranslator`/timing → Profile 0 Modulator/Demodulator; `LightDetector` → SignalExtractor v1; `CameraLightSource` (+ tracking) → VisionEngine v1; `TransmissionSynchronizer` → replaced by preamble Synchronizer for Profile ≥1 (kept for Profile 0). Lifecycle/disposal discipline carried into all I/O modules.

**Parallel-run / flagging:** V2 ships behind a mode switch; Morse-v1 path remains selectable until V2 profiles are field-proven.

---

## 14. Cross-Cutting Concerns

- **Testing:** every layer driven by synthetic inputs (continue the V1 discipline — synthetic pulse/luminance trains, now extended to frames, chips, symbols, FEC blocks). Loopback tests: Modulator→Demodulator, Encoder→Decoder, full TX→RX simulation without hardware.
- **Performance:** target real-time at camera fps; native hot-path only if full-frame OCC demands it. Frame-drop guard + bounded buffers (V1 discipline).
- **Observability:** developer overlay (SNR, profile, sync state, FEC stats, spot track) — extend V1's diagnostics.
- **Lifecycle:** strict dispose/guard discipline on camera/torch (the V1 regressions taught this — keep it as a rule).
- **Versioning:** profile + frame-version fields make the wire format forward/backward compatible.

## 15. Risks & Open Questions (for review)

1. Rolling-shutter OCC feasibility across the wide range of phone cameras (API access to raw rolling-shutter timing varies).
2. Achievable frame timing precision via `DateTime.now()` vs sensor timestamps — may need platform timestamps for tight clock recovery.
3. Two-way ARQ requires both phones to alternate TX/RX (half-duplex) — session/turn-taking design needed.
4. PPM/soft-decision complexity vs benefit at our SNRs — validate empirically before committing.
5. Daylight: likely needs a narrowband emitter accessory — confirm before promising daytime range.
6. How much native (NDK) code is acceptable vs pure Dart, given the cross-platform goal.

---

## Recommendation

Adopt the **layered, profile-driven stack** above. Build the **interfaces first**, wrap **V1 as Profile 0**, then add **Profile 1 (framed OOK + preamble + CRC)** as the first real V2 increment — it delivers the biggest reliability jump (deterministic sync + integrity) with the least optical risk, and proves the whole architecture end-to-end before investing in FEC, vision upgrades, and optics.
