"""Refresh runtime resource selection and the separate browser QA preset."""
from pathlib import Path
import re

root = Path(__file__).resolve().parents[1]
files = {str(p.relative_to(root)).replace("\\", "/") for p in (root / "scenes").rglob("*.tscn") if p.name != "engineer.tscn"}
files.update(str(p.relative_to(root)).replace("\\", "/") for p in (root / "scripts").rglob("*.gd") if p.name not in ["engineer_npc.gd", "engineer_appearance.gd"])
files.update(["data/facility_navigation.tres", "themes/ui_theme.tres", "default_bus_layout.tres"])
source = "\n".join((root / name).read_text(encoding="utf-8-sig") for name in files if name.endswith(".gd"))
for name in re.findall(r'"((?:environment|architecture|interactive|props|spacecraft|launch|rocket|celestial|category_c_assembly)/[a-z_0-9/]+)"', source):
    path = "assets/models/" + name + ".glb"
    if (root / path).is_file():
        files.add(path)
for kind in ["spacecraft", "rocket", "verification", "launch"]:
    files.add("assets/models/interactive/retro_computer_" + kind + ".glb")
import json
craft = json.loads((root / "data/spacecraft_components.json").read_text(encoding="utf8"))
files.update("assets/models/spacecraft/modules/"+part["model"]+".glb" for part in craft)
files.update(str(p.relative_to(root)).replace("\\","/") for p in (root/"assets/models/spacecraft").glob("*/*.glb") if p.parent.name!="modules")
files.update(str(p.relative_to(root)).replace("\\","/") for p in (root/"assets/ui/plates").glob("*.png"))
# Flight builds engines from catalog IDs; literal-path scanning cannot find them.
files.update(str(p.relative_to(root)).replace("\\", "/") for p in (root / "assets/models/rocket/engines").glob("*.glb"))
pending = list(files)
while pending:
    name = pending.pop()
    if Path(name).suffix not in [".tscn", ".gd", ".tres"]:
        continue
    content = (root / name).read_text(encoding="utf-8-sig")
    for dependency in re.findall(r'"res://([^\"]+)"', content):
        if (root / dependency).is_file() and dependency not in files:
            files.add(dependency)
            pending.append(dependency)
path = root / "export_presets.cfg"
text = path.read_text(encoding="utf-8-sig").split("[preset.1]", 1)[0].rstrip() + "\n"
line = next(line for line in text.splitlines() if line.startswith("export_files="))
selection = "export_files=PackedStringArray(" + ", ".join('"res://' + name + '"' for name in sorted(files)) + ")"
text = text.replace(line, selection)
qa = text.replace("[preset.0", "[preset.1").replace('name="Web"', 'name="Web QA"').replace('custom_features=""', 'custom_features="qa"').replace('export_path="build/web/index.html"', 'export_path="build/qa/index.html"').replace('tests/*', '')
qa_files = files | {"tests/stage_two_test.gd", "tests/stage_two_test.tscn"}
qa_selection = "export_files=PackedStringArray(" + ", ".join('"res://' + name + '"' for name in sorted(qa_files)) + ")"
qa = qa.replace(selection, qa_selection)
path.write_text(text + "\n" + qa, encoding="utf-8")
(root / "build/qa").mkdir(parents=True, exist_ok=True)
print("Production resources:", len(files), "/ QA resources:", len(qa_files))
