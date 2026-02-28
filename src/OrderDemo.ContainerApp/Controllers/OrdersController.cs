using Azure.Messaging.EventGrid;
using Azure.Messaging.ServiceBus;
using Microsoft.AspNetCore.Mvc;
using OrderDemo.ContainerApp.Models;
using System.Text.Json;

namespace OrderDemo.ContainerApp.Controllers;

[ApiController]
[Route("api/[controller]")]
public class OrdersController : ControllerBase
{
    private readonly ILogger<OrdersController> _logger;
    private readonly ServiceBusClient? _serviceBusClient;
    private readonly EventGridPublisherClient? _eventGridClient;

    public OrdersController(
        ILogger<OrdersController> logger,
        ServiceBusClient? serviceBusClient = null,
        EventGridPublisherClient? eventGridClient = null)
    {
        _logger = logger;
        _serviceBusClient = serviceBusClient;
        _eventGridClient = eventGridClient;
    }

    /// <summary>
    /// Create a new order and send to Service Bus queue
    /// </summary>
    [HttpPost]
    public async Task<IActionResult> CreateOrder([FromBody] Order order)
    {
        try
        {
            var correlationId = Guid.NewGuid().ToString();
            _logger.LogInformation("Creating order {OrderId} with correlation ID {CorrelationId}", 
                order.OrderId, correlationId);

            // Send to Service Bus Queue
            if (_serviceBusClient != null)
            {
                var sender = _serviceBusClient.CreateSender("order-queue");
                var message = new ServiceBusMessage(JsonSerializer.Serialize(order))
                {
                    ContentType = "application/json",
                    CorrelationId = correlationId,
                    MessageId = order.OrderId
                };
                message.ApplicationProperties.Add("OrderId", order.OrderId);
                message.ApplicationProperties.Add("CustomerName", order.CustomerName);

                await sender.SendMessageAsync(message);
                _logger.LogInformation("Order {OrderId} sent to Service Bus queue", order.OrderId);
            }

            return CreatedAtAction(nameof(GetOrder), new { id = order.OrderId }, order);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error creating order {OrderId}", order.OrderId);
            return StatusCode(500, new { error = ex.Message });
        }
    }

    /// <summary>
    /// Get order by ID (mock implementation)
    /// </summary>
    [HttpGet("{id}")]
    public IActionResult GetOrder(string id)
    {
        _logger.LogInformation("Retrieving order {OrderId}", id);
        
        // Mock response
        var order = new Order
        {
            OrderId = id,
            CustomerName = "Sample Customer",
            TotalAmount = 99.99m,
            Status = "Processing"
        };

        return Ok(order);
    }

    /// <summary>
    /// Publish order event to Event Grid
    /// </summary>
    [HttpPost("{id}/events")]
    public async Task<IActionResult> PublishOrderEvent(string id, [FromBody] OrderEvent orderEvent)
    {
        try
        {
            if (_eventGridClient == null)
            {
                return BadRequest(new { error = "Event Grid client not configured" });
            }

            orderEvent.OrderId = id;
            orderEvent.Timestamp = DateTime.UtcNow;

            var eventGridEvent = new Azure.Messaging.EventGrid.EventGridEvent(
                subject: $"orders/{id}",
                eventType: orderEvent.EventType,
                dataVersion: "1.0",
                data: orderEvent
            );

            await _eventGridClient.SendEventAsync(eventGridEvent);
            _logger.LogInformation("Published event {EventType} for order {OrderId}", 
                orderEvent.EventType, id);

            return Accepted(orderEvent);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error publishing event for order {OrderId}", id);
            return StatusCode(500, new { error = ex.Message });
        }
    }

    /// <summary>
    /// Send order status update to Service Bus topic
    /// </summary>
    [HttpPost("{id}/status")]
    public async Task<IActionResult> UpdateOrderStatus(string id, [FromBody] string status)
    {
        try
        {
            if (_serviceBusClient == null)
            {
                return BadRequest(new { error = "Service Bus client not configured" });
            }

            var statusUpdate = new
            {
                OrderId = id,
                Status = status,
                Timestamp = DateTime.UtcNow
            };

            var sender = _serviceBusClient.CreateSender("order-topic");
            var message = new ServiceBusMessage(JsonSerializer.Serialize(statusUpdate))
            {
                ContentType = "application/json",
                Subject = "OrderStatusUpdate",
                CorrelationId = Guid.NewGuid().ToString()
            };

            await sender.SendMessageAsync(message);
            _logger.LogInformation("Status update sent for order {OrderId}: {Status}", id, status);

            return Accepted(statusUpdate);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error updating status for order {OrderId}", id);
            return StatusCode(500, new { error = ex.Message });
        }
    }
}
