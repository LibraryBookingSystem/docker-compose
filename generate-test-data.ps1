# ============================================================================
# Generate Complete Test Data Script
# ============================================================================
# This script generates comprehensive test data:
#   - Admin user (approved)
#   - Student user (auto-approved)
#   - Faculty user (approved)
#   - Resources of all types (Study Rooms, Group Rooms, Computer Stations, Seats)
#   - Booking policies
#
# Usage:
#   .\generate-test-data.ps1              # Generate all data
#   .\generate-test-data.ps1 -UsersOnly   # Only create users
#   .\generate-test-data.ps1 -ResourcesOnly # Only create resources
# ============================================================================

param(
    [switch]$UsersOnly,      # Only create users
    [switch]$ResourcesOnly   # Only create resources and policies
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$apiBaseUrl = "http://localhost:8080"
$registerUrl = "$apiBaseUrl/api/auth/register"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Generate Test Data                   " -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
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

# Function to check if user exists
function Test-UserExists {
    param([string]$Username)
    $result = docker exec library-postgres psql -U postgres -d user_db -t -A -c "SELECT username FROM users WHERE username = '$Username';" 2>&1
    return ($result -and $result.Trim() -eq $Username)
}

# Function to delete user
function Remove-User {
    param([string]$Username, [string]$Email)
    Write-Host "  Removing existing user: $Username..." -ForegroundColor Gray
    docker exec library-postgres psql -U postgres -d user_db -c "DELETE FROM users WHERE username = '$Username' OR email = '$Email';" | Out-Null
    Start-Sleep -Seconds 1
}

# Function to approve user
function Approve-User {
    param([string]$Username)
    Write-Host "  Approving user: $Username..." -ForegroundColor Gray
    docker exec library-postgres psql -U postgres -d user_db -c @"
UPDATE users 
SET pending_approval = false, 
    rejected = false, 
    restricted = false,
    updated_at = NOW()
WHERE username = '$Username';
"@ | Out-Null
}

# Function to create user via API
function New-User {
    param(
        [string]$Username,
        [string]$Email,
        [string]$Password,
        [string]$Role
    )
    
    Write-Host "  Registering user: $Username ($Role)..." -ForegroundColor Gray
    
    $userData = @{
        username = $Username
        email = $Email
        password = $Password
        role = $Role
    } | ConvertTo-Json
    
    try {
        $response = Invoke-RestMethod -Uri $registerUrl -Method Post -Body $userData -ContentType "application/json" -ErrorAction Stop
        Write-Host "    [OK] User registered successfully" -ForegroundColor Green
        Start-Sleep -Seconds 1
        return $true
    } catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        $errorMessage = $_.Exception.Message
        
        if ($statusCode -eq 409) {
            Write-Host "    [WARN] User already exists" -ForegroundColor Yellow
            return $true
        } elseif ($statusCode -eq 401 -or $statusCode -eq 503) {
            # For ADMIN/FACULTY, registration might fail due to pending approval,
            # but the user might still be created. Check if user exists.
            Start-Sleep -Seconds 2  # Wait for user-service to process
            if (Test-UserExists $Username) {
                Write-Host "    [OK] User was created but pending approval (this is expected)" -ForegroundColor Yellow
                return $true
            } else {
                Write-Host "    [ERROR] Registration failed: $errorMessage" -ForegroundColor Red
                Write-Host "    [INFO] Status Code: $statusCode" -ForegroundColor Gray
                return $false
            }
        } else {
            Write-Host "    [ERROR] Registration failed: $errorMessage" -ForegroundColor Red
            if ($statusCode) {
                Write-Host "    [INFO] Status Code: $statusCode" -ForegroundColor Gray
            }
            # Check if user was still created despite the error
            Start-Sleep -Seconds 2
            if (Test-UserExists $Username) {
                Write-Host "    [INFO] User exists in database, continuing..." -ForegroundColor Yellow
                return $true
            }
            return $false
        }
    }
}

