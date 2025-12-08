# PowerShell script to initialize all dummy data
# Run this from the docker-compose directory

Write-Host "Copying SQL files to container..." -ForegroundColor Green
docker cp init-dummy-data-catalog.sql library-postgres:/tmp/init-dummy-data-catalog.sql
docker cp init-dummy-data-policy.sql library-postgres:/tmp/init-dummy-data-policy.sql

Write-Host "Waiting for services to create tables..." -ForegroundColor Yellow
Start-Sleep -Seconds 10

Write-Host "Inserting catalog data (resources)..." -ForegroundColor Green
docker exec -i library-postgres psql -U postgres -d catalog_db -f /tmp/init-dummy-data-catalog.sql

Write-Host "Inserting policy data..." -ForegroundColor Green
docker exec -i library-postgres psql -U postgres -d policy_db -f /tmp/init-dummy-data-policy.sql

Write-Host "Creating admin user via API (ensures correct password hash)..." -ForegroundColor Green
# Use the setup-admin-user script to create and approve admin user
& "$PSScriptRoot\setup-admin-user.ps1"

Write-Host "Verifying data..." -ForegroundColor Green
Write-Host "Resources count:" -ForegroundColor Cyan
docker exec library-postgres psql -U postgres -d catalog_db -c "SELECT COUNT(*) FROM resources;"
Write-Host "Policies count:" -ForegroundColor Cyan
docker exec library-postgres psql -U postgres -d policy_db -c "SELECT COUNT(*) FROM booking_policies;"
Write-Host "Admin user:" -ForegroundColor Cyan
docker exec library-postgres psql -U postgres -d user_db -c "SELECT username, email, role, pending_approval FROM users WHERE username = 'admin1';"

Write-Host ""
Write-Host "Admin Credentials:" -ForegroundColor Green
Write-Host "  Username: admin1" -ForegroundColor Cyan
Write-Host "  Password: 12345678a" -ForegroundColor Cyan
Write-Host "  Email: admin@gmail.com" -ForegroundColor Cyan
Write-Host ""
Write-Host "Done!" -ForegroundColor Green
