using Microsoft.AspNetCore.Mvc;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace OrderDemo.ContainerApp.Controllers;

[ApiController]
[Route("api/[controller]")]
public class WebhooksController : ControllerBase
{
    private readonly ILogger<WebhooksController> _logger;

    public WebhooksController(ILogger<WebhooksController> logger)
    {
        _logger = logger;
    }

    /// <summary>
    /// Event Grid webhook endpoint
    /// Handles subscription validation and event notifications
    /// </summary>
    [HttpPost("eventgrid")]
    public async Task<IActionResult> HandleEventGridEvent()
    {
        using var reader = new StreamReader(Request.Body);
        var requestBody = await reader.ReadToEndAsync();
        
        _logger.LogInformation("Received Event Grid webhook request: {RequestBody}", requestBody);

        try
        {
            var events = JsonSerializer.Deserialize<EventGridEvent[]>(requestBody, new JsonSerializerOptions
            {
                PropertyNameCaseInsensitive = true
            });
            
            if (events == null || events.Length == 0)
            {
                _logger.LogWarning("No events received in request");
                return BadRequest("No events received");
            }

            foreach (var eventGridEvent in events)
            {
                // Handle subscription validation
                if (eventGridEvent.EventType == "Microsoft.EventGrid.SubscriptionValidationEvent")
                {
                    _logger.LogInformation("Received subscription validation event");
                    
                    var dataElement = (JsonElement)eventGridEvent.Data;
                    var validationCode = dataElement.GetProperty("validationCode").GetString();
                    
                    _logger.LogInformation("Validating Event Grid subscription with code: {ValidationCode}", validationCode);
                    
                    var response = new { validationResponse = validationCode };
                    return Ok(response);
                }
                
                // Handle actual events
                _logger.LogInformation(
                    "Received Event Grid event: Type={EventType}, Subject={Subject}, Id={Id}",
                    eventGridEvent.EventType,
                    eventGridEvent.Subject,
                    eventGridEvent.Id);
                
                // Process the event based on type
                switch (eventGridEvent.EventType)
                {
                    case "OrderCreated":
                        _logger.LogInformation("Processing OrderCreated event for {Subject}", eventGridEvent.Subject);
                        break;
                    case "OrderStatusUpdate":
                        _logger.LogInformation("Processing OrderStatusUpdate event for {Subject}", eventGridEvent.Subject);
                        break;
                    case "OrderCompleted":
                        _logger.LogInformation("Processing OrderCompleted event for {Subject}", eventGridEvent.Subject);
                        break;
                    default:
                        _logger.LogInformation("Processing event type: {EventType}", eventGridEvent.EventType);
                        break;
                }
            }

            return Ok();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error processing Event Grid webhook");
            return StatusCode(500, new { error = ex.Message });
        }
    }
}

// Event Grid event model
public class EventGridEvent
{
    [JsonPropertyName("id")]
    public string Id { get; set; } = string.Empty;
    
    [JsonPropertyName("eventType")]
    public string EventType { get; set; } = string.Empty;
    
    [JsonPropertyName("subject")]
    public string Subject { get; set; } = string.Empty;
    
    [JsonPropertyName("eventTime")]
    public DateTime EventTime { get; set; }
    
    [JsonPropertyName("data")]
    public object Data { get; set; } = new();
    
    [JsonPropertyName("dataVersion")]
    public string DataVersion { get; set; } = string.Empty;
    
    [JsonPropertyName("metadataVersion")]
    public string MetadataVersion { get; set; } = string.Empty;
    
    [JsonPropertyName("topic")]
    public string Topic { get; set; } = string.Empty;
}
