param(
    [string]$Godot = 'godot'
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$godotCommand = Get-Command -Name $Godot -ErrorAction Stop
if ($godotCommand.CommandType -ne 'Application') {
    throw 'Pass -Godot with the path to a Godot 4.5+ executable.'
}
$godotExecutable = $godotCommand.Source

function Invoke-GodotStep {
    param([string]$StepName, [string[]]$GodotArguments)
    Write-Host $StepName
    & $godotExecutable @GodotArguments
    if ($LASTEXITCODE -ne 0) {
        throw "$StepName failed with exit code $LASTEXITCODE."
    }
}

Invoke-GodotStep 'Import assets and scripts' @('--headless', '--editor', '--path', $projectRoot, '--import', '--quit')
Invoke-GodotStep 'Economy and persistence model' @('--headless', '--path', $projectRoot, '--script', 'tests/model_test.gd')
Invoke-GodotStep 'Complete game flow (user saves disabled)' @('--headless', '--path', $projectRoot, '--script', 'tests/game_flow_test.gd', '--', '--test')
Invoke-GodotStep 'Combat and state machine smoke' @('--headless', '--path', $projectRoot, '--script', 'src/combat/combat_smoke.gd')
Write-Host 'All Godot checks passed.'
