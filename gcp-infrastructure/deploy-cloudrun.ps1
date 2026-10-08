<#
.SYNOPSIS
  Builds and deploys the Spring Boot adapter to Google Cloud Run, then updates GCP API Gateway with the /v2 target.
#>

[CmdletBinding()]
param (
    [string]$ProjectId = "as400-modernization-poc-123456",
    [string]$Region = "us-central1",
    [string]$ServiceName = "as400-hybrid-adapter",
    [string]$Pub400User = $env:PUB400_USER,
    [string]$Pub400Password = $env:PUB400_PASSWORD,
    [string]$Pub400Library = $env:PUB400_LIBRARY,
    [string]$GatewayId = "as400-gateway",
    [string]$ApiId = "as400-invoice-api",
    [string]$AdapterDir = "$PSScriptRoot\..\as400-migration\hybrid-adapter",
    [string]$SpecFile = "$PSScriptRoot\openapi-gateway-active.yaml"
)

$ErrorActionPreference = "Stop"

# Ensure gcloud is found in PATH
$gcloudBin = "$env:LOCALAPPDATA\Google\Cloud SDK\google-cloud-sdk\bin"
if (Test-Path "$gcloudBin\gcloud.cmd") {
    $env:PATH = "$gcloudBin;$env:PATH"
}

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "  Deploying Spring Boot Adapter to Google Cloud Run (/v2)" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Enable Cloud Run & Cloud Build APIs
Write-Host "`n[*] Step 1: Enabling Cloud Run and Build APIs..." -ForegroundColor Yellow
gcloud services enable run.googleapis.com cloudbuild.googleapis.com artifactregistry.googleapis.com --project=$ProjectId --quiet

# 2. Grant Required IAM Permissions to the Default Service Account
$projectNumber = (gcloud projects describe $ProjectId --format="value(projectNumber)").Trim()
$computeSa = "$projectNumber-compute@developer.gserviceaccount.com"
Write-Host "`n[*] Step 2: Configuring IAM permissions for Build Service Account ($computeSa)..." -ForegroundColor Yellow
gcloud projects add-iam-policy-binding $ProjectId --member="serviceAccount:$computeSa" --role="roles/cloudbuild.builds.builder" --quiet
gcloud projects add-iam-policy-binding $ProjectId --member="serviceAccount:$computeSa" --role="roles/storage.objectViewer" --quiet
gcloud projects add-iam-policy-binding $ProjectId --member="serviceAccount:$computeSa" --role="roles/storage.admin" --quiet
gcloud projects add-iam-policy-binding $ProjectId --member="serviceAccount:$computeSa" --role="roles/artifactregistry.writer" --quiet

# Build environment variables list
$envVarsList = [System.Collections.Generic.List[string]]::new()
if ($Pub400Password) { $envVarsList.Add("PUB400_PASSWORD=$Pub400Password") }
if ($Pub400User) { $envVarsList.Add("PUB400_USER=$Pub400User") }
if ($Pub400Library) { $envVarsList.Add("PUB400_LIBRARY=$Pub400Library") }
$envVarsString = $envVarsList -join ","

# 3. Build and Deploy Container to Cloud Run
Write-Host "`n[*] Step 3: Building container and deploying to Cloud Run in $Region..." -ForegroundColor Yellow
gcloud run deploy $ServiceName `
    --source=$AdapterDir `
    --region=$Region `
    --platform=managed `
    --allow-unauthenticated `
    --set-env-vars="$envVarsString" `
    --project=$ProjectId `
    --quiet

if ($LASTEXITCODE -ne 0) {
    Write-Error "Cloud Run deployment failed. Please check build logs above."
    return
}
$cloudRunUrl = (gcloud run services describe $ServiceName --region=$Region --project=$ProjectId --format="value(status.url)").Trim()
Write-Host "`n[SUCCESS] Cloud Run Service Deployed: $cloudRunUrl" -ForegroundColor Green

# 4. Prepare deployment OpenAPI spec with live Cloud Run URL
Write-Host "`n[*] Step 3: Preparing API Gateway spec revision with Cloud Run backend URL..." -ForegroundColor Yellow
$deploySpecFile = Join-Path ([System.IO.Path]::GetTempPath()) ("openapi-gateway-deploy-" + (Get-Date -Format 'yyyyMMdd-HHmmss') + ".yaml")
$specContent = Get-Content -Path $SpecFile -Raw
$specContent = $specContent -replace 'https://CLOUD_RUN_SERVICE_URL_PLACEHOLDER', $cloudRunUrl
if ($env:NGROK_DOMAIN) {
    $specContent = $specContent -replace 'https://YOUR_NGROK_TUNNEL_URL', "https://$env:NGROK_DOMAIN"
}
Set-Content -Path $deploySpecFile -Value $specContent -Encoding UTF8

# 5. Push New API Config Revision to GCP API Gateway
$configId = "as400-config-v2-" + (Get-Date -Format "yyyyMMdd-HHmmss")
$saEmail = "as400-gateway-sa@$ProjectId.iam.gserviceaccount.com"

Write-Host "`n[*] Step 4: Creating new API Config revision '$configId'..." -ForegroundColor Yellow
gcloud api-gateway api-configs create $configId `
    --api=$ApiId `
    --openapi-spec=$deploySpecFile `
    --backend-auth-service-account=$saEmail `
    --project=$ProjectId `
    --display-name="AS400 Dual Backend Config $configId"

# 6. Update Existing Gateway with New Revision
Write-Host "`n[*] Step 5: Rolling update of existing Gateway '$GatewayId' to config '$configId'..." -ForegroundColor Yellow
gcloud api-gateway gateways update $GatewayId `
    --api=$ApiId `
    --api-config=$configId `
    --location=$Region `
    --project=$ProjectId

# Clean up temp spec file
if (Test-Path $deploySpecFile) { Remove-Item -Force $deploySpecFile }

Write-Host "==========================================================" -ForegroundColor Green
Write-Host "  Dual Backend Deployment Complete!" -ForegroundColor Green
$gwHostname = (gcloud api-gateway gateways describe $GatewayId --location=$Region --project=$ProjectId --format="value(defaultHostname)").Trim()
Write-Host "  Gateway Base URL: https://$gwHostname" -ForegroundColor Cyan
Write-Host "  /api/v1/* routes -> ngrok local tunnel" -ForegroundColor White
Write-Host "  /api/v2/* routes -> Cloud Run ($cloudRunUrl)" -ForegroundColor White
Write-Host "==========================================================" -ForegroundColor Green

