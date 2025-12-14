# ============================================================================
# Complete Setup Script for Library Booking System
# ============================================================================
# This script performs a complete setup:
#   1. Checks if Docker is running
#   2. Rebuilds all services
#   3. Starts all services
#   4. Waits for services to be ready
#   5. Initializes dummy data
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File setup-complete.ps1
#
# Run this from the docker-compose directory
# ============================================================================

$ErrorActionPreference = "Continue"

# Initialize tracking variables
$script:stepResults = @{}
$script:errors = @()
$script:overallSuccess = $true

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Library Booking System - Complete Setup" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Check if Docker is running
Write-Host "Step 1: Checking Docker..." -ForegroundColor Yellow
try {
    $dockerVersion = docker --version 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Docker command failed"
    }
    Write-Host "  [OK] Docker is installed: $dockerVersion" -ForegroundColor Green
    
    # Check if Docker daemon is running
    $null = docker info 2>&1
    if ($LASTEXITCODE -ne 0) {
        $errorMsg = "Docker daemon is not running"
        $script:errors += "Step 1: $errorMsg"
        $script:stepResults["Step 1: Docker Check"] = "FAILED"
        $script:overallSuccess = $false
        Write-Host "  [ERROR] $errorMsg" -ForegroundColor Red
        Write-Host ""
        Write-Host "Please start Docker Desktop and try again." -ForegroundColor Yellow
        exit 1
    }
    Write-Host "  [OK] Docker daemon is running" -ForegroundColor Green
    $script:stepResults["Step 1: Docker Check"] = "SUCCESS"
} catch {
    $errorMsg = "Docker is not installed or not accessible"
    $script:errors += "Step 1: $errorMsg"
    $script:stepResults["Step 1: Docker Check"] = "FAILED"
    $script:overallSuccess = $false
    Write-Host "  [ERROR] $errorMsg" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please install Docker Desktop from: https://www.docker.com/get-started" -ForegroundColor Yellow
    exit 1
}

Write-Host ""

# Step 2: Stop existing containers (if any)
Write-Host "Step 2: Stopping existing containers..." -ForegroundColor Yellow
try {
    docker compose down 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  [OK] Done" -ForegroundColor Green
        $script:stepResults["Step 2: Stop Containers"] = "SUCCESS"
    } else {
        $script:stepResults["Step 2: Stop Containers"] = "WARNING"
    }
} catch {
    $script:stepResults["Step 2: Stop Containers"] = "WARNING"
}
Write-Host ""

# Step 3: Rebuild all services
Write-Host "Step 3: Rebuilding all services (this may take several minutes)..." -ForegroundColor Yellow
Write-Host "  This will rebuild all microservices and the API gateway..." -ForegroundColor Gray

# Try building with cache first
$buildSuccess = $false
try {
    Write-Host "  Attempting build with cache..." -ForegroundColor Gray
    docker compose build 2>&1 | ForEach-Object {
        $line = $_
        if ($line -match "ERROR|error|Error|FAILED|Failed|failed to solve|parent snapshot.*does not exist") {
            Write-Host "  [WARN] $line" -ForegroundColor Yellow
            if ($line -match "parent snapshot.*does not exist") {
                $script:buildCacheIssue = $true
            }
        } else {
            Write-Host "  $line" -ForegroundColor Gray
        }
    }
    
    if ($LASTEXITCODE -eq 0) {
        $buildSuccess = $true
        Write-Host "  [OK] All services rebuilt successfully" -ForegroundColor Green
        $script:stepResults["Step 3: Rebuild Services"] = "SUCCESS"
    } else {
        $script:stepResults["Step 3: Rebuild Services"] = "FAILED"
        $script:errors += "Step 3: Build failed with cache"
    }
} catch {
    Write-Host "  [WARN] Build with cache had issues" -ForegroundColor Yellow
    $script:stepResults["Step 3: Rebuild Services"] = "FAILED"
    $script:errors += "Step 3: Build with cache had issues"
}

# If build failed due to cache issues, prune cache and retry
if (-not $buildSuccess -or $buildCacheIssue) {
    Write-Host "  Build cache issue detected. Pruning Docker build cache..." -ForegroundColor Yellow
    docker builder prune -f 2>&1 | Out-Null
    Write-Host "  Retrying build without cache..." -ForegroundColor Gray
    
    try {
        docker compose build --no-cache 2>&1 | ForEach-Object {
            $line = $_
            if ($line -match "ERROR|error|Error|FAILED|Failed") {
                Write-Host "  [WARN] $line" -ForegroundColor Yellow
            } else {
                Write-Host "  $line" -ForegroundColor Gray
            }
        }
        
        if ($LASTEXITCODE -ne 0) {
            $errorMsg = "Build failed even after cache prune"
            $script:errors += "Step 3: $errorMsg"
            $script:stepResults["Step 3: Rebuild Services"] = "FAILED"
            $script:overallSuccess = $false
            Write-Host "  [ERROR] $errorMsg. Check the output above for errors." -ForegroundColor Red
            Write-Host "  You may need to manually run: docker builder prune -af" -ForegroundColor Yellow
            exit 1
        }
        Write-Host "  [OK] All services rebuilt successfully (after cache prune)" -ForegroundColor Green
        $script:stepResults["Step 3: Rebuild Services"] = "SUCCESS"
    } catch {
        $errorMsg = "Build failed even after cache prune"
        $script:errors += "Step 3: $errorMsg"
        $script:stepResults["Step 3: Rebuild Services"] = "FAILED"
        $script:overallSuccess = $false
        Write-Host "  [ERROR] $errorMsg. Check the output above for errors." -ForegroundColor Red
        Write-Host "  You may need to manually run: docker builder prune -af" -ForegroundColor Yellow
        exit 1
    }
}

