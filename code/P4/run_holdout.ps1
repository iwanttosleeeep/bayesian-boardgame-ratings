param([ValidateSet('audit','baseline','external')][string]$Stage)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'P4_runtime.ps1')
$repoRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Initialize-P4Environment $repoRoot
Push-Location $repoRoot
try {
 $runtime=Get-P4Runtime $repoRoot
 if($Stage -eq 'audit') {
  & $runtime --vanilla -e "source('code/P4/M1b_holdout_run.R')" $Stage
  if($LASTEXITCODE -ne 0) { throw 'Holdout audit failed' }
 } else {
  $label=@{baseline='matched_baseline';external='external_sd'}[$Stage]
  $path=Join-Path $repoRoot ('outputs/P4/Holdout_3209/'+$label)
  if(Test-Path (Join-Path $path 'progress.csv')) { throw 'Existing predictions protected' }
  New-Item -ItemType Directory -Force -Path $path | Out-Null
  $proc=Start-Process -FilePath $runtime -ArgumentList @('--vanilla','-e',"source('code/P4/M1b_holdout_run.R')",$Stage) -WorkingDirectory $repoRoot -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $path 'run.log') -RedirectStandardError (Join-Path $path 'run_errors.log')
  do {
   $measurement=Get-Process -Id $proc.Id -ErrorAction SilentlyContinue
   if($measurement) {
    [pscustomobject]@{utc=[DateTime]::UtcNow.ToString('o');working_set_MB=$measurement.WorkingSet64/1MB;private_MB=$measurement.PrivateMemorySize64/1MB;peak_working_set_MB=$measurement.PeakWorkingSet64/1MB} | Export-Csv -Path (Join-Path $path 'memory_samples.csv') -NoTypeInformation -Append
   }
   Start-Sleep -Seconds 2
   $proc.Refresh()
  } while(-not $proc.HasExited)
  $proc.WaitForExit()
  Get-Content (Join-Path $path 'run.log')
  Get-Content (Join-Path $path 'run_errors.log')
  if($proc.ExitCode -ne 0) { throw "Holdout prediction failed: $Stage" }
 }
} finally { Pop-Location }
