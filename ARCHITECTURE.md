# Architecture Diagrams

## System Architecture (Mermaid)

```mermaid
graph TB
    Client[Client Application]
    
    subgraph APIM["API Management"]
        Gateway[Gateway<br/>Rate Limit: 10/min<br/>Caching<br/>Correlation ID]
    end
    
    subgraph ContainerApp["Azure Container App<br/>.NET 8 ASP.NET Core"]
        HTTP[OrdersController<br/>REST API Endpoints]
        Webhook[WebhooksController<br/>Event Grid Webhook]
        SBQ[ServiceBusQueueProcessor<br/>Background Service]
        SBT[ServiceBusTopicProcessor<br/>Background Service]
        Health[Health Endpoint<br/>/health]
    end
    
    subgraph ServiceBus["Service Bus Namespace"]
        Queue[Queue: order-queue<br/>DLQ Enabled<br/>Max Delivery: 10]
        Topic[Topic: order-topic]
        Sub[Subscription:<br/>order-subscription]
    end
    
    subgraph EventGrid["Event Grid"]
        EGTopic[Event Grid Topic<br/>Custom Events]
        EGSub[Webhook Subscription<br/>→ /api/webhooks/eventgrid]
    end
    
    KeyVault[Key Vault<br/>RBAC Enabled<br/>Stores Secrets]
    ACR[Azure Container Registry<br/>orderdemodevacr]
    LogAnalytics[Log Analytics<br/>Monitoring & Logs]
    
    Client -->|POST /orders/create| Gateway
    Gateway -->|Forward| HTTP
    
    HTTP -->|Send Message| Queue
    HTTP -->|Publish Message| Topic
    HTTP -->|Publish Event| EGTopic
    
    Queue -->|Pull Messages| SBQ
    Topic --> Sub
    Sub -->|Pull Messages| SBT
    EGTopic --> EGSub
    EGSub -->|POST Events| Webhook
    
    HTTP -.->|Read Secrets| KeyVault
    ContainerApp -.->|Pull Image| ACR
    ContainerApp -.->|Send Logs| LogAnalytics
    
    style Client fill:#e1f5ff
    style APIM fill:#fff4e1
    style ContainerApp fill:#e8f5e9
    style ServiceBus fill:#f3e5f5
    style EventGrid fill:#fce4ec
    style KeyVault fill:#fff9c4
    style ACR fill:#e0f2f1
    style LogAnalytics fill:#f3e5f5
```

## Event Flow Diagram

```mermaid
sequenceDiagram
    autonumber
    participant C as Client
    participant A as API Management
    participant CA as Container App<br/>(OrdersController)
    participant Q as Service Bus Queue
    participant T as Service Bus Topic
    participant E as Event Grid Topic
    participant P1 as Queue Processor<br/>(Background Service)
    participant P2 as Topic Processor<br/>(Background Service)
    participant W as Webhook Handler<br/>(WebhooksController)
    
    C->>A: POST /orders/create
    Note over A: Rate Limit Check<br/>Add X-Correlation-ID<br/>Cache Lookup
    A->>CA: Forward Request
    
    par Parallel Publishing
        CA->>Q: SendMessageAsync
        CA->>T: SendMessageAsync
        CA->>E: SendEventAsync
    end
    
    CA-->>A: 202 Accepted {orderId}
    A-->>C: Response
    
    Note over P1: Continuous Polling
    Q->>P1: ReceiveMessagesAsync
    Note over P1: Process Message<br/>Max 10 Retries<br/>1min Lock Duration
    P1->>P1: CompleteMessageAsync
    
    Note over P2: Continuous Polling
    T->>P2: ReceiveMessagesAsync
    Note over P2: Process Subscription
    P2->>P2: CompleteMessageAsync
    
    E->>W: POST /api/webhooks/eventgrid
    Note over W: Validate Subscription<br/>Process Event
    W-->>E: 200 OK
```

## Container App Architecture

```mermaid
graph TB
    subgraph Environment["Container App Environment"]
        subgraph App["Container App: orderdemo-dev-app"]
            subgraph Runtime["Runtime Container"]
                API[ASP.NET Core 8<br/>Web API]
                BG1[Background Service<br/>Queue Processor]
                BG2[Background Service<br/>Topic Processor]
            end
            
            subgraph Identity["Managed Identity"]
                MI[System Assigned<br/>Principal ID]
            end
        end
        
        Ingress[Ingress Controller<br/>HTTPS:443 → HTTP:8080]
        
        subgraph Probes["Health Probes"]
            Liveness[Liveness: /health]
            Readiness[Readiness: /health]
            Startup[Startup: /health]
        end
    end
    
    subgraph External["External Services"]
        SB[Service Bus<br/>order-queue<br/>order-topic]
        EG[Event Grid<br/>order-topic]
        KV[Key Vault<br/>Secrets]
        AppInsights[Application Insights<br/>Telemetry]
    end
    
    Ingress --> API
    API --> BG1
    API --> BG2
    
    Liveness -.-> API
    Readiness -.-> API
    Startup -.-> API
    
    MI -->|RBAC| SB
    MI -->|RBAC| EG
    MI -->|RBAC| KV
    
    API -.-> AppInsights
    BG1 -.-> AppInsights
    BG2 -.-> AppInsights
    
    style Environment fill:#e8f5e9
    style App fill:#c8e6c9
    style Runtime fill:#a5d6a7
    style Identity fill:#90caf9
    style Probes fill:#ffcc80
```