Write-Host ""

# Step 4: Start all services
Write-Host "Step 4: Starting all services..." -ForegroundColor Yellow
try {
    docker compose up -d 2>&1 | ForEach-Object {
        Write-Host "  $_" -ForegroundColor Gray
    }
    
    if ($LASTEXITCODE -ne 0) {
        $errorMsg = "Failed to start services"
        $script:errors += "Step 4: $errorMsg"
        $script:stepResults["Step 4: Start Services"] = "FAILED"
        $script:overallSuccess = $false
        Write-Host "  [ERROR] $errorMsg" -ForegroundColor Red
        exit 1
    }
    Write-Host "  [OK] Services started" -ForegroundColor Green
    $script:stepResults["Step 4: Start Services"] = "SUCCESS"
} catch {
    $errorMsg = "Failed to start services: $($_.Exception.Message)"
    $script:errors += "Step 4: $errorMsg"
    $script:stepResults["Step 4: Start Services"] = "FAILED"
    $script:overallSuccess = $false
    Write-Host "  [ERROR] Failed to start services" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Step 5: Wait for services to be ready
Write-Host "Step 5: Waiting for services to be ready..." -ForegroundColor Yellow
Write-Host "  Waiting for infrastructure services (PostgreSQL, Redis, RabbitMQ)..." -ForegroundColor Gray
Start-Sleep -Seconds 15

Write-Host "  Waiting for microservices to start and create database tables..." -ForegroundColor Gray
Start-Sleep -Seconds 30

# Check if services are running
Write-Host "  Checking service status..." -ForegroundColor Gray
$serviceCheckSuccess = $false
try {
    $serviceOutput = docker compose ps --format json 2>&1
    if ($serviceOutput -and $serviceOutput.Trim()) {
        $services = $serviceOutput | ConvertFrom-Json
        # Handle both single object and array
        if ($services -isnot [Array]) {
            $services = @($services)
        }
        $runningServices = $services | Where-Object { $_.State -eq "running" }
        $totalServices = $services.Count
        
        Write-Host "  [OK] $($runningServices.Count)/$totalServices services are running" -ForegroundColor Green
        
        if ($runningServices.Count -lt $totalServices) {
            Write-Host "  [WARN] Some services may still be starting. Waiting additional 30 seconds..." -ForegroundColor Yellow
            Start-Sleep -Seconds 30
            $script:stepResults["Step 5: Service Readiness"] = "WARNING"
            $script:errors += "Step 5: Only $($runningServices.Count)/$totalServices services are running"
        } else {
            $serviceCheckSuccess = $true
            $script:stepResults["Step 5: Service Readiness"] = "SUCCESS"
        }
    } else {
        Write-Host "  [WARN] Could not check service status. Continuing..." -ForegroundColor Yellow
        $script:stepResults["Step 5: Service Readiness"] = "WARNING"
        $script:errors += "Step 5: Could not check service status"
    }
} catch {
    Write-Host "  [WARN] Could not parse service status. Continuing..." -ForegroundColor Yellow
    $script:stepResults["Step 5: Service Readiness"] = "WARNING"
    $script:errors += "Step 5: Could not parse service status"
}

Write-Host ""

# Step 6: Verify API Gateway is accessible
Write-Host "Step 6: Verifying API Gateway..." -ForegroundColor Yellow
$maxRetries = 10
$retryCount = 0
$gatewayReady = $false

while ($retryCount -lt $maxRetries -and -not $gatewayReady) {
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:8080/api/auth/health" -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
        if ($response.StatusCode -eq 200) {
            $gatewayReady = $true
            Write-Host "  [OK] API Gateway is accessible" -ForegroundColor Green
        }
    } catch {
        $retryCount++
        if ($retryCount -lt $maxRetries) {
            Write-Host "  Waiting for API Gateway... (attempt $retryCount/$maxRetries)" -ForegroundColor Gray
            Start-Sleep -Seconds 5
        }
    }
}

if (-not $gatewayReady) {
    Write-Host "  [WARN] API Gateway may not be ready yet. Continuing anyway..." -ForegroundColor Yellow
    Write-Host "  You can check manually: curl http://localhost:8080/api/auth/health" -ForegroundColor Gray
    $script:stepResults["Step 6: API Gateway Verification"] = "WARNING"
    $script:errors += "Step 6: API Gateway not accessible after $maxRetries attempts"
} else {
    $script:stepResults["Step 6: API Gateway Verification"] = "SUCCESS"
}

