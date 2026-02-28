# Quick Start Deployment Script for Azure Serverless Order Demo
# Run this script from the project root directory

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Azure Serverless Order Demo - Quick Deploy" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check Prerequisites
Write-Host "Checking prerequisites..." -ForegroundColor Yellow

# Check Azure CLI
try {
    $azVersion = az version --query '\"azure-cli\"' -o tsv 2>$null
    Write-Host "✓ Azure CLI installed: $azVersion" -ForegroundColor Green
} catch {
    Write-Host "✗ Azure CLI not found. Please install: https://aka.ms/InstallAzureCLI" -ForegroundColor Red
    exit 1
}

# Check Terraform
try {
    $tfVersion = terraform version -json | ConvertFrom-Json | Select-Object -ExpandProperty terraform_version
    Write-Host "✓ Terraform installed: $tfVersion" -ForegroundColor Green
} catch {
    Write-Host "✗ Terraform not found. Please install: https://www.terraform.io/downloads" -ForegroundColor Red
    exit 1
}

# Check .NET SDK
try {
    $dotnetVersion = dotnet --version
    Write-Host "✓ .NET SDK installed: $dotnetVersion" -ForegroundColor Green
} catch {
    Write-Host "✗ .NET SDK not found. Please install: https://dotnet.microsoft.com/download" -ForegroundColor Red
    exit 1
}

# Check Azure Functions Core Tools
try {
    $funcVersion = func --version
    Write-Host "✓ Azure Functions Core Tools installed: $funcVersion" -ForegroundColor Green
} catch {
    Write-Host "✗ Azure Functions Core Tools not found. Please install: npm i -g azure-functions-core-tools@4" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "All prerequisites satisfied!" -ForegroundColor Green
Write-Host ""

# Azure Login
Write-Host "Step 1: Azure Login" -ForegroundColor Cyan
Write-Host "Checking Azure login status..."
$loginStatus = az account show 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "Not logged in. Initiating Azure login..." -ForegroundColor Yellow
    az login
} else {
    $accountInfo = $loginStatus | ConvertFrom-Json
    Write-Host "Already logged in as: $($accountInfo.user.name)" -ForegroundColor Green
    Write-Host "Subscription: $($accountInfo.name)" -ForegroundColor Green
    
    $continue = Read-Host "`nContinue with this subscription? (y/n)"
    if ($continue -ne 'y') {
        Write-Host "Run 'az account set --subscription <name>' to change subscription" -ForegroundColor Yellow
        exit 0
    }
}

Write-Host ""

# Deploy Infrastructure
Write-Host "Step 2: Deploy Infrastructure with Terraform" -ForegroundColor Cyan
Set-Location infra

if (-not (Test-Path ".terraform")) {
    Write-Host "Initializing Terraform..." -ForegroundColor Yellow
    terraform init
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Terraform init failed!" -ForegroundColor Red
        exit 1
    }
}

Write-Host "Planning infrastructure..." -ForegroundColor Yellow
terraform plan -out=tfplan
if ($LASTEXITCODE -ne 0) {
    Write-Host "Terraform plan failed!" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Ready to deploy infrastructure. This will create ~35 Azure resources." -ForegroundColor Yellow
Write-Host "Note: APIM provisioning takes 10-15 minutes." -ForegroundColor Yellow
$confirm = Read-Host "`nProceed with deployment? (yes/no)"

if ($confirm -eq 'yes') {
    Write-Host "Deploying infrastructure..." -ForegroundColor Yellow
    terraform apply tfplan
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Terraform apply failed!" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "✓ Infrastructure deployed successfully!" -ForegroundColor Green
    
    # Save outputs
    terraform output > outputs.txt
    Write-Host "✓ Outputs saved to infra/outputs.txt" -ForegroundColor Green
} else {
    Write-Host "Deployment cancelled." -ForegroundColor Yellow
    exit 0
}

Write-Host ""

# Get Terraform outputs
Write-Host "Retrieving deployment information..." -ForegroundColor Yellow
$functionAppName = terraform output -raw function_app_name
$resourceGroup = terraform output -raw resource_group_name
$apimUrl = terraform output -raw apim_order_api_url

Write-Host "Function App: $functionAppName" -ForegroundColor Cyan
Write-Host "Resource Group: $resourceGroup" -ForegroundColor Cyan
Write-Host "APIM URL: $apimUrl" -ForegroundColor Cyan

Write-Host ""

# Build and Deploy Function App
Write-Host "Step 3: Build and Deploy Function App" -ForegroundColor Cyan
Set-Location ..\src\OrderDemo.Functions

Write-Host "Restoring NuGet packages..." -ForegroundColor Yellow
dotnet restore

Write-Host "Building project..." -ForegroundColor Yellow
dotnet build --configuration Release

if ($LASTEXITCODE -ne 0) {
    Write-Host "Build failed!" -ForegroundColor Red
    exit 1
}

Write-Host "Publishing to Azure..." -ForegroundColor Yellow
func azure functionapp publish $functionAppName

if ($LASTEXITCODE -ne 0) {
    Write-Host "Publish failed!" -ForegroundColor Red
    exit 1
}

Write-Host "✓ Function App deployed successfully!" -ForegroundColor Green

Write-Host ""

# Event Grid Subscription Setup
Write-Host "Step 4: Event Grid Subscription" -ForegroundColor Cyan
Write-Host "Event Grid subscriptions need to be configured manually or via CLI." -ForegroundColor Yellow
Write-Host ""
Write-Host "Option 1 - Azure Portal:" -ForegroundColor Yellow
Write-Host "  1. Navigate to Event Grid Topic '$resourceGroup/orderdemo-dev-eg-topic'" -ForegroundColor Gray
Write-Host "  2. Create Event Subscription -> Name: 'order-events'" -ForegroundColor Gray
Write-Host "  3. Endpoint Type: Azure Function" -ForegroundColor Gray
Write-Host "  4. Select Function: HandleOrderCreatedEvent" -ForegroundColor Gray
Write-Host ""
Write-Host "Option 2 - Azure CLI (run manually):" -ForegroundColor Yellow
Write-Host "  See README.md for complete CLI commands" -ForegroundColor Gray

Write-Host ""

# Summary
Write-Host "========================================" -ForegroundColor Green
Write-Host "Deployment Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Resource Group: $resourceGroup" -ForegroundColor Cyan
Write-Host "Function App: $functionAppName" -ForegroundColor Cyan
Write-Host "APIM Gateway: $apimUrl" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "  1. Configure Event Grid subscription (see above)" -ForegroundColor White
Write-Host "  2. Test the API: POST $apimUrl" -ForegroundColor White
Write-Host "  3. View logs: func azure functionapp logstream $functionAppName" -ForegroundColor White
Write-Host ""
Write-Host "For detailed testing instructions, see README.md" -ForegroundColor Gray
Write-Host ""

# Return to root
Set-Location ..\..
