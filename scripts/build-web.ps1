# Builds the MoonQuery engine to JavaScript and stages it for the Web Playground.
#
# Usage:  pwsh -File scripts/build-web.ps1
#
# Produces:
#   web/moonquery.js         ES module      -> import { run_query_js } from "./moonquery.js"
#   web/moonquery.global.js  classic script -> globalThis.run_query_js (usable over file://)

$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $root

Write-Host "[1/3] moon build src/ffi --target js --release"
moon build src/ffi --target js --release

$artifact = Join-Path $root "_build/js/release/build/ffi/ffi.js"
if (-not (Test-Path -LiteralPath $artifact)) {
  throw "build artifact not found: $artifact"
}

$web = Join-Path $root "web"
New-Item -ItemType Directory -Force -Path $web | Out-Null

Write-Host "[2/3] staging ES module -> web/moonquery.js"
Copy-Item -LiteralPath $artifact -Destination (Join-Path $web "moonquery.js") -Force

Write-Host "[3/3] staging classic script -> web/moonquery.global.js"
$code = [System.IO.File]::ReadAllText($artifact, [System.Text.Encoding]::UTF8)
$pattern = '(?m)^[ \t]*export[ \t]*\{[ \t]*(?<inner>[\w$]+)[ \t]+as[ \t]+(?<name>[\w$]+)[ \t]*\}[ \t]*;?[ \t]*$'
$globalCode = $code -replace $pattern, 'globalThis.${name} = ${inner};'
if ($globalCode -eq $code -or $globalCode -match '(?m)^[ \t]*export[ \t]*\{') {
  throw "cannot rewrite the export statement of $artifact; load the ES module in index.html instead"
}
[System.IO.File]::WriteAllText((Join-Path $web "moonquery.global.js"), $globalCode, (New-Object System.Text.UTF8Encoding($false)))

$node = Get-Command node -ErrorAction SilentlyContinue
if ($node) {
  Write-Host "[smoke] node scripts/smoke-web.cjs web"
  node (Join-Path $PSScriptRoot "smoke-web.cjs") $web
} else {
  Write-Host "[smoke] node not found, skipped"
}

Write-Host ""
Write-Host "done. serve the playground with one of:" -ForegroundColor Green
Write-Host "  cd web; python -m http.server 8080"
Write-Host "  npx --yes serve web"
Write-Host "then open http://localhost:8080/ (web/index.html also works when opened directly)"