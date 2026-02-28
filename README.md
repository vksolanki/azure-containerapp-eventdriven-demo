Collecting workspace information# Azure Container Apps Order Demo - Complete Setup Guide

This guide provides step-by-step instructions for deploying and testing the Azure Container Apps Order Demo application.

## 📋 Prerequisites

### Required Software
1. **Azure CLI** (v2.50+)
   ```powershell
   az --version
   ```
   Install: https://aka.ms/azure-cli

2. **Terraform** (v1.0+)
   ```powershell
   terraform --version
   ```
   Install: https://www.terraform.io/downloads

3. **Docker Desktop**
   ```powershell
   docker --version
   ```
   Install: https://www.docker.com/get-started

4. **.NET 8 SDK**
   ```powershell
   dotnet --version  # Should show 8.x.x
   ```
   Install: https://dotnet.microsoft.com/download/dotnet/8.0

### Azure Requirements
- Active Azure subscription with Contributor or Owner role
- Sufficient quota for Container Apps resources

---

## 🚀 Deployment Instructions

### Step 1: Azure Login & Subscription Setup

```powershell
# Login to Azure
az login

# List available subscriptions
az account list --output table

# Set your active subscription
az account set --subscription "<your-subscription-id-or-name>"

# Verify current subscription
az account show --query "{Name:name, SubscriptionId:id}" --output table
```

### Step 2: Register Azure Resource Providers

```powershell
# Register required providers (one-time setup)
az provider register --namespace Microsoft.App
az provider register --namespace Microsoft.OperationalInsights
az provider register --namespace Microsoft.ContainerRegistry
az provider register --namespace Microsoft.ServiceBus
az provider register --namespace Microsoft.EventGrid
az provider register --namespace Microsoft.KeyVault
az provider register --namespace Microsoft.ApiManagement

# Check registration status (may take 2-3 minutes)
az provider show -n Microsoft.App --query "registrationState"
az provider show -n Microsoft.OperationalInsights --query "registrationState"
az provider show -n Microsoft.ContainerRegistry --query "registrationState"
```

Wait until all providers show `"Registered"` status.

---

### Step 3: Configure Terraform Variables (Optional)

Navigate to the project root and customize variables if needed:

```powershell
cd infra

# Edit terraform.tfvars to customize settings
notepad terraform.tfvars
```

**Key variables you can customize:**
- `project_name`: Prefix for all resource names (default: "orderdemo")
- `environment`: Environment identifier (default: "dev")
- `location`: Azure region (default: "uksouth")
- `apim_publisher_email`: Your email address for APIM

Leave defaults for quick start.

---

### Step 4: Initialize Terraform

```powershell
# Ensure you're in the infra directory
cd infra

# Initialize Terraform (downloads providers and sets up modules)
terraform init

# If you see providers already initialized, optionally upgrade them
terraform init -upgrade
```

**Expected output:**
```
Initializing modules...
Initializing the backend...
Initializing provider plugins...
Terraform has been successfully initialized!
```

---

### Step 5: Plan Infrastructure Deployment

```powershell
# Create an execution plan
terraform plan -out=tfplan

# Review the plan output carefully
# Should show ~35-40 resources to be created
```

**Resources to be created:**
- Resource Group
- Container Registry (ACR)
- Container App Environment
- Container App
- Log Analytics Workspace
- Service Bus Namespace (queue + topic + subscription)
- Event Grid Topic
- Key Vault
- API Management (Developer tier)
- RBAC role assignments
- Secrets in Key Vault

---

### Step 6: Build and Push Container Image

Before applying Terraform, build and push the Docker image to ACR:

```powershell
# Return to project root
cd ..

# Build and tag the Docker image locally (optional - for testing)
docker build -t orderdemo:latest -f src/Dockerfile src/

# Get ACR name from your terraform.tfvars
# Format: {project_name}{environment}acr (e.g., "orderdemodevacr")
$acrName = "orderdemodevacr"  # Adjust if you changed project_name/environment

# Build and push directly to ACR using Azure CLI
cd src
az acr build `
    --registry $acrName `
    --image orderdemo:latest `
    --file Dockerfile `
    . `
    --platform linux

cd ..
```

**Note:** If ACR doesn't exist yet, run Terraform apply first (Step 7), then come back to this step.

---

### Step 7: Apply Terraform Configuration

```powershell
# Navigate back to infra directory
cd infra

# Apply the Terraform plan
terraform apply tfplan

# Type 'yes' when prompted to confirm
```

**⏱️ Deployment Time:** 15-20 minutes (APIM provisioning takes the longest)

**Expected output:**
```
Apply complete! Resources: 35 added, 0 changed, 0 destroyed.

Outputs:
apim_gateway_url = "https://orderdemo-dev-apim.azure-api.net"
container_app_fqdn = "orderdemo-dev-app.xxx.azurecontainerapps.io"
container_app_name = "orderdemo-dev-app"
container_app_url = "https://orderdemo-dev-app.xxx.azurecontainerapps.io"
...
```

---

### Step 8: Save Terraform Outputs

```powershell
# Save outputs to a file for reference
terraform output > outputs.txt

