-- ============================================================================
-- Dummy Data Initialization Script for Library Booking System
-- ============================================================================
-- IMPORTANT: Run this script AFTER all services have started and created their tables
-- 
-- This is a COMPREHENSIVE merged file containing all dummy data sections.
-- Each section targets a different database and must be run separately.
--
-- For automated execution, use: init-dummy-data-all.ps1
--
-- Manual execution per database:
--   Section 1 (catalog_db):
--     docker exec -i library-postgres psql -U postgres -d catalog_db -f /tmp/init-dummy-data.sql
--     (or extract Section 1 and run it)
--
--   Section 2 (policy_db):
--     docker exec -i library-postgres psql -U postgres -d policy_db -f /tmp/init-dummy-data.sql
--     (or extract Section 2 and run it)
--
--   Section 3 (user_db):
--     powershell -ExecutionPolicy Bypass -File setup-admin-user.ps1
--
-- ============================================================================

-- ============================================================================
-- SECTION 1: CATALOG_DB - Dummy Resources
-- ============================================================================
-- Database: catalog_db
-- Creates: 18 resources (6 study rooms, 6 computer stations, 6 seats) + amenities
-- 
-- To run this section:
--   docker exec -i library-postgres psql -U postgres -d catalog_db << 'EOF'
--   [copy Section 1 SQL here]
--   EOF

-- Insert dummy resources (study rooms, computer stations, seats)
-- Only insert if table is empty to avoid duplicates
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM resources LIMIT 1) THEN
        INSERT INTO resources (name, type, capacity, floor, location_x, location_y, status, created_at, updated_at) VALUES
        -- Study Rooms
        ('Study Room 101', 'STUDY_ROOM', 4, 1, 10.5, 20.3, 'AVAILABLE', NOW(), NOW()),
        ('Study Room 102', 'STUDY_ROOM', 6, 1, 15.2, 20.3, 'AVAILABLE', NOW(), NOW()),
        ('Study Room 201', 'STUDY_ROOM', 4, 2, 10.5, 25.0, 'AVAILABLE', NOW(), NOW()),
        ('Study Room 202', 'GROUP_ROOM', 8, 2, 15.2, 25.0, 'UNAVAILABLE', NOW(), NOW()),
        ('Study Room 301', 'STUDY_ROOM', 6, 3, 10.5, 30.0, 'AVAILABLE', NOW(), NOW()),
        ('Study Room 302', 'GROUP_ROOM', 10, 3, 15.2, 30.0, 'AVAILABLE', NOW(), NOW()),

        -- Computer Stations
        ('Computer Station 1', 'COMPUTER_STATION', 1, 1, 5.0, 10.0, 'AVAILABLE', NOW(), NOW()),
        ('Computer Station 2', 'COMPUTER_STATION', 1, 2, 5.0, 15.0, 'AVAILABLE', NOW(), NOW()),
        ('Computer Station 3', 'COMPUTER_STATION', 1, 1, 8.0, 12.0, 'AVAILABLE', NOW(), NOW()),
        ('Computer Station 4', 'COMPUTER_STATION', 1, 2, 8.0, 18.0, 'UNAVAILABLE', NOW(), NOW()),
        ('Computer Station 5', 'COMPUTER_STATION', 1, 1, 12.0, 15.0, 'AVAILABLE', NOW(), NOW()),
        ('Computer Station 6', 'COMPUTER_STATION', 1, 2, 12.0, 20.0, 'AVAILABLE', NOW(), NOW()),

        -- Seats
        ('Quiet Study Seat 1', 'SEAT', 1, 1, 20.0, 10.0, 'AVAILABLE', NOW(), NOW()),
        ('Quiet Study Seat 2', 'SEAT', 1, 1, 20.0, 12.0, 'AVAILABLE', NOW(), NOW()),
        ('Quiet Study Seat 3', 'SEAT', 1, 2, 20.0, 15.0, 'AVAILABLE', NOW(), NOW()),
        ('Quiet Study Seat 4', 'SEAT', 1, 2, 20.0, 18.0, 'UNAVAILABLE', NOW(), NOW()),
        ('Quiet Study Seat 5', 'SEAT', 1, 3, 20.0, 20.0, 'AVAILABLE', NOW(), NOW()),
        ('Quiet Study Seat 6', 'SEAT', 1, 3, 20.0, 22.0, 'AVAILABLE', NOW(), NOW());
    END IF;
END $$;

-- Insert amenities for rooms (assuming resources get IDs 1-18)
-- Note: This will only work if resources were inserted successfully
DO $$
DECLARE
    room_ids INTEGER[];
