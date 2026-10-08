<#
.SYNOPSIS
  Deploys GCP API Gateway with API Key authentication using the active OpenAPI specification.
.DESCRIPTION
  Automates the creation of the API definition, API config, gateway deployment, managed service enablement,
  and API key generation for the AS/400 hybrid cloud adapter.
#>

[CmdletBinding()]
param (
    [string]$ProjectId,
    [string]$Region = "us-central1",
    [string]$ApiId = "as400-invoice-api",
    [string]$ConfigId = ("as400-config-" + (Get-Date -Format "yyyyMMdd-HHmmss")),
    [string]$GatewayId = "as400-gateway",
    [string]$SpecFile = "$PSScriptRoot\openapi-gateway-active.yaml"
)

$ErrorActionPreference = "Stop"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "  AS/400 to Hybrid Cloud - GCP API Gateway Deployment" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# Ensure gcloud is found in PATH even if terminal hasn't restarted
$gcloudBin = "$env:LOCALAPPDATA\Google\Cloud SDK\google-cloud-sdk\bin"
if (Test-Path "$gcloudBin\gcloud.cmd") {
    $env:PATH = "$gcloudBin;$env:PATH"
}

# 1. Determine active GCP Project
if (-not $ProjectId) {
    try {
        $ProjectId = (gcloud config get-value project 2>$null).Trim()
    } catch {
        $ProjectId = $null
    }
}

if (-not $ProjectId) {
    Write-Error "No GCP project specified or found in active gcloud context. Run 'gcloud config set project <PROJECT_ID>' or pass -ProjectId <PROJECT_ID>."
    return
}

Write-Host "[+] Target GCP Project: $ProjectId" -ForegroundColor Green
Write-Host "[+] Target Region:      $Region" -ForegroundColor Green
Write-Host "[+] API ID:             $ApiId" -ForegroundColor Green
Write-Host "[+] Config ID:          $ConfigId" -ForegroundColor Green
Write-Host "[+] Gateway ID:         $GatewayId" -ForegroundColor Green
Write-Host "[+] OpenAPI Spec:       $SpecFile" -ForegroundColor Green

# 2. Verify OpenAPI spec exists
if (-not (Test-Path $SpecFile)) {
    Write-Error "OpenAPI specification not found at: $SpecFile. Please run .\gcp-infrastructure\start-tunnel.ps1 first."
    return
}

# 3. Enable Required Google Cloud Services
Write-Host "`n[*] Step 1: Enabling required GCP API services..." -ForegroundColor Yellow
gcloud services enable apigateway.googleapis.com --project=$ProjectId
gcloud services enable servicemanagement.googleapis.com --project=$ProjectId
gcloud services enable servicecontrol.googleapis.com --project=$ProjectId

# 4. Create or verify API definition
Write-Host "`n[*] Step 2: Creating or verifying API '$ApiId'..." -ForegroundColor Yellow
$apiExists = $false
try {
    $existingApi = gcloud api-gateway apis describe $ApiId --project=$ProjectId --format="value(name)" 2>$null
    if ($existingApi) { $apiExists = $true }
} catch {}

if (-not $apiExists) {
    gcloud api-gateway apis create $ApiId --project=$ProjectId --display-name="AS400 Invoice API"
    Write-Host "[+] API created successfully." -ForegroundColor Green
} else {
    Write-Host "[i] API '$ApiId' already exists. Reusing existing API definition." -ForegroundColor Gray
}

# 5. Create or verify dedicated Service Account for API Gateway
$saName = "as400-gateway-sa"
$saEmail = "$saName@$ProjectId.iam.gserviceaccount.com"
Write-Host "`n[*] Step 3: Verifying / Creating Service Account '$saEmail'..." -ForegroundColor Yellow
$saExists = $false
try {
    $existingSa = gcloud iam service-accounts describe $saEmail --project=$ProjectId --format="value(email)" 2>$null
    if ($existingSa) { $saExists = $true }
} catch {}

if (-not $saExists) {
    gcloud iam service-accounts create $saName --display-name="AS400 Gateway Service Account" --project=$ProjectId
    Write-Host "[+] Service Account created: $saEmail" -ForegroundColor Green
} else {
    Write-Host "[i] Reusing Service Account: $saEmail" -ForegroundColor Gray
}

# 6. Create API Config from OpenAPI specification
Write-Host "`n[*] Step 4: Creating API Config '$ConfigId' from OpenAPI spec..." -ForegroundColor Yellow
gcloud api-gateway api-configs create $ConfigId `
    --api=$ApiId `
    --openapi-spec=$SpecFile `
    --backend-auth-service-account=$saEmail `
    --project=$ProjectId `
    --display-name="AS400 Invoice Config $ConfigId"

# 6. Deploy or Update API Gateway
Write-Host "`n[*] Step 4: Deploying API Gateway '$GatewayId'..." -ForegroundColor Yellow
$gwExists = $false
try {
    $existingGw = gcloud api-gateway gateways describe $GatewayId --location=$Region --project=$ProjectId --format="value(name)" 2>$null
    if ($existingGw) { $gwExists = $true }
} catch {}

if (-not $gwExists) {
    gcloud api-gateway gateways create $GatewayId `
        --api=$ApiId `
        --api-config=$ConfigId `
        --location=$Region `
        --project=$ProjectId `
        --display-name="AS400 Invoice Gateway"
} else {
    Write-Host "[*] Gateway '$GatewayId' exists. Updating config to '$ConfigId'..." -ForegroundColor Cyan
    gcloud api-gateway gateways update $GatewayId `
        --api=$ApiId `
        --api-config=$ConfigId `
        --location=$Region `
        --project=$ProjectId
}

# 7. Retrieve Gateway Hostname
Write-Host "`n[*] Step 5: Retrieving Gateway URL..." -ForegroundColor Yellow
$gwJson = gcloud api-gateway gateways describe $GatewayId --location=$Region --project=$ProjectId --format="json" | ConvertFrom-Json
$gatewayUrl = "https://" + $gwJson.defaultHostname

Write-Host "==========================================================" -ForegroundColor Green
Write-Host "  GCP API Gateway Deployment Complete!" -ForegroundColor Green
Write-Host "  Gateway Base URL: $gatewayUrl" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Green

# 8. Enable the API's managed service
Write-Host "`n[*] Step 6: Enabling Managed Service for API Gateway..." -ForegroundColor Yellow
$apiJson = gcloud api-gateway apis describe $ApiId --project=$ProjectId --format="json" | ConvertFrom-Json
$managedService = $apiJson.managedService
if ($managedService) {
    Write-Host "[+] Managed Service: $managedService" -ForegroundColor Gray
    gcloud services enable $managedService --project=$ProjectId
}

# 9. Print Testing Instructions
Write-Host "`n--- VERIFICATION INSTRUCTIONS ---" -ForegroundColor Yellow
Write-Host "1. Test without API key (Should be rejected with 401/403):" -ForegroundColor White
Write-Host "   curl `"$gatewayUrl/api/v1/invoices/getinvoice?invId=INV-1001`"" -ForegroundColor Gray
Write-Host "`n2. Test with API key (Query param):" -ForegroundColor White
Write-Host "   curl `"$gatewayUrl/api/v1/invoices/getinvoice?invId=INV-1001&key=<YOUR_GCP_API_KEY>`"" -ForegroundColor Gray
Write-Host "`n3. Test with API key (Header):" -ForegroundColor White
Write-Host "   curl -H `"x-api-key: <YOUR_GCP_API_KEY>`" `"$gatewayUrl/api/v1/invoices/getinvoice?invId=INV-1001`"" -ForegroundColor Gray

