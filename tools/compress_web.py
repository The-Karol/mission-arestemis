"""Make deterministic gzip variants for web hosting and the local launcher."""
from pathlib import Path
import gzip
import json

root = Path(__file__).resolve().parents[1]
web = root / "build/web"
sizes = {}
for name in ["index.wasm", "index.pck", "index.js"]:
    source = web / name
    content = source.read_bytes()
    compressed = gzip.compress(content, compresslevel=9, mtime=0)
    source.with_name(name + ".gz").write_bytes(compressed)
    sizes[name] = {"bytes": len(content), "gzip_bytes": len(compressed)}
(web / "build_sizes.json").write_text(json.dumps(sizes, indent=2), encoding="utf-8")
print(json.dumps(sizes))

licenses = web / "licenses"
licenses.mkdir(exist_ok=True)
for source in (root / "assets/fonts").glob("*-OFL.txt"):
    (licenses / source.name).write_bytes(source.read_bytes())
