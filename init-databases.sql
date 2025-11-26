-- Create databases for each service
-- This script runs when PostgreSQL container starts for the first time

CREATE DATABASE user_db;
CREATE DATABASE catalog_db;
CREATE DATABASE booking_db;
CREATE DATABASE policy_db;
CREATE DATABASE notification_db;
CREATE DATABASE analytics_db;

-- Grant privileges
GRANT ALL PRIVILEGES ON DATABASE user_db TO postgres;
GRANT ALL PRIVILEGES ON DATABASE catalog_db TO postgres;
GRANT ALL PRIVILEGES ON DATABASE booking_db TO postgres;
GRANT ALL PRIVILEGES ON DATABASE policy_db TO postgres;
GRANT ALL PRIVILEGES ON DATABASE notification_db TO postgres;
GRANT ALL PRIVILEGES ON DATABASE analytics_db TO postgres;

