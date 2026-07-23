# V2 Success Metrics (Milestone M00)

**Status:** Draft for review. **Living document.** Documentation only — no implementation.
**Date:** 2026-06-30
**Role:** Objective, reproducible acceptance criteria for every V2 experiment (E1–E4) and milestone. Every metric is measurable and reproducible; each experiment/milestone references its target(s) here.

> Numbers marked *provisional* are initial targets. E1 (timing/fps) and E3 (SNR range) may revise the timing, fps, and range figures; per governance, this doc is updated **before** dependent subsystems are built. V1 baselines that were never instrumented are marked **"not instrumented"** rather than guessed.

---

## Reproducibility harness (fixed so results compare across runs/devices)

**Reference messages**
- `M-SHORT` = `SOS` (3 chars)
- `M-MED` = `HELLO WORLD` (11 chars)
- `M-LONG` = `SOS HELP NEEDED NOW` (19 chars)
- A **trial** = one transmission of a stated message; a **run** = 20 trials of the same message/condition (for rate statistics).

**Reference conditions**
- `C-NIGHT` — outdoors, clear, no direct competing light in frame, ambient < ~1 lux.
- `C-INDOOR` — dim indoor room, steady LED/fluorescent lighting present (mains flicker).
- `C-DAY-SHADE` — daytime open shade (best-effort only; not a promised regime).

**Reference transmitter**
- Emitter = phone torch. Timing unit `U-STD` **recommended ≈300 ms** per E1 Phone A findings (see §E1 Findings below) — **interim, pending Phone B**; supersedes the earlier 120 ms placeholder. Same message, same unit across compared runs.

**Reference receiver postures**
- `P-BRACED` — phone steadied against a fixed object (baseline, motion ≈ 0).
- `P-HAND` — normal handheld.
- `P-MOTION` — deliberate pan at a gyro-logged rate (see Motion tolerance).

**Reference devices** — the project's **existing test phones** (current dev/test hardware). Formal low/mid/high-tier coverage (≥3 devices) is **deferred** until more hardware is available and is **not an interim pass gate**. `D-MID` in the metrics below maps to the primary current test phone.

**Instruments**
- Distance: tape/laser rangefinder.
- Timing/lock/latency: in-app timestamped event log (`start`, `lock`, `decoded`).
- FPS / processing latency: in-app counter (built in E1).
- CPU: Android Studio profiler / `adb shell top -m` (normalized to one core).
- Battery: `adb shell dumpsys batterystats` / Battery Historian over a timed run, extrapolated to %/hr.
- Thermal: `adb shell dumpsys thermalservice` (or vendor skin-temp) + FPS-stability watch.
- Motion: on-device gyro log (°/s).

**Global pass rule (interim):** a metric passes if it meets its criterion on the project's **existing test phones**. Multi-tier device coverage (≥3 devices) is a **deferred** target, not an interim gate.

---

## E1 Findings (Interim — Phone A only, Phone B pending)

Raw measurements (V2 Lab → Frame timing probe, wall-clock only):

| FPS | Mean interval | Jitter σ | Max interval | p90 | Est. dropped gaps | Proc. latency avg | Proc. latency max |
|---|---|---|---|---|---|---|---|
| 23.16 | 41.4 ms | 19.6 ms | 194 ms | 61 ms | 31 | 0.11 ms | 2.79 ms |

**Analysis:**
- Processing latency (≤2.79 ms) is negligible next to jitter (σ 19.6 ms, gaps to 194 ms) — the dominant timing error is camera-pipeline frame delivery, not our code. **Wall-clock timestamps remain acceptable** on this basis; a hardware/sensor timestamp isn't exposed by the `camera` plugin's stream API and isn't worth native platform-channel work at this stage. Open Question #1 in the Vision Engine doc stays open but deprioritized.
- Gap rate ≈2.2% of intervals (~1 stall per ~2 s, assuming a ~60 s run) — frequent enough to be a real design input. Reinforces (does not change) the roadmap's Phase 4 FEC priority; also means Module 8 (Temporal Integration) must be gap-aware when implemented (implementation detail, not a structural change).
- **No Vision Engine structural change required** — module boundaries and the `Track` contract are unaffected; this data calibrates parameters the Architecture Freeze doc explicitly left open.
- **U-STD recommendation:** ≈**300 ms** (raw pulse-width floor), derived from 4–5×p90 (244–305 ms) and 1.5–2×max-gap margin (291–388 ms). Supersedes the 120 ms placeholder. Exact bit-period/encoding allocation is an MP1 (PHY) decision built on this floor.
- **Metric #10 (Min FPS):** measured 23.16 fps vs the ≥24 fps provisional target — essentially at target; treated as E1 supplying the real number rather than a failed gate. Final target locks after Phone B.

