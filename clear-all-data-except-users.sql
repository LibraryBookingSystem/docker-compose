-- ============================================================================
-- Clear All Data Except Users
-- ============================================================================
-- This script deletes all data from all databases EXCEPT user data
-- Run this script to reset the system for testing while keeping user accounts
--
-- Usage:
--   PowerShell: docker exec -i library-postgres psql -U postgres -d <database> -f /tmp/clear-all-data-except-users.sql
--   Or use the PowerShell script: clear-all-data-except-users.ps1
-- ============================================================================

-- ============================================================================
-- SECTION 1: BOOKING_DB - Delete all bookings
-- ============================================================================
-- Database: booking_db
-- Tables: bookings

-- Delete all bookings
TRUNCATE TABLE bookings CASCADE;

-- ============================================================================
-- SECTION 2: CATALOG_DB - Delete all resources
-- ============================================================================
-- Database: catalog_db
-- Tables: resources, resource_amenities

-- Delete resource amenities first (foreign key constraint)
DELETE FROM resource_amenities;

-- Delete all resources
TRUNCATE TABLE resources CASCADE;

-- ============================================================================
-- SECTION 3: POLICY_DB - Delete all policies
-- ============================================================================
-- Database: policy_db
-- Tables: booking_policies

-- Delete all booking policies
TRUNCATE TABLE booking_policies CASCADE;

-- ============================================================================
-- SECTION 4: NOTIFICATION_DB - Delete all notifications
-- ============================================================================
-- Database: notification_db
-- Tables: notifications

-- Delete all notifications
TRUNCATE TABLE notifications CASCADE;

-- ============================================================================
-- SECTION 5: ANALYTICS_DB - Delete all analytics data
-- ============================================================================
-- Database: analytics_db
-- Tables: usage_statistics, analytics_events (if they exist)

-- Delete analytics data (tables may not exist, so we use IF EXISTS pattern)
DO $$
BEGIN
    -- Delete usage statistics if table exists
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'usage_statistics') THEN
        TRUNCATE TABLE usage_statistics CASCADE;
    END IF;
    
    -- Delete analytics events if table exists
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'analytics_events') THEN
        TRUNCATE TABLE analytics_events CASCADE;
    END IF;
END $$;

-- ============================================================================
-- VERIFICATION QUERIES (uncomment to verify deletion)
-- ============================================================================
-- SELECT 'bookings' as table_name, COUNT(*) as count FROM bookings
-- UNION ALL
-- SELECT 'resources', COUNT(*) FROM resources
-- UNION ALL
-- SELECT 'booking_policies', COUNT(*) FROM booking_policies
-- UNION ALL
-- SELECT 'notifications', COUNT(*) FROM notifications;

