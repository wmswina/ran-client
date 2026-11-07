##############################################################
#  restore-sparse.ps1
#
#  Run this after cloning ran-client to re-apply sparse-checkout
#  on the 'client' submodule so only selected items are visible.
#
#  Usage (after cloning ran-client):
#    git clone --recurse-submodules <ran-client-url>
#    cd ran-client
#    .\restore-sparse.ps1
##############################################################

# ── EDIT THIS LIST to match your selected folders / files ─
# Add folder names (without trailing slash) or exact filenames.
# Example:
#   "data"           -> includes everything inside data/
#   "cfg"            -> includes everything inside cfg/
#   "GameClient.exe" -> single root-level file
$SELECTED_ITEMS = @(
    # --- FOLDERS ---
    "data",
    # "cfg",
    # "client",
    "textures",
    "sounds",
    "vcredist",
    # "animation",
    # "effect",
    # "gui",
    # "map",
    # "skin",

    # --- FILES ---
    "BugTrap.dll",
    "D3DCompiler_43.dll",
    "d3dx9_43.dll",
    "D3dx9d_43.dll",
    "dbghelp.dll",
    "ijl15.dll",
    "Launcher.exe",
    "mfc71.dll",
    "minia.exe",
    "mtd.dll",
    "mtp.dll",
    "netauth.dll",
    "OneRanOnline.ico",
    "rlauncher.xml",
    "rlauncher.ini",
    "param.ini",
    "option.ini"
)

# ── CONFIG ────────────────────────────────────────────────
$SUBMODULE_NAME = "client"
# ─────────────────────────────────────────────────────────

$ErrorActionPreference = "Stop"

function Write-Header($msg) {
    Write-Host ""
    Write-Host "================================================" -ForegroundColor Cyan
    Write-Host "  $msg" -ForegroundColor Cyan
    Write-Host "================================================" -ForegroundColor Cyan
}

Write-Header "Restore Sparse-Checkout for ran-client"

# ── Validate ──────────────────────────────────────────────
$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

if ($SELECTED_ITEMS.Count -eq 0) {
    Write-Host ""
    Write-Host "  ERROR: No items configured." -ForegroundColor Red
    Write-Host "  Edit the SELECTED_ITEMS list at the top of this script" -ForegroundColor Yellow
    Write-Host "  then run it again." -ForegroundColor Yellow
    exit 1
}

$submodulePath = Join-Path $repoRoot $SUBMODULE_NAME
if (-not (Test-Path $submodulePath)) {
    Write-Host ""
    Write-Host "  ERROR: Submodule folder not found: $submodulePath" -ForegroundColor Red
    Write-Host "  Make sure you ran: git submodule update --init --recursive" -ForegroundColor Yellow
    exit 1
}

# ── Init submodule if needed ──────────────────────────────
Write-Host ""
Write-Host "  Ensuring submodule is initialized..." -ForegroundColor Gray
Set-Location $repoRoot
$ErrorActionPreference = "Continue"
git submodule update --init --recursive
$ErrorActionPreference = "Stop"

# ── Move into submodule ───────────────────────────────────
Set-Location $submodulePath

# Get real git dir (submodule .git is a file, not a folder)
$submoduleGitDir = (git rev-parse --git-dir).Trim()
if (-not [System.IO.Path]::IsPathRooted($submoduleGitDir)) {
    $submoduleGitDir = Join-Path $submodulePath $submoduleGitDir
}

$infoDir    = Join-Path $submoduleGitDir "info"
$sparseFile = Join-Path $infoDir "sparse-checkout"

if (-not (Test-Path $infoDir)) {
    New-Item -ItemType Directory -Path $infoDir | Out-Null
}

# ── Build patterns ────────────────────────────────────────
Write-Host "  Building sparse-checkout patterns..." -ForegroundColor Gray

# Determine if any selected item is a file (not a folder on disk)
$sourceRoot = $submodulePath   # check against submodule working dir
$patterns   = @()
$hasFiles   = $false

foreach ($item in $SELECTED_ITEMS) {
    $fullPath = Join-Path $submodulePath $item
    $isDir    = Test-Path $fullPath -PathType Container

    # Treat as folder if it ends with / or exists as a directory
    if ($isDir -or $item.EndsWith("/")) {
        $cleanName = $item.TrimEnd("/")
        $patterns += "/$cleanName/"
    } else {
        $patterns += "/$item"
        $hasFiles = $true
    }
}

# ── Apply sparse-checkout ─────────────────────────────────
$ErrorActionPreference = "Continue"

if ($hasFiles) {
    Write-Host "  Mode: non-cone (individual files included)" -ForegroundColor DarkYellow
    git sparse-checkout init --no-cone
    $patterns | Set-Content $sparseFile -Encoding UTF8
} else {
    Write-Host "  Mode: cone (folders only)" -ForegroundColor Gray
    git sparse-checkout init --cone
    $folderNames = $SELECTED_ITEMS | ForEach-Object { $_.TrimEnd("/") }
    git sparse-checkout set $folderNames
}

Write-Host "  Removing unselected files from disk..." -ForegroundColor Gray
git sparse-checkout reapply

$ErrorActionPreference = "Stop"

# ── Summary ───────────────────────────────────────────────
Write-Header "Done! Sparse-checkout restored."
Write-Host ""
Write-Host "  Visible items in $SUBMODULE_NAME/:" -ForegroundColor Yellow
foreach ($item in $SELECTED_ITEMS) {
    Write-Host "    -> $item" -ForegroundColor Green
}
Write-Host ""
Write-Host "  To verify:" -ForegroundColor Gray
Write-Host "    cd $submodulePath" -ForegroundColor White
Write-Host "    git sparse-checkout list" -ForegroundColor White
Write-Host ""
