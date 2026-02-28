# Architecture Diagrams

## System Architecture (Mermaid)

```mermaid
graph TB
    Client[Client Application]
    
    subgraph APIM["API Management"]
        Gateway[Gateway<br/>Rate Limit: 10/min<br/>JWT Validation<br/>Caching]
    end
    
    subgraph Functions["Azure Function App<br/>.NET 8 Isolated"]
        HTTP[HTTP Trigger<br/>CreateOrder]
        SBQ[Service Bus Queue Trigger<br/>ProcessOrderQueue]
        SBT[Service Bus Topic Trigger<br/>ProcessOrderTopic]
        EG[Event Grid Trigger<br/>HandleOrderCreatedEvent]
        Timer[Timer Trigger<br/>SystemHeartbeat]
        Durable[Durable Orchestrator<br/>OrderProcessing]
        
        subgraph Activities["Activities"]
            A1[ValidateOrder]
            A2[ProcessPayment]
            A3[SendNotification]
        end
    end
    
    subgraph ServiceBus["Service Bus Namespace"]
        Queue[Queue: order-queue<br/>DLQ Enabled]
        Topic[Topic: order-topic]
        Sub[Subscription:<br/>order-subscription]
    end
    
    EventGrid[Event Grid Topic<br/>Custom Events]
    KeyVault[Key Vault<br/>RBAC Enabled]
    
    Client -->|POST /orders/create| Gateway
    Gateway -->|Forward| HTTP
    
    HTTP -->|Send Message| Queue
    HTTP -->|Publish Message| Topic
    HTTP -->|Publish Event| EventGrid
    
    Queue -->|Trigger| SBQ
    Topic --> Sub
    Sub -->|Trigger| SBT
    EventGrid -->|Trigger| EG
    
    Timer -.->|Every 5 min| EventGrid
    
    Durable --> A1
    A1 --> A2
    A2 --> A3
    
    HTTP -.->|Read Secrets| KeyVault
    
    style Client fill:#e1f5ff
    style APIM fill:#fff4e1
    style Functions fill:#e8f5e9
    style ServiceBus fill:#f3e5f5
    style EventGrid fill:#fce4ec
    style KeyVault fill:#fff9c4
```

## Event Flow Diagram

```mermaid
sequenceDiagram
    autonumber
    participant C as Client
    participant A as API Management
    participant F as CreateOrder Function
    participant Q as Service Bus Queue
    participant T as Service Bus Topic
    participant E as Event Grid
    participant P1 as Queue Processor
    participant P2 as Topic Processor
    participant P3 as Event Handler
    
    C->>A: POST /orders/create
    Note over A: Rate Limit Check<br/>Add Correlation-ID
    A->>F: Forward Request
    
    par Parallel Publishing
        F->>Q: Send Message
        F->>T: Publish to Topic
        F->>E: Publish Order.Created Event
    end
    
    F-->>A: 202 Accepted
    A-->>C: Response
    
    Q->>P1: Trigger ProcessOrderQueue
    Note over P1: Process with Retry<br/>Max 10 attempts
    
    T->>P2: Trigger ProcessOrderTopic
    Note over P2: Process Subscription Message
    
    E->>P3: Trigger HandleOrderCreatedEvent
    Note over P3: Handle Event Data
```

## Durable Orchestration Flow

```mermaid
graph LR
    Start[Start Orchestration] --> V[Validate Order]
    V -->|Success| P[Process Payment]
    V -->|Failure| End1[Return: ValidationFailed]
    P -->|Success| N[Send Notification]
    P -->|Retry| P
    P -->|Max Retries Failed| End2[Return: PaymentFailed]
    N --> End3[Return: Completed]
    
    style Start fill:#e8f5e9
    style End1 fill:#ffebee
    style End2 fill:#ffebee
    style End3 fill:#c8e6c9
    style V fill:#fff9c4
    style P fill:#fff9c4
    style N fill:#fff9c4
```

## Security & Access Flow

```mermaid
graph TB
    subgraph FunctionApp["Function App"]
        MI[Managed Identity<br/>System Assigned]
    end
    
    subgraph ServiceBus["Service Bus"]
        SB[Namespace]
    end
    
    subgraph EventGrid["Event Grid"]
        EGT[Topic]
    end
    
    subgraph KeyVault["Key Vault"]
        KV[Secrets]
    end
    
    MI -->|RBAC: Service Bus<br/>Data Sender/Receiver| SB
    MI -->|RBAC: EventGrid<br/>Data Sender| EGT
    MI -->|RBAC: Key Vault<br/>Secrets User| KV
    
    style MI fill:#90caf9
    style SB fill:#ce93d8
    style EGT fill:#f48fb1
    style KV fill:#fff59d
```

