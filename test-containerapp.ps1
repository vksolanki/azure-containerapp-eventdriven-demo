# Test script for Container App Order Demo

param(
    [Parameter(Mandatory=$false)]
    [string]$ContainerAppUrl
)

$ErrorActionPreference = "Stop"

# Get Container App URL if not provided
if (-not $ContainerAppUrl) {
    try {
        Push-Location .\infra
        $fqdn = terraform output -raw container_app_fqdn
        Pop-Location
        $ContainerAppUrl = "https://$fqdn"
    } catch {
        Pop-Location
        Write-Error "Could not get Container App URL. Please provide it with -ContainerAppUrl parameter"
        exit 1
    }
}

Write-Host "====================================" -ForegroundColor Cyan
Write-Host " Testing Container App" -ForegroundColor Cyan
Write-Host "====================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Container App URL: $ContainerAppUrl" -ForegroundColor Yellow
Write-Host ""

# Test 1: Health Check
Write-Host "Test 1: Health Check" -ForegroundColor Cyan
try {
    $health = Invoke-RestMethod -Uri "$ContainerAppUrl/health" -Method GET
    Write-Host "[PASS] Health check passed" -ForegroundColor Green
    Write-Host "  Status: $($health.status)" -ForegroundColor Gray
} catch {
    Write-Host "[FAIL] Health check failed: $($_.Exception.Message)" -ForegroundColor Red
}
Write-Host ""

# Test 2: Create Order
Write-Host "Test 2: Create Order (POST /api/orders)" -ForegroundColor Cyan
$order = @{
    customerName = "Test Customer"
    totalAmount = 149.99
    items = @(
        @{
            productId = "PROD001"
            productName = "Azure Container Apps Guide"
            quantity = 1
            price = 149.99
        }
    )
} | ConvertTo-Json

try {
    $createdOrder = Invoke-RestMethod -Uri "$ContainerAppUrl/api/orders" -Method POST -Body $order -ContentType "application/json"
    Write-Host "[PASS] Order created successfully" -ForegroundColor Green
    Write-Host "  Order ID: $($createdOrder.orderId)" -ForegroundColor Gray
    Write-Host "  Customer: $($createdOrder.customerName)" -ForegroundColor Gray
    Write-Host "  Amount: `$$($createdOrder.totalAmount)" -ForegroundColor Gray
    $orderId = $createdOrder.orderId
} catch {
    Write-Host "[FAIL] Order creation failed: $($_.Exception.Message)" -ForegroundColor Red
    $orderId = $null
}
Write-Host ""

# Test 3: Get Order
if ($orderId) {
    Write-Host "Test 3: Get Order (GET /api/orders/$orderId)" -ForegroundColor Cyan
    try {
        $retrievedOrder = Invoke-RestMethod -Uri "$ContainerAppUrl/api/orders/$orderId" -Method GET
        Write-Host "[PASS] Order retrieved successfully" -ForegroundColor Green
        Write-Host "  Order ID: $($retrievedOrder.orderId)" -ForegroundColor Gray
        Write-Host "  Status: $($retrievedOrder.status)" -ForegroundColor Gray
    } catch {
        Write-Host "[FAIL] Order retrieval failed: $($_.Exception.Message)" -ForegroundColor Red
    }
    Write-Host ""
}

# Test 4: Publish Event to Event Grid
if ($orderId) {
    Write-Host "Test 4: Publish Event (POST /api/orders/$orderId/events)" -ForegroundColor Cyan
    $eventData = @{
        eventType = "OrderCreated"
        data = @{
            orderId = $orderId
            timestamp = (Get-Date).ToString("o")
        }
    } | ConvertTo-Json

    try {
        $result = Invoke-RestMethod -Uri "$ContainerAppUrl/api/orders/$orderId/events" -Method POST -Body $eventData -ContentType "application/json"
        Write-Host "[PASS] Event published successfully" -ForegroundColor Green
        Write-Host "  Event Type: $($result.eventType)" -ForegroundColor Gray
    } catch {
        Write-Host "[WARN] Event publishing failed (this may be expected if Event Grid is not configured)" -ForegroundColor Yellow
        Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Gray
    }
    Write-Host ""
}

# Test 5: Update Order Status via Service Bus Topic
if ($orderId) {
    Write-Host "Test 5: Update Status (POST /api/orders/$orderId/status)" -ForegroundColor Cyan
    $status = "Processing" | ConvertTo-Json

    try {
        $result = Invoke-RestMethod -Uri "$ContainerAppUrl/api/orders/$orderId/status" -Method POST -Body $status -ContentType "application/json"
        Write-Host "[PASS] Status update sent successfully" -ForegroundColor Green
        Write-Host "  New Status: $($result.Status)" -ForegroundColor Gray
    } catch {
        Write-Host "[WARN] Status update failed (this may be expected if Service Bus is not configured)" -ForegroundColor Yellow
        Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Gray
    }
    Write-Host ""
}

# Test 6: Swagger UI
Write-Host "Test 6: Swagger UI" -ForegroundColor Cyan
try {
    $swagger = Invoke-WebRequest -Uri "$ContainerAppUrl/swagger" -Method GET -UseBasicParsing
    if ($swagger.StatusCode -eq 200) {
        Write-Host "[PASS] Swagger UI is accessible" -ForegroundColor Green
        Write-Host "  URL: $ContainerAppUrl/swagger" -ForegroundColor Gray
    }
} catch {
    Write-Host "[FAIL] Swagger UI check failed: $($_.Exception.Message)" -ForegroundColor Red
}
Write-Host ""

Write-Host "====================================" -ForegroundColor Cyan
Write-Host " Testing Complete" -ForegroundColor Cyan
Write-Host "====================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "To view Container App logs:" -ForegroundColor Yellow
Write-Host "  az containerapp logs show --name <container-app-name> --resource-group <rg-name> --tail 50" -ForegroundColor Gray
Write-Host ""
