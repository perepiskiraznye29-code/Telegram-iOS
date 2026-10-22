# Android-to-iOS port status

This branch starts from Telegram iOS 12.9.2, commit 5425ba4f2c5519e6acabc7bfd4dda80ebe7e9599.

Implemented in source:
- Settings screen with persistent switches for message details, hiding the own number in the settings header, and hiding the stories strip above chats.
- Message details submenu with message ID, internal peer and author IDs, ID namespace, local date/time and Unix timestamp.
- Tap a value to copy it. Russian and English labels.
- Visual hide options take full effect after restarting the app.

Not yet implemented:
- Remaining exteraGram features, including its Android/Xposed Python plugin engine.
- DC lookup.

Custom server requirement:
- Network.swift and MTContext.m must stay byte-for-byte identical to the user's master branch at the base commit.
- The build verifies their Git blob hashes before compiling. This preserves the user's custom server IP, port and RSA key.

Build:
- GitHub Actions uses macOS 26 and selects the exact Xcode version from versions.json.
- Uses the repository's existing API configuration and verification signing material.
- Artifact: Telegram-iOS-port-IPA. Verification signing does not make this installable on a device without re-signing.
- Existing incompatible build workflows are removed only from this port branch.
- Compilation of this revision and device behavior are not yet verified.
