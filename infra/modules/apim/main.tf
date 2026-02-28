resource "azurerm_api_management" "main" {
  name                = var.apim_name
  location            = var.location
  resource_group_name = var.resource_group_name
  publisher_name      = var.publisher_name
  publisher_email     = var.publisher_email

  sku_name = "Developer_1"

  # Enable Managed Identity
  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}

# API for Function App
resource "azurerm_api_management_api" "function_api" {
  name                = "order-api"
  resource_group_name = var.resource_group_name
  api_management_name = azurerm_api_management.main.name
  revision            = "1"
  display_name        = "Order API"
  path                = "orders"
  protocols           = ["https"]
  service_url         = var.function_app_url != null ? "https://${var.function_app_url}" : ""

  subscription_required = false
}

# Operation: Create Order
resource "azurerm_api_management_api_operation" "create_order" {
  operation_id        = "create-order"
  api_name            = azurerm_api_management_api.function_api.name
  api_management_name = azurerm_api_management.main.name
  resource_group_name = var.resource_group_name
  display_name        = "Create Order"
  method              = "POST"
  url_template        = "/create"

  response {
    status_code = 202
    description = "Accepted"
  }
}

# Policy for the API with rate limiting, caching, and correlation ID
resource "azurerm_api_management_api_policy" "function_api_policy" {
  api_name            = azurerm_api_management_api.function_api.name
  api_management_name = azurerm_api_management.main.name
  resource_group_name = var.resource_group_name

  xml_content = <<XML
<policies>
  <inbound>
    <base />
    <!-- Add CorrelationId header if not present -->
    <set-header name="X-Correlation-Id" exists-action="skip">
      <value>@(Guid.NewGuid().ToString())</value>
    </set-header>
    
    <!-- Rate limiting: 10 requests per minute -->
    <rate-limit calls="10" renewal-period="60" />
    
    <!-- Response caching for GET requests (if any) -->
    <cache-lookup vary-by-developer="false" vary-by-developer-groups="false" />
    
    <!-- Mock JWT validation (accept all for demo) -->
    <set-header name="Authorization" exists-action="skip">
      <value>Bearer demo-token</value>
    </set-header>
  </inbound>
  <backend>
    <base />
  </backend>
  <outbound>
    <base />
    <!-- Cache responses -->
    <cache-store duration="60" />
    
    <!-- Add correlation ID to response -->
    <set-header name="X-Correlation-Id" exists-action="override">
      <value>@(context.Request.Headers.GetValueOrDefault("X-Correlation-Id",""))</value>
    </set-header>
  </outbound>
  <on-error>
    <base />
  </on-error>
</policies>
XML
}