# ============================================================================
# STEP 1: Create Users
# ============================================================================
if (-not $ResourcesOnly) {
    Write-Host "[1/3] Creating users..." -ForegroundColor Yellow
    Write-Host ""
    
    # Admin User
    Write-Host "Admin User:" -ForegroundColor Cyan
    $adminUsername = "admin1"
    $adminEmail = "admin@gmail.com"
    $adminPassword = "12345678a"
    
    if (Test-UserExists $adminUsername) {
        Remove-User $adminUsername $adminEmail
    }
    
    $adminCreated = New-User $adminUsername $adminEmail $adminPassword "ADMIN"
    # Always try to approve if user exists (even if registration seemed to fail)
    if (Test-UserExists $adminUsername) {
        Approve-User $adminUsername
        Write-Host "    [OK] Admin user approved" -ForegroundColor Green
    } elseif (-not $adminCreated) {
        Write-Host "    [WARN] Admin user creation failed, skipping approval" -ForegroundColor Yellow
    }
    Write-Host ""
    
    # Student User
    Write-Host "Student User:" -ForegroundColor Cyan
    $studentUsername = "student1"
    $studentEmail = "student1@example.com"
    $studentPassword = "12345678s"
    
    if (Test-UserExists $studentUsername) {
        Remove-User $studentUsername $studentEmail
    }
    
    # Students are auto-approved, so no need to approve
    New-User $studentUsername $studentEmail $studentPassword "STUDENT" | Out-Null
    Write-Host ""
    
    # Faculty User
    Write-Host "Faculty User:" -ForegroundColor Cyan
    $facultyUsername = "faculty1"
    $facultyEmail = "faculty1@example.com"
    $facultyPassword = "12345678f"
    
    if (Test-UserExists $facultyUsername) {
        Remove-User $facultyUsername $facultyEmail
    }
    
    $facultyCreated = New-User $facultyUsername $facultyEmail $facultyPassword "FACULTY"
    # Always try to approve if user exists (even if registration seemed to fail)
    if (Test-UserExists $facultyUsername) {
        Approve-User $facultyUsername
        Write-Host "    [OK] Faculty user approved" -ForegroundColor Green
    } elseif (-not $facultyCreated) {
        Write-Host "    [WARN] Faculty user creation failed, skipping approval" -ForegroundColor Yellow
    }
    Write-Host ""
}

