# ============================================================================
# Library System - Complete Setup Script
# ============================================================================
# This script handles the complete setup process:
#   1. Builds common-aspects library
#   2. Builds all microservices
#   3. Starts all services
#   4. Waits for services to be ready
#   5. Initializes dummy data (catalog and policy)
#   6. Creates and approves admin user
#
# Usage:
#   .\setup.ps1              # Full setup (build, start, initialize)
#   .\setup.ps1 -NoCache     # Build without cache
#   .\setup.ps1 -SkipBuild   # Skip build, just start and initialize
#   .\setup.ps1 -SkipInit    # Skip initialization (data and admin user)
# ============================================================================

param(
    [switch]$NoCache,      # Build without cache
    [switch]$SkipBuild,    # Skip build steps
    [switch]$SkipInit,     # Skip data initialization
    [switch]$SkipCommonAspects  # Skip common-aspects build
)

$ErrorActionPreference = "Stop"

# Get the script directory (docker-compose)
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $scriptDir

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Library System - Complete Setup      " -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Enable BuildKit for Docker builds
$env:DOCKER_BUILDKIT = "1"
$env:COMPOSE_DOCKER_CLI_BUILD = "1"

# ============================================================================
# STEP 1: Build common-aspects library
# ============================================================================
if (-not $SkipBuild -and -not $SkipCommonAspects) {
    Write-Host "[1/5] Building common-aspects library..." -ForegroundColor Yellow
    
    $commonAspectsPath = Join-Path $projectRoot "common-aspects"
    if (-not (Test-Path $commonAspectsPath)) {
        Write-Host "  [ERROR] common-aspects directory not found at $commonAspectsPath" -ForegroundColor Red
        exit 1
    }
    
    $buildCmd = "docker run --rm -v `"${commonAspectsPath}:/app`" -w /app maven:3.9-eclipse-temurin-17 mvn clean package -DskipTests -B"
    
    Write-Host "  Running: docker build..." -ForegroundColor Gray
    Invoke-Expression $buildCmd
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  [ERROR] Failed to build common-aspects!" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "  [OK] common-aspects built successfully" -ForegroundColor Green
    
    # Copy common-aspects jar to each service's libs directory
    $services = @("user-service", "auth-service", "catalog-service", "booking-service", "policy-service", "notification-service", "analytics-service")
    $jarPath = Join-Path $commonAspectsPath "target\common-aspects-1.0.0.jar"
    
    if (-not (Test-Path $jarPath)) {
        Write-Host "  [ERROR] common-aspects jar not found at $jarPath" -ForegroundColor Red
        exit 1
    }
    
    foreach ($service in $services) {
        $libsDir = Join-Path $projectRoot "${service}\libs"
        if (-not (Test-Path $libsDir)) {
            New-Item -ItemType Directory -Path $libsDir -Force | Out-Null
        }
        Copy-Item $jarPath $libsDir -Force | Out-Null
    }
    
    Write-Host "  [OK] Copied common-aspects jar to all service libs directories" -ForegroundColor Green
    Write-Host ""
}

# ============================================================================
# STEP 2: Build all services with docker-compose
# ============================================================================
if (-not $SkipBuild) {
    Write-Host "[2/5] Building all services with docker-compose..." -ForegroundColor Yellow
    
    Push-Location $scriptDir
    
    $composeCmd = "docker compose build --parallel"
    if ($NoCache) {
        $composeCmd = "docker compose build --parallel --no-cache"
    }
    
    Write-Host "  Running: $composeCmd" -ForegroundColor Gray
    Invoke-Expression $composeCmd
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  [ERROR] Failed to build services!" -ForegroundColor Red
        Pop-Location
        exit 1
    }
    
    Pop-Location
    Write-Host "  [OK] All services built successfully" -ForegroundColor Green
    Write-Host ""
}

# ============================================================================
# STEP 3: Start all services
# ============================================================================
Write-Host "[3/5] Starting all services..." -ForegroundColor Yellow

Push-Location $scriptDir
docker compose up -d
Pop-Location

if ($LASTEXITCODE -ne 0) {
    Write-Host "  [ERROR] Failed to start services!" -ForegroundColor Red
    exit 1
}

Write-Host "  [OK] Services started" -ForegroundColor Green
Write-Host ""

# ============================================================================
# STEP 4: Wait for services to be ready
# ============================================================================
Write-Host "[4/5] Waiting for services to be ready..." -ForegroundColor Yellow

$maxWaitTime = 120  # seconds
$waitInterval = 5   # seconds
$elapsed = 0
$apiBaseUrl = "http://localhost:8080"

Write-Host "  Waiting for API gateway to be available..." -ForegroundColor Gray
while ($elapsed -lt $maxWaitTime) {
    try {
        $response = Invoke-WebRequest -Uri "$apiBaseUrl/api/auth/health" -UseBasicParsing -TimeoutSec 3 -ErrorAction Stop
        if ($response.StatusCode -eq 200) {
            Write-Host "  [OK] API gateway is ready" -ForegroundColor Green
            break
        }
    } catch {
        # Service not ready yet, continue waiting
    }
    
    Start-Sleep -Seconds $waitInterval
    $elapsed += $waitInterval
    Write-Host "  Still waiting... ($elapsed/$maxWaitTime seconds)" -ForegroundColor Gray
}

if ($elapsed -ge $maxWaitTime) {
    Write-Host "  [WARN] Timeout waiting for services. They may still be starting." -ForegroundColor Yellow
    Write-Host "  You can check status with: docker compose ps" -ForegroundColor Gray
} else {
    # Give services a bit more time to fully initialize
    Write-Host "  Waiting additional 10 seconds for services to fully initialize..." -ForegroundColor Gray
    Start-Sleep -Seconds 10
}

Write-Host ""

# ============================================================================
# STEP 5: Initialize data and admin user
# ============================================================================
if (-not $SkipInit) {
    Write-Host "[5/5] Initializing data and admin user..." -ForegroundColor Yellow
    
    # Admin user configuration
    $adminUsername = "admin1"
    $adminEmail = "admin@gmail.com"
    $adminPassword = "12345678a"
    $adminRole = "ADMIN"
    $registerUrl = "$apiBaseUrl/api/auth/register"
    
    # Function to check if user exists
    function Test-AdminUserExists {
        $result = docker exec library-postgres psql -U postgres -d user_db -t -A -c "SELECT username FROM users WHERE username = '$adminUsername';" 2>&1
        return ($result -and $result.Trim() -eq $adminUsername)
    }
    
    # Function to approve user
    function Approve-AdminUser {
        Write-Host "  Approving admin user..." -ForegroundColor Gray
        $updateResult = docker exec library-postgres psql -U postgres -d user_db -c @"
UPDATE users 
SET pending_approval = false, 
    rejected = false, 
    restricted = false,
    updated_at = NOW()
WHERE username = '$adminUsername';
"@ | Out-Null
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "    [OK] User approved" -ForegroundColor Green
            return $true
        } else {
            Write-Host "    [ERROR] Failed to approve user" -ForegroundColor Red
            return $false
        }
    }
    
    # Function to delete user
    function Remove-AdminUser {
        Write-Host "  Removing existing admin user..." -ForegroundColor Gray
        docker exec library-postgres psql -U postgres -d user_db -c "DELETE FROM users WHERE username = '$adminUsername' OR email = '$adminEmail';" | Out-Null
        Start-Sleep -Seconds 1
    }
    
    # Function to create user via API
    function New-AdminUser {
        Write-Host "  Registering admin user via API..." -ForegroundColor Gray
        
        $userData = @{
            username = $adminUsername
            email = $adminEmail
            password = $adminPassword
            role = $adminRole
        } | ConvertTo-Json
        
        try {
            $response = Invoke-RestMethod -Uri $registerUrl -Method Post -Body $userData -ContentType "application/json" -ErrorAction Stop
            Write-Host "    [OK] User registered successfully" -ForegroundColor Green
            Start-Sleep -Seconds 2
            return $true
        } catch {
            $statusCode = $_.Exception.Response.StatusCode.value__
            
            if ($statusCode -eq 409) {
                Write-Host "    [WARN] User already exists, will approve existing user" -ForegroundColor Yellow
                return $true
            } else {
                Write-Host "    [ERROR] Registration failed: $($_.Exception.Message)" -ForegroundColor Red
                return $false
            }
        }
    }
    
    # 5.1: Initialize catalog data
    Write-Host "  Initializing catalog data..." -ForegroundColor Gray
    $catalogSqlFile = Join-Path $scriptDir "init-dummy-data-catalog.sql"
    if (Test-Path $catalogSqlFile) {
        docker cp $catalogSqlFile library-postgres:/tmp/init-dummy-data-catalog.sql | Out-Null
        docker exec -i library-postgres psql -U postgres -d catalog_db -f /tmp/init-dummy-data-catalog.sql | Out-Null
        Write-Host "    [OK] Catalog data initialized" -ForegroundColor Green
    } else {
        Write-Host "    [WARN] Catalog SQL file not found: $catalogSqlFile" -ForegroundColor Yellow
    }
    
    # 5.2: Initialize policy data
    Write-Host "  Initializing policy data..." -ForegroundColor Gray
    $policySqlFile = Join-Path $scriptDir "init-dummy-data-policy.sql"
    if (Test-Path $policySqlFile) {
        docker cp $policySqlFile library-postgres:/tmp/init-dummy-data-policy.sql | Out-Null
        docker exec -i library-postgres psql -U postgres -d policy_db -f /tmp/init-dummy-data-policy.sql | Out-Null
        Write-Host "    [OK] Policy data initialized" -ForegroundColor Green
    } else {
        Write-Host "    [WARN] Policy SQL file not found: $policySqlFile" -ForegroundColor Yellow
    }
    
    # 5.3: Create and approve admin user
    Write-Host "  Setting up admin user..." -ForegroundColor Gray
    
    # Delete existing user if it exists
    if (Test-AdminUserExists) {
        Remove-AdminUser
    }
    
    # Create user via API
    if (-not (New-AdminUser)) {
        Write-Host "    [ERROR] Failed to create admin user" -ForegroundColor Red
        Write-Host "    You can retry later with: .\setup-admin-user.ps1" -ForegroundColor Yellow
    } else {
        # Approve user
        if (-not (Approve-AdminUser)) {
            Write-Host "    [ERROR] Failed to approve admin user" -ForegroundColor Red
        } else {
            Write-Host "    [OK] Admin user created and approved" -ForegroundColor Green
        }
    }
    
    Write-Host ""
}

# ============================================================================
# Summary
# ============================================================================
Write-Host "========================================" -ForegroundColor Green
Write-Host "  Setup Complete!                      " -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

if (-not $SkipInit) {
    Write-Host "Admin Credentials:" -ForegroundColor Cyan
    Write-Host "  Username: admin1" -ForegroundColor White
    Write-Host "  Password: 12345678a" -ForegroundColor White
    Write-Host "  Email: admin@gmail.com" -ForegroundColor White
    Write-Host ""
}

Write-Host "Services:" -ForegroundColor Cyan
Write-Host "  API Gateway: http://localhost:8080" -ForegroundColor White
Write-Host "  RabbitMQ Management: http://localhost:15672 (admin/admin)" -ForegroundColor White
Write-Host ""

Write-Host "Useful commands:" -ForegroundColor Cyan
Write-Host "  docker compose ps              # Check service status" -ForegroundColor Gray
Write-Host "  docker compose logs -f         # View all logs" -ForegroundColor Gray
Write-Host "  docker compose down            # Stop all services" -ForegroundColor Gray
Write-Host "  .\check-services.ps1          # Check service health" -ForegroundColor Gray
Write-Host ""

