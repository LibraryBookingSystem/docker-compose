# ============================================================================
# Admin User Setup Script for Library Booking System
# ============================================================================
# This script handles all admin user operations:
#   - Create new admin user via API (ensures correct password hashing)
#   - Approve existing admin user
#   - Fix/recreate admin user if there are issues
#
# Usage:
#   .\setup-admin-user.ps1              # Full setup (delete, create, approve)
#   .\setup-admin-user.ps1 -ApproveOnly # Just approve existing user
#   .\setup-admin-user.ps1 -Recreate    # Delete and recreate (same as default)
#
# Admin Credentials:
#   Username: admin1
#   Password: 12345678a
#   Email: admin@gmail.com
#   Role: ADMIN
# ============================================================================

param(
    [switch]$ApproveOnly,  # Only approve existing user (don't create)
    [switch]$Recreate       # Delete and recreate (default behavior)
)

$ErrorActionPreference = "Stop"

# Admin user configuration
$adminUsername = "admin1"
$adminEmail = "admin@gmail.com"
$adminPassword = "12345678a"
$adminRole = "ADMIN"
$apiBaseUrl = "http://localhost:8080"
$registerUrl = "$apiBaseUrl/api/auth/register"

Write-Host "=== Admin User Setup ===" -ForegroundColor Green
Write-Host ""

# Check if services are running
Write-Host "Checking if services are available..." -ForegroundColor Yellow
try {
    $healthCheck = Invoke-WebRequest -Uri "$apiBaseUrl/api/auth/health" -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
    Write-Host "  [OK] Services are running" -ForegroundColor Green
} catch {
    Write-Host "  [ERROR] Services are not available. Please start services first:" -ForegroundColor Red
    Write-Host "    docker compose up -d" -ForegroundColor Gray
    exit 1
}

# Function to check if user exists
function Test-AdminUserExists {
    $result = docker exec library-postgres psql -U postgres -d user_db -t -A -c "SELECT username FROM users WHERE username = '$adminUsername';" 2>&1
    return ($result -and $result.Trim() -eq $adminUsername)
}

# Function to approve user
function Approve-AdminUser {
    Write-Host "Approving admin user..." -ForegroundColor Yellow
    $updateResult = docker exec library-postgres psql -U postgres -d user_db -c @"
UPDATE users 
SET pending_approval = false, 
    rejected = false, 
    restricted = false,
    updated_at = NOW()
WHERE username = '$adminUsername';
"@
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  [OK] User approved" -ForegroundColor Green
        return $true
    } else {
        Write-Host "  [ERROR] Failed to approve user" -ForegroundColor Red
        return $false
    }
}

# Function to delete user
function Remove-AdminUser {
    Write-Host "Removing existing admin user..." -ForegroundColor Yellow
    docker exec library-postgres psql -U postgres -d user_db -c "DELETE FROM users WHERE username = '$adminUsername' OR email = '$adminEmail';" | Out-Null
    Start-Sleep -Seconds 1
    Write-Host "  [OK] Done" -ForegroundColor Green
}

# Function to create user via API
function New-AdminUser {
    Write-Host "Registering admin user via API..." -ForegroundColor Yellow
    
    $userData = @{
        username = $adminUsername
        email = $adminEmail
        password = $adminPassword
        role = $adminRole
    } | ConvertTo-Json
    
    try {
        $response = Invoke-RestMethod -Uri $registerUrl -Method Post -Body $userData -ContentType "application/json" -ErrorAction Stop
        Write-Host "  [OK] User registered successfully" -ForegroundColor Green
        Start-Sleep -Seconds 2  # Wait for database update
        return $true
    } catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        $errorMessage = $_.Exception.Message
        
        if ($statusCode -eq 409) {
            Write-Host "  [WARN] User already exists" -ForegroundColor Yellow
            return $true
        } else {
            Write-Host "  [ERROR] Registration failed: $errorMessage" -ForegroundColor Red
            Write-Host "  Status Code: $statusCode" -ForegroundColor Yellow
            return $false
        }
    }
}