## Retry & DLQ Flow

```mermaid
graph TD
    Msg[Message Arrives] --> Process[Function Processes]
    Process -->|Success| Complete[Complete ✓]
    Process -->|Exception| Count{Delivery Count<br/>< 10?}
    Count -->|Yes| Retry[Re-queue Message<br/>Increment Count]
    Retry --> Wait[Wait Lock Duration<br/>1 minute]
    Wait --> Process
    Count -->|No| DLQ[Move to Dead Letter Queue]
    
    style Complete fill:#c8e6c9
    style DLQ fill:#ffcdd2
    style Msg fill:#e1f5ff
    style Process fill:#fff9c4
```

## Terraform Module Structure

```mermaid
graph TB
    Root[main.tf<br/>Root Configuration]
    
    Root --> RG[Module: resource_group]
    Root --> FA[Module: function_app]
    Root --> SB[Module: service_bus]
    Root --> EG[Module: event_grid]
    Root --> KV[Module: key_vault]
    Root --> APIM[Module: apim]
    
    RG --> |Provides| RGOut[Resource Group<br/>Name & Location]
    FA --> |Provides| FAOut[Principal ID<br/>for RBAC]
    SB --> |Uses| FAOut
    EG --> |Uses| FAOut
    KV --> |Uses| FAOut
    
    style Root fill:#64b5f6
    style RG fill:#81c784
    style FA fill:#81c784
    style SB fill:#81c784
    style EG fill:#81c784
    style KV fill:#81c784
    style APIM fill:#81c784
```

## Component Interaction Matrix

| Component | Service Bus | Event Grid | Key Vault | APIM |
|-----------|-------------|------------|-----------|------|
| **HTTP Trigger** | ✓ Send | ✓ Publish | ✓ Read | Exposed via |
| **Queue Trigger** | ✓ Receive | - | - | - |
| **Topic Trigger** | ✓ Receive | - | - | - |
| **Event Grid Trigger** | - | ✓ Subscribe | - | - |
| **Timer Trigger** | - | ✓ Publish | - | - |
| **Durable Orchestrator** | - | - | - | - |

## Technology Stack

```
┌─────────────────────────────────────────┐
│         Application Layer               │
├─────────────────────────────────────────┤
│  .NET 8 (Isolated Worker)               │
│  Azure Functions v4                     │
│  Durable Functions                      │
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│         Messaging Layer                 │
├─────────────────────────────────────────┤
│  Azure Service Bus (Standard)           │
│  Azure Event Grid (Custom Topics)       │
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│         Security Layer                  │
├─────────────────────────────────────────┤
│  Managed Identity (System Assigned)     │
│  Azure Key Vault (RBAC)                 │
│  RBAC Role Assignments                  │
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│         API Gateway Layer               │
├─────────────────────────────────────────┤
│  Azure API Management (Developer)       │
│  - Rate Limiting                        │
│  - Caching                              │
│  - Security Policies                    │
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│         Infrastructure Layer            │
├─────────────────────────────────────────┤
│  Terraform v1.0+ (Module-based)         │
│  Azure Resource Manager                 │
└─────────────────────────────────────────┘
```

## Data Flow: Order Creation

```
1. Client Request
   └─> APIM Gateway
       ├─> Rate Limit Check (10/min)
       ├─> Add X-Correlation-Id
       └─> Cache Lookup

2. Function: CreateOrder
   └─> Parse Order JSON
       ├─> Validate Input
       └─> Generate Correlation ID

3. Parallel Message Publishing
   ├─> Service Bus Queue
   │   └─> order-queue
   │       └─> Queue Trigger (ProcessOrderQueue)
   │           ├─> Process Order
   │           ├─> Retry on Failure (max 10)
   │           └─> DLQ if max retries exceeded
   │
   ├─> Service Bus Topic
   │   └─> order-topic
   │       └─> Subscription (order-subscription)
   │           └─> Topic Trigger (ProcessOrderTopic)
   │
   └─> Event Grid
       └─> Custom Topic
           └─> Event (Order.Created)
               └─> Event Grid Trigger

4. Response
   └─> 202 Accepted
       └─> { orderId, correlationId }
```
