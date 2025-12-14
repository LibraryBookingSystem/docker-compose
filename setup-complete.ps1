# ============================================================================
# Complete Setup Script for Library Booking System
# ============================================================================
# This script performs a complete setup:
#   1. Checks if Docker is running
#   2. Builds common-aspects library
#   3. Rebuilds all services
#   4. Starts all services
#   5. Waits for services to be ready
#   6. Verifies API Gateway
#   7. Initializes dummy data
#   8. Final verification
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
    $stopOutput = docker compose down 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  [OK] Done" -ForegroundColor Green
        $script:stepResults["Step 2: Stop Containers"] = "SUCCESS"
    } else {
        $errorMsg = "Failed to stop containers: $stopOutput"
        $script:errors += "Step 2: $errorMsg"
        $script:stepResults["Step 2: Stop Containers"] = "WARNING"
        Write-Host "  [WARN] $errorMsg" -ForegroundColor Yellow
    }
} catch {
    $errorMsg = "Exception while stopping containers: $($_.Exception.Message)"
    $script:errors += "Step 2: $errorMsg"
    $script:stepResults["Step 2: Stop Containers"] = "WARNING"
    Write-Host "  [WARN] $errorMsg" -ForegroundColor Yellow
}
Write-Host ""

# Step 3: Build common-aspects library
Write-Host "Step 3: Building common-aspects library..." -ForegroundColor Yellow
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $scriptPath) {
    $scriptPath = Get-Location
}
$projectRoot = Split-Path -Parent $scriptPath
$commonAspectsPath = Join-Path $projectRoot "common-aspects"

