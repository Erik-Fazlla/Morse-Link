# Morse

Morse is an offline Flutter app for emergency optical communication. Phase 1 focuses on converting typed text into Morse and transmitting it through the phone flashlight with accurate timing.

## Phase 1 MVP

- Text input
- Morse preview
- Adjustable timing unit
- Start and stop transmission
- Emergency presets: `SOS`, `HELP`, `YES`, `NO`, `OK`
- Offline-only architecture

## Architecture

The transmission path is intentionally separated:

1. Text input
2. Morse translation
3. Timing sequence generation
4. Flashlight transmission engine

The flashlight layer only reads timing instructions such as:

```text
[ON 200ms, OFF 200ms, ON 600ms]
```

## Notes

- The project files for the Phase 1 Flutter app are included under `lib/`.
- Because this repository started empty, platform scaffolding may still need to be generated with `flutter create .` on a machine where Flutter can complete setup normally.
- After scaffolding, run `flutter pub get` and test on a physical Android device with a flashlight.
