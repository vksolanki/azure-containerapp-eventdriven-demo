namespace OrderDemo.ContainerApp.Models;

public class Order
{
    public string OrderId { get; set; } = Guid.NewGuid().ToString();
    public string CustomerName { get; set; } = string.Empty;
    public decimal TotalAmount { get; set; }
    public DateTime OrderDate { get; set; } = DateTime.UtcNow;
    public string Status { get; set; } = "Pending";
    public List<OrderItem> Items { get; set; } = new();
}

public class OrderItem
{
    public string ProductId { get; set; } = string.Empty;
    public string ProductName { get; set; } = string.Empty;
    public int Quantity { get; set; }
    public decimal Price { get; set; }
}

public class OrderEvent
{
    public string EventType { get; set; } = string.Empty;
    public string OrderId { get; set; } = string.Empty;
    public DateTime Timestamp { get; set; } = DateTime.UtcNow;
    public string CorrelationId { get; set; } = Guid.NewGuid().ToString();
    public Dictionary<string, object> Data { get; set; } = new();
}

public class HealthCheckResponse
{
    public string Status { get; set; } = "Healthy";
    public DateTime Timestamp { get; set; } = DateTime.UtcNow;
    public Dictionary<string, string> Dependencies { get; set; } = new();
}
