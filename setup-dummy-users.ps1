# ============================================================================
# Dummy Users Setup Script for Library Booking System
# ============================================================================
# This script creates hardcoded student and faculty users via API
# (ensures correct password hashing)
#
# Usage:
#   .\setup-dummy-users.ps1
#
# Creates:
#   - Student: student1 / 12345678s / student1@example.com
#   - Faculty: faculty1 / 12345678f / faculty1@example.com
# ============================================================================

$ErrorActionPreference = "Stop"

# User configurations
$users = @(
    @{
        Username = "student1"
        Email = "student1@example.com"
        Password = "12345678s"
        Role = "STUDENT"
    },
    @{
        Username = "faculty1"
        Email = "faculty1@example.com"
        Password = "12345678f"
        Role = "FACULTY"
    }
)

$apiBaseUrl = "http://localhost:8080"
$registerUrl = "$apiBaseUrl/api/auth/register"

Write-Host "=== Dummy Users Setup ===" -ForegroundColor Green
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
function Test-UserExists {
    param($username)
    $result = docker exec library-postgres psql -U postgres -d user_db -t -A -c "SELECT username FROM users WHERE username = '$username';" 2>&1
    return ($result -and $result.Trim() -eq $username)
}

# Function to approve user
function Approve-User {
    param($username)
    Write-Host "  Approving $username..." -ForegroundColor Gray
    $updateResult = docker exec library-postgres psql -U postgres -d user_db -c @"
UPDATE users 
SET pending_approval = false, 
    rejected = false, 
    restricted = false,
    updated_at = NOW()
WHERE username = '$username';
"@ | Out-Null
    
    return ($LASTEXITCODE -eq 0)
}

# Function to delete user
function Remove-User {
    param($username, $email)
    docker exec library-postgres psql -U postgres -d user_db -c "DELETE FROM users WHERE username = '$username' OR email = '$email';" | Out-Null
    Start-Sleep -Seconds 1
}

# Function to create user via API
function New-User {
    param($userData)
    
    $jsonData = @{
        username = $userData.Username
        email = $userData.Email
        password = $userData.Password
        role = $userData.Role
    } | ConvertTo-Json
    
    try {
        $response = Invoke-RestMethod -Uri $registerUrl -Method Post -Body $jsonData -ContentType "application/json" -ErrorAction Stop
        Write-Host "    [OK] Registered successfully" -ForegroundColor Green
        Start-Sleep -Seconds 2  # Wait for database update
        return $true
    } catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        $errorMessage = $_.Exception.Message
        
        if ($statusCode -eq 409) {
            Write-Host "    [WARN] User already exists" -ForegroundColor Yellow
            return $true
        } else {
            Write-Host "    [ERROR] Registration failed: $errorMessage" -ForegroundColor Red
            Write-Host "    Status Code: $statusCode" -ForegroundColor Yellow
            return $false
        }
    }
}

# Process each user
$successCount = 0
$failCount = 0

foreach ($user in $users) {
    Write-Host "Processing $($user.Role) user: $($user.Username)..." -ForegroundColor Yellow
    
    # Check if user exists
    if (Test-UserExists -username $user.Username) {
        Write-Host "  User exists, checking status..." -ForegroundColor Gray
        
        # Get user status
        $userInfo = docker exec library-postgres psql -U postgres -d user_db -t -A -F "|" -c "SELECT pending_approval, restricted, rejected FROM users WHERE username = '$($user.Username)';"
        
        if ($userInfo) {
            $fields = $userInfo -split '\|'
            $needsApproval = $fields[0] -eq 't' -or $fields[1] -eq 't' -or $fields[2] -eq 't'
            
            if ($needsApproval) {
                if (Approve-User -username $user.Username) {
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
        } else {
            Write-Host "  [WARN] User exists but status unknown, attempting to approve..." -ForegroundColor Yellow
            if (Approve-User -username $user.Username) {
                $successCount++
            } else {
                $failCount++
            }
        }
    } else {
        # User doesn't exist, create it
        Write-Host "  Creating new user..." -ForegroundColor Gray
        
        if (New-User -userData $user) {
            # Approve the newly created user
            if (Approve-User -username $user.Username) {
                Write-Host "  [OK] User created and approved" -ForegroundColor Green
                $successCount++
            } else {
                Write-Host "  [WARN] User created but approval failed" -ForegroundColor Yellow
                $successCount++  # Still count as success since user was created
            }
        } else {
            Write-Host "  [ERROR] Failed to create user" -ForegroundColor Red
            $failCount++
        }
    }
    
    Write-Host ""
}

# Summary
Write-Host "=== Summary ===" -ForegroundColor Green
Write-Host "Successfully processed: $successCount" -ForegroundColor $(if ($successCount -gt 0) { 'Green' } else { 'Red' })
Write-Host "Failed: $failCount" -ForegroundColor $(if ($failCount -gt 0) { 'Red' } else { 'Green' })
Write-Host ""

# Display credentials
Write-Host "=== User Credentials ===" -ForegroundColor Green
foreach ($user in $users) {
    Write-Host "$($user.Role):" -ForegroundColor Cyan
    Write-Host "  Username: $($user.Username)" -ForegroundColor Gray
    Write-Host "  Password: $($user.Password)" -ForegroundColor Gray
    Write-Host "  Email: $($user.Email)" -ForegroundColor Gray
    Write-Host ""
}

if ($failCount -eq 0) {
    Write-Host "All users created successfully!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "Some users failed to create. Please check the errors above." -ForegroundColor Red
    exit 1
}