## Security & Access Flow

```mermaid
graph TB
    subgraph ContainerApp["Container App"]
        MI[Managed Identity<br/>System Assigned<br/>DefaultAzureCredential]
    end
    
    subgraph ServiceBus["Service Bus"]
        SB[Namespace<br/>order-queue<br/>order-topic]
    end
    
    subgraph EventGrid["Event Grid"]
        EGT[Topic<br/>Custom Events]
    end
    
    subgraph KeyVault["Key Vault"]
        KV[Secrets<br/>EventGridKey]
    end
    
    subgraph ACR["Container Registry"]
        Registry[orderdemodevacr<br/>Admin Enabled]
    end
    
    MI -->|Azure Service Bus<br/>Data Sender| SB
    MI -->|Azure Service Bus<br/>Data Receiver| SB
    MI -->|EventGrid<br/>Data Sender| EGT
    MI -->|Key Vault<br/>Secrets User| KV
    
    ContainerApp -.->|Pull with<br/>Admin Credentials| Registry
    
    style MI fill:#90caf9
    style SB fill:#ce93d8
    style EGT fill:#f48fb1
    style KV fill:#fff59d
    style Registry fill:#80deea
```

## Retry & Dead Letter Queue Flow

```mermaid
graph TD
    Msg[Message Arrives<br/>in Queue/Topic] --> Receive[Processor Receives<br/>via ReceiveMessagesAsync]
    Receive --> Process[Process Message<br/>in Background Service]
    Process -->|Success| Complete[CompleteMessageAsync<br/>Remove from Queue ✓]
    Process -->|Exception| Abandon[AbandonMessageAsync<br/>Increment DeliveryCount]
    
    Abandon --> Count{DeliveryCount<br/>< MaxDeliveryCount<br/>&#40;10&#41;?}
    
    Count -->|Yes| Wait[Message Reappears<br/>After Lock Duration<br/>&#40;1 minute&#41;]
    Wait --> Receive
    
    Count -->|No| DLQ[Automatic Move to<br/>Dead Letter Queue<br/>&#40;DLQ&#41;]
    
    DLQ --> Manual[Manual Processing<br/>or Investigation Required]
    
    style Complete fill:#c8e6c9
    style DLQ fill:#ffcdd2
    style Msg fill:#e1f5ff
    style Process fill:#fff9c4
    style Manual fill:#fff9c4
```

## Terraform Module Structure

```mermaid
graph TB
    Root[main.tf<br/>Root Configuration]
    
    Root --> RG[Module: resource_group<br/>Creates RG]
    Root --> CA[Module: container_app<br/>ACR + Container App + Environment]
    Root --> SB[Module: service_bus<br/>Queue + Topic + Subscription]
    Root --> EG[Module: event_grid<br/>Topic + Webhook Subscription]
    Root --> KV[Module: key_vault<br/>Store secrets]
    Root --> APIM[Module: apim<br/>API Gateway]
    
    RG --> |Provides| RGOut[name, location, id]
    CA --> |Provides| CAOut[principal_id<br/>for RBAC<br/>fqdn]
    
    SB --> |Uses| CAOut
    SB --> |Creates| RBAC1[RBAC: Data Sender<br/>Data Receiver]
    
    EG --> |Uses| CAOut
    EG --> |Creates| RBAC2[RBAC: Data Sender<br/>Webhook to Container App]
    
    KV --> |Uses| CAOut
    KV --> |Creates| RBAC3[RBAC: Secrets User]
    
    APIM --> |Uses| CAOut
    APIM --> |Configures| Backend[Backend: Container App URL]
    
    Root --> EnvVars[null_resource:<br/>Update Container App<br/>Environment Variables]
    EnvVars --> |Uses| SB
    EnvVars --> |Uses| EG
    EnvVars --> |Uses| KV
    
    style Root fill:#64b5f6
    style RG fill:#81c784
    style CA fill:#81c784
    style SB fill:#81c784
    style EG fill:#81c784
    style KV fill:#81c784
    style APIM fill:#81c784
    style EnvVars fill:#fff59d
```

## Component Interaction Matrix

