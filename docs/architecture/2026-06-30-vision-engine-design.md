# V2 Vision Engine — Design

**Status:** APPROVED-pending-review. **Living design document.**
**Date:** 2026-06-30
**Scope:** Vision Engine ONLY. Ignores protocol, FEC, framing, UI, Morse.
**Constraint:** two unmodified smartphones, zero hardware budget. Standard camera only.

## Objective

Detect and continuously track the **weakest possible optical point source** with a standard smartphone camera, at the **greatest practical distance**, robust to **camera motion**, **environmental lighting**, and **device variation** — and output a clean, **protocol-agnostic** intensity-vs-time signal that any future communication layer can consume unchanged.

The Vision Engine answers exactly two questions per frame: **where is the source** and **how bright is it** — plus **how trustworthy** that answer is. It knows nothing about symbols, bits, Morse, or protocols.

---

## Core problem reframed (so we borrow the right algorithms)

A distant flashlight at night is, optically, **a faint point source on a noisy, possibly moving background** — the *exact* problem solved for decades in **astronomy** (find a star), **radar/robotics** (track a blip), and **optical beacon systems** (find and follow a light). We reuse their mature algorithms rather than invent.

Three sub-problems, each a separate, replaceable module:
1. **Detection** — is there a credible point source, and where? (astronomy)
2. **Tracking** — maintain its identity/position over time through motion and dropouts. (radar/robotics MOT)
3. **Localization** — sub-pixel center + intensity for a precise, low-noise sample. (astrometry)
Plus **arbitration** (which source is "ours") and **motion compensation** (separate camera motion from source motion).

---

## Borrowed techniques (reuse, don't reinvent)

| Field | Proven algorithm | Use here | Maturity |
|---|---|---|---|
| Astronomy (source extraction, à la SExtractor) | **Sigma-clipped background + noise (σ) map** | Per-region adaptive background; work in **SNR units**, not absolute brightness → device/lighting invariant | Very high |
| Astronomy / radar | **Matched filter** (correlate frame with PSF kernel) | SNR-optimal weak point-source detection — pulls the source out of noise | Very high |
| Astronomy | **Frame stacking / temporal integration** (√N SNR gain) | Range booster for weak sources (align by track, then integrate) | Very high |
| Astronomy | **Median temporal combine** | Reject hot/dead pixels & transient sensor spikes across devices | Very high |
| Astrometry | **Gaussian-PSF / intensity-weighted centroid** | Sub-pixel position + clean intensity estimate | Very high |
| Radar / robotics MOT | **Kalman/EKF + constant-velocity model** | Predict the source's next position; ride dropouts (light OFF between pulses) | Very high |
| Radar / robotics MOT | **Mahalanobis-gated data association** + **track lifecycle** (tentative→confirmed→coasting→lost) | Robust multi-candidate tracking; reject spurious blips | Very high |
| AR / robotics (sensor fusion) | **IMU/gyroscope-aided motion prediction** | Use the phone's gyro to predict camera-induced shift → cheap, robust motion compensation (no costly optical flow) | High |
| Optical beacon / drone landing / lighthouse ID | **Temporal-signature / blink-coherence detection** | Distinguish the *modulating* comm source from static ambient lights — **protocol-agnostically** (uses "is it flickering coherently," not "what does it say") | High |
| Classic CV | Adaptive threshold, connected components, blob analysis | Fallback candidate detection when matched filter is overkill | Very high |
| Classic CV | Optical flow / feature registration | *Optional* global-motion fallback when no usable IMU | High (costly) |

**Deliberately avoided:** full-frame AI/CNN detection (heavy, wrong tool for a structureless point), full-frame optical flow as the primary motion strategy (CPU-expensive — IMU fusion is cheaper and more robust). These stay as last-resort fallbacks, not the core.

---

## Key design insights

