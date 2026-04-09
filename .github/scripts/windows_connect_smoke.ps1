$ErrorActionPreference = "Stop"

& "$PSScriptRoot/windows_smoke_suite.ps1" @args
exit $LASTEXITCODE
