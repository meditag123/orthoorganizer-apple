# OrthoOrganizer Apple

Apple client foundation for OrthoOrganizer: iPhone, iPad and macOS, with the same navy/teal visual language, sections and terminology as the Windows and Android applications.

## Targets

- `OrthoOrganizerApple`: iOS/iPadOS application (the same target adapts its layout for iPhone and iPad).
- `OrthoOrganizerMac`: macOS application, using the same SwiftUI source files with desktop navigation and window sizing.
- `OrthoOrganizerWidget` / `OrthoOrganizerMacWidget`: WidgetKit extensions for the next duty and role.

## Open in Xcode

This workspace is intentionally generated with XcodeGen so the two Apple app targets share one source of truth. On a Mac with Xcode and XcodeGen installed:

```sh
cd OrthoOrganizerApple
xcodegen generate
open OrthoOrganizerApple.xcodeproj
```

Set the Apple Developer Team and signing capabilities in Xcode. The bundle identifiers are placeholders and should remain stable once the first TestFlight build is uploaded. For a quick unsigned simulator/macOS validation, run `scripts/build_apple.sh` from a Mac with XcodeGen installed.

## Cloud compatibility

The Apple client keeps the same username/password UX and is designed to use the existing Firebase username index and encrypted archive contract used by Windows and Android. The cloud adapter is kept separate from the SwiftUI views so the same screens can be tested with preview data before signing and TestFlight configuration.

The Apple source now includes the REST cloud client, username lookup, Firebase email verification check, encrypted `archive.ortho` AES-GCM decoding/encoding, chunked Firestore download/upload, keychain session persistence, surgical/duty editing, attachment import/preview/download/print, biometric unlock, configurable app locking, widget cache and the same archive fields used by Windows/Android. The final signed build still requires macOS/Xcode plus the Apple Developer account; an iOS `.ipa` cannot be produced or signed on Windows/Linux alone.
