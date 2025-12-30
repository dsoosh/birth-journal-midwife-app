#!/usr/bin/env pwsh
# Deploy Flutter midwife app to connected phone with correct backend IP

# Get local IP address (excluding localhost and link-local)
$ipAddress = (Get-NetIPAddress -AddressFamily IPv4 | 
    Where-Object { $_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.254.*' } |
    Select-Object -First 1).IPAddress

if (-not $ipAddress) {
    Write-Error "Could not determine local IP address"
    exit 1
}

$apiUrl = "http://${ipAddress}:8000/api/v1"

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Deploying Polozne Midwife App" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Backend API: " -NoNewline
Write-Host $apiUrl -ForegroundColor Yellow
Write-Host ""

# Check if device is connected
Write-Host "Checking for connected devices..." -ForegroundColor Gray
flutter devices

$confirmation = Read-Host "`nProceed with deployment? (y/n)"
if ($confirmation -ne 'y') {
    Write-Host "Deployment cancelled." -ForegroundColor Yellow
    exit 0
}

Write-Host "`nBuilding and deploying app..." -ForegroundColor Green
flutter run --dart-define API_BASE_URL=$apiUrl

Write-Host "`n[OK] Deployment complete!" -ForegroundColor Green