try {
    if (-not (Test-Path $commonAspectsPath)) {
        $errorMsg = "common-aspects directory not found at $commonAspectsPath"
        $script:errors += "Step 3: $errorMsg"
        $script:stepResults["Step 3: Build Common-Aspects"] = "FAILED"
        $script:overallSuccess = $false
        Write-Host "  [ERROR] $errorMsg" -ForegroundColor Red
        Write-Host "  Please ensure common-aspects repository is cloned in the workspace root." -ForegroundColor Yellow
        exit 1
    }
    
    Write-Host "  Building common-aspects with Maven..." -ForegroundColor Gray
    $buildOutput = docker run --rm -v "${commonAspectsPath}:/app" -w /app maven:3.9-eclipse-temurin-17 mvn clean package -DskipTests -B 2>&1
    
    if ($LASTEXITCODE -ne 0) {
        $errorMsg = "Failed to build common-aspects (exit code: $LASTEXITCODE)"
        $script:errors += "Step 3: $errorMsg"
        $script:stepResults["Step 3: Build Common-Aspects"] = "FAILED"
        $script:overallSuccess = $false
        Write-Host "  [ERROR] $errorMsg" -ForegroundColor Red
        Write-Host "  Build output:" -ForegroundColor Gray
        $buildOutput | ForEach-Object { Write-Host "    $_" -ForegroundColor Gray }
        exit 1
    }
    
    Write-Host "  [OK] common-aspects built successfully" -ForegroundColor Green
    
    # Copy common-aspects jar to each service's libs directory
    $services = @("user-service", "auth-service", "catalog-service", "booking-service", "policy-service", "notification-service", "analytics-service")
    $jarPath = Join-Path $commonAspectsPath "target\common-aspects-1.0.0.jar"
    
    if (-not (Test-Path $jarPath)) {
        $errorMsg = "common-aspects jar not found at $jarPath"
        $script:errors += "Step 3: $errorMsg"
        $script:stepResults["Step 3: Build Common-Aspects"] = "FAILED"
        $script:overallSuccess = $false
        Write-Host "  [ERROR] $errorMsg" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "  Copying JAR to service libs directories..." -ForegroundColor Gray
    $copyErrors = @()
    foreach ($service in $services) {
        $libsDir = Join-Path $projectRoot "${service}\libs"
        try {
            if (-not (Test-Path $libsDir)) {
                New-Item -ItemType Directory -Path $libsDir -Force | Out-Null
            }
            Copy-Item $jarPath $libsDir -Force | Out-Null
        } catch {
            $copyErrors += "Failed to copy to ${service}: $($_.Exception.Message)"
        }
    }
    
    if ($copyErrors.Count -gt 0) {
        $errorMsg = "Some copies failed: $($copyErrors -join '; ')"
        $script:errors += "Step 3: $errorMsg"
        $script:stepResults["Step 3: Build Common-Aspects"] = "WARNING"
        Write-Host "  [WARN] $errorMsg" -ForegroundColor Yellow
    } else {
        Write-Host "  [OK] Copied common-aspects jar to all service libs directories" -ForegroundColor Green
        $script:stepResults["Step 3: Build Common-Aspects"] = "SUCCESS"
    }
} catch {
    $errorMsg = "Exception while building common-aspects: $($_.Exception.Message)"
    $script:errors += "Step 3: $errorMsg"
    $script:stepResults["Step 3: Build Common-Aspects"] = "FAILED"
    $script:overallSuccess = $false
    Write-Host "  [ERROR] $errorMsg" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Step 4: Rebuild all services
Write-Host "Step 4: Rebuilding all services (this may take several minutes)..." -ForegroundColor Yellow
Write-Host "  This will rebuild all microservices and the API gateway..." -ForegroundColor Gray

# Try building with cache first
$buildSuccess = $false
$buildErrors = @()
try {
    Write-Host "  Attempting build with cache..." -ForegroundColor Gray
    $buildOutput = docker compose build 2>&1 | ForEach-Object {
        $line = $_
        if ($line -match "ERROR|error|Error|FAILED|Failed|failed to solve|parent snapshot.*does not exist") {
            Write-Host "  [WARN] $line" -ForegroundColor Yellow
            $buildErrors += $line
            if ($line -match "parent snapshot.*does not exist") {
                $script:buildCacheIssue = $true
            }
        } else {
            Write-Host "  $line" -ForegroundColor Gray
        }
        $line
    }
    
    if ($LASTEXITCODE -eq 0) {
        $buildSuccess = $true
        Write-Host "  [OK] All services rebuilt successfully" -ForegroundColor Green
        $script:stepResults["Step 4: Rebuild Services"] = "SUCCESS"
    } else {
        $errorMsg = "Build failed with cache (exit code: $LASTEXITCODE)"
        if ($buildErrors.Count -gt 0) {
            $errorMsg += ". Errors: $($buildErrors[0..([Math]::Min(3, $buildErrors.Count-1))] -join '; ')"
        }
        $script:stepResults["Step 4: Rebuild Services"] = "FAILED"
        $script:errors += "Step 4: $errorMsg"
        Write-Host "  [ERROR] Build failed. See errors above." -ForegroundColor Red
    }
} catch {
    $errorMsg = "Exception during build with cache: $($_.Exception.Message)"
    $script:stepResults["Step 4: Rebuild Services"] = "FAILED"
    $script:errors += "Step 4: $errorMsg"
    Write-Host "  [ERROR] Build with cache had issues: $($_.Exception.Message)" -ForegroundColor Red
}

# If build failed due to cache issues, prune cache and retry
if (-not $buildSuccess -or $buildCacheIssue) {
    Write-Host "  Build cache issue detected. Pruning Docker build cache..." -ForegroundColor Yellow
    docker builder prune -f 2>&1 | Out-Null
    Write-Host "  Retrying build without cache..." -ForegroundColor Gray
    
    $retryBuildErrors = @()
    try {
        $retryBuildOutput = docker compose build --no-cache 2>&1 | ForEach-Object {
            $line = $_
            if ($line -match "ERROR|error|Error|FAILED|Failed") {
                Write-Host "  [ERROR] $line" -ForegroundColor Red
                $retryBuildErrors += $line
            } else {
                Write-Host "  $line" -ForegroundColor Gray
            }
            $line
        }
        
        if ($LASTEXITCODE -ne 0) {
            $errorMsg = "Build failed even after cache prune (exit code: $LASTEXITCODE)"
            if ($retryBuildErrors.Count -gt 0) {
                $errorMsg += ". Key errors: $($retryBuildErrors[0..([Math]::Min(3, $retryBuildErrors.Count-1))] -join '; ')"
            }
            $script:errors += "Step 4: $errorMsg"
            $script:stepResults["Step 4: Rebuild Services"] = "FAILED"
            $script:overallSuccess = $false
            Write-Host "  [ERROR] Build failed even after cache prune. Check the output above for errors." -ForegroundColor Red
            Write-Host "  [INFO] Exit code: $LASTEXITCODE" -ForegroundColor Gray
            Write-Host "  You may need to manually run: docker builder prune -af" -ForegroundColor Yellow
            exit 1
        }
        Write-Host "  [OK] All services rebuilt successfully (after cache prune)" -ForegroundColor Green
        $script:stepResults["Step 4: Rebuild Services"] = "SUCCESS"
    } catch {
        $errorMsg = "Exception during build after cache prune: $($_.Exception.Message)"
        $script:errors += "Step 4: $errorMsg"
        $script:stepResults["Step 4: Rebuild Services"] = "FAILED"
        $script:overallSuccess = $false
        Write-Host "  [ERROR] Build failed even after cache prune." -ForegroundColor Red
        Write-Host "  [INFO] Exception: $($_.Exception.Message)" -ForegroundColor Gray
        Write-Host "  You may need to manually run: docker builder prune -af" -ForegroundColor Yellow
        exit 1
    }
}

Write-Host ""

# Step 5: Start all services
Write-Host "Step 5: Starting all services..." -ForegroundColor Yellow
$startErrors = @()
try {
    $startOutput = docker compose up -d 2>&1 | ForEach-Object {
        $line = $_
        if ($line -match "ERROR|error|Error|FAILED|Failed|failed|Cannot|unable|Unable") {
            Write-Host "  [ERROR] $line" -ForegroundColor Red
            $startErrors += $line
        } else {
            Write-Host "  $line" -ForegroundColor Gray
        }
        $line
    }
    
    if ($LASTEXITCODE -ne 0) {
        $errorMsg = "Failed to start services (exit code: $LASTEXITCODE)"
        if ($startErrors.Count -gt 0) {
            $errorMsg += ". Errors: $($startErrors[0..([Math]::Min(3, $startErrors.Count-1))] -join '; ')"
        }
        $script:errors += "Step 5: $errorMsg"
        $script:stepResults["Step 5: Start Services"] = "FAILED"
        $script:overallSuccess = $false
        Write-Host "  [ERROR] Failed to start services. Check the output above for details." -ForegroundColor Red
        Write-Host "  [INFO] Exit code: $LASTEXITCODE" -ForegroundColor Gray
        Write-Host "  You can check logs: docker compose logs [service-name]" -ForegroundColor Yellow
        exit 1
    }
    Write-Host "  [OK] Services started" -ForegroundColor Green
    $script:stepResults["Step 5: Start Services"] = "SUCCESS"
} catch {
    $errorMsg = "Exception while starting services: $($_.Exception.Message)"
    $script:errors += "Step 5: $errorMsg"
    $script:stepResults["Step 5: Start Services"] = "FAILED"
    $script:overallSuccess = $false
    Write-Host "  [ERROR] Failed to start services" -ForegroundColor Red
    Write-Host "  [INFO] Exception: $($_.Exception.Message)" -ForegroundColor Gray
    Write-Host "  You can check logs: docker compose logs [service-name]" -ForegroundColor Yellow
    exit 1
}

Write-Host ""

# Step 6: Wait for services to be ready
Write-Host "Step 6: Waiting for services to be ready..." -ForegroundColor Yellow
Write-Host "  Waiting for infrastructure services (PostgreSQL, Redis, RabbitMQ)..." -ForegroundColor Gray
Start-Sleep -Seconds 15

Write-Host "  Waiting for microservices to start and create database tables..." -ForegroundColor Gray
Start-Sleep -Seconds 30

# Check if services are running
Write-Host "  Checking service status..." -ForegroundColor Gray
$serviceCheckSuccess = $false
try {
    $serviceOutput = docker compose ps --format json 2>&1
    if ($LASTEXITCODE -ne 0) {
        $errorMsg = "Failed to get service status: $serviceOutput"
        $script:errors += "Step 6: $errorMsg"
        $script:stepResults["Step 6: Service Readiness"] = "WARNING"
        Write-Host "  [WARN] $errorMsg" -ForegroundColor Yellow
    } elseif ($serviceOutput -and $serviceOutput.Trim()) {
        try {
            $services = $serviceOutput | ConvertFrom-Json
            # Handle both single object and array
            if ($services -isnot [Array]) {
                $services = @($services)
            }
            $runningServices = $services | Where-Object { $_.State -eq "running" }
            $totalServices = $services.Count
            
            Write-Host "  [OK] $($runningServices.Count)/$totalServices services are running" -ForegroundColor Green
            
            if ($runningServices.Count -lt $totalServices) {
                $notRunning = $services | Where-Object { $_.State -ne "running" } | ForEach-Object { "$($_.Name): $($_.State)" }
                $errorMsg = "Only $($runningServices.Count)/$totalServices services are running. Not running: $($notRunning -join ', ')"
                Write-Host "  [WARN] Some services may still be starting. Waiting additional 30 seconds..." -ForegroundColor Yellow
                Write-Host "  [INFO] Services not running: $($notRunning -join ', ')" -ForegroundColor Gray
                Start-Sleep -Seconds 30
                $script:stepResults["Step 5: Service Readiness"] = "WARNING"
                $script:errors += "Step 5: $errorMsg"
            } else {
                $serviceCheckSuccess = $true
                $script:stepResults["Step 6: Service Readiness"] = "SUCCESS"
            }
        } catch {
            $errorMsg = "Could not parse service status JSON: $($_.Exception.Message). Raw output: $serviceOutput"
            $script:errors += "Step 5: $errorMsg"
            $script:stepResults["Step 5: Service Readiness"] = "WARNING"
            Write-Host "  [WARN] Could not parse service status. Continuing..." -ForegroundColor Yellow
            Write-Host "  [INFO] Error details: $($_.Exception.Message)" -ForegroundColor Gray
        }
    } else {
        $errorMsg = "Service status output is empty"
        $script:errors += "Step 6: $errorMsg"
        $script:stepResults["Step 6: Service Readiness"] = "WARNING"
        Write-Host "  [WARN] Could not check service status. Continuing..." -ForegroundColor Yellow
    }
} catch {
    $errorMsg = "Exception while checking service status: $($_.Exception.Message)"
    $script:errors += "Step 5: $errorMsg"
    $script:stepResults["Step 5: Service Readiness"] = "WARNING"
    Write-Host "  [WARN] Could not check service status. Continuing..." -ForegroundColor Yellow
    Write-Host "  [INFO] Error details: $($_.Exception.Message)" -ForegroundColor Gray
}

Write-Host ""

# Step 7: Verify API Gateway is accessible
Write-Host "Step 7: Verifying API Gateway..." -ForegroundColor Yellow
$maxRetries = 10
$retryCount = 0
$gatewayReady = $false

$lastGatewayError = $null
while ($retryCount -lt $maxRetries -and -not $gatewayReady) {
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:8080/api/auth/health" -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
        if ($response.StatusCode -eq 200) {
            $gatewayReady = $true
            Write-Host "  [OK] API Gateway is accessible" -ForegroundColor Green
        }
    } catch {
        $lastGatewayError = $_.Exception.Message
        $retryCount++
        if ($retryCount -lt $maxRetries) {
            Write-Host "  Waiting for API Gateway... (attempt $retryCount/$maxRetries)" -ForegroundColor Gray
            Start-Sleep -Seconds 5
        }
    }
}

if (-not $gatewayReady) {
    $errorMsg = "API Gateway not accessible after $maxRetries attempts"
    if ($lastGatewayError) {
        $errorMsg += ": $lastGatewayError"
    }
    Write-Host "  [WARN] API Gateway may not be ready yet. Continuing anyway..." -ForegroundColor Yellow
    Write-Host "  [INFO] Last error: $lastGatewayError" -ForegroundColor Gray
    Write-Host "  You can check manually: curl http://localhost:8080/api/auth/health" -ForegroundColor Gray
    $script:stepResults["Step 7: API Gateway Verification"] = "WARNING"
    $script:errors += "Step 7: $errorMsg"
} else {
    $script:stepResults["Step 7: API Gateway Verification"] = "SUCCESS"
}

Write-Host ""

# Step 8: Initialize dummy data
Write-Host "Step 8: Initializing dummy data..." -ForegroundColor Yellow
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $scriptPath) {
    $scriptPath = Get-Location
}
$initScript = Join-Path $scriptPath "init-dummy-data-all.ps1"

