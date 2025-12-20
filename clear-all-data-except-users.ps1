# PowerShell script to clear all data except users
# Run this from the docker-compose directory

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Clearing All Data Except Users" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check if Docker container is running
$containerName = "library-postgres"
$containerRunning = docker ps --filter "name=$containerName" --format "{{.Names}}" | Select-String -Pattern $containerName

if (-not $containerRunning) {
    Write-Host "ERROR: PostgreSQL container '$containerName' is not running!" -ForegroundColor Red
    Write-Host "Please start Docker containers first:" -ForegroundColor Yellow
    Write-Host "  cd docker-compose" -ForegroundColor Gray
    Write-Host "  docker-compose up -d" -ForegroundColor Gray
    exit 1
}

Write-Host "Copying SQL script to container..." -ForegroundColor Green
docker cp clear-all-data-except-users.sql $containerName:/tmp/clear-all-data-except-users.sql

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Failed to copy SQL file to container" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Deleting data from each database..." -ForegroundColor Yellow
Write-Host ""

# 1. Delete bookings
Write-Host "[1/5] Deleting bookings from booking_db..." -ForegroundColor Cyan
docker exec -i $containerName psql -U postgres -d booking_db -c "TRUNCATE TABLE bookings CASCADE;"
if ($LASTEXITCODE -eq 0) {
    Write-Host "  ✓ Bookings deleted" -ForegroundColor Green
} else {
    Write-Host "  ✗ Failed to delete bookings" -ForegroundColor Red
}

# 2. Delete resources and amenities
Write-Host "[2/5] Deleting resources from catalog_db..." -ForegroundColor Cyan
docker exec -i $containerName psql -U postgres -d catalog_db -c "DELETE FROM resource_amenities; TRUNCATE TABLE resources CASCADE;"
if ($LASTEXITCODE -eq 0) {
    Write-Host "  ✓ Resources deleted" -ForegroundColor Green
} else {
    Write-Host "  ✗ Failed to delete resources" -ForegroundColor Red
}

# 3. Delete policies
Write-Host "[3/5] Deleting policies from policy_db..." -ForegroundColor Cyan
docker exec -i $containerName psql -U postgres -d policy_db -c "TRUNCATE TABLE booking_policies CASCADE;"
if ($LASTEXITCODE -eq 0) {
    Write-Host "  ✓ Policies deleted" -ForegroundColor Green
} else {
    Write-Host "  ✗ Failed to delete policies" -ForegroundColor Red
}

# 4. Delete notifications
Write-Host "[4/5] Deleting notifications from notification_db..." -ForegroundColor Cyan
docker exec -i $containerName psql -U postgres -d notification_db -c "TRUNCATE TABLE notifications CASCADE;"
if ($LASTEXITCODE -eq 0) {
    Write-Host "  ✓ Notifications deleted" -ForegroundColor Green
} else {
    Write-Host "  ✗ Failed to delete notifications" -ForegroundColor Red
}

# 5. Delete analytics data
Write-Host "[5/5] Deleting analytics data from analytics_db..." -ForegroundColor Cyan
docker exec -i $containerName psql -U postgres -d analytics_db -c @"
DO \$\$
BEGIN
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'usage_statistics') THEN
        TRUNCATE TABLE usage_statistics CASCADE;
    END IF;
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'analytics_events') THEN
        TRUNCATE TABLE analytics_events CASCADE;
    END IF;
END \$\$;
"@
if ($LASTEXITCODE -eq 0) {
    Write-Host "  ✓ Analytics data deleted" -ForegroundColor Green
} else {
    Write-Host "  ✗ Failed to delete analytics data (may not exist)" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Verification" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Verify deletion
Write-Host "Checking data counts..." -ForegroundColor Yellow
Write-Host ""

Write-Host "Bookings:" -ForegroundColor Cyan
docker exec $containerName psql -U postgres -d booking_db -t -c "SELECT COUNT(*) FROM bookings;"

Write-Host "Resources:" -ForegroundColor Cyan
docker exec $containerName psql -U postgres -d catalog_db -t -c "SELECT COUNT(*) FROM resources;"

Write-Host "Policies:" -ForegroundColor Cyan
docker exec $containerName psql -U postgres -d policy_db -t -c "SELECT COUNT(*) FROM booking_policies;"

Write-Host "Notifications:" -ForegroundColor Cyan
docker exec $containerName psql -U postgres -d notification_db -t -c "SELECT COUNT(*) FROM notifications;"

Write-Host "Users (should still exist):" -ForegroundColor Cyan
docker exec $containerName psql -U postgres -d user_db -t -c "SELECT COUNT(*) FROM users;"

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "Done! All data cleared except users." -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Note: User accounts are preserved. You can now:" -ForegroundColor Yellow
Write-Host "  1. Re-initialize resources: .\init-dummy-data-catalog.sql" -ForegroundColor Gray
Write-Host "  2. Re-initialize policies: .\init-dummy-data-policy.sql" -ForegroundColor Gray
Write-Host "  3. Or create new data through the UI" -ForegroundColor Gray
Write-Host ""






