param([ValidateSet('prepare','smoke','baseline','external')][string]$Stage)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'P4_runtime.ps1')
$repoRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Initialize-P4Environment $repoRoot
# Avoid oversubscription of numerical libraries across the four chain workers.
$env:OMP_NUM_THREADS='1'
$env:OPENBLAS_NUM_THREADS='1'
Push-Location $repoRoot
try {
  if($Stage -in @('smoke','baseline','external')) {
    $runName=@{smoke='smoke_external';baseline='matched_baseline';external='external_sd'}[$Stage]
    $runPath=Join-Path $repoRoot ('outputs/P4/ExternalSD_6416/'+$runName)
    if((Test-Path (Join-Path $runPath 'inputs.rds')) -or (Test-Path (Join-Path $runPath 'progress.csv'))) { throw 'Existing run protected' }
    New-Item -ItemType Directory -Force -Path $runPath | Out-Null
    $runtime=Get-P4Runtime $repoRoot
    $proc=Start-Process -FilePath $runtime -ArgumentList @('--vanilla','-e',"source('code/P4/M1b_sd_run.R')",$Stage) -WorkingDirectory $repoRoot -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $runPath 'run.log') -RedirectStandardError (Join-Path $runPath 'run_errors.log')
    $monitorTick=0
    $freeMemoryMB=0
    do {
      if(($monitorTick % 15) -eq 0) {
        $freeMemoryMB=(Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory/1024
        if($freeMemoryMB -lt 2048) { 'Available physical RAM below 2 GB; stop after saved checkpoint' | Set-Content (Join-Path $runPath 'STOP_AFTER_CHECKPOINT') }
      }
      $processIds=@($proc.Id)
      $pidFile=Join-Path $runPath 'worker_pids.csv'
      if(Test-Path -LiteralPath $pidFile) { $processIds+=@(Import-Csv -LiteralPath $pidFile | ForEach-Object {[int]$_.pid}) }
      $measurements=@(Get-Process -Id $processIds -ErrorAction SilentlyContinue)
      if($measurements.Count) {
        [pscustomobject]@{utc=[DateTime]::UtcNow.ToString('o');processes=$measurements.Count;working_set_MB=($measurements | Measure-Object WorkingSet64 -Sum).Sum/1MB;private_MB=($measurements | Measure-Object PrivateMemorySize64 -Sum).Sum/1MB;sum_process_peak_MB=($measurements | Measure-Object PeakWorkingSet64 -Sum).Sum/1MB;available_physical_MB=$freeMemoryMB} | Export-Csv -Path (Join-Path $runPath 'memory_samples.csv') -NoTypeInformation -Append
      }
      Start-Sleep -Seconds 2
      $proc.Refresh()
      $monitorTick++
    } while(-not $proc.HasExited)
    $proc.WaitForExit()
    Get-Content (Join-Path $runPath 'run.log')
    Get-Content (Join-Path $runPath 'run_errors.log')
    if($proc.ExitCode -ne 0) { throw "P4 analysis failed: $Stage, exit $($proc.ExitCode)" }
  } else {
    $runtime=Get-P4Runtime $repoRoot
    & $runtime --vanilla -e "source('code/P4/M1b_sd_run.R')" $Stage
    if($LASTEXITCODE -ne 0) { throw "P4 analysis failed: $Stage" }
  }
} finally { Pop-Location }
