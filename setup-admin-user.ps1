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

# Admin user configurations
$admins = @(
    @{
        Username = "admin1"
        Email = "admin@gmail.com"
        Password = "12345678a"
        Role = "ADMIN"
    },
    @{
        Username = "admin2"
        Email = "admin2@gmail.com"
        Password = "12345678a"
        Role = "ADMIN"
    }
)

# Legacy single admin support (for backward compatibility)
$adminUsername = $admins[0].Username
$adminEmail = $admins[0].Email
$adminPassword = $admins[0].Password
$adminRole = $admins[0].Role

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
    param($username)
    if (-not $username) { $username = $adminUsername }
    
    Write-Host "Verifying admin user: $username..." -ForegroundColor Yellow
    $userInfo = docker exec library-postgres psql -U postgres -d user_db -t -A -F "|" -c "SELECT username, email, role, pending_approval, restricted, rejected FROM users WHERE username = '$username';"
    
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

# Function to process all admin users
function Process-AllAdmins {
    $successCount = 0
    $failCount = 0
    
    foreach ($admin in $admins) {
        Write-Host "Processing admin: $($admin.Username)..." -ForegroundColor Yellow
        
        # Check if user exists
        $exists = docker exec library-postgres psql -U postgres -d user_db -t -A -c "SELECT username FROM users WHERE username = '$($admin.Username)';" 2>&1
        $exists = ($exists -and $exists.Trim() -eq $admin.Username)
        
        if ($exists) {
            Write-Host "  User exists, checking status..." -ForegroundColor Gray
            $userInfo = docker exec library-postgres psql -U postgres -d user_db -t -A -F "|" -c "SELECT pending_approval, restricted, rejected FROM users WHERE username = '$($admin.Username)';"
            
            if ($userInfo) {
                $fields = $userInfo -split '\|'
                $needsApproval = $fields[0] -eq 't' -or $fields[1] -eq 't' -or $fields[2] -eq 't'
                
                if ($needsApproval) {
                    $updateResult = docker exec library-postgres psql -U postgres -d user_db -c @"
UPDATE users 
SET pending_approval = false, 
    rejected = false, 
    restricted = false,
    updated_at = NOW()
WHERE username = '$($admin.Username)';
"@ | Out-Null
                    
                    if ($LASTEXITCODE -eq 0) {
                        Write-Host "  [OK] User approved" -ForegroundColor Green
                        $successCount++
                    } else {
                        Write-Host "  [ERROR] Failed to approve user" -ForegroundColor Red
                        $failCount++
                    }
                } else {
                    Write-Host "  [OK] User already approved" -ForegroundColor Green
                    $successCount++
                }
            }
        } else {
            # Create new admin user
            Write-Host "  Creating new admin user..." -ForegroundColor Gray
            
            $userData = @{
                username = $admin.Username
                email = $admin.Email
                password = $admin.Password
                role = $admin.Role
            } | ConvertTo-Json
            
            try {
                $response = Invoke-RestMethod -Uri $registerUrl -Method Post -Body $userData -ContentType "application/json" -ErrorAction Stop
                Write-Host "    [OK] Registered successfully" -ForegroundColor Green
                Start-Sleep -Seconds 2
                
                # Approve the user
                $updateResult = docker exec library-postgres psql -U postgres -d user_db -c @"
UPDATE users 
SET pending_approval = false, 
    rejected = false, 
    restricted = false,
    updated_at = NOW()
WHERE username = '$($admin.Username)';
"@ | Out-Null
                
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "  [OK] User created and approved" -ForegroundColor Green
                    $successCount++
                } else {
                    Write-Host "  [WARN] User created but approval failed" -ForegroundColor Yellow
                    $successCount++
                }
            } catch {
                $statusCode = $_.Exception.Response.StatusCode.value__
                if ($statusCode -eq 409) {
                    Write-Host "    [WARN] User already exists" -ForegroundColor Yellow
                    $successCount++
                } else {
                    Write-Host "    [ERROR] Registration failed: $($_.Exception.Message)" -ForegroundColor Red
                    $failCount++
                }
            }
        }
        
        Write-Host ""
    }
    
    return @{ Success = $successCount; Failed = $failCount }
}

# Main execution logic
# Process all admin users
Write-Host "Mode: Processing all admin users" -ForegroundColor Cyan
Write-Host ""

$result = Process-AllAdmins

Write-Host "=== Summary ===" -ForegroundColor Green
Write-Host "Successfully processed: $($result.Success)" -ForegroundColor $(if ($result.Success -gt 0) { 'Green' } else { 'Red' })
Write-Host "Failed: $($result.Failed)" -ForegroundColor $(if ($result.Failed -gt 0) { 'Red' } else { 'Green' })
Write-Host ""

# Verify all admins
Write-Host "=== Verification ===" -ForegroundColor Green
foreach ($admin in $admins) {
    Test-AdminUser -username $admin.Username
    Write-Host ""
}

# Display credentials
Write-Host "=== Admin Credentials ===" -ForegroundColor Green
foreach ($admin in $admins) {
    Write-Host "Admin ($($admin.Username)):" -ForegroundColor Cyan
    Write-Host "  Username: $($admin.Username)" -ForegroundColor Gray
    Write-Host "  Password: $($admin.Password)" -ForegroundColor Gray
    Write-Host "  Email: $($admin.Email)" -ForegroundColor Gray
    Write-Host "  Role: $($admin.Role)" -ForegroundColor Gray
    Write-Host ""
}

if ($result.Failed -eq 0) {
    Write-Host "All admin users created successfully!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "Some admin users failed to create. Please check the errors above." -ForegroundColor Red
    exit 1
}
