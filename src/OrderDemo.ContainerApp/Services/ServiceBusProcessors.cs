using Azure.Messaging.ServiceBus;
using System.Text.Json;

namespace OrderDemo.ContainerApp.Services;

public class ServiceBusQueueProcessor : BackgroundService
{
    private readonly ILogger<ServiceBusQueueProcessor> _logger;
    private readonly ServiceBusClient? _serviceBusClient;
    private ServiceBusProcessor? _processor;

    public ServiceBusQueueProcessor(
        ILogger<ServiceBusQueueProcessor> logger,
        ServiceBusClient? serviceBusClient = null)
    {
        _logger = logger;
        _serviceBusClient = serviceBusClient;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        if (_serviceBusClient == null)
        {
            _logger.LogWarning("Service Bus client not configured, queue processor will not start");
            return;
        }

        _processor = _serviceBusClient.CreateProcessor("order-queue", new ServiceBusProcessorOptions
        {
            MaxConcurrentCalls = 5,
            AutoCompleteMessages = false,
            MaxAutoLockRenewalDuration = TimeSpan.FromMinutes(5)
        });

        _processor.ProcessMessageAsync += ProcessMessageAsync;
        _processor.ProcessErrorAsync += ProcessErrorAsync;

        _logger.LogInformation("Starting Service Bus queue processor");
        await _processor.StartProcessingAsync(stoppingToken);

        // Keep running until cancellation
        await Task.Delay(Timeout.Infinite, stoppingToken);
    }

    private async Task ProcessMessageAsync(ProcessMessageEventArgs args)
    {
        var correlationId = args.Message.CorrelationId ?? Guid.NewGuid().ToString();
        
        try
        {
            var body = args.Message.Body.ToString();
            _logger.LogInformation(
                "Processing queue message {MessageId} (CorrelationId: {CorrelationId})",
                args.Message.MessageId, correlationId);

            // Simulate order processing
            var order = JsonSerializer.Deserialize<JsonElement>(body);
            var orderId = order.GetProperty("OrderId").GetString();
            
            _logger.LogInformation("Processing order {OrderId}", orderId);
            
            // Simulate some work
            await Task.Delay(TimeSpan.FromSeconds(1));

            // Complete the message
            await args.CompleteMessageAsync(args.Message);
            _logger.LogInformation("Successfully processed order {OrderId}", orderId);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, 
                "Error processing message {MessageId} (CorrelationId: {CorrelationId}). Delivery count: {DeliveryCount}",
                args.Message.MessageId, correlationId, args.Message.DeliveryCount);

            // Dead-letter after 3 attempts
            if (args.Message.DeliveryCount >= 3)
            {
                await args.DeadLetterMessageAsync(args.Message, new Dictionary<string, object>
                {
                    { "Reason", "MaxDeliveryCountExceeded" },
                    { "ErrorMessage", ex.Message }
                });
            }
            else
            {
                // Abandon to retry
                await args.AbandonMessageAsync(args.Message);
            }
        }
    }

    private Task ProcessErrorAsync(ProcessErrorEventArgs args)
    {
        _logger.LogError(args.Exception,
            "Service Bus error from {EntityPath}. Error source: {ErrorSource}",
            args.EntityPath, args.ErrorSource);
        return Task.CompletedTask;
    }

    public override async Task StopAsync(CancellationToken stoppingToken)
    {
        if (_processor != null)
        {
            _logger.LogInformation("Stopping Service Bus queue processor");
            await _processor.StopProcessingAsync(stoppingToken);
            await _processor.DisposeAsync();
        }

        await base.StopAsync(stoppingToken);
    }
}

public class ServiceBusTopicProcessor : BackgroundService
{
    private readonly ILogger<ServiceBusTopicProcessor> _logger;
    private readonly ServiceBusClient? _serviceBusClient;
    private ServiceBusProcessor? _processor;

    public ServiceBusTopicProcessor(
        ILogger<ServiceBusTopicProcessor> logger,
        ServiceBusClient? serviceBusClient = null)
    {
        _logger = logger;
        _serviceBusClient = serviceBusClient;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        if (_serviceBusClient == null)
        {
            _logger.LogWarning("Service Bus client not configured, topic processor will not start");
            return;
        }

        _processor = _serviceBusClient.CreateProcessor("order-topic", "order-subscription", new ServiceBusProcessorOptions
        {
            MaxConcurrentCalls = 5,
            AutoCompleteMessages = false
        });

        _processor.ProcessMessageAsync += ProcessMessageAsync;
        _processor.ProcessErrorAsync += ProcessErrorAsync;

        _logger.LogInformation("Starting Service Bus topic processor");
        await _processor.StartProcessingAsync(stoppingToken);

        await Task.Delay(Timeout.Infinite, stoppingToken);
    }

    private async Task ProcessMessageAsync(ProcessMessageEventArgs args)
    {
        var correlationId = args.Message.CorrelationId ?? Guid.NewGuid().ToString();
        
        try
        {
            var body = args.Message.Body.ToString();
            _logger.LogInformation(
                "Processing topic message {MessageId} with subject {Subject} (CorrelationId: {CorrelationId})",
                args.Message.MessageId, args.Message.Subject, correlationId);

            var statusUpdate = JsonSerializer.Deserialize<JsonElement>(body);
            var orderId = statusUpdate.GetProperty("OrderId").GetString();
            var status = statusUpdate.GetProperty("Status").GetString();

            _logger.LogInformation("Order {OrderId} status updated to {Status}", orderId, status);

            await args.CompleteMessageAsync(args.Message);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, 
                "Error processing topic message {MessageId} (CorrelationId: {CorrelationId})",
                args.Message.MessageId, correlationId);

            if (args.Message.DeliveryCount >= 3)
            {
                await args.DeadLetterMessageAsync(args.Message, new Dictionary<string, object>
                {
                    { "Reason", "ProcessingError" },
                    { "ErrorMessage", ex.Message }
                });
            }
            else
            {
                await args.AbandonMessageAsync(args.Message);
            }
        }
    }

    private Task ProcessErrorAsync(ProcessErrorEventArgs args)
    {
        _logger.LogError(args.Exception,
            "Service Bus topic error from {EntityPath}. Error source: {ErrorSource}",
            args.EntityPath, args.ErrorSource);
        return Task.CompletedTask;
    }

    public override async Task StopAsync(CancellationToken stoppingToken)
    {
        if (_processor != null)
        {
            _logger.LogInformation("Stopping Service Bus topic processor");
            await _processor.StopProcessingAsync(stoppingToken);
            await _processor.DisposeAsync();
        }

        await base.StopAsync(stoppingToken);
    }
}
