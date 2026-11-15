"""Recover the project's matching, already shipped Godot 4.7.2 Web runtime.

The machine has Windows export templates but is missing Web template ZIPs.
The existing build/web runtime embeds both the exact engine version and commit.
This repackages those unmodified runtime files as a local release template;
Godot still performs the actual release export and fills fresh file sizes/config.
It is not a debug template. Install official templates to change engine version.
"""
from pathlib import Path
import hashlib
import json
import re
import zipfile

root = Path(__file__).resolve().parents[1]
web = root / "build/web"
destination = root / "build/templates"
destination.mkdir(parents=True, exist_ok=True)
runtime = (web / "index.wasm").read_bytes()
assert b"Godot Engine v4.7.2.stable.official" in runtime
assert b"ed1daf0bf001b61586d9930840f2f1394092c079" in runtime
html = (web / "index.html").read_text(encoding="utf-8")
html = re.sub(r"const GODOT_CONFIG = .*?;", "const GODOT_CONFIG = $GODOT_CONFIG;", html)
html = re.sub(r"const GODOT_THREADS_ENABLED = .*?;", "const GODOT_THREADS_ENABLED = $GODOT_THREADS_ENABLED;", html)
html = html.replace('src="index.js"', 'src="$GODOT_URL"')
html = html.replace("<title>Space</title>", "<title>$GODOT_PROJECT_NAME</title>")
entries = {"godot.wasm": runtime, "godot.html": html.encode("utf-8")}
for suffix in ["js", "audio.worklet.js", "audio.position.worklet.js"]:
    entries["godot." + suffix] = (web / ("index." + suffix)).read_bytes()
with zipfile.ZipFile(destination / "web_nothreads_release.zip", "w", zipfile.ZIP_DEFLATED, compresslevel=3) as archive:
    for name, content in entries.items():
        archive.writestr(name, content)
manifest = {"engine": "4.7.2.stable.official.ed1daf0bf", "source": "Existing project build/web, unchanged Web runtime", "files": {name: hashlib.sha256(content).hexdigest() for name, content in entries.items()}}
(destination / "runtime_manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")
print("Recovered matching single-threaded Web release template.")