**E1 status: IN PROGRESS.** Roadmap requires ≥2 devices before E1 formally closes and E2 begins (see roadmap E1 entry). Phone B (and any other available test phones) still needed.

---

## Metrics

### 1. Reliable communication range (night)
- **Definition:** greatest distance at which `M-MED` achieves ≥95% delivery over a run, `C-NIGHT`, `P-HAND`, `U-STD`.
- **V1 baseline:** ~8–10 m (observed, `P-HAND`; not instrumented as a delivery-rate curve).
- **V2 target (provisional):** ≥10 m must-hold; goal 25–50 m; stretch to physical bare-phone limit.
- **Measurement:** run at increasing measured distances until delivery < 95%; record the last passing distance + a delivery-vs-distance curve.
- **Pass/Fail:** PASS if ≥95% delivery at ≥10 m (must); range curve recorded.

### 2. Delivery success rate
- **Definition:** fraction of transmitted framed messages fully recovered and **exact-match** (CRC-valid in V2).
- **V1 baseline:** exact-match on clean `M-SHORT`/`M-MED` at short range (no framing/CRC; rate not formally logged).
- **V2 target:** ≥95% at rated range (`C-NIGHT`); ≥99% at ≤½ rated range with FEC.
- **Measurement:** per run, decoded-exact / 20; per condition & distance.
- **Pass/Fail:** PASS if ≥95% at rated range; ≥99% at short range.

### 3. False-positive rate while idle
- **Definition:** spurious output with **no transmitter present**, during 10-minute runs including `P-MOTION` panning across `C-INDOOR` lights.
- **V1 baseline:** ≈0 after the conservative gate (observed; not counted over long runs).
- **V2 target:** **0 false framed messages** (CRC must reject); ≤1 spurious raw character per 10 min.
- **Measurement:** 10-min idle+pan runs ×3 per device; count any emitted characters/messages.
- **Pass/Fail:** PASS if 0 false framed messages and ≤1 spurious char / 10 min.

### 4. Acquisition / lock time
- **Definition:** elapsed time from transmitter start to receiver's first valid sync-lock.
- **V1 baseline:** variable; sometimes required repeating the message to lock (poor; not measured).
- **V2 target (provisional):** median ≤2 s, p90 ≤4 s, at rated range `C-NIGHT`.
- **Measurement:** timestamp `lock` − `tx-start` over ≥20 trials; report median & p90.
- **Pass/Fail:** PASS if median ≤2 s and p90 ≤4 s.

### 5. Decode accuracy
- **Definition:** character error rate (CER) on recovered messages, and undetected-error count.
- **V1 baseline:** exact on clean short messages; degraded with motion/distance (rate not logged).
- **V2 target:** ≤1% CER at rated range post-FEC; **0 undetected corruptions** (all corruption CRC-caught).
- **Measurement:** Levenshtein(decoded, sent)/len over all delivered trials; count any CRC-passed-but-wrong.
- **Pass/Fail:** PASS if CER ≤1% and 0 undetected corruptions.

### 6. Motion tolerance
- **Definition:** delivery rate under `P-MOTION` at a defined gyro-logged pan rate, `C-NIGHT`, rated ≤½ range.
- **V1 baseline:** small hand movement caused misdecodes (qualitative failure).
- **V2 target (provisional):** ≥90% delivery under ~30°/s sustained pan (and normal handheld tremor).
- **Measurement:** run with gyro logging confirming the motion profile; delivery / 20.
- **Pass/Fail:** PASS if ≥90% delivery at the defined motion profile.

### 7. Latency (end-to-end)
- **Definition:** time from sender "send" action to the decoded message displayed on the receiver, `M-MED`, `U-STD`, rated range.
- **V1 baseline:** dominated by Morse timing; several seconds (not logged precisely).
- **V2 target (provisional):** ≤ (message on-air time at chosen rate) + ≤1 s overhead; e.g. ≤5 s for `M-MED` at `U-STD`.
- **Measurement:** receiver `decoded` timestamp − sender `send` timestamp (clocks noted; use on-air + processing components).
- **Pass/Fail:** PASS if within target for `M-MED`.

### 8. CPU usage
- **Definition:** mean CPU (normalized to one core) during continuous receive, 5-min run, `D-MID`.
- **V1 baseline:** not instrumented.
- **V2 target (provisional):** ≤25% sustained on `D-MID`; UI stays at display refresh with no visible jank.
- **Measurement:** profiler/`top` sampled over the 5-min run; record mean & peak.
- **Pass/Fail:** PASS if ≤25% mean on `D-MID` and no UI jank.