# Or view specific outputs
terraform output container_app_url
terraform output apim_gateway_url
terraform output servicebus_namespace
terraform output key_vault_name
```

---

### Step 9: Update Container App Environment Variables

The Container App needs environment variables configured. Run this after infrastructure is deployed:

```powershell
# Get values from Terraform outputs
$containerAppName = terraform output -raw container_app_name
$resourceGroupName = terraform output -raw resource_group_name
$serviceBusNamespace = terraform output -raw servicebus_namespace
$eventGridEndpoint = terraform output -raw event_grid_endpoint
$keyVaultUri = terraform output -raw key_vault_uri

# Update Container App with environment variables
az containerapp update `
    --name $containerAppName `
    --resource-group $resourceGroupName `
    --set-env-vars `
        "ServiceBusConnection__fullyQualifiedNamespace=$serviceBusNamespace.servicebus.windows.net" `
        "EventGridTopicEndpoint=$eventGridEndpoint" `
        "KeyVaultUri=$keyVaultUri"
```

**Alternative:** The deploy-containerapp.ps1 script automates steps 6-9.

---

## 🧪 Testing the Application

### Test 1: Health Check

```powershell
# Get Container App URL
cd infra
$appUrl = terraform output -raw container_app_url

# Test health endpoint
Invoke-RestMethod -Uri "$appUrl/health" -Method GET

