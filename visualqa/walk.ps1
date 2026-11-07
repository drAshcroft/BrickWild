# Walk QA: walk a series of generated villages (or one building) and pin problems.
#   .\visualqa\walk.ps1                                   # the village series 'mixed'
#   .\visualqa\walk.ps1 -Villages smoke                   # another series: visualqa/villages/<name>.json
#   .\visualqa\walk.ps1 --villages=mixed --stop=5         # start at village 5
#   .\visualqa\walk.ps1 -Bake                             # bake the series first (hours; see visualqa/README.md)
#   .\visualqa\walk.ps1 --kind=castle --seed=9118 --style=crusader
#   .\visualqa\walk.ps1 -Tour sprint_2026_10_26          # a bug walk: visualqa/tours/<name>.json
#   .\visualqa\walk.ps1 --village-terrain=manarola       # a village on real ground
#
# Tolerant of new code: if any script is newer than Godot's class registry
# (a new class_name another task just added), the editor is run once headless
# to register it before the rig starts. Otherwise every BrickWild script fails
# with "Identifier not declared".
# No param() block: a positional parameter would swallow '--kind=...'.
$Tour = ''
$Villages = ''
$Bake = $false
$Rest = @()
for ($i = 0; $i -lt $args.Count; $i++) {
    if ($args[$i] -eq '-Tour' -and $i + 1 -lt $args.Count) { $Tour = $args[$i + 1]; $i++ }
    elseif ($args[$i] -eq '-Villages' -and $i + 1 -lt $args.Count) { $Villages = $args[$i + 1]; $i++ }
    elseif ($args[$i] -eq '-Bake') { $Bake = $true }
    else { $Rest += [string]$args[$i] }
}
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
if ($Bake) {
    # every village of the series not yet baked at this commit; one Godot, logged
    $series = if ($Villages -ne '') { $Villages } else { 'mixed' }
    $log = Join-Path $root "artifacts\walk_villages\bake_$series.log"
    New-Item -ItemType Directory -Force (Split-Path $log) | Out-Null
    Write-Host "Baking series '$series' (log: $log). The walk can start meanwhile; unbaked villages generate live."
    & $godot --path $root --script res://tools/bake_walk_villages.gd -- "--series=$series" @Rest *> $log
    Write-Host "Bake finished: $((Select-String -Path $log -Pattern '^bake: finished').Line)"
    exit
}
$userArgs = @()
if ($Tour -ne '') { $userArgs += "--tour=$Tour" }
if ($Villages -ne '') { $userArgs += "--villages=$Villages" }
if ($Rest) { $userArgs += $Rest }
& $godot --path $root res://visualqa/walk/walk_qa.tscn -- @userArgs
