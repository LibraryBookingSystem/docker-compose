# ============================================================================
# Test Audit Logs Script
# ============================================================================
# This script helps test and verify audit logging functionality
# ============================================================================

$ErrorActionPreference = "Continue"

Write-Host "=== Testing Audit Logs ===" -ForegroundColor Green
Write-Host ""

# Check if services are running
Write-Host "1. Checking service status..." -ForegroundColor Yellow
$analyticsStatus = docker ps --filter "name=library-analytics-service" --format "{{.Status}}"
$gatewayStatus = docker ps --filter "name=library-api-gateway" --format "{{.Status}}"

if ($analyticsStatus) {
    Write-Host "  [OK] Analytics Service: $analyticsStatus" -ForegroundColor Green
} else {
    Write-Host "  [ERROR] Analytics Service is not running!" -ForegroundColor Red
    Write-Host "    Start it with: docker compose up -d analytics-service" -ForegroundColor Gray
    exit 1
}

if ($gatewayStatus) {
    Write-Host "  [OK] API Gateway: $gatewayStatus" -ForegroundColor Green
} else {
    Write-Host "  [ERROR] API Gateway is not running!" -ForegroundColor Red
    Write-Host "    Start it with: docker compose up -d api-gateway" -ForegroundColor Gray
    exit 1
}

Write-Host ""
Write-Host "2. Testing API Gateway route..." -ForegroundColor Yellow
try {
    $healthCheck = Invoke-WebRequest -Uri "http://localhost:8080/api/audit-logs/health" -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
    Write-Host "  [OK] Audit logs endpoint is accessible via gateway" -ForegroundColor Green
    Write-Host "    Response: $($healthCheck.Content)" -ForegroundColor Gray
} catch {
    Write-Host "  [ERROR] Cannot reach audit logs endpoint: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "    Check if analytics-service is running and API gateway is configured correctly" -ForegroundColor Gray
}

Write-Host ""
Write-Host "3. Checking database for audit logs..." -ForegroundColor Yellow
try {
    $logCount = docker exec library-postgres psql -U postgres -d analytics_db -t -A -c "SELECT COUNT(*) FROM audit_logs;" 2>&1
    if ($logCount -match '^\d+$') {
        Write-Host "  [OK] Found $logCount audit log entries in database" -ForegroundColor Green
        
        if ([int]$logCount -gt 0) {
            Write-Host ""
            Write-Host "  Recent audit logs:" -ForegroundColor Cyan
            docker exec library-postgres psql -U postgres -d analytics_db -c @"
SELECT 
    id,
    username,
    action_type,
    resource_type,
    description,
    success,
    timestamp
FROM audit_logs
ORDER BY timestamp DESC
LIMIT 10;
"@
        } else {
            Write-Host "  [INFO] No audit logs found yet. Perform some actions in the UI to generate logs." -ForegroundColor Yellow
        }
    } else {
        Write-Host "  [WARN] Could not query audit logs table. It may not exist yet." -ForegroundColor Yellow
        Write-Host "    The table will be created when analytics-service starts." -ForegroundColor Gray
    }
} catch {
    Write-Host "  [ERROR] Failed to query database: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "4. Checking RabbitMQ audit queue..." -ForegroundColor Yellow
try {
    $queueInfo = docker exec library-rabbitmq rabbitmqctl list_queues name messages 2>&1 | Select-String -Pattern "audit"
    if ($queueInfo) {
        Write-Host "  [OK] Audit queue exists:" -ForegroundColor Green
        Write-Host "    $queueInfo" -ForegroundColor Gray
    } else {
        Write-Host "  [INFO] Audit queue not found or empty (this is OK if no events have been published yet)" -ForegroundColor Yellow
    }
} catch {
    Write-Host "  [WARN] Could not check RabbitMQ queues: $($_.Exception.Message)" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=== Testing Instructions ===" -ForegroundColor Green
Write-Host ""
Write-Host "To generate audit logs, perform these actions in the UI:" -ForegroundColor Cyan
Write-Host "  1. Login as any user (generates LOGIN audit log)" -ForegroundColor Gray
Write-Host "  2. Create a resource (generates CREATE RESOURCE audit log)" -ForegroundColor Gray
Write-Host "  3. Create a booking (generates CREATE BOOKING audit log)" -ForegroundColor Gray
Write-Host "  4. Cancel a booking (generates CANCEL BOOKING audit log)" -ForegroundColor Gray
Write-Host "  5. Create/Update/Delete a policy (generates POLICY audit logs)" -ForegroundColor Gray
Write-Host ""
Write-Host "Then check the Audit Logs screen in Admin Dashboard to view them." -ForegroundColor Cyan
Write-Host ""
Write-Host "To view logs directly in database:" -ForegroundColor Cyan
Write-Host "  docker exec -it library-postgres psql -U postgres -d analytics_db" -ForegroundColor Gray
Write-Host "  SELECT * FROM audit_logs ORDER BY timestamp DESC LIMIT 20;" -ForegroundColor Gray
Write-Host ""
