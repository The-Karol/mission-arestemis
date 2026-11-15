"""Build a portable Windows browser test bundle, with no Python/Godot requirement."""
from pathlib import Path
import shutil
import zipfile
import argparse
parser = argparse.ArgumentParser()
parser.add_argument("--name",default="MissionArestemis-Test.zip")
args=parser.parse_args()

root = Path(__file__).resolve().parents[1]
export_log = root / "build/export.log"
if export_log.exists():
    report = export_log.read_text(encoding="utf-8",errors="replace")
    if any(marker in report for marker in ("SCRIPT ERROR:", "Parse Error:", "Compile Error:")):
        raise SystemExit("Export has script errors; refusing to package a broken build.")
bundle = root / "build" / "testing" / "MissionArestemis-Test"
web = bundle / "web"
web.mkdir(parents=True, exist_ok=True)
for source in (root / "build/web").iterdir():
    if source.is_dir():
        shutil.copytree(source, web / source.name, dirs_exist_ok=True)
    elif not source.name.endswith((".gz", ".import")) and source.name != "build_sizes.json":
        shutil.copy2(source, web / source.name)
shutil.copy2(root / "tools/testing_server.ps1", bundle / "server.ps1")
(bundle / "Start Game.bat").write_bytes(
    '@echo off\r\ncd /d "%~dp0"\r\npowershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0server.ps1"\r\nif errorlevel 1 pause\r\n'.encode("ascii"),
)
readme = (root / "docs/TESTING_README.md").read_text(encoding="utf-8")
(bundle / "README.md").write_text(readme, encoding="utf-8")
(bundle / "README.txt").write_text(readme, encoding="utf-8-sig")
archive = bundle.parent / args.name
with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as output:
    for source in sorted(bundle.rglob("*")):
        if source.is_file():
            output.write(source, source.relative_to(bundle.parent))
print(f"Testing archive: {archive} ({archive.stat().st_size / 1024**2:.1f} MiB)")
