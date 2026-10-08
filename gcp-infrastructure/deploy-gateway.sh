#!/usr/bin/env bash
# Deploy GCP API Gateway with API Key authentication

set -euo pipefail

PROJECT_ID="${1:-$(gcloud config get-value project 2>/dev/null)}"
REGION="${2:-us-central1}"
API_ID="${3:-as400-invoice-api}"
CONFIG_ID="as400-config-$(date +%Y%m%d-%H%M%S)"
GATEWAY_ID="${4:-as400-gateway}"
SPEC_FILE="$(dirname "$0")/openapi-gateway-active.yaml"

echo "=========================================================="
echo "  AS/400 to Hybrid Cloud - GCP API Gateway Deployment"
echo "=========================================================="
echo "Project ID:  $PROJECT_ID"
echo "Region:      $REGION"
echo "API ID:      $API_ID"
echo "Config ID:   $CONFIG_ID"
echo "Gateway ID:  $GATEWAY_ID"
echo "Spec File:   $SPEC_FILE"

# 1. Enable Required Services
echo "[*] Step 1: Enabling required GCP services..."
gcloud services enable apigateway.googleapis.com --project="$PROJECT_ID"
gcloud services enable servicemanagement.googleapis.com --project="$PROJECT_ID"
gcloud services enable servicecontrol.googleapis.com --project="$PROJECT_ID"

# 2. Create API if not exists
echo "[*] Step 2: Creating API resource..."
if ! gcloud api-gateway apis describe "$API_ID" --project="$PROJECT_ID" >/dev/null 2>&1; then
    gcloud api-gateway apis create "$API_ID" --project="$PROJECT_ID" --display-name="AS400 Invoice API"
fi

# 3. Create or verify dedicated Service Account
SA_NAME="as400-gateway-sa"
SA_EMAIL="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
echo "[*] Step 3: Verifying / Creating Service Account '$SA_EMAIL'..."
if ! gcloud iam service-accounts describe "$SA_EMAIL" --project="$PROJECT_ID" >/dev/null 2>&1; then
    gcloud iam service-accounts create "$SA_NAME" --display-name="AS400 Gateway Service Account" --project="$PROJECT_ID"
fi

# 4. Create API Config
echo "[*] Step 4: Creating API Config..."
gcloud api-gateway api-configs create "$CONFIG_ID" \
    --api="$API_ID" \
    --openapi-spec="$SPEC_FILE" \
    --backend-auth-service-account="$SA_EMAIL" \
    --project="$PROJECT_ID" \
    --display-name="AS400 Invoice Config $CONFIG_ID"

# 4. Create or Update Gateway
echo "[*] Step 4: Deploying API Gateway..."
if ! gcloud api-gateway gateways describe "$GATEWAY_ID" --location="$REGION" --project="$PROJECT_ID" >/dev/null 2>&1; then
    gcloud api-gateway gateways create "$GATEWAY_ID" \
        --api="$API_ID" \
        --api-config="$CONFIG_ID" \
        --location="$REGION" \
        --project="$PROJECT_ID" \
        --display-name="AS400 Invoice Gateway"
else
    gcloud api-gateway gateways update "$GATEWAY_ID" \
        --api="$API_ID" \
        --api-config="$CONFIG_ID" \
        --location="$REGION" \
        --project="$PROJECT_ID"
fi

# 5. Retrieve Gateway URL
GATEWAY_HOST=$(gcloud api-gateway gateways describe "$GATEWAY_ID" --location="$REGION" --project="$PROJECT_ID" --format="value(defaultHostname)")
GATEWAY_URL="https://$GATEWAY_HOST"

echo "=========================================================="
echo "Deployment Complete! Gateway URL: $GATEWAY_URL"
echo "=========================================================="

# 6. Enable Managed Service
MANAGED_SERVICE=$(gcloud api-gateway apis describe "$API_ID" --project="$PROJECT_ID" --format="value(managedService)")
if [ -n "$MANAGED_SERVICE" ]; then
    gcloud services enable "$MANAGED_SERVICE" --project="$PROJECT_ID"
fi