# ============================================================================
# STEP 2: Create Resources
# ============================================================================
if (-not $UsersOnly) {
    Write-Host "[2/3] Creating resources..." -ForegroundColor Yellow
    
    # Wait for catalog service to be ready
    Write-Host "  Waiting for catalog service to initialize tables..." -ForegroundColor Gray
    Start-Sleep -Seconds 5
    
    # Create SQL file for resources
    $catalogSql = @"
-- Delete existing resources (for clean regeneration)
DELETE FROM resource_amenities;
DELETE FROM resources;

-- Insert resources of all types
INSERT INTO resources (name, type, capacity, floor, location_x, location_y, status, created_at, updated_at) VALUES
-- Study Rooms
('Study Room 101', 'STUDY_ROOM', 4, 1, 10.5, 20.3, 'AVAILABLE', NOW(), NOW()),
('Study Room 102', 'STUDY_ROOM', 6, 1, 15.2, 20.3, 'AVAILABLE', NOW(), NOW()),
('Study Room 201', 'STUDY_ROOM', 4, 2, 10.5, 25.0, 'AVAILABLE', NOW(), NOW()),
('Study Room 202', 'STUDY_ROOM', 6, 2, 15.2, 25.0, 'AVAILABLE', NOW(), NOW()),
('Study Room 301', 'STUDY_ROOM', 8, 3, 10.5, 30.0, 'AVAILABLE', NOW(), NOW()),

-- Group Rooms
('Group Room A', 'GROUP_ROOM', 10, 1, 20.0, 25.0, 'AVAILABLE', NOW(), NOW()),
('Group Room B', 'GROUP_ROOM', 12, 2, 20.0, 30.0, 'AVAILABLE', NOW(), NOW()),
('Group Room C', 'GROUP_ROOM', 15, 3, 20.0, 35.0, 'UNAVAILABLE', NOW(), NOW()),

-- Computer Stations
('Computer Station 1', 'COMPUTER_STATION', 1, 1, 5.0, 10.0, 'AVAILABLE', NOW(), NOW()),
('Computer Station 2', 'COMPUTER_STATION', 1, 1, 8.0, 12.0, 'AVAILABLE', NOW(), NOW()),
('Computer Station 3', 'COMPUTER_STATION', 1, 1, 12.0, 15.0, 'AVAILABLE', NOW(), NOW()),
('Computer Station 4', 'COMPUTER_STATION', 1, 2, 5.0, 15.0, 'AVAILABLE', NOW(), NOW()),
('Computer Station 5', 'COMPUTER_STATION', 1, 2, 8.0, 18.0, 'UNAVAILABLE', NOW(), NOW()),
('Computer Station 6', 'COMPUTER_STATION', 1, 2, 12.0, 20.0, 'AVAILABLE', NOW(), NOW()),
('Computer Station 7', 'COMPUTER_STATION', 1, 3, 5.0, 20.0, 'AVAILABLE', NOW(), NOW()),
('Computer Station 8', 'COMPUTER_STATION', 1, 3, 8.0, 25.0, 'AVAILABLE', NOW(), NOW()),

-- Seats
('Quiet Study Seat 1', 'SEAT', 1, 1, 25.0, 10.0, 'AVAILABLE', NOW(), NOW()),
('Quiet Study Seat 2', 'SEAT', 1, 1, 25.0, 12.0, 'AVAILABLE', NOW(), NOW()),
('Quiet Study Seat 3', 'SEAT', 1, 1, 25.0, 15.0, 'AVAILABLE', NOW(), NOW()),
('Quiet Study Seat 4', 'SEAT', 1, 2, 25.0, 18.0, 'AVAILABLE', NOW(), NOW()),
('Quiet Study Seat 5', 'SEAT', 1, 2, 25.0, 20.0, 'UNAVAILABLE', NOW(), NOW()),
('Quiet Study Seat 6', 'SEAT', 1, 2, 25.0, 22.0, 'AVAILABLE', NOW(), NOW()),
('Quiet Study Seat 7', 'SEAT', 1, 3, 25.0, 25.0, 'AVAILABLE', NOW(), NOW()),
('Quiet Study Seat 8', 'SEAT', 1, 3, 25.0, 28.0, 'AVAILABLE', NOW(), NOW()),
('Quiet Study Seat 9', 'SEAT', 1, 3, 25.0, 30.0, 'AVAILABLE', NOW(), NOW());

-- Insert amenities for rooms (STUDY_ROOM and GROUP_ROOM)
DO `$`$
DECLARE
    room_ids INTEGER[];
BEGIN
    -- Get IDs of room resources
    SELECT ARRAY_AGG(id) INTO room_ids FROM resources WHERE type IN ('STUDY_ROOM', 'GROUP_ROOM');
    
    -- Add amenities to each room
    IF room_ids IS NOT NULL THEN
        -- First study room - basic amenities
        IF array_length(room_ids, 1) >= 1 THEN
            INSERT INTO resource_amenities (resource_id, amenity) 
            SELECT room_ids[1], amenity FROM (VALUES ('WiFi'), ('Power Outlets'), ('Whiteboard')) AS t(amenity);
        END IF;
        
        -- Second study room - more amenities
        IF array_length(room_ids, 1) >= 2 THEN
            INSERT INTO resource_amenities (resource_id, amenity) 
            SELECT room_ids[2], amenity FROM (VALUES ('WiFi'), ('Power Outlets'), ('Whiteboard'), ('Projector')) AS t(amenity);
        END IF;
        
        -- Third study room - basic
        IF array_length(room_ids, 1) >= 3 THEN
            INSERT INTO resource_amenities (resource_id, amenity) 
            SELECT room_ids[3], amenity FROM (VALUES ('WiFi'), ('Power Outlets')) AS t(amenity);
        END IF;
        
        -- Fourth study room
        IF array_length(room_ids, 1) >= 4 THEN
            INSERT INTO resource_amenities (resource_id, amenity) 
            SELECT room_ids[4], amenity FROM (VALUES ('WiFi'), ('Power Outlets'), ('Whiteboard')) AS t(amenity);
        END IF;
        
        -- Fifth study room - premium
        IF array_length(room_ids, 1) >= 5 THEN
            INSERT INTO resource_amenities (resource_id, amenity) 
            SELECT room_ids[5], amenity FROM (VALUES ('WiFi'), ('Power Outlets'), ('Whiteboard'), ('Projector'), ('Video Conference')) AS t(amenity);
        END IF;
        
        -- First group room
        IF array_length(room_ids, 1) >= 6 THEN
            INSERT INTO resource_amenities (resource_id, amenity) 
            SELECT room_ids[6], amenity FROM (VALUES ('WiFi'), ('Power Outlets'), ('Whiteboard'), ('Projector')) AS t(amenity);
        END IF;
        
        -- Second group room
        IF array_length(room_ids, 1) >= 7 THEN
            INSERT INTO resource_amenities (resource_id, amenity) 
            SELECT room_ids[7], amenity FROM (VALUES ('WiFi'), ('Power Outlets'), ('Whiteboard'), ('Projector'), ('Video Conference')) AS t(amenity);
        END IF;
        
        -- Third group room
        IF array_length(room_ids, 1) >= 8 THEN
            INSERT INTO resource_amenities (resource_id, amenity) 
            SELECT room_ids[8], amenity FROM (VALUES ('WiFi'), ('Power Outlets'), ('Whiteboard'), ('Projector'), ('Video Conference'), ('Sound System')) AS t(amenity);
        END IF;
    END IF;
END `$`$;
"@
    
    # Write SQL to temp file and copy to container
    $tempSqlFile = Join-Path $env:TEMP "generate-resources.sql"
    $catalogSql | Out-File -FilePath $tempSqlFile -Encoding UTF8
    
    Write-Host "  Copying resources SQL to container..." -ForegroundColor Gray
    docker cp $tempSqlFile library-postgres:/tmp/generate-resources.sql | Out-Null
    
    Write-Host "  Inserting resources..." -ForegroundColor Gray
    docker exec -i library-postgres psql -U postgres -d catalog_db -f /tmp/generate-resources.sql | Out-Null
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "    [OK] Resources created successfully" -ForegroundColor Green
    } else {
        Write-Host "    [ERROR] Failed to create resources" -ForegroundColor Red
    }
    
    # Clean up temp file
    Remove-Item $tempSqlFile -ErrorAction SilentlyContinue
    Write-Host ""
}

