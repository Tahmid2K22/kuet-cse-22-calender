# Rebuilds the Flutter web app and publishes build/web to the gh-pages branch.
#
# Usage (from anywhere):
#   $env:CALENDAR_ENDPOINT = "https://script.google.com/macros/s/.../exec"
#   powershell -ExecutionPolicy Bypass -File tool\deploy_web.ps1
#
# The endpoint is read from, in order:
#   1. the CALENDAR_ENDPOINT environment variable
#   2. tool/secrets.json  (git-ignored; copy tool/secrets.example.json)
#
# The gh-pages branch is generated output. This script force-pushes it, so never
# keep hand-written files there; edit the source in main instead.

$ErrorActionPreference = 'Stop'

$repoUrl = 'https://github.com/Tahmid2K22/kuet-cse-22-calender.git'
$baseHref = '/kuet-cse-22-calender/'
$siteUrl = 'https://tahmid2k22.github.io/kuet-cse-22-calender/'
$root = Split-Path -Parent $PSScriptRoot

Push-Location $root
try {
    $endpoint = $env:CALENDAR_ENDPOINT
    if (-not $endpoint) {
        $secretsPath = Join-Path $root 'tool/secrets.json'
        if (Test-Path $secretsPath) {
            $secrets = Get-Content $secretsPath -Raw | ConvertFrom-Json
            $endpoint = $secrets.CALENDAR_ENDPOINT
        }
    }

    if (-not $endpoint) {
        throw @'
CALENDAR_ENDPOINT is not set.

Set it for this session:
  $env:CALENDAR_ENDPOINT = "https://script.google.com/macros/s/.../exec"

Or copy tool/secrets.example.json to tool/secrets.json and fill in the URL.
Neither file is committed.
'@
    }

    if ($endpoint -notmatch '^https://script\.google\.com/macros/s/[^/]+/exec$') {
        throw "CALENDAR_ENDPOINT does not look like an Apps Script /exec URL: $endpoint"
    }

    Write-Host 'Building web release...' -ForegroundColor Cyan
    flutter build web --release --base-href $baseHref --dart-define=CALENDAR_ENDPOINT=$endpoint
    if ($LASTEXITCODE -ne 0) { throw 'flutter build web failed' }

    $staging = Join-Path $env:TEMP 'kuet-cse-22-calender-gh-pages'
    if (Test-Path $staging) { Remove-Item -Recurse -Force $staging }
    New-Item -ItemType Directory -Force -Path $staging | Out-Null

    Copy-Item 'build/web/*' $staging -Recurse -Force
    # Stops GitHub Pages from running Jekyll over the build output.
    New-Item -ItemType File -Path (Join-Path $staging '.nojekyll') -Force | Out-Null

    git init -b gh-pages $staging | Out-Null
    git -C $staging add -A
    git -C $staging -c user.name='Tahmid2K22' -c user.email='chowdhurytahmid20@gmail.com' `
        commit -m "Deploy web build $(Get-Date -Format 'yyyy-MM-dd HH:mm')" | Out-Null
    git -C $staging remote add origin $repoUrl

    Write-Host 'Pushing to gh-pages...' -ForegroundColor Cyan
    git -C $staging push -u origin gh-pages --force
    if ($LASTEXITCODE -ne 0) { throw 'git push failed' }

    Write-Host ''
    Write-Host "Deployed: $siteUrl" -ForegroundColor Green
    Write-Host 'GitHub Pages needs a minute to publish; hard-refresh if you see the old build.'
} finally {
    Pop-Location
}
