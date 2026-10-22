$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$godotExecutable = Join-Path $projectRoot '.local-tools\Godot\Godot_v4.7.2-stable_win64_console.exe'
if (-not (Test-Path -LiteralPath $godotExecutable)) {
    throw 'Godot 4.7.2 não foi encontrado em .local-tools\Godot.'
}

# Cada execução usa dados isolados, sem ler ou alterar o save pessoal.
$testRoot = Join-Path $projectRoot ('.local-tools\GodotTestData\' + [guid]::NewGuid().ToString())
$roamingPath = Join-Path $testRoot 'Roaming'
$localPath = Join-Path $testRoot 'Local'
New-Item -ItemType Directory -Path $roamingPath, $localPath -Force | Out-Null
$env:APPDATA = $roamingPath
$env:LOCALAPPDATA = $localPath

& $godotExecutable --headless --path $projectRoot --script res://tests/godot_smoke.gd
exit $LASTEXITCODE
