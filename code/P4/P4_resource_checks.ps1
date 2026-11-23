$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'P4_runtime.ps1')
$repoRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$runtime=Get-P4Runtime $repoRoot
$probePath=Join-Path $repoRoot '.local/resource_probe_pid.txt'
New-Item -ItemType Directory -Force -Path (Join-Path $repoRoot '.local') | Out-Null
$rPath=$probePath.Replace('\','/')
$expression="writeLines(as.character(Sys.getpid()),'$rPath');Sys.sleep(1)"
$probe=Start-Process -FilePath $runtime -ArgumentList @('--vanilla','-e',$expression) -WindowStyle Hidden -PassThru -Wait
$actualPid=[int](Get-Content -LiteralPath $probePath)
if($actualPid -ne $probe.Id) { throw "Measured PID $($probe.Id) differs from actual R interpreter PID $actualPid" }
Write-Output 'PASS: resource monitoring PID is the actual R interpreter'
