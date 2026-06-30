# Physical-Layer Systems Study — Smartphone Optical Comms

**Status:** Living design document. Update when research or field testing changes assumptions.
**Date:** 2026-06-30
**Companion:** `2026-06-30-v2-optical-comms-architecture.md`, `2026-06-30-vision-engine-design.md`

---

## Final product constraint (decision of record)

**The product is designed around two completely unmodified smartphones. Zero hardware budget.**
- The core architecture must **not** depend on telephoto lenses, collimators, tripods, external LEDs, or optical filters.
- Accessories are **future, optional extensions only** — they may never be required and must not influence core design.
- **Baseline promise:** *two ordinary smartphones communicate offline using only their built-in flashlight and camera.* Everything in V2 optimizes for this baseline.

This study's physics stands; its accessory analysis is retained only as **future-extension reference**. The recommended strategy below is updated to reflect the constraint: **optimize the bare-phone link; treat all optics as optional add-ons layered on the same accessory-agnostic PHY.**

---

## Verdict

The phone torch/camera pair is the **correct core platform** and, per the constraint above, the **only one the architecture targets**. Bare-phone reliable range is the design target. Accessories are documented as optional future extensions but are explicitly **out of the core**.

---

## Physics — the three levers

1. **Beam divergence (dominant).** Torch is Lambertian (~120°); range ∝ √(on-axis intensity). Software cannot collimate. (Collimation would give ×10–50 intensity → ×3–7 range — *future accessory only*.)
2. **Pointing & stability (dominant practical limit).** Sub-degree jitter walks the spot at distance. Software mitigates via tracking/aiming UI; cannot fully replace mechanical stability.
3. **Background light (daylight ceiling).** Sky shot-noise swamps a broadband LED; only a narrowband emitter + filter beats it (*future accessory*). Night is the reliable regime.

Photons are not the night limit (a torch is a detectable point to ~1 km); **divergence + pointing** are. Both are hardware — so the bare-phone reliable range is set by how well software handles weak signal + motion + aiming.

## Range estimates (bare phone, reliable comms — validate empirically)

| Configuration | Night (reliable) | Daylight |
|---|---|---|
| **Bare phone, handheld (CORE TARGET)** | **50–150 m** | 10–40 m |
| Bare phone, braced/steadied (no accessory) | up to ~200–300 m | 15–50 m |

> Accessory tiers (collimator/tripod/telephoto/external-LED/narrowband) previously estimated 300 m – 2 km night / 100–200 m day. **Retained as future reference only — not part of V2 core.**

## Trade-offs (bare-phone focus)

| Factor | Bare phone |
|---|---|
| Cost | $0 |
| UX friction | none — grab & go |
| Availability | universal (the whole emergency value) |
| Range | tens–~150 m night reliable; daylight short |
| Limits | divergence + pointing + daylight background |

**UX note retained:** wide torch = easy "find-me" beacon; the bare phone naturally favors the *beacon/short-link* use case, which suits the emergency baseline.

## Phone vs dedicated device

For an offline/emergency product, **ubiquity is the value proposition** — must work with two unmodified phones and nothing else. A dedicated device wins raw range but loses the floor. **Phone-core is correct.**

## Recommended physical-layer strategy (constraint-aligned)

- **Optimize the bare-phone link end to end** — weak-signal vision, motion robustness, aiming UI, conservative robust modulation/FEC (software levers) to push the reliable bare-phone range as far as physics allows (target the upper end of 50–150 m+ night).
- **Keep the PHY accessory-agnostic** so that *if* a user later adds optics, the same protocol stack benefits — but the product never assumes it.
- **Two emission modes (software/optical use, no hardware):** wide "beacon/find-me" vs best-effort "directed" aiming with on-screen reticle + signal meter.
- **Market night as the reliable regime;** treat daylight as best-effort, not promised.
- **Receiver-side software (Vision Engine) is the highest-leverage lever left** under the zero-budget constraint — see the Vision Engine design doc.

## Answer to the core question (updated)

Under the zero-hardware-budget constraint, the bare smartphone **is** the platform — full stop. The long-range vision is pursued **entirely through software** on unmodified phones: a weak-signal, motion-robust Vision Engine + a robust protocol/FEC stack. Accessories remain a documented optional future, never a dependency. The product promise is fixed: **two ordinary phones, flashlight + camera, offline.**
