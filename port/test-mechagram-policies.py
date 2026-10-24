"""Compile and execute the actual production policies with host Swift."""
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
sections = [
    ("submodules/TelegramCore/Sources/TelegramEngine/Payments/StarGifts.swift", "GIFT_CONFIRMATION"),
    ("submodules/TelegramCore/Sources/State/AccountStateManagementUtils.swift", "RETENTION"),
    ("submodules/TelegramCore/Sources/TelegramEngine/Payments/TelegramEnginePayments.swift", "DEMO"),
]
source = "import Foundation\n"
for path, name in sections:
    text = (root / path).read_text()
    source += text.split(f"// MECHAGRAM_{name}_POLICY_BEGIN\n")[1].split(f"// MECHAGRAM_{name}_POLICY_END")[0]
source += r'''
assert(mechagramDeletionRetentionAllowed(isCloud: true, enabled: true, now: 100, expiresAt: nil, viewOnce: false))
assert(mechagramDeletionRetentionAllowed(isCloud: true, enabled: true, now: 100, expiresAt: 101, viewOnce: false))
assert(!mechagramDeletionRetentionAllowed(isCloud: true, enabled: true, now: 100, expiresAt: 100, viewOnce: false))
assert(!mechagramDeletionRetentionAllowed(isCloud: false, enabled: true, now: 100, expiresAt: nil, viewOnce: false))
assert(!mechagramDeletionRetentionAllowed(isCloud: true, enabled: false, now: 100, expiresAt: nil, viewOnce: false))
assert(!mechagramDeletionRetentionAllowed(isCloud: true, enabled: true, now: 100, expiresAt: nil, viewOnce: true))
assert(mechagramDemoBalanceAfterPurchase(raw: "100", value: 25, nanos: 0, isTon: false) == "75")
assert(mechagramDemoBalanceAfterPurchase(raw: "1.5", value: 250_000_000, nanos: 0, isTon: true) == "1.25")
assert(mechagramDemoBalanceAfterPurchase(raw: "25", value: 25, nanos: 0, isTon: false) == "0")
assert(mechagramDemoBalanceAfterPurchase(raw: "0", value: 25, nanos: 0, isTon: false) == nil)
assert(mechagramDemoBalanceAfterPurchase(raw: "100", value: -1, nanos: 0, isTon: false) == nil)
assert(mechagramDemoBalanceAfterPurchase(raw: "NaN", value: 1, nanos: 0, isTon: false) == nil)
assert(mechagramDemoBalanceAfterPurchase(raw: "100", value: 1, nanos: 1_000_000_000, isTon: false) == nil)
let giftDefaultsName = "mechagram-tests-" + UUID().uuidString
let giftDefaults = UserDefaults(suiteName: giftDefaultsName)!
assert(!mechagramShouldConfirmLocalGifts(defaults: giftDefaults))
giftDefaults.set(true, forKey: "mechagram.confirmLocalGifts")
assert(!mechagramShouldConfirmLocalGifts(defaults: giftDefaults))
giftDefaults.set(true, forKey: "mechagram.confirmLocalGifts.v2")
assert(mechagramShouldConfirmLocalGifts(defaults: giftDefaults))
giftDefaults.set(false, forKey: "mechagram.confirmLocalGifts.v2")
assert(!mechagramShouldConfirmLocalGifts(defaults: giftDefaults))
giftDefaults.removePersistentDomain(forName: giftDefaultsName)
print("Mechagram: 17 production policy cases passed")
'''
with tempfile.TemporaryDirectory() as directory:
    path = Path(directory) / "main.swift"
    executable = Path(directory) / "policy-tests"
    path.write_text(source)
    subprocess.run(["xcrun", "swiftc", "-Onone", str(path), "-o", str(executable)], check=True)
    subprocess.run([str(executable)], check=True)
