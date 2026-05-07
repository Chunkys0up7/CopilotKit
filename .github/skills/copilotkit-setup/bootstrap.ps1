# =============================================================================
# bootstrap.ps1 — scaffold a fresh CopilotKit Kickstarter project.
#
# Self-contained: does NOT require GitHub access. Copies the complete project
# layout from the skill's bundled `bootstrap/` directory into <target>.
#
# Usage:
#   pwsh bootstrap.ps1 -Target C:\path\to\new-project
#   pwsh bootstrap.ps1 -Target .\my-app -Force
#
# After this completes, follow RUNBOOK.md from Step 4 (backend deps).
# =============================================================================

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Target,

    [switch]$Force,
    [switch]$NoGit
)

$ErrorActionPreference = "Stop"

# Resolve paths
$skillDir = $PSScriptRoot
$srcDir = Join-Path $skillDir "bootstrap"
$Target = [System.IO.Path]::GetFullPath($Target)

# Pre-flight
if (-not (Test-Path $srcDir)) {
    throw "Bootstrap source not found at $srcDir. Re-install the skill."
}

if (Test-Path $Target) {
    $existing = Get-ChildItem -Path $Target -Force -ErrorAction SilentlyContinue
    if ($existing -and -not $Force) {
        throw "Target $Target is not empty. Use -Force to overwrite, or pick an empty directory."
    }
} else {
    New-Item -ItemType Directory -Path $Target -Force | Out-Null
}

Write-Host "==> Bootstrapping CopilotKit Kickstarter" -ForegroundColor Cyan
Write-Host "    source: $srcDir"
Write-Host "    target: $Target"
Write-Host ""

# Copy. -Recurse + -Force means hidden files (.gitignore, .env.example) come along.
Copy-Item -Path (Join-Path $srcDir "*") -Destination $Target -Recurse -Force

# Initialize git unless told otherwise
if (-not $NoGit) {
    Push-Location $Target
    try {
        if (-not (Test-Path ".git")) {
            git init --quiet
            git add .
            git commit --quiet -m "Initial commit (from copilotkit-setup skill)"
            Write-Host "==> git initialized + initial commit created" -ForegroundColor Green
        } else {
            Write-Host "==> existing .git found; skipped git init" -ForegroundColor Yellow
        }
    } finally {
        Pop-Location
    }
}

# Make .env from .env.example if missing
$envFile = Join-Path $Target ".env"
$envExample = Join-Path $Target ".env.example"
if ((-not (Test-Path $envFile)) -and (Test-Path $envExample)) {
    Copy-Item $envExample $envFile
    Write-Host "==> .env created from .env.example" -ForegroundColor Green
}

# Summary
$count = (Get-ChildItem -Path $Target -Recurse -File -Force | Where-Object { $_.FullName -notmatch '\\\.git\\' }).Count
Write-Host ""
Write-Host "==> Done. $count files written." -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  cd `"$Target`""
Write-Host "  # Backend (Terminal 1):"
Write-Host "  cd backend"
Write-Host "  python -m venv .venv"
Write-Host "  .\.venv\Scripts\Activate.ps1"
Write-Host "  pip install -r requirements.txt"
Write-Host "  uvicorn app.main:app --reload --port 8000"
Write-Host ""
Write-Host "  # Frontend (Terminal 2):"
Write-Host "  cd frontend"
Write-Host "  npm install"
Write-Host "  npm run dev"
Write-Host ""
Write-Host "  # Then open http://localhost:3000"
Write-Host ""
Write-Host "Full procedure: see RUNBOOK.md in the new project."
