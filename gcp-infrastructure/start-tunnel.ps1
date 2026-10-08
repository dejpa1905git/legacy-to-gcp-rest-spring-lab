<#
.SYNOPSIS
  Starts local ngrok tunnel for port 8080 and populates GCP API Gateway OpenAPI configuration.
#>

[CmdletBinding()]
param (
    [int]$Port = 8080,
    [string]$AuthToken = $env:NGROK_AUTHTOKEN,
    [string]$SpecTemplate = "$PSScriptRoot\openapi2-spec.yaml",
    [string]$OutputSpec = "$PSScriptRoot\openapi-gateway-active.yaml"
)

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "  AS/400 Modernization - Hybrid Cloud Tunnel & Gateway Sync" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Verify ngrok executable (check PATH and WinGet default install location)
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
$machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
$env:PATH = "$userPath;$machinePath;$env:PATH"

$ngrokCmd = Get-Command ngrok -ErrorAction SilentlyContinue
$ngrokPath = if ($ngrokCmd) { $ngrokCmd.Source } else { $null }

if (-not $ngrokPath) {
    $fallbackPaths = @(
        "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\Ngrok.Ngrok_Microsoft.Winget.Source_8wekyb3d8bbwe\ngrok.exe",
        "$env:LOCALAPPDATA\Microsoft\WinGet\Links\ngrok.exe"
    )
    foreach ($p in $fallbackPaths) {
        if (Test-Path $p) {
            $ngrokPath = $p
            break
        }
    }
}

if (-not $ngrokPath) {
    Write-Warning "ngrok command not found in PATH or WinGet packages."
    Write-Host "You can install ngrok via winget:" -ForegroundColor Yellow
    Write-Host "  winget install Ngrok.Ngrok" -ForegroundColor White
    return
}

# 2. Configure authtoken if provided
if ($AuthToken) {
    Write-Host "[+] Configuring ngrok authtoken..." -ForegroundColor Gray
    & $ngrokPath config add-authtoken $AuthToken
}

# 3. Check if ngrok is already running
$existingTunnels = $null
try {
    $existingTunnels = Invoke-RestMethod -Uri "http://127.0.0.1:4040/api/tunnels" -ErrorAction Stop
} catch {
    # Not running
}

if (-not $existingTunnels) {
    Write-Host "[+] Launching ngrok tunnel on port $Port..." -ForegroundColor Green
    Start-Process $ngrokPath -ArgumentList "http $Port" -WindowStyle Minimized
    Write-Host "[*] Waiting for ngrok tunnel initialization..." -ForegroundColor Gray
    Start-Sleep -Seconds 4
}

# 3. Retrieve public URL from ngrok API
try {
    $tunnels = Invoke-RestMethod -Uri "http://127.0.0.1:4040/api/tunnels" -ErrorAction Stop
    $httpsTunnel = $tunnels.tunnels | Where-Object { $_.proto -eq "https" } | Select-Object -First 1

    if (-not $httpsTunnel) {
        Write-Error "Could not retrieve public HTTPS tunnel URL from ngrok API."
        return
    }

    $publicUrl = $httpsTunnel.public_url
    # Strip https:// prefix for host variable if needed
    $hostOnly = $publicUrl -replace "^https?://", ""

    Write-Host "[SUCCESS] Public Tunnel Active: $publicUrl" -ForegroundColor Green
    Write-Host "[INFO] Backend Host: $hostOnly" -ForegroundColor Gray

    # 4. Generate active OpenAPI spec for GCP API Gateway
    if (Test-Path $SpecTemplate) {
        $content = Get-Content -Path $SpecTemplate -Raw
        $activeContent = $content -replace '\$\{BACKEND_TUNNEL_HOST\}', $hostOnly
        Set-Content -Path $OutputSpec -Value $activeContent -Encoding UTF8
        Write-Host "[+] Generated GCP API Gateway Spec: $OutputSpec" -ForegroundColor Cyan
        Write-Host "    Backend address configured to: https://$hostOnly" -ForegroundColor Gray
    }
} catch {
    Write-Warning "Could not connect to ngrok local API."
    Write-Host "If ngrok failed to start, it requires a free ngrok authtoken:" -ForegroundColor Yellow
    Write-Host "  1. Sign up for free at: https://dashboard.ngrok.com/signup" -ForegroundColor White
    Write-Host "  2. Grab your token from: https://dashboard.ngrok.com/get-started/your-authtoken" -ForegroundColor White
    Write-Host "  3. Run: .\gcp-infrastructure\start-tunnel.ps1 -AuthToken <YOUR_TOKEN>" -ForegroundColor White
    Write-Host "     (or run: ngrok config add-authtoken <YOUR_TOKEN>)" -ForegroundColor Gray
}

