using System.Runtime.InteropServices;
using OpenTelemetry.Metrics;
using OpenTelemetry.Resources;

var builder = WebApplication.CreateBuilder(args);
var serviceName =
    Environment.GetEnvironmentVariable("DD_SERVICE") ?? "dotnet-runtime-metrics-demo";

builder.Services.AddOpenTelemetry()
    .ConfigureResource(resource => resource.AddService(serviceName))
    .WithMetrics(metrics =>
    {
        metrics.AddAspNetCoreInstrumentation();
        metrics.AddRuntimeInstrumentation();
        metrics.AddPrometheusExporter();
    });

var app = builder.Build();

app.MapPrometheusScrapingEndpoint();

app.MapGet("/", () => Results.Ok(new
{
    status = "ok",
    framework = RuntimeInformation.FrameworkDescription,
    service = serviceName
}));

app.MapGet("/work", () =>
{
    var allocations = new List<byte[]>();
    for (var i = 0; i < 50; i++)
    {
        allocations.Add(new byte[100_000]);
    }

    try
    {
        throw new InvalidOperationException("intentional caught exception");
    }
    catch (InvalidOperationException)
    {
        // Generate a caught exception for runtime-metrics activity.
    }

    GC.Collect();
    return Results.Ok(new { allocatedBlocks = allocations.Count });
});

app.Run();
