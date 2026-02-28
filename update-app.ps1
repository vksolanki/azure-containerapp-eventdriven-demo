# Just update configuration and restart
# .\update-app.ps1

# Build image first, then update configuration
# .\update-app.ps1 -BuildImage

# Update Container App with latest configuration
param(
    [switch]$BuildImage
)

$ErrorActionPreference = "Stop"

# Build and push image if requested
if ($BuildImage) {
    Write-Host "Building and pushing Docker image..." -ForegroundColor Cyan
    Push-Location src
    az acr build --registry orderdemodevacr --image orderdemo:latest --file Dockerfile . --platform linux
    Pop-Location
    Write-Host "Image build complete!" -ForegroundColor Green
}

# Get values from Terraform
Write-Host "Retrieving configuration from Terraform..." -ForegroundColor Cyan
Push-Location infra
$serviceBusNamespace = terraform output -raw servicebus_namespace
$eventGridEndpoint = terraform output -raw event_grid_endpoint
$keyVaultUri = terraform output -raw key_vault_uri
Pop-Location

# Update Container App
Write-Host "Updating Container App..." -ForegroundColor Cyan
$timestamp = Get-Date -Format "yyyyMMddHHmmss"

az containerapp update `
    --name orderdemo-dev-app `
    --resource-group orderdemo-dev-rg `
    --set-env-vars `
        "ServiceBusNamespace=$serviceBusNamespace.servicebus.windows.net" `
        "EventGridTopicEndpoint=$eventGridEndpoint" `
        "KeyVaultUri=$keyVaultUri" `
        "LAST_UPDATED=$timestamp"

Write-Host "Waiting for app to restart..." -ForegroundColor Cyan
Start-Sleep -Seconds 20

Write-Host "Streaming logs..." -ForegroundColor Cyan
az containerapp logs show `
    --name orderdemo-dev-app `
    --resource-group orderdemo-dev-rg `
    --tail 50 `
    --follow
