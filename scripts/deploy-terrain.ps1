# deploy-terrain.ps1 - Auth Firebase + deploy complet (rules, functions, hosting PWA)
# Usage (depuis la racine du projet) :
#   .\scripts\deploy-terrain.ps1
#   .\scripts\deploy-terrain.ps1 -SkipLogin
#   .\scripts\deploy-terrain.ps1 -SkipApk
#   .\scripts\deploy-terrain.ps1 -RulesOnly

param(
    [switch]$SkipLogin,
    [switch]$SkipApk,
    [switch]$RulesOnly
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $Root
$env:NODE_TLS_REJECT_UNAUTHORIZED = "0"

function Write-Step($msg) {
    Write-Host ""
    Write-Host "==> $msg" -ForegroundColor Cyan
}

function Get-FirebaseToken {
    $tokenFile = Join-Path $Root ".firebase-token.local"
    if ($env:FIREBASE_TOKEN) { return $env:FIREBASE_TOKEN }
    if (Test-Path $tokenFile) {
        return (Get-Content $tokenFile -Raw).Trim()
    }
    return $null
}

function Invoke-FirebaseArgs($subArgs) {
    $token = Get-FirebaseToken
    if ($token) {
        return @("npx", "--yes", "firebase-tools") + $subArgs + @("--token", $token)
    }
    return @("npx", "--yes", "firebase-tools") + $subArgs
}

Write-Step "Kelegance - deploiement terrain complet"
Write-Host "Racine : $Root"

# --- 1. Authentification Firebase ---
if (-not $SkipLogin) {
    $token = Get-FirebaseToken
    if ($token) {
        Write-Host "Token CI detecte (.firebase-token.local) - login interactif ignore." -ForegroundColor Yellow
    } else {
        Write-Step "Re-authentification Firebase (navigateur)"
        Write-Host "Si l'IDE bloque le navigateur, lancez : npm run firebase:login-ci" -ForegroundColor DarkGray
        & npx --yes firebase-tools login --reauth
        if ($LASTEXITCODE -ne 0) { throw "firebase login --reauth a echoue (code $LASTEXITCODE)" }
    }
}

# --- 2. Build PWA web (requis pour hosting : public = build/web) ---
if (-not $RulesOnly) {
    Write-Step "Build PWA Flutter web + preparation service worker"
    $webOrigin = if ($env:KELEGANCE_WEB_ORIGIN) { $env:KELEGANCE_WEB_ORIGIN } else { "https://kelegance.web.app" }
    $mapsKey = if ($env:GOOGLE_MAPS_API_KEY) { $env:GOOGLE_MAPS_API_KEY } else { "AIzaSyCM_g7NBu0L8WZDi8SuJTyt2wiilbCvfmI" }
    & flutter build web --release `
        "--dart-define=KELEGANCE_WEB_ORIGIN=$webOrigin" `
        "--dart-define=GOOGLE_MAPS_API_KEY=$mapsKey"
    if ($LASTEXITCODE -ne 0) { throw "flutter build web a echoue" }
    & node scripts/prepare-web-build.mjs
    if ($LASTEXITCODE -ne 0) { throw "prepare-web-build.mjs a echoue" }

    if (-not $SkipApk) {
        Write-Step "Build APK Android + copie OTA dans build/web/releases"
        & node scripts/publish-android-release.mjs
        if ($LASTEXITCODE -ne 0) {
            Write-Host "APK non compile - PWA deployee quand meme." -ForegroundColor Yellow
        }
    } else {
        Write-Host "APK ignore (-SkipApk)" -ForegroundColor DarkGray
    }
}

# --- 3. Deploy Firebase ---
Write-Step "firebase deploy - firestore:rules, functions, hosting"
$deployArgs = if ($RulesOnly) {
    @("deploy", "--only", "firestore:rules,functions")
} else {
    @("deploy", "--only", "firestore:rules,functions,hosting")
}
$fb = Invoke-FirebaseArgs $deployArgs
& $fb[0] $fb[1..($fb.Length - 1)]
if ($LASTEXITCODE -ne 0) { throw "firebase deploy a echoue (code $LASTEXITCODE)" }

Write-Step "Termine - pret pour le terrain"
Write-Host "PWA Bras Droit : https://kelegance.web.app/gestion" -ForegroundColor Green
Write-Host "PWA Chauffeur  : https://kelegance.web.app/chauffeur" -ForegroundColor Green
Write-Host "APK OTA        : https://kelegance.web.app/releases/kelegance-latest.apk" -ForegroundColor Green
Write-Host ""
Write-Host "Token CI sans navigateur : npm run firebase:login-ci" -ForegroundColor DarkGray
Write-Host 'Deploy sans rebuild APK  : .\scripts\deploy-terrain.ps1 -SkipLogin -SkipApk' -ForegroundColor DarkGray