Write-Host ""

# Step 7: Initialize dummy data
Write-Host "Step 7: Initializing dummy data..." -ForegroundColor Yellow
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $scriptPath) {
    $scriptPath = Get-Location
}
$initScript = Join-Path $scriptPath "init-dummy-data-all.ps1"

if (Test-Path $initScript) {
    Write-Host "  Running init-dummy-data-all.ps1..." -ForegroundColor Gray
    & $initScript
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  [OK] Dummy data initialized successfully" -ForegroundColor Green
        $script:stepResults["Step 7: Initialize Dummy Data"] = "SUCCESS"
    } else {
        Write-Host "  [WARN] Dummy data initialization had issues. Check output above." -ForegroundColor Yellow
        Write-Host "  You can run it manually: powershell -ExecutionPolicy Bypass -File init-dummy-data-all.ps1" -ForegroundColor Gray
        $script:stepResults["Step 7: Initialize Dummy Data"] = "WARNING"
        $script:errors += "Step 7: Dummy data initialization had issues (exit code: $LASTEXITCODE)"
    }
} else {
    Write-Host "  [WARN] init-dummy-data-all.ps1 not found. Skipping dummy data initialization." -ForegroundColor Yellow
    Write-Host "  You can initialize dummy data manually later." -ForegroundColor Gray
    $script:stepResults["Step 7: Initialize Dummy Data"] = "SKIPPED"
}

Write-Host ""

# Step 8: Final verification
Write-Host "Step 8: Final verification..." -ForegroundColor Yellow
Write-Host "  Service status:" -ForegroundColor Gray
try {
    docker compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}"
    $script:stepResults["Step 8: Final Verification"] = "SUCCESS"
} catch {
    $script:stepResults["Step 8: Final Verification"] = "WARNING"
    $script:errors += "Step 8: Could not display service status"
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "FINAL SUMMARY" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Display step results
Write-Host "Step Results:" -ForegroundColor Yellow
foreach ($step in $script:stepResults.Keys | Sort-Object) {
    $status = $script:stepResults[$step]
    $color = switch ($status) {
        "SUCCESS" { "Green" }
        "WARNING" { "Yellow" }
        "FAILED" { "Red" }
        "SKIPPED" { "Gray" }
        default { "Gray" }
    }
    Write-Host "  $step : $status" -ForegroundColor $color
}

Write-Host ""

# Display overall status
if ($script:overallSuccess) {
    Write-Host "Overall Status: " -NoNewline -ForegroundColor Yellow
    Write-Host "SUCCESS" -ForegroundColor Green
    Write-Host ""
    Write-Host "Setup completed successfully!" -ForegroundColor Green
} else {
    Write-Host "Overall Status: " -NoNewline -ForegroundColor Yellow
    Write-Host "FAILED" -ForegroundColor Red
    Write-Host ""
    Write-Host "Setup completed with errors. Please review the errors below." -ForegroundColor Red
}

# Display errors if any
if ($script:errors.Count -gt 0) {
    Write-Host ""
    Write-Host "Errors Encountered:" -ForegroundColor Red
    for ($i = 0; $i -lt $script:errors.Count; $i++) {
        Write-Host "  $($i + 1). $($script:errors[$i])" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "  1. Verify services: docker compose ps" -ForegroundColor Gray
Write-Host "  2. Check logs: docker compose logs -f [service-name]" -ForegroundColor Gray
Write-Host "  3. Access API Gateway: http://localhost:8080" -ForegroundColor Gray
Write-Host "  4. Access RabbitMQ Management: http://localhost:15672 (admin/admin)" -ForegroundColor Gray
Write-Host ""

if ($script:stepResults["Step 7: Initialize Dummy Data"] -eq "SUCCESS") {
    Write-Host "User Credentials:" -ForegroundColor Yellow
    Write-Host "Admin:" -ForegroundColor Cyan
    Write-Host "  Username: admin1" -ForegroundColor Gray
    Write-Host "  Password: 12345678a" -ForegroundColor Gray
    Write-Host "  Email: admin@gmail.com" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Student:" -ForegroundColor Cyan
    Write-Host "  Username: student1" -ForegroundColor Gray
    Write-Host "  Password: 12345678s" -ForegroundColor Gray
    Write-Host "  Email: student1@example.com" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Faculty:" -ForegroundColor Cyan
    Write-Host "  Username: faculty1" -ForegroundColor Gray
    Write-Host "  Password: 12345678f" -ForegroundColor Gray
    Write-Host "  Email: faculty1@example.com" -ForegroundColor Gray
    Write-Host ""
}

Write-Host "To stop all services: docker compose down" -ForegroundColor Gray
Write-Host "To view logs: docker compose logs -f" -ForegroundColor Gray
Write-Host ""

# Exit with appropriate code
if (-not $script:overallSuccess) {
    exit 1
}