1. **Work in SNR (σ-above-background), never in absolute luminance.** This is what makes detection *device- and lighting-invariant*: a Pixel and a budget Android, a dark field and a dim room, all reduce to "is there a peak ≥ k·σ above the local background." (Astronomy's core trick.)
2. **Use the gyroscope.** Every phone has one. Predicting camera rotation from the IMU lets us shift the search ROI to compensate for hand motion **cheaply and reliably** — the single biggest, lowest-cost win for the motion-robustness requirement. Vision-only motion estimation is the fallback when IMU is unavailable/poor.
3. **"Ours" = the source that modulates coherently.** A comm source flickers (any protocol); ambient lights are steady or flicker at mains frequency. A **temporal-variance / change map** flags candidates that are modulating, without decoding them → protocol-agnostic arbitration. (Beacon/lighthouse identification, generalized.)
4. **Detection ≠ tracking ≠ localization ≠ arbitration.** Four separable concerns → four replaceable modules. Swap a centroid for a PSF-fit, or a Kalman for a particle filter, without touching the rest.
5. **Adaptive everything, calibrated per device.** Measure the noise floor, fps, and (if available) exposure controllability at runtime; set thresholds in σ. No hardcoded luminance constants.

---

## Module architecture

```
 Camera frames + IMU
        │
        ▼
 ┌──────────────────────────┐
 │ 1. Acquisition &          │  abstract camera; Y-plane; sensor timestamp;
 │    Conditioning           │  exposure/gain state; optional downscale; IMU sync
 └─────────────┬────────────┘
               ▼  Frame{ y, w, h, tMs, gain, imu }
 ┌──────────────────────────┐
 │ 2. Background & Noise      │  sigma-clipped local background + σ map (EMA over time)
 │    Model                   │  → everything downstream in SNR units
 └─────────────┬────────────┘
               ▼  (frame, background, σ)
 ┌──────────────────────────┐        ┌───────────────────────────┐
 │ 3. Candidate Detection     │◀──────│ 4. Motion Compensation     │
 │    matched filter / peak    │  ROI  │   IMU-predicted shift       │
 │    ≥ k·σ  +  variance map    │ hint  │   (+ optical-flow fallback) │
 └─────────────┬────────────┘        └───────────────────────────┘
               ▼  Candidate[]{ x,y, peakSNR, modScore }
 ┌──────────────────────────┐
 │ 5. Tracker (Kalman + MOT)  │  predict/update; Mahalanobis gating;
 │                            │  track lifecycle; multi-target
 └─────────────┬────────────┘
               ▼  Track[]
 ┌──────────────────────────┐
 │ 6. Source Arbitration      │  pick the coherently-modulating, stable track
 │                            │  (reject steady ambient / mains-flicker lights)
 └─────────────┬────────────┘
               ▼  active Track
 ┌──────────────────────────┐
 │ 7. Sub-pixel Localization  │  Gaussian/intensity-weighted centroid → precise
 │                            │  position + low-noise intensity
 └─────────────┬────────────┘
               ▼
 ┌──────────────────────────┐
 │ 8. Temporal Integration    │  (optional, regime-aware) align-and-stack for
 │    (weak-signal booster)    │  weak far sources; √N SNR at a latency cost
 └─────────────┬────────────┘
               ▼
 ┌──────────────────────────┐
 │ 9. Output / Telemetry      │  emit the protocol-agnostic Track sample +
 │                            │  diagnostics; feed ROI back to (3)/(4)
 └──────────────────────────┘
        ▲
 ┌──────────────────────────┐
 │ 0. Calibration / Self-tune │  per-device noise floor, fps, exposure ctrl,
 │    (runs at start + idle)   │  σ thresholds, kernel size
 └──────────────────────────┘
```

### Responsibilities

| # | Module | Responsibility | Replaceable with |
|---|---|---|---|
| 0 | Calibration | measure device noise floor/fps/exposure controllability; set σ-thresholds | static profiles |
| 1 | Acquisition & Conditioning | camera abstraction, Y-plane, **sensor timestamps**, gain/exposure state, IMU time-sync, optional downscale | any FrameSource |
| 2 | Background & Noise Model | local sigma-clipped background + σ map; temporal EMA; outputs SNR frame | rolling-median / morphological |
| 3 | Candidate Detection | matched-filter or peak detection ≥ k·σ **and** temporal-variance map → candidates | connected-components / threshold |
| 4 | Motion Compensation | IMU-predicted inter-frame shift → ROI/search offset; optical-flow fallback | vision-only registration |
| 5 | Tracker | Kalman/EKF predict-update, Mahalanobis gating, track lifecycle, multi-target | particle filter / nearest-neighbor |
| 6 | Source Arbitration | select the coherently-modulating, stable track as "ours" | period/signature matching |
| 7 | Sub-pixel Localization | PSF/intensity-weighted centroid → position + intensity | parabolic peak interp |
| 8 | Temporal Integration | align-by-track frame stacking for weak sources (optional) | none (bypass) |
| 9 | Output/Telemetry | emit Track sample; ROI feedback; diagnostics | — |

---

## Output contract (protocol-agnostic — the whole point)

```
Track {
  intensity   : double   // background-subtracted source brightness (the signal)
  snr         : double   // intensity / local σ  (quality)
  x, y        : double   // sub-pixel position (normalized)
  size        : double   // blob extent (regime hint: point vs filled)
  tMs         : int       // frame/sensor timestamp
  locked      : bool      // arbitration has a confident active source
  confidence  : double   // composite (peakSNR × track stability × mod-coherence)
}
```
Plus a **Telemetry** side-channel for diagnostics (background σ, candidate count, IMU shift, fps, integration depth).

This is *all* the rest of the system needs. Signal Extraction turns `intensity(t)` into chips; Sync/Decoder/Protocol never touch the Vision Engine. Any protocol — OOK, Manchester, PPM, OCC, or Morse — consumes the same `Track` stream. **No protocol change ever requires a Vision Engine change**, which satisfies the brief.

---

## Robustness strategies (the three requirements)

**Camera motion**
- Primary: **IMU/gyro-predicted ROI shift** (cheap, device-common) + **Kalman prediction** (coasts through OFF gaps so the window stays on the source).
- Fallback: lightweight global registration when IMU is unusable.
- Net: the source stays inside a small predicted ROI even during hand motion → no false split/loss (the exact V1 failure, solved structurally).

**Environmental lighting**
- **SNR-domain detection** (k·σ above an adaptive local background) → invariant to ambient level and gradients.
- **Temporal-coherence arbitration** rejects steady lights and mains-flicker (50/60 Hz) sources → only a real modulating beacon is selected.
- Sigma-clipping + median temporal combine reject glints/transients.

**Device variation**
- **Camera abstraction** (resolution, fps, rolling shutter, exposure controllability) behind module 1.
- **Runtime self-calibration** (module 0): measure each device's noise floor and fps; express all thresholds in σ and in *time* (ms), never in device-specific pixels/luminance.
- Graceful degradation: no IMU → vision-only motion comp; no exposure lock → faster background adaptation; low fps → rely more on integration.

**Weakest source / max distance**
- **Matched filter** (SNR-optimal detection) + **temporal integration / stacking** (√N gain) + **sub-pixel centroid** (low-noise intensity). Together these push the bare-phone night range toward the physical limit under the zero-hardware constraint.

---

## Performance budget (mobile, real-time)

- Operate on the **Y plane**, **downscaled/ROI** where possible — full-frame work only for periodic background refresh and initial search.
- Matched filter = small separable convolution on the ROI → cheap.
- Kalman + centroid = negligible.
- Temporal integration bounded (small N) to cap latency.
- Frame-drop guard + bounded buffers (carry V1's lifecycle discipline).
- Target: keep up with camera fps with margin on mid-range Android; native (NDK) hot-path only if full-frame matched filtering proves too heavy in Dart — behind the unchanged module interface.

---

## Minimal viable Vision Engine (first V2 increment)

Not all nine modules at once. MVP that already beats V1:
1. Acquisition (Y-plane, sensor timestamp) — module 1.
2. Adaptive background + σ → SNR domain — module 2.
3. Peak/variance candidate ≥ k·σ — module 3 (matched filter later).
4. Kalman track + ROI prediction — module 5 (+ basic IMU shift, module 4).
5. Centroid localization — module 7.
6. Coherence arbitration (variance-based) — module 6.
7. Track output — module 9.

Defer matched filter, temporal stacking, optical-flow fallback, full self-calibration to later increments — each slots in behind a fixed interface. **V1's bright-region + EMA tracker is a strict subset** of this MVP and becomes the starting implementation to refactor behind module interfaces 1/3/5/7.

---

## Open questions (for review)

1. **Sensor timestamps:** are per-frame hardware timestamps reliably available across target Android devices (needed for clean timing)? If not, characterize `DateTime.now()` jitter.
2. **IMU/camera time-sync:** offset and rate alignment between gyro and frames — measure per device.
3. **Matched-filter PSF:** fixed kernel vs adaptive to measured spot size/defocus.
4. **Mains-flicker rejection:** confirm 50/60 Hz ambient is reliably separable from comm modulation at our frame rates (aliasing risk).
5. **Dart vs native:** how much full-frame work stays real-time in pure Dart before NDK is needed.
6. **Rolling shutter:** Vision Engine samples per-frame intensity; sub-frame rolling-shutter exploitation is explicitly **Signal Extraction's** concern, not the Vision Engine's — confirm this boundary holds.

---

## Recommendation

Adopt the nine-module Vision Engine with the **SNR-domain + IMU-fusion + Kalman-MOT + coherence-arbitration** core, reusing astronomy and robotics algorithms wholesale. Build the **MVP subset first** (wrapping V1's tracker behind the new interfaces), then add matched filtering and temporal integration as range-focused increments. The `Track` output contract is fixed from day one so every later protocol — and every later optional accessory — plugs in without changing this engine.
