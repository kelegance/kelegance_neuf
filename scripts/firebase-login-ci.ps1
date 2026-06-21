# Génère un token Firebase CI et l'enregistre dans .firebase-token.local
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot\..

$tokenFile = Join-Path (Get-Location) ".firebase-token.local"

Write-Host ""
Write-Host "=== Firebase login:ci (mode --no-localhost) ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. Une URL va s'afficher ci-dessous."
Write-Host "2. Copiez-la et ouvrez-la dans Chrome/Edge (pas dans l'IDE)."
Write-Host "3. Connectez-vous avec le compte Google du projet Firebase 'kelegance'."
Write-Host "4. Autorisez l'acces, puis revenez ici."
Write-Host ""
Write-Host "Appuyez sur Entree pour lancer firebase login:ci..." -ForegroundColor Yellow
Read-Host

$output = npx firebase login:ci --no-localhost 2>&1 | Out-String
Write-Host $output

# Extraire le token (ligne commencant par 1//)
$token = $null
foreach ($line in ($output -split "`n")) {
    $trimmed = $line.Trim()
    if ($trimmed -match '^1//') {
        $token = $trimmed
        break
    }
}

if (-not $token) {
    Write-Host ""
    Write-Host "Token non detecte automatiquement." -ForegroundColor Yellow
    $token = Read-Host "Collez le token Firebase CI ici"
}

$token = $token.Trim()
if (-not $token) {
    Write-Host "Token vide — abandon." -ForegroundColor Red
    exit 1
}

Set-Content -Path $tokenFile -Value $token -Encoding UTF8 -NoNewline
$env:FIREBASE_TOKEN = $token

Write-Host ""
Write-Host "Token enregistre dans .firebase-token.local" -ForegroundColor Green
Write-Host "Variable de session FIREBASE_TOKEN definie pour ce terminal." -ForegroundColor Green
Write-Host ""
Write-Host "Verification du projet..." -ForegroundColor Cyan
npx firebase projects:list --token $token

Write-Host ""
Write-Host "Pret. Lancez maintenant :" -ForegroundColor Green
Write-Host "  npm run deploy:hosting:only   (si build/web existe deja)"
Write-Host "  npm run deploy:web              (build + deploy complet)"
Write-Host ""