# ============================================================================
# STEP 3: Create Policies
# ============================================================================
if (-not $UsersOnly) {
    Write-Host "[3/3] Creating booking policies..." -ForegroundColor Yellow
    
    $policySql = @"
-- Delete existing policies (for clean regeneration)
DELETE FROM booking_policies;

-- Insert default booking policies
INSERT INTO booking_policies (name, max_duration_minutes, max_advance_days, max_concurrent_bookings, grace_period_minutes, is_active, created_at, updated_at) VALUES
('Default Student Policy', 240, 7, 3, 15, true, NOW(), NOW()),
('Default Faculty Policy', 480, 14, 5, 30, true, NOW(), NOW()),
('Default Admin Policy', 1440, 30, 10, 60, true, NOW(), NOW()),
('Peak Hours Policy', 120, 3, 2, 10, true, NOW(), NOW());
"@
    
    $tempPolicyFile = Join-Path $env:TEMP "generate-policies.sql"
    $policySql | Out-File -FilePath $tempPolicyFile -Encoding UTF8
    
    Write-Host "  Copying policies SQL to container..." -ForegroundColor Gray
    docker cp $tempPolicyFile library-postgres:/tmp/generate-policies.sql | Out-Null
    
    Write-Host "  Inserting policies..." -ForegroundColor Gray
    docker exec -i library-postgres psql -U postgres -d policy_db -f /tmp/generate-policies.sql | Out-Null
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "    [OK] Policies created successfully" -ForegroundColor Green
    } else {
        Write-Host "    [ERROR] Failed to create policies" -ForegroundColor Red
    }
    
    Remove-Item $tempPolicyFile -ErrorAction SilentlyContinue
    Write-Host ""
}

# ============================================================================
# Summary
# ============================================================================
Write-Host "========================================" -ForegroundColor Green
Write-Host "  Test Data Generation Complete!       " -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

if (-not $ResourcesOnly) {
    Write-Host "User Credentials:" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Admin:" -ForegroundColor Yellow
    Write-Host "  Username: admin1" -ForegroundColor White
    Write-Host "  Password: 12345678a" -ForegroundColor White
    Write-Host "  Email: admin@gmail.com" -ForegroundColor White
    Write-Host "  Role: ADMIN" -ForegroundColor White
    Write-Host ""
    Write-Host "Student:" -ForegroundColor Yellow
    Write-Host "  Username: student1" -ForegroundColor White
    Write-Host "  Password: 12345678s" -ForegroundColor White
    Write-Host "  Email: student1@example.com" -ForegroundColor White
    Write-Host "  Role: STUDENT (auto-approved)" -ForegroundColor White
    Write-Host ""
    Write-Host "Faculty:" -ForegroundColor Yellow
    Write-Host "  Username: faculty1" -ForegroundColor White
    Write-Host "  Password: 12345678f" -ForegroundColor White
    Write-Host "  Email: faculty1@example.com" -ForegroundColor White
    Write-Host "  Role: FACULTY" -ForegroundColor White
    Write-Host ""
}

if (-not $UsersOnly) {
    Write-Host "Resources Created:" -ForegroundColor Cyan
    Write-Host "  - 5 Study Rooms" -ForegroundColor White
    Write-Host "  - 3 Group Rooms" -ForegroundColor White
    Write-Host "  - 8 Computer Stations" -ForegroundColor White
    Write-Host "  - 9 Quiet Study Seats" -ForegroundColor White
    Write-Host ""
    Write-Host "Policies Created:" -ForegroundColor Cyan
    Write-Host "  - Default Student Policy" -ForegroundColor White
    Write-Host "  - Default Faculty Policy" -ForegroundColor White
    Write-Host "  - Default Admin Policy" -ForegroundColor White
    Write-Host "  - Peak Hours Policy" -ForegroundColor White
    Write-Host ""
}

Write-Host "You can now test the system with these credentials!" -ForegroundColor Green
Write-Host ""

