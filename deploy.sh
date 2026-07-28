#!/usr/bin/env bash
set -euo pipefail

: "${DD_API_KEY:?Set DD_API_KEY before running this script}"
: "${ACR:?Set ACR to an existing Azure Container Registry name}"
: "${RG:?Set RG to an existing Azure resource group}"
: "${ENV_NAME:?Set ENV_NAME to an existing Azure Container Apps environment}"

DD_SITE="${DD_SITE:-datadoghq.com}"
IMAGE_REPOSITORY="dotnet-runtime-metrics-example"
ACR_SERVER="$(az acr show --name "$ACR" --query loginServer -o tsv)"
ACR_USER="$(az acr credential show --name "$ACR" --query username -o tsv)"
ACR_PASS="$(az acr credential show --name "$ACR" --query 'passwords[0].value' -o tsv)"
SUBSCRIPTION_ID="$(az account show --query id -o tsv)"

az acr build \
  --registry "$ACR" \
  --image "$IMAGE_REPOSITORY:init-1.9.6" \
  --build-arg DOTNET_VERSION=10.0 \
  --build-arg SERVERLESS_INIT_VERSION=1.9.6 \
  .

az acr build \
  --registry "$ACR" \
  --image "$IMAGE_REPOSITORY:init-1.9.15" \
  --build-arg DOTNET_VERSION=10.0 \
  --build-arg SERVERLESS_INIT_VERSION=1.9.15 \
  .

deploy_app() {
  local app_name="$1"
  local image_tag="$2"
  local dd_env="$3"
  local dd_version="$4"

  az containerapp create \
    --name "$app_name" \
    --resource-group "$RG" \
    --environment "$ENV_NAME" \
    --image "$ACR_SERVER/$IMAGE_REPOSITORY:$image_tag" \
    --registry-server "$ACR_SERVER" \
    --registry-username "$ACR_USER" \
    --registry-password "$ACR_PASS" \
    --target-port 8080 \
    --ingress external \
    --min-replicas 1 \
    --max-replicas 1 \
    --cpu 0.5 \
    --memory 1Gi \
    --secrets dd-api-key="$DD_API_KEY" \
    --env-vars \
      DD_API_KEY=secretref:dd-api-key \
      DD_SITE="$DD_SITE" \
      DD_SERVICE=dotnet-runtime-metrics-demo \
      DD_ENV="$dd_env" \
      DD_VERSION="$dd_version" \
      DD_RUNTIME_METRICS_ENABLED=true \
      DD_TRACE_DEBUG=true \
      DD_LOG_LEVEL=debug \
      DD_AZURE_SUBSCRIPTION_ID="$SUBSCRIPTION_ID" \
      DD_AZURE_RESOURCE_GROUP="$RG" \
    --output none
}

deploy_app \
  dotnet-runtime-metrics-init196 \
  init-1.9.6 \
  serverless-init-196 \
  serverless-init-1.9.6

deploy_app \
  dotnet-runtime-metrics-init1915 \
  init-1.9.15 \
  serverless-init-1915 \
  serverless-init-1.9.15

echo "Deployed both runtime-metrics examples."
