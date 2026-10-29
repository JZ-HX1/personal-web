$ErrorActionPreference = 'Stop'
Push-Location (Join-Path $PSScriptRoot '..')
try {
    python scripts/build.py
    if ($LASTEXITCODE -ne 0) { throw 'Build failed' }
} finally { Pop-Location }
