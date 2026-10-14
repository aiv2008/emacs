<#
fix-pyqpanda3-stubs.ps1 -- make pyqpanda3's compiled-extension symbols visible to
static tools (jedi/pylsp, pyright), so M-. and completion work inside Emacs.

WHY THIS IS NEEDED
  pyqpanda3 ships per-subpackage stubs like pyqpanda3\core\__init__.pyi that
  contain nothing but __all__ plus a "# Names in __all__ with no definition:"
  comment.  The real signatures live in the sibling core.pyi, and at runtime the
  names are injected into globals() by _extension_loader.export_public_symbols().
  Static tools prefer the .pyi, see no definitions there, and therefore cannot
  resolve core.H / core.QProg / CPUQVM.  This script appends an explicit
  "from .<mod> import *" re-export so they can.

WHAT IT TOUCHES
  <site-packages>\pyqpanda3\<sub>\__init__.pyi   (7 subpackages)
  <site-packages>\pyqpanda3\core\__init__.py     (runtime file, see -SkipRuntimeFile)

  Both changes are static-analysis only; the runtime file change is equivalent
  to what export_public_symbols() already does at import time.

SAFETY
  * Idempotent: already-patched files are skipped.
  * The first time a file is patched, the original is kept next to it as
    <name>.pystub-orig -- to revert, move it back.
  * Re-run this after every "pip install -U pyqpanda3" (upgrades overwrite it).

USAGE
  pwsh -File ~/.emacs.d/scripts/fix-pyqpanda3-stubs.ps1
  pwsh -File ~/.emacs.d/scripts/fix-pyqpanda3-stubs.ps1 -Roots D:\workspace\qpanda3-env
  pwsh -File ~/.emacs.d/scripts/fix-pyqpanda3-stubs.ps1 -Roots C:\path\to\site-packages
#>
[CmdletBinding()]
param(
  # Extra directories to search: a venv root, a site-packages dir, a project.
  [string[]] $Roots = @(),
  # Skip patching <pkg>\core\__init__.py (the .pyi patches alone are usually enough).
  [switch]   $SkipRuntimeFile
)

$ErrorActionPreference = 'Continue'

$subs = @('core', 'vqcircuit', 'hamiltonian', 'intermediate_compiler',
          'quantum_info', 'transpilation', 'pilot_service', 'qcloud')
$brokenMarker = '# Names in __all__ with no definition'

function Add-StubLine {
  param([string] $File, [string] $Line)
  $text = [System.IO.File]::ReadAllText($File)
  if ($text.Contains($Line)) { return 'skip (already patched)' }
  $bak = "$File.pystub-orig"
  if (-not (Test-Path -LiteralPath $bak)) {
    Copy-Item -LiteralPath $File -Destination $bak
  }
  [System.IO.File]::AppendAllText($File, "`r`n$Line`r`n")
  return 'patched'
}

# ---------- 1. where to look ------------------------------------------------
$search = New-Object System.Collections.Generic.List[string]

$emacsDir = Split-Path -Parent $PSScriptRoot          # .../.emacs.d
if ($emacsDir) { $search.Add($emacsDir) }             # finds .emacs.d/*-env/Lib/site-packages
$search.Add((Get-Location).Path)                      # run it from a project dir to catch .\.venv
if ($env:USERPROFILE) { $search.Add((Join-Path $env:USERPROFILE '.emacs.d')) }
if ($env:LOCALAPPDATA) {                              # MS Store Python user site
  $pkgsRoot = Join-Path $env:LOCALAPPDATA 'Packages'
  Get-ChildItem -LiteralPath $pkgsRoot -Directory -Filter 'PythonSoftwareFoundation.Python.*' -ErrorAction SilentlyContinue |
    ForEach-Object { $search.Add($_.FullName) }
}
foreach ($r in $Roots) { if ($r) { $search.Add($r) } }

# Also ask whatever "python" is on PATH where its pyqpanda3 lives.
if (Get-Command python -ErrorAction SilentlyContinue) {
  $p = & python -c "import os,pyqpanda3;print(os.path.dirname(pyqpanda3.__file__))" 2>$null
  if ($p -and (Test-Path -LiteralPath $p)) { $search.Add((Split-Path -Parent $p)) }
}

# ---------- 2. find every installed copy -----------------------------------
$pkgs = @{}
foreach ($root in ($search | Where-Object { $_ } | Select-Object -Unique)) {
  if (-not (Test-Path -LiteralPath $root)) { continue }
  Get-ChildItem -LiteralPath $root -Recurse -Directory -Filter 'pyqpanda3' -ErrorAction SilentlyContinue |
    Where-Object { $_.Parent -and $_.Parent.Name -eq 'site-packages' } |
    ForEach-Object { $pkgs[$_.FullName] = $true }
}

if ($pkgs.Count -eq 0) {
  Write-Host 'No pyqpanda3 package found.' -ForegroundColor Yellow
  Write-Host 'Pass its location explicitly, e.g. -Roots D:\myproj\.venv' -ForegroundColor Yellow
  exit 1
}

Write-Host ("pyqpanda3 copies found: {0}" -f $pkgs.Count)
foreach ($pkg in ($pkgs.Keys | Sort-Object)) {
  Write-Host ''
  Write-Host ("== {0}" -f $pkg) -ForegroundColor Cyan

  foreach ($s in $subs) {
    $stub = Join-Path $pkg "$s\__init__.pyi"
    if (-not (Test-Path -LiteralPath $stub)) { continue }
    if (-not ([System.IO.File]::ReadAllText($stub).Contains($brokenMarker))) {
      Write-Host ("   {0,-24} skip (not the broken shim layout)" -f "$s\__init__.pyi")
      continue
    }
    $res = Add-StubLine -File $stub -Line "from .$s import *"
    Write-Host ("   {0,-24} {1}" -f "$s\__init__.pyi", $res)
  }

  if (-not $SkipRuntimeFile) {
    $rt = Join-Path $pkg 'core\__init__.py'
    if (Test-Path -LiteralPath $rt) {
      $txt = [System.IO.File]::ReadAllText($rt)
      if ($txt.Contains('export_public_symbols') -and -not $txt.Contains('from .core import *')) {
        $res = Add-StubLine -File $rt -Line 'from .core import *'
        Write-Host ("   {0,-24} {1}" -f 'core\__init__.py', $res)
      } else {
        Write-Host ("   {0,-24} skip" -f 'core\__init__.py')
      }
    }
  }
}

Write-Host ''
Write-Host 'Done. Restart the language server to pick it up:' -ForegroundColor Green
Write-Host '  in the .py buffer:  M-x mvue-restart-server    (or restart Emacs)'
Write-Host ''
Write-Host 'Notes:'
Write-Host '  * "pip install -U pyqpanda3" wipes these patches -- re-run this script.'
Write-Host '  * pyqpanda3.utils ships no .pyi at all, so utils.* stays invisible to'
Write-Host '    static tools no matter what.'
Write-Host '  * Revert: move every *.pystub-orig back over its file.'
