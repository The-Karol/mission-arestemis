"""Package an already-exported web game for the Pages release workflow."""
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
import hashlib
root = Path(__file__).resolve().parents[1]
web = root / "build/web"
for name in ("index.html", "index.pck", "index.wasm", "index.js"):
    if not (web / name).is_file():
        raise SystemExit("Missing web export: " + name)
archive = root / "build/pages-web.zip"
with ZipFile(archive, "w", ZIP_DEFLATED, compresslevel=6) as output:
    for file in sorted(web.iterdir()):
        if file.is_file() and file.name.startswith("index.") and file.suffix not in (".gz", ".import"):
            output.write(file, file.name)
    output.writestr(".nojekyll", "")
print("Archive:", archive)
print("WEB_SHA256:", hashlib.sha256(archive.read_bytes()).hexdigest())
