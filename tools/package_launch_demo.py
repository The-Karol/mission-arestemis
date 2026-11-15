"""Package the browser demo using user arguments (Web forbids scene overrides)."""
from pathlib import Path
import shutil
import zipfile
root = Path(__file__).resolve().parents[1]
web = root / "build/web"
bundle = root / "build/Launch-Demo"
(bundle / "web").mkdir(parents=True, exist_ok=True)
for source in web.iterdir():
    if source.is_file() and source.suffix not in (".gz", ".import"):
        shutil.copy2(source, bundle / "web" / source.name)
html = (web / "index.html").read_text(encoding="utf-8")
assert '\"args\":[]' in html
html = html.replace('\"args\":[]', '\"args\":[\"--\",\"--launch-demo\"]')
(bundle / "web/index.html").write_text(html, encoding="utf-8")
served = root / "build/testing/MissionArestemis-Test/web"
if served.exists():
    (served / "demo.html").write_text(html, encoding="utf-8")
shutil.copy2(root / "tools/testing_server.ps1", bundle / "server.ps1")
(bundle / "Start Demo.bat").write_bytes(b'@echo off\r\ncd /d "%~dp0"\r\npowershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0server.ps1"\r\n')
readme = (root / "docs/LAUNCH_DEMO_README.md").read_text(encoding="utf-8")
(bundle / "README.md").write_text(readme, encoding="utf-8")
(bundle / "README.txt").write_text(readme, encoding="utf-8-sig")
archive = root / "build/testing/MissionArestemis-Launch-Demo.zip"
with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as z:
    for source in bundle.rglob("*"):
        if source.is_file():
            z.write(source, source.relative_to(bundle.parent))
print(archive)
