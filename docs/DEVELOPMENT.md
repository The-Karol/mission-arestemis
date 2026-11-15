# Development guide

## Open the source project

1. Install Godot **4.7.2** and import `project.godot`.
2. Allow asset importing to finish.
3. Run the project with **F6** for the current scene or **F5** for the main menu. Use F5 for the complete game.

Compatibility rendering is required for the browser target. A desktop run does not share saves with a browser run.

## Project layout

| Directory | Contents |
| --- | --- |
| `scenes/` | World, player, computers, UI and separate launch demo |
| `scripts/gameplay/` | Mission logic, assembly editors, NPCs, facility dressing and flight presentation |
| `scripts/` | Main menu, settings, saves, scene loading and Workshop |
| `data/` | Missions, component catalogs, navigation and visibility data |
| `assets/` | Models, characters, fonts, images, music and sound effects |
| `materials/` | Materials and shaders |
| `tools/` | Export, packaging, local server and facility baking tools |
| `tests/` | Focused Godot checks and visual review scenes |
| `build/` | Generated exports, test captures and distributable archives |

## Build the web release

Run from the project directory in PowerShell. Adjust the Godot executable path to your installation:

```powershell
$godotExe = 'D:\Godot Engine\Godot_v4.7.2-stable_win64_console.exe'
python tools/prepare_export.py
& $godotExe --headless --path . --export-release Web build/web/index.html --log-file build/export.log
python tools/compress_web.py
python tools/package_testing.py --name MissionArestemis-Test-workshop.zip
python tools/package_launch_demo.py
```

The export preset currently points to `build/templates/web_nothreads_release.zip`. Keep that matching template available, or configure matching official Godot export templates and clear the custom template override. Do not mix engine and template versions.

Inspect `build/export.log` for script, parse or compile errors even if Godot returns exit code zero. The packaging tool rejects those errors. Generated compressed files are for hosts that support precompressed delivery; the portable test server uses the regular web files.

The launch demo is selected through `-- --launch-demo`. Do not put a `res://` scene path in the release web launch arguments: this template disables scene-path overrides.

After changing facility geometry, refresh navigation and visibility:

```powershell
& $godotExe --headless --path . --script tools/bake_navigation.gd -- --bake-nav
node tools/bake_visibility.mjs
```

## Checks

- `tests/final_polish.tscn`: disabled map binding, blueprint validation, Sandbox spawn and illustrated spacecraft chooser; captures room views.
- `tests/workshop_flow.tscn`: launch music, automatic results, Workshop save/import validation and scientist introduction. **Requires an isolated APPDATA directory** to avoid changing player data.
- `tests/facility_walkthrough.tscn`: important sealed edges, rocket supports and navigation routes.

Example isolated run:

```powershell
$previousAppData = $env:APPDATA
try {
    $env:APPDATA = Join-Path (Get-Location) 'build/polish_userdata'
    & $godotExe --path . res://tests/workshop_flow.tscn --log-file build/workshop_flow.log -- --test
} finally {
    $env:APPDATA = $previousAppData
}
```

Browser verification is also needed for downloads, file import and local storage; native tests cannot verify browser behavior.

## Static hosting and GitHub Pages

Publish the **contents of `build/web/`** with `index.html` at the site root. The current single-threaded build does not need cross-origin isolation headers. Serve through HTTP(S), not `file://`.

GitHub Pages is a suitable static hosting option. The current PCK is over GitHub's normal 100 MiB file limit: deploy the web directory as a Pages artifact through GitHub Actions rather than committing that PCK directly. Publishing requires access to the target repository and its Pages settings. The repository now deploys a tested release archive through `.github/workflows/pages.yml`. See [deployment instructions](DEPLOYMENT.md).

See [Godot web export documentation](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html), [GitHub Pages custom workflows](https://docs.github.com/en/pages/getting-started-with-github-pages/using-custom-workflows-with-github-pages) and [Pages limits](https://docs.github.com/en/pages/getting-started-with-github-pages/github-pages-limits).

## Saves and distribution

Campaign, Sandbox and Workshop data are local to the browser and site origin. They do not sync between computers. Export Workshop blueprints before clearing site data or moving to another URL; blueprints contain designs, not campaign progress.

This repository does not declare an open-source license. Check rights to source assets, models, fonts, music and sound effects before public redistribution.
