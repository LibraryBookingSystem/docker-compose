-- Dummy data for policy_db - Booking Policies
-- Run this with: docker exec -i library-postgres psql -U postgres -d policy_db -f /tmp/init-dummy-data-policy.sql

-- Insert default booking policies
INSERT INTO booking_policies (name, max_duration_minutes, max_advance_days, max_concurrent_bookings, grace_period_minutes, is_active, created_at, updated_at) VALUES
('Default Student Policy', 240, 7, 3, 15, true, NOW(), NOW()),
('Default Faculty Policy', 480, 14, 5, 30, true, NOW(), NOW()),
('Default Admin Policy', 1440, 30, 10, 60, true, NOW(), NOW()),
('Peak Hours Policy', 120, 3, 2, 10, true, NOW(), NOW())
ON CONFLICT (name) DO NOTHING;
