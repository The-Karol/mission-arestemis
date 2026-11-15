param([string]$Godot = "", [switch]$FullChecks)
$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
if (-not $Godot) {
    $command = Get-Command godot -ErrorAction SilentlyContinue
    if ($command) { $Godot = $command.Source }
    elseif (Test-Path -LiteralPath 'D:\Godot Engine\Godot_v4.7.2-stable_win64_console.exe') {
        $Godot = 'D:\Godot Engine\Godot_v4.7.2-stable_win64_console.exe'
    } else { throw 'Pass -Godot with the path to the Godot 4.7.2 console executable.' }
}
Push-Location -LiteralPath $projectRoot
try {
    New-Item -ItemType Directory -Force build\web,build\qa | Out-Null
    & $Godot --headless --editor --path $projectRoot --import --log-file "$projectRoot/build/import.log"
    if ($LASTEXITCODE) { throw 'Godot import failed.' }
    & $Godot --headless --path $projectRoot --script tools/bake_navigation.gd --log-file "$projectRoot/build/nav.log" -- --bake-nav
    if ($LASTEXITCODE) { throw 'Navigation bake failed.' }
    node tools/bake_visibility.mjs
    if ($LASTEXITCODE) { throw 'Visibility bake failed.' }
    & $Godot --headless --path $projectRoot tests/cinematic_review.tscn --log-file "$projectRoot/build/cinematic_review.log" -- --test
    if ($LASTEXITCODE) { throw "Focused revision checks failed." }
    if ($FullChecks) {
        & $Godot --headless --path $projectRoot tests/stage_two_test.tscn --fixed-fps 60 --log-file "$projectRoot/build/stage_two_test.log" -- --test
        if ($LASTEXITCODE) { throw 'Scenario checks failed.' }
        & $Godot --headless --path $projectRoot tests/navigation_routes.tscn --fixed-fps 60 --log-file "$projectRoot/build/navigation_routes.log" -- --test
        if ($LASTEXITCODE) { throw 'Navigation route checks failed.' }
    }
    python tools/prepare_export.py
    if ($LASTEXITCODE) { throw 'Export selection failed.' }
    if (-not (Test-Path -LiteralPath 'build/templates/web_nothreads_release.zip')) {
        python tools/recover_web_template.py
        if ($LASTEXITCODE) { throw 'Install matching Web export templates or restore the matching project Web runtime.' }
    }
    & $Godot --headless --path $projectRoot --export-release Web build/web/index.html --log-file "$projectRoot/build/export.log"
    if ($LASTEXITCODE) { throw 'Web release export failed.' }
    if ($FullChecks) {
        & $Godot --headless --path $projectRoot --export-release 'Web QA' build/qa/index.html --log-file "$projectRoot/build/export_qa.log"
        if ($LASTEXITCODE) { throw 'Web QA export failed.' }
    }
    python tools/compress_web.py
    if ($LASTEXITCODE) { throw 'Web compression failed.' }
    Write-Host 'Web release ready: build/web/index.html'
} finally { Pop-Location }