if (Test-Path $initScript) {
    Write-Host "  Running init-dummy-data-all.ps1..." -ForegroundColor Gray
    try {
        # Capture both stdout and stderr
        $initOutput = & $initScript 2>&1
        $initExitCode = $LASTEXITCODE
        
        if ($initExitCode -eq 0) {
            Write-Host "  [OK] Dummy data initialized successfully" -ForegroundColor Green
            $script:stepResults["Step 8: Initialize Dummy Data"] = "SUCCESS"
        } else {
            $errorMsg = "Dummy data initialization failed with exit code: $initExitCode"
            # Check if there are any error messages in the output
            $errorLines = $initOutput | Where-Object { $_ -match "ERROR|Error|error|FAILED|Failed|failed|Exception" }
            if ($errorLines) {
                $errorMsg += ". Errors found: $($errorLines -join '; ')"
                Write-Host "  [ERROR] Error output from init script:" -ForegroundColor Red
                $errorLines | ForEach-Object { Write-Host "    $_" -ForegroundColor Red }
            }
            Write-Host "  [WARN] Dummy data initialization had issues. Check output above." -ForegroundColor Yellow
            Write-Host "  You can run it manually: powershell -ExecutionPolicy Bypass -File init-dummy-data-all.ps1" -ForegroundColor Gray
            $script:stepResults["Step 8: Initialize Dummy Data"] = "WARNING"
            $script:errors += "Step 8: $errorMsg"
        }
    } catch {
        $errorMsg = "Exception while running init script: $($_.Exception.Message)"
        $script:errors += "Step 8: $errorMsg"
        $script:stepResults["Step 8: Initialize Dummy Data"] = "FAILED"
        $script:overallSuccess = $false
        Write-Host "  [ERROR] $errorMsg" -ForegroundColor Red
        Write-Host "  You can run it manually: powershell -ExecutionPolicy Bypass -File init-dummy-data-all.ps1" -ForegroundColor Gray
    }
} else {
    Write-Host "  [WARN] init-dummy-data-all.ps1 not found. Skipping dummy data initialization." -ForegroundColor Yellow
    Write-Host "  Expected path: $initScript" -ForegroundColor Gray
    Write-Host "  You can initialize dummy data manually later." -ForegroundColor Gray
    $script:stepResults["Step 8: Initialize Dummy Data"] = "SKIPPED"
}

Write-Host ""

# Step 9: Final verification
Write-Host "Step 9: Final verification..." -ForegroundColor Yellow
Write-Host "  Service status:" -ForegroundColor Gray
try {
    $finalStatusOutput = docker compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}" 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host $finalStatusOutput
        $script:stepResults["Step 9: Final Verification"] = "SUCCESS"
    } else {
        $errorMsg = "Failed to get final service status: $finalStatusOutput"
        $script:errors += "Step 9: $errorMsg"
        $script:stepResults["Step 9: Final Verification"] = "WARNING"
        Write-Host "  [WARN] Could not display service status" -ForegroundColor Yellow
        Write-Host "  [INFO] Error: $finalStatusOutput" -ForegroundColor Gray
    }
} catch {
    $errorMsg = "Exception while getting final service status: $($_.Exception.Message)"
    $script:errors += "Step 9: $errorMsg"
    $script:stepResults["Step 9: Final Verification"] = "WARNING"
    Write-Host "  [WARN] Could not display service status" -ForegroundColor Yellow
    Write-Host "  [INFO] Error details: $($_.Exception.Message)" -ForegroundColor Gray
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

if ($script:stepResults["Step 8: Initialize Dummy Data"] -eq "SUCCESS") {
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