BEGIN
    -- Get IDs of room resources (STUDY_ROOM and GROUP_ROOM)
    SELECT ARRAY_AGG(id) INTO room_ids FROM resources WHERE type IN ('STUDY_ROOM', 'GROUP_ROOM');
    
    -- Insert amenities for each room
    IF room_ids IS NOT NULL THEN
        -- Room 1 (first room)
        IF array_length(room_ids, 1) >= 1 THEN
            INSERT INTO resource_amenities (resource_id, amenity) 
            SELECT room_ids[1], 'WiFi' WHERE NOT EXISTS (SELECT 1 FROM resource_amenities WHERE resource_id = room_ids[1] AND amenity = 'WiFi')
            UNION ALL
            SELECT room_ids[1], 'Power Outlets' WHERE NOT EXISTS (SELECT 1 FROM resource_amenities WHERE resource_id = room_ids[1] AND amenity = 'Power Outlets')
            UNION ALL
            SELECT room_ids[1], 'Whiteboard' WHERE NOT EXISTS (SELECT 1 FROM resource_amenities WHERE resource_id = room_ids[1] AND amenity = 'Whiteboard');
        END IF;
        
        -- Room 2
        IF array_length(room_ids, 1) >= 2 THEN
            INSERT INTO resource_amenities (resource_id, amenity) 
            SELECT room_ids[2], amenity FROM (VALUES ('WiFi'), ('Power Outlets'), ('Whiteboard'), ('Projector')) AS t(amenity)
            WHERE NOT EXISTS (SELECT 1 FROM resource_amenities WHERE resource_id = room_ids[2] AND amenity = t.amenity);
        END IF;
        
        -- Room 3
        IF array_length(room_ids, 1) >= 3 THEN
            INSERT INTO resource_amenities (resource_id, amenity) 
            SELECT room_ids[3], amenity FROM (VALUES ('WiFi'), ('Power Outlets')) AS t(amenity)
            WHERE NOT EXISTS (SELECT 1 FROM resource_amenities WHERE resource_id = room_ids[3] AND amenity = t.amenity);
        END IF;
        
        -- Room 4
        IF array_length(room_ids, 1) >= 4 THEN
            INSERT INTO resource_amenities (resource_id, amenity) 
            SELECT room_ids[4], amenity FROM (VALUES ('WiFi'), ('Power Outlets'), ('Whiteboard'), ('Projector')) AS t(amenity)
            WHERE NOT EXISTS (SELECT 1 FROM resource_amenities WHERE resource_id = room_ids[4] AND amenity = t.amenity);
        END IF;
        
        -- Room 5
        IF array_length(room_ids, 1) >= 5 THEN
            INSERT INTO resource_amenities (resource_id, amenity) 
            SELECT room_ids[5], amenity FROM (VALUES ('WiFi'), ('Power Outlets'), ('Whiteboard')) AS t(amenity)
            WHERE NOT EXISTS (SELECT 1 FROM resource_amenities WHERE resource_id = room_ids[5] AND amenity = t.amenity);
        END IF;
        
        -- Room 6
        IF array_length(room_ids, 1) >= 6 THEN
            INSERT INTO resource_amenities (resource_id, amenity) 
            SELECT room_ids[6], amenity FROM (VALUES ('WiFi'), ('Power Outlets'), ('Whiteboard'), ('Projector'), ('Video Conference')) AS t(amenity)
            WHERE NOT EXISTS (SELECT 1 FROM resource_amenities WHERE resource_id = room_ids[6] AND amenity = t.amenity);
        END IF;
    END IF;
END $$;

-- ============================================================================
-- SECTION 2: POLICY_DB - Dummy Booking Policies
-- ============================================================================
-- Database: policy_db
-- Creates: 4 default booking policies
--
-- To run this section:
--   docker exec -i library-postgres psql -U postgres -d policy_db << 'EOF'
--   [copy Section 2 SQL here]
--   EOF

-- Insert default booking policies
INSERT INTO booking_policies (name, max_duration_minutes, max_advance_days, max_concurrent_bookings, grace_period_minutes, is_active, created_at, updated_at) VALUES
('Default Student Policy', 240, 7, 3, 15, true, NOW(), NOW()),
('Default Faculty Policy', 480, 14, 5, 30, true, NOW(), NOW()),
('Default Admin Policy', 1440, 30, 10, 60, true, NOW(), NOW()),
('Peak Hours Policy', 120, 3, 2, 10, true, NOW(), NOW())
ON CONFLICT (name) DO NOTHING;

-- ============================================================================
-- SECTION 3: USER_DB - Hardcoded Users (Admin, Student, Faculty)
-- ============================================================================
-- Database: user_db
-- Creates: 3 hardcoded users (admin1, student1, faculty1)
--
-- IMPORTANT: Users should be created via API to ensure correct password hashing
-- Use: powershell -ExecutionPolicy Bypass -File setup-admin-user.ps1
--      powershell -ExecutionPolicy Bypass -File setup-dummy-users.ps1
--
-- User credentials:
--   Admin:
--     Username: admin1
--     Password: 12345678a
--     Email: admin@gmail.com
--     Role: ADMIN
--
--   Student:
--     Username: student1
--     Password: 12345678s
--     Email: student1@example.com
--     Role: STUDENT
--
--   Faculty:
--     Username: faculty1
--     Password: 12345678f
--     Email: faculty1@example.com
--     Role: FACULTY
--
-- NOTE: This section only approves existing users
-- The users must be created via API first (see setup scripts above)
--
-- To run this section (only if users exist):
--   docker exec -i library-postgres psql -U postgres -d user_db << 'EOF'
--   [copy Section 3 SQL here]
--   EOF

-- Update existing users to ensure they're approved
UPDATE users 
SET pending_approval = false, 
    rejected = false, 
    restricted = false,
    updated_at = NOW()
WHERE username IN ('admin1', 'student1', 'faculty1');

-- ============================================================================
-- NOTES AND SUMMARY
-- ============================================================================
-- 
-- What gets created:
--   - Resources: 18 total (6 study rooms, 6 computer stations, 6 seats)
--   - Policies: 4 default booking policies
--   - Users: 3 hardcoded users (admin1, student1, faculty1) - created via API, approved via SQL
--
-- What is NOT created here (created dynamically):
--   - Bookings: Created by users through the application
--   - Notifications: Created dynamically by the system
--   - Analytics: Generated dynamically from bookings and resources
--
-- Execution:
--   Use init-dummy-data-all.ps1 for automated execution (recommended)
--   OR run sections individually per database
--
-- File Structure:
--   - init-dummy-data.sql - This merged file (all sections)
--   - init-dummy-data-catalog.sql - Section 1 extract (for convenience)
--   - init-dummy-data-policy.sql - Section 2 extract (for convenience)
--   - setup-admin-user.ps1 - Creates admin user via API
--   - setup-dummy-users.ps1 - Creates student and faculty users via API
--
-- ============================================================================
