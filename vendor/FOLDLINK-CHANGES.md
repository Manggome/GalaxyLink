# FoldLink scrcpy 4.1 modifications

Upstream: https://github.com/Genymobile/scrcpy/releases/tag/v4.1 (Apache-2.0; original LICENSE retained).

Modified for FoldLink on 2026-09-07:

- `screen.c`, `screen.h`, `scrcpy.c`, `foldlink_easing.h`: animate actual SDL video-window size changes over 360 ms using a main-thread, non-blocking 16 ms event-loop tick. Temporarily relax aspect constraints, retain letterboxing and input-coordinate transforms, restore aspect lock at completion. Retarget from current dimensions on successive size changes. Skip fullscreen and Reduce Motion.
- `foldlink_macos.m/.h`, `events.h`, `input_manager.c`: app-local Cocoa Caps Lock handling and focused macOS input-source notification fallback. Deduplicate switch events; send Android LANGUAGE_SWITCH press/release on the existing controller. Do not monitor other applications.
- `uhid/keyboard_uhid.c`: stop mirroring host Caps Lock LED state to the phone so it does not force uppercase while switching languages.
- Meson: compile the native Cocoa bridge and link Cocoa/Carbon frameworks.
- `util/log.c`: flush connection and frame-size log lines immediately so the parent app receives live state over its output pipe.

The installed Homebrew scrcpy binary is unchanged. FoldLink runs its bundled `scrcpy-foldlink` client and matching v4.1 server. Runtime video dependencies still come from Homebrew.

Version 1.3 clipboard additions:
- Normalize physical Cmd/Ctrl+C,V,X in input_manager.c; use existing clipboard control messages for text.
- foldlink_macos.m captures PNG/TIFF/single image file only on explicit paste and stages PNG in the app-provided session directory.
- receiver.c ignores echoes of helper content URIs to preserve the original Mac image.
- Swift parent transfers the staged file over authenticated ADB into the helper provider, registers image ClipData, and requests paste only if the original app remains foreground.

Version 1.4 typing corrections (supersedes the earlier default Caps Lock relay):
- Default to SDK prefer-text with native macOS composition; send committed non-ASCII text through SET_CLIPBOARD+paste because Android KeyCharacterMap cannot inject Hangul/emoji.
- Remove Cocoa Caps Lock interception and input-source notification relaying; macOS owns the input language in the default mode.
- Consume Command modifier keys and unsupported Command combinations instead of forwarding Android Meta/launcher events. Keep explicit Cmd/Ctrl clipboard shortcuts.
- Move scrcpy control shortcuts to right Option to separate them from normal Mac typing.
- Keep a HID scancode even if its logical keycode is unknown for the optional UHID mode.
- Add a non-persistent, shell-protected diagnostic editor to the Android companion.
