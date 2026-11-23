$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'P4_runtime.ps1')
$repoRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$runtime=Get-P4Runtime $repoRoot
Initialize-P4Environment $repoRoot
Push-Location $repoRoot
try {
  foreach($run in @('baseline_development','sensitivity_s_upper6')) {
    if(-not (Test-Path -LiteralPath "outputs/P4/$run/pointwise_loglik.rds")) { throw "Full fit/export is incomplete: $run" }
  }
  & $runtime --vanilla code/P4/M1b_checks.R
  if($LASTEXITCODE -ne 0) { throw 'Implementation checks failed' }
  & code/P4/P4_resource_checks.ps1
  & $runtime --vanilla code/P4/M1b_compare.R
  if($LASTEXITCODE -ne 0) { throw 'Prior comparison failed' }
  & $runtime --vanilla code/P4/M1b_final_checks.R
  if($LASTEXITCODE -ne 0) { throw 'Final artifact checks failed' }
  $expected=Import-Csv 'outputs/P4/resources/original_smoke_hashes.csv'
  foreach($file in $expected) {
    $target=Join-Path 'outputs/P4/smoke' (Split-Path $file.Path -Leaf)
    if((Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash -ne $file.Hash) { throw "Original smoke changed: $target" }
  }
  'PASS: all original smoke file hashes unchanged' | Set-Content 'outputs/P4/resources/smoke_integrity.txt'
  if(-not (Test-Path 'outputs/P4/smoke_record_README.md')) {
    Copy-Item 'outputs/P4/README.md' 'outputs/P4/smoke_record_README.md'
  }
  & $runtime --vanilla code/P4/M1b_write_report.R
  if($LASTEXITCODE -ne 0) { throw 'Evidence report generation failed' }
  Write-Output 'PASS: P4 comparison, verification, original-record integrity and report generation completed'
} finally { Pop-Location }
