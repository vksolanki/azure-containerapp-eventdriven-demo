# Build stage
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

# Copy csproj and restore dependencies
COPY ["OrderDemo.ContainerApp/OrderDemo.ContainerApp.csproj", "OrderDemo.ContainerApp/"]
RUN dotnet restore "OrderDemo.ContainerApp/OrderDemo.ContainerApp.csproj"

# Copy everything else and build
COPY . .
WORKDIR "/src/OrderDemo.ContainerApp"
RUN dotnet build "OrderDemo.ContainerApp.csproj" -c Release -o /app/build

# Publish stage
FROM build AS publish
RUN dotnet publish "OrderDemo.ContainerApp.csproj" -c Release -o /app/publish /p:UseAppHost=false

# Runtime stage
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS final
WORKDIR /app

# Create non-root user
RUN addgroup --system --gid 1001 containerapp && \
    adduser --system --uid 1001 --ingroup containerapp containerapp

COPY --from=publish /app/publish .

# Set user
USER containerapp

# Expose port
EXPOSE 8080

# Set environment variables
ENV ASPNETCORE_URLS=http://+:8080
ENV DOTNET_RUNNING_IN_CONTAINER=true

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD curl --fail http://localhost:8080/health || exit 1

ENTRYPOINT ["dotnet", "OrderDemo.ContainerApp.dll"]
