# .NET runtime metrics on Azure Container Apps

Minimal .NET 10 example using Datadog serverless-init inside the application
container. The same application is deployed twice to compare serverless-init
1.9.6 and 1.9.15.

Both variants emit `runtime.dotnet.*` metrics through DogStatsD UDP on
`127.0.0.1:8125`.

## Topology

Each Azure Container App contains one container. `serverless-init` is copied
into the application image and remains the main process:

```text
serverless-init (PID 1)
└── dotnet RuntimeMetricsExample.dll
```

There is no separate Datadog sidecar container.

## Prerequisites

- Azure CLI authenticated to a subscription
- An existing Azure resource group
- An existing Azure Container Registry with admin access enabled
- An existing Azure Container Apps environment
- A Datadog API key

## Deploy both versions

```bash
export DD_API_KEY="<datadog-api-key>"
export DD_SITE="datadoghq.com"
export ACR="<azure-container-registry-name>"
export RG="<azure-resource-group>"
export ENV_NAME="<container-apps-environment>"

./deploy.sh
```

The script creates:

- `dotnet-runtime-metrics-init196` with serverless-init 1.9.6 and
  `env:serverless-init-196`
- `dotnet-runtime-metrics-init1915` with serverless-init 1.9.15 and
  `env:serverless-init-1915`

Both use `service:dotnet-runtime-metrics-demo` and explicitly set
`DD_RUNTIME_METRICS_ENABLED=true`.

## Generate runtime activity

```bash
for app in dotnet-runtime-metrics-init196 dotnet-runtime-metrics-init1915; do
  fqdn="$(az containerapp show \
    --name "$app" \
    --resource-group "$RG" \
    --query properties.configuration.ingress.fqdn \
    --output tsv)"

  for i in $(seq 1 30); do
    curl -fsS "https://$fqdn/" >/dev/null
    curl -fsS "https://$fqdn/work" >/dev/null
    sleep 2
  done
done
```

## Verify

The startup and tracer logs should contain:

```text
SERVERLESS_INIT | INFO | dogstatsd-udp: starting to listen on 127.0.0.1:8125
Using UDP for metrics transport: 127.0.0.1:8125
Sent the following metrics to the DD agent: runtime.dotnet...
```

In Datadog Metrics Explorer, query:

```text
runtime.dotnet.cpu.percent{service:dotnet-runtime-metrics-demo} by {env}
runtime.dotnet.threads.count{service:dotnet-runtime-metrics-demo} by {env}
runtime.dotnet.gc.size.gen0{service:dotnet-runtime-metrics-demo} by {env}
```

Current datapoints should appear for both environment tags.

## Build one version manually

```bash
docker build \
  --build-arg DOTNET_VERSION=10.0 \
  --build-arg SERVERLESS_INIT_VERSION=1.9.15 \
  --tag dotnet-runtime-metrics-example:1.9.15 \
  .
```

The Datadog installation script resolves the latest compatible .NET tracer at
image build time. Pin the resulting image digest when repeatability is required.
