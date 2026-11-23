param([ValidateSet('verify','smoke')][string]$Mode = 'verify')
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'P4_runtime.ps1')
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Initialize-P4Environment $repoRoot
$runtime = Get-P4Runtime $repoRoot
if (-not (Test-Path -LiteralPath $runtime)) { throw 'Local R 4.5.3 is missing' }
Push-Location $repoRoot
try {
    & $runtime --vanilla code/P4/verify_environment.R
    if ($LASTEXITCODE -ne 0) { throw 'Environment validation failed' }
    if ($Mode -eq 'smoke') {
        & $runtime --vanilla code/P4/M1b_smoke.R
        if ($LASTEXITCODE -ne 0) { throw 'M1b smoke failed' }
    }
} finally { Pop-Location }
