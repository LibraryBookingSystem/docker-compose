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

Write-Host "Creating dummy student and faculty users via API..." -ForegroundColor Green
# Use the setup-dummy-users script to create student and faculty users
& "$PSScriptRoot\setup-dummy-users.ps1"

Write-Host "Verifying data..." -ForegroundColor Green
Write-Host "Resources count:" -ForegroundColor Cyan
docker exec library-postgres psql -U postgres -d catalog_db -c "SELECT COUNT(*) FROM resources;"
Write-Host "Policies count:" -ForegroundColor Cyan
docker exec library-postgres psql -U postgres -d policy_db -c "SELECT COUNT(*) FROM booking_policies;"
Write-Host "Users:" -ForegroundColor Cyan
docker exec library-postgres psql -U postgres -d user_db -c "SELECT username, email, role, pending_approval FROM users WHERE username IN ('admin1', 'student1', 'faculty1') ORDER BY role, username;"

Write-Host ""
Write-Host "User Credentials:" -ForegroundColor Green
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
Write-Host "Done!" -ForegroundColor Green