| Component | Service Bus | Event Grid | Key Vault | APIM | ACR |
|-----------|-------------|------------|-----------|------|-----|
| **OrdersController** | ✓ Send | ✓ Publish | ✓ Read | Exposed via | - |
| **Queue Processor** | ✓ Receive | - | - | - | - |
| **Topic Processor** | ✓ Receive | - | - | - | - |
| **Webhooks Controller** | - | ✓ Subscribe | - | - | - |
| **Container App** | - | - | - | - | ✓ Pull Image |
| **Health Endpoint** | - | - | - | ✓ Health Probe | - |

## Technology Stack

```
┌─────────────────────────────────────────┐
│         Application Layer               │
├─────────────────────────────────────────┤
│  .NET 8 ASP.NET Core Web API            │
│  RESTful Controllers                    │
│  Background Services (IHostedService)   │
│  Swagger/OpenAPI Documentation          │
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│         Container Platform              │
├─────────────────────────────────────────┤
│  Azure Container Apps (v1)              │
│  Azure Container Registry (Basic)       │
│  Container App Environment              │
│  Managed Identity Integration           │
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│         Messaging Layer                 │
├─────────────────────────────────────────┤
│  Azure Service Bus (Standard)           │
│  - Queues with DLQ                      │
│  - Topics & Subscriptions               │
│  Azure Event Grid (Custom Topics)       │
│  - Webhook Event Delivery               │
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│         Security Layer                  │
├─────────────────────────────────────────┤
│  Managed Identity (System Assigned)     │
│  DefaultAzureCredential                 │
│  Azure Key Vault (RBAC)                 │
│  RBAC Role Assignments                  │
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│         API Gateway Layer               │
├─────────────────────────────────────────┤
│  Azure API Management (Developer)       │
│  - Rate Limiting (10 calls/min)         │
│  - Response Caching (60s)               │
│  - Correlation ID Injection             │
│  - Backend: Container App               │
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│         Observability Layer             │
├─────────────────────────────────────────┤
│  Application Insights                   │
│  Log Analytics Workspace                │
│  Container App Logs                     │
│  Health Probes (Liveness/Readiness)     │
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│         Infrastructure Layer            │
├─────────────────────────────────────────┤
│  Terraform v1.0+ (Module-based)         │
│  Azure Resource Manager                 │
│  PowerShell Deployment Scripts          │
└─────────────────────────────────────────┘
```

## Data Flow: Order Creation

```
1. Client Request
   └─> APIM Gateway (orderdemo-dev-apim.azure-api.net)
       ├─> Rate Limit Check (10 calls/min)
       ├─> Add X-Correlation-Id Header
       └─> Cache Lookup (60s)

2. Container App: OrdersController.CreateOrder
   └─> Parse Order JSON
       ├─> Validate OrderRequest
       │   ├─> customerName (required)
       │   ├─> totalAmount > 0
       │   └─> items array (not empty)
       └─> Generate Order
           ├─> orderId = Guid.NewGuid()
           ├─> status = "Created"
           └─> createdAt = UTC Now

3. Parallel Message Publishing
   ├─> Service Bus Queue (order-queue)
   │   └─> ServiceBusClient.SendMessageAsync
   │       ├─> Body: Order JSON
   │       ├─> MessageId: orderId
   │       └─> CorrelationId: X-Correlation-Id
   │       
   │   Background Processing:
   │   └─> ServiceBusQueueProcessor (IHostedService)
   │       └─> Continuous Polling
   │           ├─> ReceiveMessagesAsync (MaxMessages: 10)
   │           ├─> Process Message
   │           │   ├─> Success → CompleteMessageAsync
   │           │   └─> Error → AbandonMessageAsync
   │           └─> MaxDeliveryCount: 10 → Move to DLQ
   │
   ├─> Service Bus Topic (order-topic)
   │   └─> ServiceBusClient.SendMessageAsync
   │       └─> Subscription: order-subscription
   │       
   │   Background Processing:
   │   └─> ServiceBusTopicProcessor (IHostedService)
   │       └─> Continuous Polling
   │           ├─> ReceiveMessagesAsync
   │           ├─> Process Subscription Message
   │           └─> CompleteMessageAsync
   │
   └─> Event Grid (orderdemo-dev-eg-topic)
       └─> EventGridPublisherClient.SendEventAsync
           ├─> EventType: "OrderCreated"
           ├─> Subject: "orders/{orderId}"
           ├─> DataVersion: "1.0"
           └─> Data: Order Object
           
       Event Delivery:
       └─> Webhook Subscription
           └─> POST https://{container-app-fqdn}/api/webhooks/eventgrid
               ├─> WebhooksController.HandleEventGridEvent
               ├─> Validation: Handle SubscriptionValidation
               ├─> Process: Handle OrderCreated Event
               └─> Return: 200 OK

4. Response
   └─> 202 Accepted
       └─> {
             "orderId": "...",
             "customerName": "...",
             "totalAmount": 149.99,
             "status": "Created",
             "createdAt": "2024-..."
           }
```
