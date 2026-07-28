# syntax=docker/dockerfile:1
ARG DOTNET_VERSION=10.0
ARG SERVERLESS_INIT_VERSION=1.9.15

FROM datadog/serverless-init:${SERVERLESS_INIT_VERSION} AS ddinit

FROM mcr.microsoft.com/dotnet/sdk:${DOTNET_VERSION} AS build
WORKDIR /src
COPY Directory.Packages.props ./
COPY src/RuntimeMetricsExample.csproj src/
RUN dotnet restore src/RuntimeMetricsExample.csproj
COPY src/ src/
RUN dotnet publish src/RuntimeMetricsExample.csproj -c Release -o /app /p:UseAppHost=false

FROM mcr.microsoft.com/dotnet/aspnet:${DOTNET_VERSION}

COPY --from=ddinit / /dd/
RUN chmod +x /dd/dotnet.sh \
    && /dd/dotnet.sh \
    && mkdir -p /LogFiles/datadog \
    && chmod -R a+rwx /LogFiles

WORKDIR /app
COPY --from=build /app ./
COPY launch.sh /launch.sh
RUN chmod a+x /launch.sh

ENV CORECLR_ENABLE_PROFILING=1
ENV CORECLR_PROFILER={846F5F1C-F9AE-4B07-969E-05C26BC060D8}
ENV CORECLR_PROFILER_PATH=/dd_tracer/dotnet/Datadog.Trace.ClrProfiler.Native.so
ENV DD_DOTNET_TRACER_HOME=/dd_tracer/dotnet
ENV LD_PRELOAD=/dd_tracer/dotnet/linux-x64/Datadog.Linux.ApiWrapper.x64.so
ENV DD_RUNTIME_METRICS_ENABLED=true
ENV DD_TRACE_ENABLED=true
ENV DD_TRACE_LOG_DIRECTORY=/LogFiles/datadog
ENV DD_STARTUP_LOGS_ENABLED=true
ENV DD_PROFILING_ENABLED=0
ENV DD_APPSEC_ENABLED=false
ENV ASPNETCORE_URLS=http://0.0.0.0:8080

EXPOSE 8080
ENTRYPOINT ["/launch.sh"]
CMD ["dotnet", "/app/RuntimeMetricsExample.dll"]