### 9. Battery consumption
- **Definition:** drain rate (%/hr) during continuous receive (torch off) and continuous transmit (torch on), `D-MID`.
- **V1 baseline:** not instrumented.
- **V2 target (provisional):** receive ≤10%/hr on `D-MID`; transmit reported (torch-bound, informational).
- **Measurement:** `batterystats`/Historian over a ≥30-min run, extrapolate to %/hr; separate RX and TX.
- **Pass/Fail:** PASS if receive ≤10%/hr on `D-MID`; TX figure documented.

### 10. Minimum FPS
- **Definition:** sustained processed camera frames/sec under full receive load, 5-min run.
- **V1 baseline:** ~camera rate (~30 fps assumed; not measured under load).
- **V2 target (provisional, set by E1):** ≥24 fps sustained on `D-MID`, and ≥ the minimum required by the chosen symbol rate on every tier.
- **Measurement:** in-app fps counter over the run; record min/mean.
- **Pass/Fail:** PASS if sustained ≥ target with no sustained dips below the symbol-rate minimum.

### 11. Thermal behavior
- **Definition:** thermal stability over sustained use — ≥10 min continuous receive and ≥5 min continuous transmit (torch heats).
- **V1 baseline:** not instrumented.
- **V2 target:** no thermal-throttling-induced FPS collapse or shutdown over the window; skin temp within device normal.
- **Measurement:** `thermalservice`/skin temp logged + FPS-stability watch across the window.
- **Pass/Fail:** PASS if no throttle-induced FPS drop and no thermal warning/shutdown over the window.

### 12. Supported device coverage
- **Definition:** number of Android devices passing the **core acceptance** (metrics 1–6) across tiers.
- **V1 baseline:** functional on the development/test device(s).
- **V2 target (interim):** pass the core acceptance (metrics 1–6) on the project's **existing test phones**. Formal ≥3-device / per-tier coverage is **deferred** (future target, not an interim gate).
- **Measurement:** run the core acceptance suite on each available test phone; record pass/fail per metric.
- **Pass/Fail (interim):** PASS if the existing test phones pass metrics 1–6.

---

## Summary table

| # | Metric | V1 baseline | V2 target (provisional) | Instrument | Pass criterion |
|---|---|---|---|---|---|
| 1 | Range (night) | ~8–10 m (obs.) | ≥10 m must / 25–50 m goal | rangefinder + delivery runs | ≥95% @ ≥10 m |
| 2 | Delivery rate | exact @ short (unlogged) | ≥95% rated / ≥99% short | trial counts | ≥95% @ rated |
| 3 | Idle false-positives | ≈0 (obs.) | 0 framed / ≤1 char per 10 min | 10-min idle+pan runs | 0 framed msgs |
| 4 | Lock time | variable/poor | median ≤2 s, p90 ≤4 s | event log | median ≤2 s |
| 5 | Decode accuracy | exact clean (unlogged) | ≤1% CER, 0 undetected | diff vs sent | ≤1% CER, 0 undetected |
| 6 | Motion tolerance | fails on small motion | ≥90% @ ~30°/s | gyro-logged runs | ≥90% delivery |
| 7 | Latency | ~seconds (unlogged) | ≤ on-air + ≤1 s (≤5 s M-MED) | send→display ts | within target |
| 8 | CPU | not instrumented | ≤25% mean D-MID | profiler/top | ≤25%, no jank |
| 9 | Battery | not instrumented | RX ≤10%/hr D-MID | batterystats | ≤10%/hr RX |
| 10 | Min FPS | ~30 (unmeasured) | ~23.16 measured Phone A (interim, pending Phone B) | in-app counter | ≥ target sustained |
| 11 | Thermal | not instrumented | no throttle over 10min RX / 5min TX | thermalservice + fps | no throttle collapse |
| 12 | Device coverage | dev device(s) | ≥3 devices, ≥1/tier | per-device suite | ≥3 pass metrics 1–6 |

---

## Review decisions (settled 2026-06-30)
- **Provisional targets accepted as-is** (range 10 m must-hold, lock ≤2 s, CPU ≤25%, battery RX ≤10%/hr, FPS ≥24, etc.), clearly marked *provisional*. E1 sets FPS/timing figures; E3 sets achievable range — those cells update after their reviews.
- **Reference devices = the project's existing test phones.** Multi-tier (≥3) coverage deferred, not an interim gate.
- **`U-STD` deferred to E1** (120 ms interim placeholder only).
- **Daylight (`C-DAY-SHADE`) is best-effort only — NOT a V2 pass criterion.**

## E1 architecture review — Phone A (interim)
- FPS/jitter/U-STD figures recorded above (§E1 Findings). No Vision Engine structural change. Wall-clock timestamps confirmed acceptable. `U-STD` revised 120 ms → **~300 ms** (interim).
- **E1 not yet closed** — roadmap requires ≥2 devices; Phone B pending before E2 begins.
