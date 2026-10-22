# Android-to-iOS port status

This branch starts from Telegram iOS 12.9.2, commit 5425ba4f2c5519e6acabc7bfd4dda80ebe7e9599.

Implemented in source:
- Settings screen with persistent switches for message details, hiding the own number in the settings header, and hiding the stories strip above chats.
- Message details submenu with message ID, internal peer and author IDs, ID namespace, local date/time and Unix timestamp.
- Tap a value to copy it. Russian and English labels.
- Optional seconds in message timestamps and full numeric counts instead of K/M abbreviations.
- Visual hide options take full effect after restarting the app.

Not yet implemented:
- Remaining exteraGram features, including its Android/Xposed Python plugin engine.
- DC lookup.

Custom server requirement:
- The user's custom IP literals, port 2398 and RSA key are preserved.
- Network.swift has two build fixes unrelated to endpoints: outgoing audio traffic direction and an explicit discard of the disabled backup address source. MTContext.m is unchanged.
- The build verifies the expected Git blob hashes before compiling. This preserves the user's custom server IP, port and RSA key.

Build:
- GitHub Actions uses macOS 26 and selects the exact Xcode version from versions.json.
- Uses the repository's existing API configuration and verification signing material.
- Artifact: Telegram-iOS-port-IPA. Verification signing does not make this installable on a device without re-signing.
- Existing incompatible build workflows are removed only from this port branch.
- Compilation of this revision and device behavior are not yet verified.
