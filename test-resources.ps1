# Test script to verify resources data and API

Write-Host "=== Checking Database ===" -ForegroundColor Cyan
Write-Host "Resources count:" -ForegroundColor Yellow
docker exec library-postgres psql -U postgres -d catalog_db -t -A -c "SELECT COUNT(*) FROM resources;"

Write-Host "`nSample resources:" -ForegroundColor Yellow
docker exec library-postgres psql -U postgres -d catalog_db -c "SELECT id, name, type, status FROM resources LIMIT 5;"

Write-Host "`n=== Testing API ===" -ForegroundColor Cyan
Write-Host "Testing API Gateway health:" -ForegroundColor Yellow
$health = Invoke-RestMethod -Uri "http://localhost:8080/health" -Method Get -ErrorAction SilentlyContinue
if ($health) { Write-Host "API Gateway: OK" -ForegroundColor Green } else { Write-Host "API Gateway: FAILED" -ForegroundColor Red }

Write-Host "`nTesting Catalog Service health:" -ForegroundColor Yellow
try {
    $catalogHealth = Invoke-RestMethod -Uri "http://localhost:8080/api/resources/health" -Method Get -ErrorAction Stop
    Write-Host "Catalog Service: OK" -ForegroundColor Green
} catch {
    Write-Host "Catalog Service: FAILED - $_" -ForegroundColor Red
}

Write-Host "`nTesting Resources API (no auth):" -ForegroundColor Yellow
try {
    $resources = Invoke-RestMethod -Uri "http://localhost:8080/api/resources" -Method Get -ErrorAction Stop
    Write-Host "Resources API: OK - Found $($resources.Count) resources" -ForegroundColor Green
    if ($resources.Count -gt 0) {
        Write-Host "First resource: $($resources[0].name)" -ForegroundColor Cyan
    }
} catch {
    Write-Host "Resources API: FAILED - $_" -ForegroundColor Red
    Write-Host "Status Code: $($_.Exception.Response.StatusCode.value__)" -ForegroundColor Yellow
}

Write-Host "`n=== Checking Service Logs ===" -ForegroundColor Cyan
Write-Host "Recent catalog service logs:" -ForegroundColor Yellow
docker logs library-catalog-service --tail 10 2>&1 | Select-Object -Last 5