# Expected response:
# @{status=Healthy; timestamp=2024-...}
```

---

### Test 2: Create an Order (API Test)

```powershell
# Create test order payload
$order = @{
    customerName = "John Doe"
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

# POST to orders endpoint
$response = Invoke-RestMethod -Uri "$appUrl/api/orders" `
    -Method POST `
    -Body $order `
    -ContentType "application/json"

# View response
$response

# Expected response:
# @{orderId=...; customerName=John Doe; totalAmount=149.99; status=Created; createdAt=...}
```

---

### Test 3: Test via API Management (with Rate Limiting)

```powershell
# Get APIM URL
$apimUrl = terraform output -raw apim_gateway_url

# Call through APIM (no auth required in this demo config)
$response = Invoke-RestMethod -Uri "$apimUrl/orders/create" `
    -Method POST `
    -Body $order `
    -ContentType "application/json" `
    -Headers @{"X-Correlation-Id"="TEST-APIM-001"}

$response
```

---

### Test 4: Access Swagger UI

```powershell
# Get Container App URL
$swaggerUrl = "$appUrl/swagger"

# Open in browser
Start-Process $swaggerUrl
```

---

### Test 5: Verify Service Bus Message Processing

```powershell
# Create an order (triggers queue message)
Invoke-RestMethod -Uri "$appUrl/api/orders" `
    -Method POST `
    -Body $order `
    -ContentType "application/json"

# View Container App logs to see message processing
az containerapp logs show `
    --name $containerAppName `
    --resource-group $resourceGroupName `
    --tail 50 `
    --follow
```

**Expected log output:**
```
OrderDemo.ContainerApp.Services.ServiceBusQueueProcessor: Processing order from queue: ORD-...
OrderDemo.ContainerApp.Services.ServiceBusTopicProcessor: Processing order from topic: ORD-...
```

---

### Test 6: Run Automated Test Script

```powershell
# Return to project root
cd ..

# Run the test script
.\test-containerapp.ps1

# Or specify URL manually
.\test-containerapp.ps1 -ContainerAppUrl "https://your-app.azurecontainerapps.io"
```

**Test script validates:**
- ✅ Health endpoint
- ✅ Create order API
- ✅ Get order by ID
- ✅ List all orders
- ✅ Swagger UI accessibility

---

## 📊 Monitoring & Logs

### View Container App Logs

```powershell
# View recent logs
az containerapp logs show `
    --name orderdemo-dev-app `
    --resource-group orderdemo-dev-rg `
    --tail 50

# Stream logs in real-time
az containerapp logs show `
    --name orderdemo-dev-app `
    --resource-group orderdemo-dev-rg `
    --follow
```

---

### View Application Insights

```powershell
# Open Container App in Azure Portal
$containerAppName = terraform output -raw container_app_name
$resourceGroupName = terraform output -raw resource_group_name

az containerapp show `
    --name $containerAppName `
    --resource-group $resourceGroupName `
    --query "properties.managedEnvironmentId"

# Navigate to Azure Portal → Container App → Monitoring → Logs
```

---

### Query Service Bus Metrics

```powershell
# Get Service Bus namespace
$sbNamespace = terraform output -raw servicebus_namespace

# View queue metrics
az servicebus queue show `
    --namespace-name $sbNamespace `
    --resource-group orderdemo-dev-rg `
    --name order-queue `
    --query "{ActiveMessages:countDetails.activeMessageCount, DeadLetters:countDetails.deadLetterMessageCount}"
```

---

## 🔄 Update & Redeploy

### Rebuild and Redeploy Container Image

```powershell
# Make code changes in src/OrderDemo.ContainerApp

# Rebuild and push to ACR
cd src
$acrName = terraform output -raw container_registry_login_server
az acr build `
    --registry $acrName `
    --image orderdemo:latest `
    --file Dockerfile `
    . `
    --platform linux

# Force Container App to pull new image
cd ..\infra
$containerAppName = terraform output -raw container_app_name
$resourceGroupName = terraform output -raw resource_group_name

az containerapp revision restart `
    --name $containerAppName `
    --resource-group $resourceGroupName
```

---

### Update Infrastructure

```powershell
cd infra

# Modify Terraform files as needed

# Plan changes
terraform plan -out=tfplan

# Apply changes
terraform apply tfplan
```

---

## 🧹 Cleanup

### Destroy All Resources

```powershell
cd infra

# Destroy all resources
terraform destroy

# Type 'yes' when prompted
```

**⚠️ Warning:** This permanently deletes all resources and data.

---

### Destroy Specific Resources

```powershell
# Destroy only Container App
terraform destroy -target=module.container_app

# Destroy only APIM (to save costs during development)
terraform destroy -target=module.apim
```

---

## 🐛 Troubleshooting

### Issue: Container App Not Starting

```powershell
# Check Container App status
az containerapp show `
    --name orderdemo-dev-app `
    --resource-group orderdemo-dev-rg `
    --query "properties.runningStatus"

# View provisioning state
az containerapp show `
    --name orderdemo-dev-app `
    --resource-group orderdemo-dev-rg `
    --query "properties.provisioningState"

# Check logs for errors
az containerapp logs show `
    --name orderdemo-dev-app `
    --resource-group orderdemo-dev-rg `
    --tail 100
```

---

### Issue: ACR Image Pull Failures

```powershell
# Verify ACR credentials are configured
az containerapp show `
    --name orderdemo-dev-app `
    --resource-group orderdemo-dev-rg `
    --query "properties.configuration.registries"

# Check ACR admin is enabled
$acrName = terraform output -raw container_registry_login_server
az acr show --name $acrName --query "adminUserEnabled"
```

---

### Issue: Terraform Apply Fails

```powershell
# Check Azure provider registration
az provider show -n Microsoft.App --query "registrationState"

# Verify current subscription has required permissions
az account show --query "{Name:name, Role:user.assignedRoles}"

# Check for resource quota limits
az vm list-usage --location uksouth --output table
```

---

### Issue: Service Bus Connection Fails

```powershell
# Verify Managed Identity has correct RBAC roles
az role assignment list `
    --assignee <container-app-principal-id> `
    --scope /subscriptions/<sub-id>/resourceGroups/orderdemo-dev-rg

# Should include:
# - Azure Service Bus Data Sender
# - Azure Service Bus Data Receiver
```

---

## 📚 Additional Resources

- **Architecture Diagram:** See ARCHITECTURE.md
- **Quick Start:** See QUICKSTART.md
- **Detailed README:** See [README copy.md](README copy.md)
- **Deployment Script:** deploy-containerapp.ps1
- **Test Script:** test-containerapp.ps1

---

## 📝 Summary of Commands

### 🔧 Infrastructure Provisioning

```powershell
# 1. Login
az login
az account set --subscription "<your-subscription>"

# 2. Register providers
az provider register --namespace Microsoft.App
az provider register --namespace Microsoft.OperationalInsights
az provider register --namespace Microsoft.ContainerRegistry

# 3. Deploy infrastructure
cd infra
terraform init
terraform plan -out=tfplan
terraform apply tfplan
terraform output > outputs.txt

# 4. Build and push image
cd ../src
az acr build --registry orderdemodevacr --image orderdemo:latest --file Dockerfile . --platform linux

# 5. Configure Container App
cd ../infra
$containerAppName = terraform output -raw container_app_name
$resourceGroupName = terraform output -raw resource_group_name
$serviceBusNamespace = terraform output -raw servicebus_namespace
$eventGridEndpoint = terraform output -raw event_grid_endpoint
$keyVaultUri = terraform output -raw key_vault_uri

az containerapp update `
    --name $containerAppName `
    --resource-group $resourceGroupName `
    --set-env-vars `
        "ServiceBusConnection__fullyQualifiedNamespace=$serviceBusNamespace.servicebus.windows.net" `
        "EventGridTopicEndpoint=$eventGridEndpoint" `
        "KeyVaultUri=$keyVaultUri"
```

---

### 🧪 Testing Commands

```powershell
# Get app URL
$appUrl = terraform output -raw container_app_url

# Health check
Invoke-RestMethod -Uri "$appUrl/health"

# Create order
$order = @{customerName="Test"; totalAmount=99.99; items=@(@{productId="P001"; productName="Widget"; quantity=1; price=99.99})} | ConvertTo-Json
Invoke-RestMethod -Uri "$appUrl/api/orders" -Method POST -Body $order -ContentType "application/json"

# View logs
az containerapp logs show --name orderdemo-dev-app --resource-group orderdemo-dev-rg --tail 50

### 🔄 Update Container App (Windows)

To rebuild and update the container app image on Windows, run:

```powershell
.\update-app.ps1 -BuildImage
```

# Run test script another window
cd ..
.\test-containerapp.ps1
```

---

**🎉 You're all set! Your Azure Container Apps Order Demo is now deployed and ready for testing.**