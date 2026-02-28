using Azure.Identity;
using Azure.Messaging.EventGrid;
using Azure.Messaging.ServiceBus;
using Azure.Security.KeyVault.Secrets;
using Microsoft.Extensions.Logging;
using OrderDemo.ContainerApp.Services;

var builder = WebApplication.CreateBuilder(args);

// Explicitly add environment variables to configuration
builder.Configuration.AddEnvironmentVariables();

// Configure logging with more details
builder.Logging.ClearProviders();
builder.Logging.AddConsole(options =>
{
    options.IncludeScopes = true;
    options.TimestampFormat = "[yyyy-MM-dd HH:mm:ss] ";
});
builder.Logging.AddDebug();
builder.Logging.SetMinimumLevel(LogLevel.Information);

// Add services to the container
builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(c =>
{
    c.SwaggerDoc("v1", new() { Title = "Order Demo API", Version = "v1" });
});

// Application Insights
builder.Services.AddApplicationInsightsTelemetry();

// Create a logger for startup configuration
var loggerFactory = LoggerFactory.Create(builder => builder.AddConsole());
var logger = loggerFactory.CreateLogger("Startup");

// Azure SDK clients with Managed Identity
var credential = new DefaultAzureCredential();

// Service Bus Client
var serviceBusNamespace = builder.Configuration["ServiceBusNamespace"];
logger.LogInformation("ServiceBusNamespace = {ServiceBusNamespace}", serviceBusNamespace ?? "(null)");
if (!string.IsNullOrEmpty(serviceBusNamespace))
{
    builder.Services.AddSingleton(_ => new ServiceBusClient(serviceBusNamespace, credential));
    builder.Services.AddHostedService<ServiceBusQueueProcessor>();
    builder.Services.AddHostedService<ServiceBusTopicProcessor>();
    logger.LogInformation("Service Bus Processing Registered");
}
else
{
    logger.LogWarning("Service Bus connection string not found, skipping Service Bus client registration");
}

// Event Grid Client
var eventGridEndpoint = builder.Configuration["EventGridTopicEndpoint"];
logger.LogInformation("EventGridTopicEndpoint = {EventGridEndpoint}", eventGridEndpoint ?? "(null)");
if (!string.IsNullOrEmpty(eventGridEndpoint))
{
    builder.Services.AddSingleton(_ => new EventGridPublisherClient(new Uri(eventGridEndpoint), credential));
    logger.LogInformation("Event Grid Client Registered");
}
else
{
    logger.LogWarning("Event Grid topic endpoint not found, skipping Event Grid client registration");
}

// Key Vault Client
var keyVaultUri = builder.Configuration["KeyVaultUri"];
logger.LogInformation("KeyVaultUri = {KeyVaultUri}", keyVaultUri ?? "(null)");
if (!string.IsNullOrEmpty(keyVaultUri))
{
    builder.Services.AddSingleton(_ => new SecretClient(new Uri(keyVaultUri), credential));
    logger.LogInformation("Key Vault Client Registered");
}
else
{
    logger.LogWarning("Key Vault URI not found, skipping Key Vault client registration");
}
// Health checks
builder.Services.AddHealthChecks();

var app = builder.Build();

// Configure the HTTP request pipeline
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI(c => c.SwaggerEndpoint("/swagger/v1/swagger.json", "Order Demo API v1"));
}

app.MapControllers();
app.MapHealthChecks("/health");

// Simple liveness probe
app.MapGet("/", () => new { status = "healthy", timestamp = DateTime.UtcNow });

app.Run();
