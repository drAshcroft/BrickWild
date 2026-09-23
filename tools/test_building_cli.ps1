[CmdletBinding()]
param([Parameter(Mandatory = $true)][string]$GodotPath)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repository = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$artifacts = Join-Path $repository 'artifacts/p1p2_api/cli_contract'
[IO.Directory]::CreateDirectory($artifacts) | Out-Null
$utf8 = New-Object Text.UTF8Encoding($false)
$requestPath = Join-Path $artifacts 'request.json'
[IO.File]::WriteAllText($requestPath, '{"kind":"temple","seed":"404"}', $utf8)

function Invoke-Generation {
    param([string]$Request, [string]$Output, [string]$Name, [switch]$WithOutputs)
    $arguments = @('--headless', '--path', $repository, '--script', 'res://tools/generate_building.gd', '--', '--request', $Request, '--out', $Output)
    if ($WithOutputs) {
        $arguments += @('--mesh', (Join-Path $artifacts "$Name.tres"), '--qa', (Join-Path $artifacts "$Name.qa.json"))
    }
    & $GodotPath @arguments *> (Join-Path $artifacts "$Name.log")
    return $LASTEXITCODE
}

foreach ($name in @('first', 'second')) {
    $code = Invoke-Generation -Request $requestPath -Output (Join-Path $artifacts "$name.json") -Name $name -WithOutputs
    if ($code -ne 0) { throw "Valid CLI generation failed ($name, exit $code). See $artifacts" }
    $qa = Get-Content -LiteralPath (Join-Path $artifacts "$name.qa.json") -Raw | ConvertFrom-Json
    if (-not $qa.ok) { throw 'CLI QA failed without a failing exit' }
}
foreach ($suffix in @('.json', '.tres', '.qa.json')) {
    $first = (Get-FileHash -LiteralPath (Join-Path $artifacts ("first" + $suffix))).Hash
    $second = (Get-FileHash -LiteralPath (Join-Path $artifacts ("second" + $suffix))).Hash
    if ($first -ne $second) { throw "CLI artifact is not deterministic: $suffix" }
}
[IO.File]::WriteAllText($requestPath, '{"kind":"house","width":"wide"}', $utf8)
$badPath = Join-Path $artifacts 'invalid.json'
$badExit = Invoke-Generation -Request $requestPath -Output $badPath -Name 'invalid'
if ($badExit -ne 3) { throw "Invalid request exit was $badExit, expected 3" }
$bad = Get-Content -LiteralPath $badPath -Raw | ConvertFrom-Json
if ($bad.ok -or @($bad.errors).Count -eq 0 -or $bad.errors[0].code -ne 'invalid_type') {
    throw 'Invalid request did not return structured diagnostics'
}
[IO.File]::WriteAllText($requestPath, '[invalid', $utf8)
$badExit = Invoke-Generation -Request $requestPath -Output $badPath -Name 'malformed'
if ($badExit -ne 3) { throw "Malformed JSON exit was $badExit, expected 3" }
$bad = Get-Content -LiteralPath $badPath -Raw | ConvertFrom-Json
if ($bad.errors[0].code -ne 'invalid_json') { throw 'Malformed JSON diagnostic missing' }
[pscustomobject]@{ Passed = $true; DeterministicArtifacts = 3; InvalidRequestsRejected = 2; Artifacts = $artifacts }
