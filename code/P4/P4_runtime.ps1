function Get-P4Runtime([string]$RepoRoot) {
  if($env:P4_RSCRIPT) {
    if(-not (Test-Path -LiteralPath $env:P4_RSCRIPT)) { throw 'P4_RSCRIPT does not exist' }
    return $env:P4_RSCRIPT
  }
  $localRuntime=Join-Path $RepoRoot '.local/R-4.5.3/bin/x64/Rscript.exe'
  if(Test-Path -LiteralPath $localRuntime) { return $localRuntime }
  $found=Get-Command Rscript -CommandType Application -ErrorAction SilentlyContinue
  if($found) { return $found.Source }
  throw 'Set P4_RSCRIPT to your Rscript executable, or add Rscript to PATH'
}

function Initialize-P4Environment([string]$RepoRoot) {
  $localJags=Join-Path $RepoRoot '.local/JAGS-4.3.2'
  $localLibrary=Join-Path $RepoRoot '.local/R-library'
  if(-not $env:JAGS_HOME -and (Test-Path $localJags)) { $env:JAGS_HOME=$localJags }
  if(-not $env:R_LIBS_USER -and (Test-Path $localLibrary)) { $env:R_LIBS_USER=$localLibrary }
  if($IsWindows -or $env:OS -eq 'Windows_NT') { $env:LC_ALL='English_United States.utf8' }
  if($env:JAGS_HOME) { $env:PATH=(Join-Path $env:JAGS_HOME 'x64/bin')+[IO.Path]::PathSeparator+$env:PATH }
  $env:OMP_NUM_THREADS='1'
  $env:OPENBLAS_NUM_THREADS='1'
}
