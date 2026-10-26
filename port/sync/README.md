# Mechagram gift previews

Standalone Python 3 service, SQLite, TLS 1.2+, listening on TCP 8443.
No Telegram session, login code, phone number, chat text or payment credentials
are sent to this service. Public profile reads contain gift metadata and the
recipient's numeric peer ID. The iOS client pins the exact public TLS certificate
in `MechagramGiftSync.swift` and rejects redirects. Only the public certificate
belongs in this repository; private keys remain on the VDS.

Authentication identifies an app installation, **not a verified Telegram user**.
Each installation can publish and change its own visual records; it cannot
write another installation's rows. A preview can target any recipient, just as
local preview creation can. For the same collectible ID the latest published
preview wins, and previous recipients receive a `moved` entry. This is a shared
visualization ledger, never proof of real gift ownership, a real marketplace,
or a financial system. Verified Telegram identity would require a separate
authentication integration.

The app retains an offline outbox and cache. Profile contexts retry and refresh
every 15 seconds. Both phones must run the new build. Older builds never call
this service. Existing local profile gifts are migrated and queued once when
their profiles are read. Old chat-only gifts cannot be recovered from that store.
Only collectible gifts are currently synchronized; regular gifts stay local.

## VDS isolation

Files: `/opt/mechagram/server.py`, `/etc/mechagram/tls.crt`,
`/etc/mechagram/tls.key`, `/var/lib/mechagram/ledger.sqlite3`.
Unit: `/etc/systemd/system/mechagram-sync.service`.
The service runs as the unprivileged `mechagram` user, with a 128 MB RAM limit,
25% CPU quota and 32-task limit. SQLite has a 200 MB page budget. Requests,
registration count, records per installation, body and response sizes are bounded.
No Amnezia container, Docker configuration, VPN port or firewall rule is changed.

Operate only this unit: `systemctl status mechagram-sync` or
`systemctl restart mechagram-sync`. Stop it with
`systemctl disable --now mechagram-sync`; the VPN is independent.
Back up the database with SQLite's backup API while the service is running.
Replacing the TLS certificate requires updating the client pin and rebuilding.

Run `python3 port/sync/test_server.py` to check authentication, installation
isolation, public reads, transfer visibility, invalid IDs and private-payload
rejection against a temporary database. Device UI verification is still required.
