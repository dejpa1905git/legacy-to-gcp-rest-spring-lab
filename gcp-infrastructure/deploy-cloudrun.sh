#!/usr/bin/env bash
# Deploy Spring Boot adapter to Cloud Run and update API Gateway

set -euo pipefail

PROJECT_ID="${1:-as400-modernization-poc-123456}"
REGION="${2:-us-central1}"
SERVICE_NAME="as400-hybrid-adapter"
GATEWAY_ID="as400-gateway"
API_ID="as400-invoice-api"
ADAPTER_DIR="$(dirname "$0")/../as400-migration/hybrid-adapter"
SPEC_FILE="$(dirname "$0")/openapi-gateway-active.yaml"
PUB400_PASSWORD="${PUB400_PASSWORD:-}"
PUB400_USER="${PUB400_USER:-}"
PUB400_LIBRARY="${PUB400_LIBRARY:-}"

echo "=========================================================="
echo "  Deploying Spring Boot Adapter to Cloud Run (/v2)"
echo "=========================================================="

# 1. Enable Required Services
echo "[*] Step 1: Enabling Cloud Run and Build APIs..."
gcloud services enable run.googleapis.com cloudbuild.googleapis.com artifactregistry.googleapis.com --project="$PROJECT_ID" --quiet

# 2. Grant IAM Permissions to Build Service Account
PROJECT_NUMBER=$(gcloud projects describe "$PROJECT_ID" --format="value(projectNumber)")
COMPUTE_SA="${PROJECT_NUMBER}-compute@developer.gserviceaccount.com"
echo "[*] Step 2: Granting IAM permissions to $COMPUTE_SA..."
gcloud projects add-iam-policy-binding "$PROJECT_ID" --member="serviceAccount:$COMPUTE_SA" --role="roles/cloudbuild.builds.builder" --quiet
gcloud projects add-iam-policy-binding "$PROJECT_ID" --member="serviceAccount:$COMPUTE_SA" --role="roles/storage.objectViewer" --quiet
gcloud projects add-iam-policy-binding "$PROJECT_ID" --member="serviceAccount:$COMPUTE_SA" --role="roles/storage.admin" --quiet
gcloud projects add-iam-policy-binding "$PROJECT_ID" --member="serviceAccount:$COMPUTE_SA" --role="roles/artifactregistry.writer" --quiet

# Build environment variables list
ENV_VARS="PUB400_PASSWORD=$PUB400_PASSWORD"
if [ -n "$PUB400_USER" ]; then ENV_VARS="$ENV_VARS,PUB400_USER=$PUB400_USER"; fi
if [ -n "$PUB400_LIBRARY" ]; then ENV_VARS="$ENV_VARS,PUB400_LIBRARY=$PUB400_LIBRARY"; fi

# 3. Build & Deploy to Cloud Run
echo "[*] Step 3: Deploying container to Cloud Run in $REGION..."
gcloud run deploy "$SERVICE_NAME" \
  --source="$ADAPTER_DIR" \
  --region="$REGION" \
  --platform=managed \
  --allow-unauthenticated \
  --set-env-vars="$ENV_VARS" \
  --project="$PROJECT_ID" \
  --quiet

CLOUD_RUN_URL=$(gcloud run services describe "$SERVICE_NAME" --region="$REGION" --project="$PROJECT_ID" --format="value(status.url)")
echo "[SUCCESS] Cloud Run Service Deployed: $CLOUD_RUN_URL"

# 4. Prepare temporary deployment OpenAPI spec
echo "[*] Step 4: Preparing deployment OpenAPI spec..."
DEPLOY_SPEC_FILE="/tmp/openapi-gateway-deploy-$(date +%Y%m%d%H%M%S).yaml"
cp "$SPEC_FILE" "$DEPLOY_SPEC_FILE"
sed -i "s|https://CLOUD_RUN_SERVICE_URL_PLACEHOLDER|$CLOUD_RUN_URL|g" "$DEPLOY_SPEC_FILE"
if [ -n "${NGROK_DOMAIN:-}" ]; then
  sed -i "s|https://YOUR_NGROK_TUNNEL_URL|https://$NGROK_DOMAIN|g" "$DEPLOY_SPEC_FILE"
fi

# 5. Push New Config Revision
CONFIG_ID="as400-config-v2-$(date +%Y%m%d-%H%M%S)"
SA_EMAIL="as400-gateway-sa@${PROJECT_ID}.iam.gserviceaccount.com"
echo "[*] Step 5: Creating new API Config revision $CONFIG_ID..."
gcloud api-gateway api-configs create "$CONFIG_ID" \
  --api="$API_ID" \
  --openapi-spec="$DEPLOY_SPEC_FILE" \
  --backend-auth-service-account="$SA_EMAIL" \
  --project="$PROJECT_ID" \
  --display-name="AS400 Dual Backend Config $CONFIG_ID"

# 6. Update Gateway
echo "[*] Step 6: Updating Gateway..."
gcloud api-gateway gateways update "$GATEWAY_ID" \
  --api="$API_ID" \
  --api-config="$CONFIG_ID" \
  --location="$REGION" \
  --project="$PROJECT_ID"

rm -f "$DEPLOY_SPEC_FILE"

GW_HOSTNAME=$(gcloud api-gateway gateways describe "$GATEWAY_ID" --location="$REGION" --project="$PROJECT_ID" --format="value(defaultHostname)")
echo "=========================================================="
echo "Deployment Complete! Gateway: https://$GW_HOSTNAME"
echo "=========================================================="

