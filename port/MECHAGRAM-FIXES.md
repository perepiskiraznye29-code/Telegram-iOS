# Mechagram revision 9

Display balances are shared by Settings, gift catalog/store, purchase/transfer and balance overlays. The actual server balances remain intact.

Remote message deletion retains previously cached cloud messages, including zero or unstarted autoremove timers; expired messages, disappearing media and secret chats follow their original lifecycle. History validation preserves retained messages. MechagramRetention logs contain reasons only, without message text or account identifiers.

Enable both visual balances and local gifts in Mechagram settings to simulate catalog/market gifts. The local transaction spends the DEMO balance and inserts a card with a DEMO notice without unsent/sending flags or network requests. Other devices cannot see local cards. Regular and collectible gifts are supported in private chats; real purchases remain separate.

CI compiles and runs 13 cases against the production retention and decimal spending policies before building the IPA. Device validation is still required.

## Local profile gifts

New catalog and market copies are persisted per account and recipient and included in profile gifts on this device, including users with no server gifts. They have no server gift reference. Existing chat-only cards are not migrated. Profile contexts refresh after a new local gift is created.

The Confirm each local gift switch defaults to enabled and applies to catalog and market copies. Turning it off creates the local copy immediately. DEMO and visual labels are removed from affected screens; the on-device explanation remains. No server payments or gift ownership changes are performed by local creation.

## Local gift presentation corrections

The v2 confirmation preference defaults to off, independently of the previous default-on preference. Its production tests cover unset, legacy-on, explicit-on and explicit-off states. The optional confirmation no longer contains the old local-copy notice; the Mechagram settings still explain the device-only behavior.

Collectible copies use the recipient as their local owner and clear listing price, TON-only sale, host, on-chain address and purchase-offer state. This normalization also applies to existing local profile entries and old local chat gift detail screens. Catalog/market model, backdrop, pattern and collectible number are preserved. Native chat cards and their view action are restored. Local references cannot be converted to server gift references, and local copies have no server trading controls.

A static review of the supplied Android eblannft_v.plugin found a Python bootstrap, embedded Python modules and a DEX core. It sets owner references and listing fields in gift models and lets native Telegram views render them. Android hooks, updater and sync code are not imported into iOS.