# Function to verify user
function Test-AdminUser {
    Write-Host "Verifying admin user..." -ForegroundColor Yellow
    $userInfo = docker exec library-postgres psql -U postgres -d user_db -t -A -F "|" -c "SELECT username, email, role, pending_approval, restricted, rejected FROM users WHERE username = '$adminUsername';"
    
    if ($userInfo) {
        $fields = $userInfo -split '\|'
        Write-Host "  [OK] User found:" -ForegroundColor Green
        Write-Host "    Username: $($fields[0])" -ForegroundColor Cyan
        Write-Host "    Email: $($fields[1])" -ForegroundColor Cyan
        Write-Host "    Role: $($fields[2])" -ForegroundColor Cyan
        Write-Host "    Pending Approval: $($fields[3])" -ForegroundColor $(if ($fields[3] -eq 'f') { 'Green' } else { 'Red' })
        Write-Host "    Restricted: $($fields[4])" -ForegroundColor $(if ($fields[4] -eq 'f') { 'Green' } else { 'Red' })
        Write-Host "    Rejected: $($fields[5])" -ForegroundColor $(if ($fields[5] -eq 'f') { 'Green' } else { 'Red' })
        return $true
    } else {
        Write-Host "  [ERROR] User not found!" -ForegroundColor Red
        return $false
    }
}

# Main execution logic
if ($ApproveOnly) {
    # Mode: Approve only
    Write-Host "Mode: Approve existing user only" -ForegroundColor Cyan
    Write-Host ""
    
    if (-not (Test-AdminUserExists)) {
        Write-Host "  [ERROR] Admin user does not exist. Use without -ApproveOnly to create." -ForegroundColor Red
        exit 1
    }
    
    if (Approve-AdminUser) {
        Test-AdminUser
    } else {
        exit 1
    }
} else {
    # Mode: Full setup (default) or Recreate
    if ($Recreate -or -not (Test-AdminUserExists)) {
        Write-Host "Mode: Full setup (create new admin user)" -ForegroundColor Cyan
        Write-Host ""
        
        # Step 1: Delete existing user (if recreating)
        if ($Recreate -or (Test-AdminUserExists)) {
            Remove-AdminUser
        }
        
        # Step 2: Create user via API
        if (-not (New-AdminUser)) {
            Write-Host ""
            Write-Host "Failed to create admin user. Please check:" -ForegroundColor Red
            Write-Host "  1. Services are running: docker compose ps" -ForegroundColor Gray
            Write-Host "  2. API gateway is accessible: http://localhost:8080/api/auth/health" -ForegroundColor Gray
            Write-Host "  3. Check logs: docker logs library-auth-service --tail 50" -ForegroundColor Gray
            exit 1
        }
        
        # Step 3: Approve user
        if (-not (Approve-AdminUser)) {
            exit 1
        }
        
        # Step 4: Verify
        if (-not (Test-AdminUser)) {
            exit 1
        }
    } else {
        # User exists, just approve if needed
        Write-Host "Mode: Approve existing user" -ForegroundColor Cyan
        Write-Host ""
        
        $userInfo = docker exec library-postgres psql -U postgres -d user_db -t -A -F "|" -c "SELECT pending_approval, restricted, rejected FROM users WHERE username = '$adminUsername';"
        if ($userInfo) {
            $fields = $userInfo -split '\|'
            $needsApproval = $fields[0] -eq 't' -or $fields[1] -eq 't' -or $fields[2] -eq 't'
            
            if ($needsApproval) {
                Approve-AdminUser
                Test-AdminUser
            } else {
                Write-Host "  [OK] User is already approved" -ForegroundColor Green
                Test-AdminUser
            }
        }
    }
}

# Display credentials
Write-Host ""
Write-Host "=== Admin Credentials ===" -ForegroundColor Green
Write-Host "Username: $adminUsername" -ForegroundColor Cyan
Write-Host "Password: $adminPassword" -ForegroundColor Cyan
Write-Host "Email: $adminEmail" -ForegroundColor Cyan
Write-Host "Role: $adminRole" -ForegroundColor Cyan
Write-Host ""
Write-Host "You can now log in with these credentials!" -ForegroundColor Green
