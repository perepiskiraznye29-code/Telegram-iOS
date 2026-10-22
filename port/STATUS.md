# Android-to-iOS port status

This branch starts from Telegram iOS 12.9.2, commit 5425ba4f2c5519e6acabc7bfd4dda80ebe7e9599.

Implemented in source:
- Message details submenu with message ID, internal peer and author IDs, ID namespace, local date/time and Unix timestamp.
- Tap a value to copy it. Russian and English labels.

Not yet implemented:
- Remaining exteraGram features, including its Android/Xposed Python plugin engine.
- DC lookup and a preference for the details submenu.

Build:
- GitHub Actions uses macOS 26 and selects the exact Xcode version from versions.json.
- Uses the repository's existing API configuration and verification signing material.
- Artifact: Telegram-iOS-port-IPA. Verification signing does not make this installable on a device without re-signing.
- Existing incompatible build workflows are removed only from this port branch.
- Compilation and device behavior are not yet verified.
