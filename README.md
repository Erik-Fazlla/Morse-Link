# Morse

Talk with light when nothing else works. Morse turns your phone's flashlight
into a signal lamp — no mobile signal, no internet, no account needed.

## Download

Get the latest Android APK from the
[Releases page](https://github.com/Erik-Fazlla/Morse-Link/releases/latest).

To install: download the `.apk` file on your phone, open it, and allow
"Install unknown apps" for your browser or file manager when Android asks.
Needs Android 7.0 or newer and a phone with a flashlight.

## How it works

**Send** — Type a message (or pick SOS, HELP, YES, NO, OK, or a saved
message). Point the back of your phone at the other person and tap START.
The flashlight blinks the message in Morse code.

- Speed: 300 ms per dot is the default and is easy to read by eye. Go slower
  for distance, faster for practised readers.
- Repeat once, a set number of times, or until you stop.
- Saved messages and recent history are one tap away.

**Receive** — Watch the other phone's flashes and tap them in:

- Short flash → **DOT**, long flash → **DASH**
- Short dark pause → **LETTER** (or turn on *Auto gap* and just wait)
- Long dark pause → **SPACE**

The app shows the letter you are building and what it could still become,
then spells out the message. The help button (?) has the full alphabet.

## Tips

- Agree on a speed first. Slow is easier: 300 ms or more.
- Send the message on repeat so the reader can catch anything they missed.
- Works best in the dark or in shade.

## Build from source

Requires Flutter 3.x.

```sh
flutter pub get
flutter test
flutter build apk --release
```

The APK lands in `build/app/outputs/flutter-apk/app-release.apk`.

Official releases are signed with the project's release key, which is not in
this repository. A build from source is signed with your local debug key
instead, so it installs as a separate copy and can't update an official
install.

## Project notes

- `lib/features/send` — text → Morse → timing sequence → flashlight.
- `lib/features/receive/manual` — the two-key receive keypad.
- `lib/features/receive` (camera pipeline) and `lib/v2` — earlier research
  into decoding flashes with the camera. Kept for reference; not used in the
  app.
- `docs/architecture` — design notes and decisions.
