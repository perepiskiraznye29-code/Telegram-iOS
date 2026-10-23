"""Prepare the supplied artwork at the sizes declared by the app icon catalog."""
import base64
import json
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parent.parent
catalog = root / 'Telegram/Telegram-iOS/DefaultAppIcon.xcassets/AppIconLLC.appiconset'
with tempfile.TemporaryDirectory() as directory:
    original = Path(directory) / 'mechagram.jpg'
    original.write_bytes(base64.b64decode((root / 'port/mechagram-icon.jpg.base64').read_text()))
    for entry in json.loads((catalog / 'Contents.json').read_text())['images']:
        if 'filename' not in entry:
            continue
        width, height = map(float, entry['size'].split('x'))
        scale = float(entry.get('scale', '1x').rstrip('x'))
        subprocess.run(['sips', '-s', 'format', 'png', '-z', str(round(height * scale)), str(round(width * scale)), str(original), '--out', str(catalog / entry['filename'])], check=True, stdout=subprocess.DEVNULL)
