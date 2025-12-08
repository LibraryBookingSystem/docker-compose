-- Dummy data for catalog_db - Resources
-- Run this with: docker exec -i library-postgres psql -U postgres -d catalog_db -f /tmp/init-dummy-data-catalog.sql

-- Insert dummy resources (rooms, equipment, books)
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
