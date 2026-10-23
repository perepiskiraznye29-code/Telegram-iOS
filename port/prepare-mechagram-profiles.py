"""Adapt the repository's self-signed verification profiles, not device signing."""
import json
from pathlib import Path
import plistlib
import subprocess
import tempfile

root = Path(__file__).resolve().parent.parent
bundle = json.loads((root / 'build-system/appstore-configuration.json').read_text())['bundle_id']
signing = root / 'build-system/fake-codesigning'
def replace(value):
    if isinstance(value, str):
        return value.replace('ph.telegra.Telegraph', bundle)
    if isinstance(value, list):
        return [replace(v) for v in value]
    if isinstance(value, dict):
        return {k: replace(v) for k, v in value.items()}
    return value
with tempfile.TemporaryDirectory() as directory:
    pem = Path(directory) / 'verification.pem'
    subprocess.run(['openssl', 'pkcs12', '-legacy', '-in', str(signing / 'certs/SelfSigned.p12'), '-passin', 'pass:', '-nodes', '-out', str(pem)], check=True, capture_output=True)
    for profile in (signing / 'profiles').glob('*.mobileprovision'):
        original = subprocess.check_output(['openssl', 'smime', '-inform', 'der', '-verify', '-noverify', '-in', str(profile)], stderr=subprocess.DEVNULL)
        data = replace(plistlib.loads(original))
        source = Path(directory) / 'profile.plist'
        source.write_bytes(plistlib.dumps(data))
        subprocess.run(['openssl', 'smime', '-sign', '-nodetach', '-in', str(source), '-outform', 'DER', '-out', str(profile), '-signer', str(pem), '-inkey', str(pem)], check=True, capture_output=True)
