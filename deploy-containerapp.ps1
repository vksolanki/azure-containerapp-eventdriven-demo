# Azure Container Apps Deployment Script
# This script deploys the Order Demo application to Azure Container Apps

param(
    [Parameter(Mandatory=$false)]
    [string]$ResourceGroupName = "orderdemo-vs-dev-rg",
    
    [Parameter(Mandatory=$false)]
    [string]$Location = "UK South",
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipBuild
)

$ErrorActionPreference = "Stop"

Write-Host "====================================" -ForegroundColor Cyan
Write-Host " Azure Container Apps Deployment" -ForegroundColor Cyan
Write-Host "====================================" -ForegroundColor Cyan
Write-Host ""

# Check prerequisites
Write-Host "Checking prerequisites..." -ForegroundColor Yellow

# Check Azure CLI
try {
    $azVersion = az version --query '\"azure-cli\"' -o tsv
    Write-Host "✓ Azure CLI version: $azVersion" -ForegroundColor Green
} catch {
    Write-Error "Azure CLI is not installed. Please install from https://aka.ms/azure-cli"
    exit 1
}

# Check if logged in
try {
    $account = az account show 2>$null | ConvertFrom-Json
    Write-Host "✓ Logged in as: $($account.user.name)" -ForegroundColor Green
    Write-Host "✓ Subscription: $($account.name)" -ForegroundColor Green
} catch {
    Write-Error "Not logged in to Azure. Run 'az login' first."
    exit 1
}

# Check Terraform
try {
    $tfVersion = terraform version -json | ConvertFrom-Json | Select-Object -ExpandProperty terraform_version
    Write-Host "✓ Terraform version: $tfVersion" -ForegroundColor Green
} catch {
    Write-Error "Terraform is not installed. Please install from https://www.terraform.io/downloads"
    exit 1
}

# Check Docker
if (-not $SkipBuild) {
    try {
        $dockerVersion = docker --version
        Write-Host "✓ $dockerVersion" -ForegroundColor Green
    } catch {
        Write-Error "Docker is not installed. Please install from https://www.docker.com/get-started"
        exit 1
    }
}

Write-Host ""

# Register providers
Write-Host "Registering Azure providers..." -ForegroundColor Yellow
$providers = @(
    "Microsoft.App",
    "Microsoft.OperationalInsights", 
    "Microsoft.ServiceBus",
    "Microsoft.EventGrid",
    "Microsoft.ApiManagement",
    "Microsoft.KeyVault",
    "Microsoft.ContainerRegistry"
)

foreach ($provider in $providers) {
    $state = az provider show -n $provider --query "registrationState" -o tsv 2>$null
    if ($state -ne "Registered") {
        Write-Host "  Registering $provider..." -ForegroundColor Gray
        az provider register --namespace $provider --wait
    }
    Write-Host "✓ $provider" -ForegroundColor Green
}

Write-Host ""

# Create or get resource group
Write-Host "Creating resource group..." -ForegroundColor Yellow
az group create --name $ResourceGroupName --location $Location --output none
Write-Host "✓ Resource group: $ResourceGroupName" -ForegroundColor Green
Write-Host ""

# Build and push container image
if (-not $SkipBuild) {
    Write-Host "Building and pushing container image..." -ForegroundColor Yellow
    
    # Get ACR name (must be lowercase, no hyphens)
    $acrName = ($ResourceGroupName -replace "-", "").ToLower() -replace "rg$", "acr"
    Write-Host "  ACR Name: $acrName" -ForegroundColor Gray
    
    # Check if ACR exists, create if not
    $acrExists = az acr show --name $acrName --resource-group $ResourceGroupName 2>$null
    if (-not $acrExists) {
        Write-Host "  Creating Azure Container Registry..." -ForegroundColor Gray
        az acr create `
            --resource-group $ResourceGroupName `
            --name $acrName `
            --sku Basic `
            --admin-enabled true `
            --output none
    }
    
    # Build and push
    Write-Host "  Building image (this may take a few minutes)..." -ForegroundColor Gray
    Push-Location -Path "..\src"
    try {
        az acr build `
            --registry $acrName `
            --image orderdemo:latest `
            --file Dockerfile `
            . `
            --platform linux
    } finally {
        Pop-Location
    }
    
    Write-Host "✓ Container image built and pushed" -ForegroundColor Green
    Write-Host ""
}

# Deploy infrastructure with Terraform
Write-Host "Deploying infrastructure with Terraform..." -ForegroundColor Yellow

Push-Location -Path ".\infra"
try {
    # Initialize
    Write-Host "  Initializing Terraform..." -ForegroundColor Gray
    terraform init -upgrade
    
    # Plan
    Write-Host "  Creating execution plan..." -ForegroundColor Gray
    terraform plan -out=tfplan
    
    # Apply
    Write-Host "  Applying infrastructure changes..." -ForegroundColor Gray
    terraform apply tfplan
    
    Write-Host "✓ Infrastructure deployed" -ForegroundColor Green
} finally {
    Pop-Location
}

Write-Host ""

# Update Container App environment variables
Write-Host "Updating Container App configuration..." -ForegroundColor Yellow

$containerAppName = (terraform -chdir=.\infra output -raw container_app_name)
$serviceBusNamespace = (terraform -chdir=.\infra output -raw servicebus_namespace)
$eventGridEndpoint = (terraform -chdir=.\infra output -raw event_grid_endpoint)
$keyVaultUri = (terraform -chdir=.\infra output -raw key_vault_uri)

az containerapp update `
    --name $containerAppName `
    --resource-group $ResourceGroupName `
    --set-env-vars `
        "ServiceBusConnection__fullyQualifiedNamespace=$serviceBusNamespace.servicebus.windows.net" `
        "EventGridTopicEndpoint=$eventGridEndpoint" `
        "KeyVaultUri=$keyVaultUri" `
    --output none

Write-Host "✓ Container App configured" -ForegroundColor Green
Write-Host ""

# Get outputs
Write-Host "====================================" -ForegroundColor Cyan
Write-Host " Deployment Complete!" -ForegroundColor Cyan
Write-Host "====================================" -ForegroundColor Cyan
Write-Host ""

$appFqdn = (terraform -chdir=.\infra output -raw container_app_fqdn)
$apimGatewayUrl = (terraform -chdir=.\infra output -raw apim_gateway_url 2>$null)

Write-Host "Container App URL: https://$appFqdn" -ForegroundColor Green
Write-Host "API Endpoint: https://$appFqdn/api/orders" -ForegroundColor Green
Write-Host "Swagger UI: https://$appFqdn/swagger" -ForegroundColor Green
Write-Host "Health Check: https://$appFqdn/health" -ForegroundColor Green

if ($apimGatewayUrl) {
    Write-Host "APIM Gateway: $apimGatewayUrl" -ForegroundColor Green
}

Write-Host ""
Write-Host "To test the API:" -ForegroundColor Yellow
Write-Host "  Invoke-RestMethod -Uri 'https://$appFqdn/health'" -ForegroundColor Gray
Write-Host ""
Write-Host "To view logs:" -ForegroundColor Yellow
Write-Host "  az containerapp logs show --name $containerAppName --resource-group $ResourceGroupName --tail 50" -ForegroundColor Gray
Write-Host ""
