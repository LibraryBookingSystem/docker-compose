# ============================================================================
# Minimal Users Setup Script for Library Booking System
# ============================================================================
# This script creates only 4 users:
#   - 1 Admin user
#   - 1 Faculty user
#   - 2 Student users (student1, student2)
# No resources, policies, or other dummy data
#
# Usage:
#   .\setup-minimal-users.ps1
# ============================================================================

$ErrorActionPreference = "Stop"

$apiBaseUrl = "http://localhost:8080"

Write-Host "=== Minimal Users Setup (Admin + Faculty + 2 Students) ===" -ForegroundColor Green
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

Write-Host ""
Write-Host "Creating admin user..." -ForegroundColor Yellow
& "$PSScriptRoot\setup-admin-user.ps1"
if ($LASTEXITCODE -ne 0) {
    Write-Host "  [ERROR] Failed to create admin user" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Creating faculty user..." -ForegroundColor Yellow

# Faculty user configuration
$facultyUsername = "faculty1"
$facultyEmail = "faculty1@example.com"
$facultyPassword = "12345678f"
$facultyRole = "FACULTY"
$registerUrl = "$apiBaseUrl/api/auth/register"

# Function to check if user exists
function Test-UserExists {
    param($username)
    $result = docker exec library-postgres psql -U postgres -d user_db -t -A -c "SELECT username FROM users WHERE username = '$username';" 2>&1
    return ($result -and $result.Trim() -eq $username)
}

# Function to approve user
function Approve-User {
    param($username)
    docker exec library-postgres psql -U postgres -d user_db -c @"
UPDATE users 
SET pending_approval = false, 
    rejected = false, 
    restricted = false,
    updated_at = NOW()
WHERE username = '$username';
"@ | Out-Null
    return ($LASTEXITCODE -eq 0)
}

# Function to create user via API
function New-User {
    param($username, $email, $password, $role)
    
    $userData = @{
        username = $username
        email = $email
        password = $password
        role = $role
    } | ConvertTo-Json
    
    try {
        $response = Invoke-RestMethod -Uri $registerUrl -Method Post -Body $userData -ContentType "application/json" -ErrorAction Stop
        Start-Sleep -Seconds 2
        return $true
    } catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        if ($statusCode -eq 409) {
            return $true  # User already exists
        }
        return $false
    }
}

# Create faculty user
if (Test-UserExists -username $facultyUsername) {
    Write-Host "  Faculty user exists, approving..." -ForegroundColor Gray
    if (Approve-User -username $facultyUsername) {
        Write-Host "  [OK] Faculty user approved" -ForegroundColor Green
    } else {
        Write-Host "  [ERROR] Failed to approve faculty user" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "  Creating faculty user..." -ForegroundColor Gray
    if (New-User -username $facultyUsername -email $facultyEmail -password $facultyPassword -role $facultyRole) {
        if (Approve-User -username $facultyUsername) {
            Write-Host "  [OK] Faculty user created and approved" -ForegroundColor Green
        } else {
            Write-Host "  [WARN] Faculty user created but approval failed" -ForegroundColor Yellow
        }
    } else {
        Write-Host "  [ERROR] Failed to create faculty user" -ForegroundColor Red
        exit 1
    }
}

Write-Host ""
Write-Host "Creating student users..." -ForegroundColor Yellow

# Student users configuration
$students = @(
    @{
        Username = "student1"
        Email = "student1@example.com"
        Password = "12345678s"
        Role = "STUDENT"
    },
    @{
        Username = "student2"
        Email = "student2@example.com"
        Password = "12345678s"
        Role = "STUDENT"
    }
)

# Function to create or approve a user
function CreateOrApprove-User {
    param($username, $email, $password, $role)
    
    if (Test-UserExists -username $username) {
        Write-Host "  $username exists, approving..." -ForegroundColor Gray
        if (Approve-User -username $username) {
            Write-Host "  [OK] $username approved" -ForegroundColor Green
            return $true
        } else {
            Write-Host "  [ERROR] Failed to approve $username" -ForegroundColor Red
            return $false
        }
    } else {
        Write-Host "  Creating $username..." -ForegroundColor Gray
        if (New-User -username $username -email $email -password $password -role $role) {
            if (Approve-User -username $username) {
                Write-Host "  [OK] $username created and approved" -ForegroundColor Green
                return $true
            } else {
                Write-Host "  [WARN] $username created but approval failed" -ForegroundColor Yellow
                return $true  # Still count as success
            }
        } else {
            Write-Host "  [ERROR] Failed to create $username" -ForegroundColor Red
            return $false
        }
    }
}

# Create all students
$studentSuccess = $true
foreach ($student in $students) {
    if (-not (CreateOrApprove-User -username $student.Username -email $student.Email -password $student.Password -role $student.Role)) {
        $studentSuccess = $false
    }
}

if (-not $studentSuccess) {
    Write-Host "  [ERROR] Some students failed to create" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "=== User Credentials ===" -ForegroundColor Green
Write-Host "Admin:" -ForegroundColor Cyan
Write-Host "  Username: admin1" -ForegroundColor Gray
Write-Host "  Password: 12345678a" -ForegroundColor Gray
Write-Host "  Email: admin@gmail.com" -ForegroundColor Gray
Write-Host ""
Write-Host "Faculty:" -ForegroundColor Cyan
Write-Host "  Username: faculty1" -ForegroundColor Gray
Write-Host "  Password: 12345678f" -ForegroundColor Gray
Write-Host "  Email: faculty1@example.com" -ForegroundColor Gray
Write-Host ""
Write-Host "Students:" -ForegroundColor Cyan
foreach ($student in $students) {
    Write-Host "  Username: $($student.Username)" -ForegroundColor Gray
    Write-Host "  Password: $($student.Password)" -ForegroundColor Gray
    Write-Host "  Email: $($student.Email)" -ForegroundColor Gray
    Write-Host ""
}
Write-Host "Done! 4 users created (1 admin, 1 faculty, 2 students - no resources or policies)." -ForegroundColor Green

