# Container Registry
resource "azurerm_container_registry" "acr" {
  name                = var.container_registry_name
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = "Basic"
  admin_enabled       = true

  tags = var.tags
}

# Build and push Docker image to ACR before Container App is created
resource "null_resource" "build_and_push_image" {
  triggers = {
    acr_id           = azurerm_container_registry.acr.id
    dockerfile_hash  = filemd5("${path.root}/../src/Dockerfile")
  }

  provisioner "local-exec" {
    command = <<-EOT
      Write-Host "Building and pushing Docker image to ACR..."
      az acr build `
        --registry ${azurerm_container_registry.acr.name} `
        --image ${var.image_name} `
        --file ../src/Dockerfile `
        ../src `
        --platform linux
      Write-Host "Image successfully pushed to ACR"
    EOT
    interpreter = ["PowerShell", "-Command"]
    working_dir = path.root
  }

  depends_on = [azurerm_container_registry.acr]
}

# Log Analytics Workspace for Container App Environment
resource "azurerm_log_analytics_workspace" "main" {
  name                = "${var.container_app_env_name}-logs"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = "PerGB2018"
  retention_in_days   = 30

  tags = var.tags
}

# Container App Environment
resource "azurerm_container_app_environment" "main" {
  name                       = var.container_app_env_name
  resource_group_name        = var.resource_group_name
  location                   = var.location
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  tags = var.tags
}

# Container App
resource "azurerm_container_app" "main" {
  name                         = var.container_app_name
  resource_group_name          = var.resource_group_name
  container_app_environment_id = azurerm_container_app_environment.main.id
  revision_mode                = "Single"

  identity {
    type = "SystemAssigned"
  }

  registry {
    server   = azurerm_container_registry.acr.login_server
    username = azurerm_container_registry.acr.admin_username
    password_secret_name = "acr-password"
  }

  secret {
    name  = "acr-password"
    value = azurerm_container_registry.acr.admin_password
  }

  template {
    min_replicas = 1
    max_replicas = 10

    container {
      name   = "orderdemo"
      image  = "${azurerm_container_registry.acr.login_server}/${var.image_name}"
      cpu    = 0.5
      memory = "1Gi"

      env {
        name  = "ASPNETCORE_ENVIRONMENT"
        value = "Production"
      }

      env {
        name  = "ASPNETCORE_URLS"
        value = "http://+:8080"
      }

      # These will be updated after other resources are created
      env {
        name  = "ServiceBusConnection__fullyQualifiedNamespace"
        value = ""
      }

      env {
        name  = "EventGridTopicEndpoint"
        value = ""
      }

      env {
        name  = "KeyVaultUri"
        value = ""
      }

      liveness_probe {
        transport = "HTTP"
        port      = 8080
        path      = "/health"
      }

      readiness_probe {
        transport = "HTTP"
        port      = 8080
        path      = "/health"
      }

      startup_probe {
        transport = "HTTP"
        port      = 8080
        path      = "/health"
      }
    }
  }

  ingress {
    external_enabled = true
    target_port      = 8080
    transport        = "http"

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  tags = var.tags

  depends_on = [null_resource.build_and_push_image]
}
