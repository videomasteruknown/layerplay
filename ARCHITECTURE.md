# LayerPlay: architecture, sync model and 2 GB memory guide

Not compiled or run on a device yet. Treat it as a complete first draft:
run `flutter pub get && flutter analyze` first, then test on real low-end hardware.

## Why Flutter + media_kit (libmpv)

- libmpv streams from disk, seeks inside multi-GB files quickly, hardware-decodes
  through MediaCodec (Android) and exposes per-player cache limits.
- Video frames go straight from the decoder to a GPU texture. No frame data crosses
  into Dart, so the Dart heap stays tiny.
- One codebase for Android, iOS, Windows, Linux and macOS.
- React Native has no equivalent low-level cache control out of the box.

## Layout

```
lib/
  main.dart                    app entry + home screen
  core/
    memory_profile.dart        every RAM knob (cache sizes, threads, trim on pressure)
    sync_controller.dart       the virtual timeline (master/slave sync)
    playback_engine.dart       owns both players, exposes ValueNotifiers to the UI
    format.dart                time/offset formatting
  ui/
    theme.dart                 dark palette, orange accent
    player_screen.dart         video surface, gestures, auto-hide, lifecycle hooks
    controls_overlay.dart      top bar, play/skip buttons, speed sheet
    scrubber.dart              timeline slider (seeks on release)
    audio_panel.dart           import, volumes, offset controls
    offset_lane.dart           draggable two-lane offset visual
```

## How the virtual timeline works (no export)

Two independent libmpv players run side by side:

| Player | Plays | Role |
|---|---|---|
| `video` | master file (picture + its own sound) | **master clock** |
| `audio` | added music / voiceover, video output disabled | **slave** |

The rule, enforced continuously in `TimelineSync`:

```
audioPosition = videoPosition - offset
```

Positive offset = audio starts later. Negative = audio starts earlier.

1. **Start / resume:** when the video starts playing (and is not buffering), the
   slave is seeked to `target` and played. If `target < 0` the audio hasn't begun yet,
   so it stays parked and the 200 ms loop starts it at the exact moment `target` reaches 0.
   After the audio ends it is paused.
2. **Pause / buffering:** the slave pauses whenever the master is paused or stalled,
   so the two cannot run apart.
3. **Seek / skip / scrub:** the master seeks first, then the slave is seeked to the
   new `target`.
4. **Speed:** the rate set on the master is mirrored to the slave. mpv's pitch
   correction keeps voices natural at 0.5x to 2.0x.
5. **Drift correction (every 200 ms):**
   `drift = audioPos - target`
   - under 30 ms: ignore
   - 30 to 150 ms: slave rate is nudged +-3%, which is inaudible and converges in about 1 to 3 s
   - over 150 ms: hard seek of the slave
   After any seek there is a 700 ms settle window so stale position readings
   don't trigger a correction loop.
6. **Offset adjust:** the value updates instantly and the slave re-syncs after a
   120 ms debounce, so dragging stays smooth. Range is +-1 hour, step is 1 ms.
   Because it is applied as a seek target, the audible result is accurate to
   about the decoder's frame size (a few ms), not literally sample-exact.

Nothing is decoded into a new file. Both files are only read, so the original
video and audio are never modified.

## Memory management on a 2 GB device

Budget (estimates, measure with `adb shell dumpsys meminfo <pkg>`):

| Item | Approx. |
|---|---|
| Video demuxer read-ahead | 24 MB |
| Video back-buffer (for instant 10 s rewind) | 4 MB |
| Audio-layer cache | 5 MB |
| Decoder surfaces (hardware path, 1080p) | 20 to 40 MB |
| Flutter engine + UI | 80 to 120 MB |
| **Target total** | **under about 250 MB** |

What `memory_profile.dart` and the engine do:

- **Never load files into RAM.** Pickers use `withData: false`; mpv reads in chunks.
- **Capped demuxer cache** (`demuxer-max-bytes`) plus a small back-buffer.
  Old data is dropped as playback advances, so a 10-hour file uses the same RAM as a 10-minute one.
- **Short read-ahead** (12 s) so the cache cap, not the clock, limits memory.
- **Hardware decoding** through MediaCodec, with 2 software threads as fallback and
  `framedrop=vo` so slow devices drop frames instead of piling up a queue.
- **Audio layer is audio-only:** `vo=null` and `vid=no`, so it allocates no video resources.
- **UI throttling:** position updates are limited to 4 Hz and flow through
  `ValueNotifier`, so only the scrubber and time labels rebuild.
- **OS memory pressure:** `didHaveMemoryPressure` calls `trimMemory()`, which
  drops back-buffers to 0 and read-ahead to 8 MB / 2 MB.
- **Lifecycle:** playback pauses when the app is backgrounded. `dispose()` cancels
  every stream, timer and notifier and disposes both players, so leaving the player screen frees everything.

Further steps for very weak devices:

- Use `MemoryProfile.lowEnd` (default) and consider cutting `videoDemuxerBytes` to 16 MB.
- Build with `flutter build apk --release --split-per-abi` and ship arm64-v8a / armeabi-v7a only.
- Prefer 1080p or lower H.264/HEVC. 4K or 10-bit footage on a chip without a
  matching hardware decoder will fall back to software and may stutter regardless of RAM.

## Platform setup

Android (`android/app/build.gradle`): `minSdkVersion 21`.

`AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.READ_MEDIA_VIDEO"/>
<uses-permission android:name="android.permission.READ_MEDIA_AUDIO"/>
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" android:maxSdkVersion="32"/>
<uses-permission android:name="android.permission.WAKE_LOCK"/>
```

Run:
```
flutter create --platforms=android,ios,windows,linux,macos .
flutter pub get
flutter run --release
```
Always profile with `--release`; debug builds use far more memory.

## Known limitations to verify

1. **File picker copies on Android.** Some `file_picker` versions copy the chosen
   file into the app cache. For a multi-GB, 10-hour video this would use huge storage and
   time. Test with a large file. If it copies, replace the picker with a SAF-based one that
   returns a `content://` URI or file descriptor, or use "Open with" intents, and pass that to `Media(...)`.
2. **Scrub precision.** On a phone-width slider a 10-hour file is roughly 30 s per pixel.
   Use the 10 s buttons and double-tap for fine moves. A vertical-drag
   "fine scrub" gesture would be a good addition.
3. **Two players ≠ sample-locked.** Sync is kept within roughly 30 to 60 ms by the
   correction loop, which is below what most people notice, but it is not a single-clock mixer.
   If you later need exact lock, mpv's `--lavfi-complex` with `amix` in one player
   is the alternative, at the cost of the filter graph restarting when volumes change.
4. **Bluetooth audio latency** adds a fixed delay to both players equally, so
   relative sync is preserved, but lip-sync against the picture can shift. Use the offset slider or
   mpv's `audio-delay` if needed.
