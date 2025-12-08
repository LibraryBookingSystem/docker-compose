# PowerShell script to check service status and troubleshoot connection issues
# Run this from the docker-compose directory

Write-Host "=== Checking Library System Services ===" -ForegroundColor Green
Write-Host ""

# Check if containers are running
Write-Host "1. Checking container status..." -ForegroundColor Yellow
docker compose ps

Write-Host ""
Write-Host "2. Checking user-service health..." -ForegroundColor Yellow
$userServiceHealth = docker exec library-user-service wget -q -O- http://localhost:3001/api/health 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "  ✓ User-service is healthy" -ForegroundColor Green
    Write-Host "  Response: $userServiceHealth" -ForegroundColor Cyan
} else {
    Write-Host "  ✗ User-service health check failed" -ForegroundColor Red
    Write-Host "  Error: $userServiceHealth" -ForegroundColor Red
}

Write-Host ""
Write-Host "3. Checking auth-service health..." -ForegroundColor Yellow
$authServiceHealth = docker exec library-auth-service wget -q -O- http://localhost:3002/api/auth/health 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "  ✓ Auth-service is healthy" -ForegroundColor Green
    Write-Host "  Response: $authServiceHealth" -ForegroundColor Cyan
} else {
    Write-Host "  ✗ Auth-service health check failed" -ForegroundColor Red
    Write-Host "  Error: $authServiceHealth" -ForegroundColor Red
}

Write-Host ""
Write-Host "4. Testing user-service endpoint from auth-service..." -ForegroundColor Yellow
$testUrl = "http://user-service:3001/api/health"
$testResult = docker exec library-auth-service wget -q -O- $testUrl 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "  ✓ Auth-service can reach user-service" -ForegroundColor Green
    Write-Host "  Response: $testResult" -ForegroundColor Cyan
} else {
    Write-Host "  ✗ Auth-service cannot reach user-service" -ForegroundColor Red
    Write-Host "  Error: $testResult" -ForegroundColor Red
    Write-Host ""
    Write-Host "  Troubleshooting steps:" -ForegroundColor Yellow
    Write-Host "  1. Check if user-service is running: docker ps | Select-String user-service" -ForegroundColor Gray
    Write-Host "  2. Check user-service logs: docker logs library-user-service --tail 50" -ForegroundColor Gray
    Write-Host "  3. Check auth-service logs: docker logs library-auth-service --tail 50" -ForegroundColor Gray
    Write-Host "  4. Restart services: docker compose restart user-service auth-service" -ForegroundColor Gray
}

Write-Host ""
Write-Host "5. Recent user-service logs (last 10 lines)..." -ForegroundColor Yellow
docker logs library-user-service --tail 10 2>&1

Write-Host ""
Write-Host "6. Recent auth-service logs (last 10 lines)..." -ForegroundColor Yellow
docker logs library-auth-service --tail 10 2>&1

Write-Host ""
Write-Host "=== Check Complete ===" -ForegroundColor Green
