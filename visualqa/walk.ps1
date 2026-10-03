# Walk QA: walk through one generated building and pin problems.
#   .\visualqa\walk.ps1
#   .\visualqa\walk.ps1 --kind=castle --seed=9118 --style=crusader
#
# Tolerant of new code: if any script is newer than Godot's class registry
# (a new class_name another task just added), the editor is run once headless
# to register it before the rig starts. Otherwise every BrickWild script fails
# with "Identifier not declared".
param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Rest)
$godot = 'C:\Projects\godot\Godot_v4.5.2-stable_mono_win64\Godot_v4.5.2-stable_mono_win64.exe'
$root = Split-Path -Parent $PSScriptRoot
$cache = Join-Path $root '.godot\global_script_class_cache.cfg'

$stale = -not (Test-Path $cache)
if (-not $stale) {
    $since = (Get-Item $cache).LastWriteTimeUtc
    $stale = [bool](Get-ChildItem -Path $root -Recurse -Filter *.gd -File -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notlike '*\.godot\*' -and $_.LastWriteTimeUtc -gt $since } |
        Select-Object -First 1)
}
if ($stale) {
    Write-Host 'New or changed scripts: registering classes first...'
    & $godot --headless --path $root --editor --quit 2>&1 |
        Select-String -Pattern 'Parse Error|SCRIPT ERROR' |
        ForEach-Object { Write-Host $_ }
    if (Test-Path $cache) { (Get-Item $cache).LastWriteTimeUtc = [DateTime]::UtcNow }
}
& $godot --path $root res://visualqa/walk/walk_qa.tscn -- @Rest
