# Database Dummy Data Initialization

This guide explains how to initialize the database with dummy data for testing.

## Important Notes

1. **Spring Boot Auto-Creates Tables**: The Spring Boot services automatically create database tables using JPA/Hibernate when they start.

2. **Run After Services Start**: The dummy data script must be run AFTER all services have started and created their tables.

3. **User Passwords**: User passwords are hashed using BCrypt. Admin users should be created via API using `setup-admin-user.ps1` to ensure correct password hashing.

4. **Merged File Structure**: All dummy data is now in `init-dummy-data.sql` (merged file). Separate files (`init-dummy-data-catalog.sql`, `init-dummy-data-policy.sql`) are convenience extracts.

## File Structure

- **`init-dummy-data.sql`** - **Merged file** containing all sections:
  - Section 1: Catalog data (resources, amenities) for `catalog_db`
  - Section 2: Policy data (booking policies) for `policy_db`
  - Section 3: Admin user approval for `user_db` (user created via API)
- **`init-dummy-data-catalog.sql`** - Section 1 extract (convenience)
- **`init-dummy-data-policy.sql`** - Section 2 extract (convenience)
- **`setup-admin-user.ps1`** - Unified admin user script (create/approve/fix)
- **`init-dummy-data-all.ps1`** - Automated script to run all initialization

## Steps to Initialize Dummy Data

### Option 1: Automated Script (Recommended)

Run the automated PowerShell script that handles everything:

```powershell
powershell -ExecutionPolicy Bypass -File init-dummy-data-all.ps1
```

This script will:
1. Copy SQL files to the container
2. Insert catalog data (resources)
3. Insert policy data (booking policies)
4. Create and approve admin user via API

### Option 2: Manual Execution Per Database

Since each section targets a different database, run them separately:

**1. Catalog Data (catalog_db):**
```powershell
docker cp init-dummy-data-catalog.sql library-postgres:/tmp/init-dummy-data-catalog.sql
docker exec -i library-postgres psql -U postgres -d catalog_db -f /tmp/init-dummy-data-catalog.sql
```

**2. Policy Data (policy_db):**
```powershell
docker cp init-dummy-data-policy.sql library-postgres:/tmp/init-dummy-data-policy.sql
docker exec -i library-postgres psql -U postgres -d policy_db -f /tmp/init-dummy-data-policy.sql
```

**3. Admin User (user_db - via API):**
```powershell
powershell -ExecutionPolicy Bypass -File setup-admin-user.ps1
```

### Option 3: Using Merged File with psql

1. **Wait for all services to start**:
   ```bash
   docker compose ps
   ```
   Ensure all services show "Up" status.

2. **Wait a few seconds** for Spring Boot to create tables.

3. **Extract and run each section** from `init-dummy-data.sql`:
   - Copy Section 1 and run in `catalog_db`
   - Copy Section 2 and run in `policy_db`
   - Use `setup-admin-user.ps1` for Section 3

## What Gets Created

- **Resources**: 18 total (6 study rooms, 6 computer stations, 6 seats) + amenities
- **Policies**: 4 default booking policies (Student, Faculty, Admin, Peak Hours)
- **Admin User**: 1 hardcoded admin (username: `admin1`, password: `12345678a`)
- **Bookings**: Created dynamically by users through the application
- **Notifications**: Created dynamically by the system

## Verifying Data

After running the script, verify data was inserted:

```bash
# Check resources
docker exec library-postgres psql -U postgres -d catalog_db -c "SELECT COUNT(*) FROM resources;"

# Check policies
docker exec library-postgres psql -U postgres -d policy_db -c "SELECT COUNT(*) FROM booking_policies;"

# Check admin user
docker exec library-postgres psql -U postgres -d user_db -c "SELECT username, email, role, pending_approval FROM users WHERE username = 'admin1';"
```

## Admin User Management

The `setup-admin-user.ps1` script is a unified tool that replaces multiple admin scripts:

```powershell
# Full setup (create new or approve existing)
.\setup-admin-user.ps1

# Only approve existing user
.\setup-admin-user.ps1 -ApproveOnly

# Force recreate (delete and create new)
.\setup-admin-user.ps1 -Recreate
```

## Troubleshooting

- **"relation does not exist"**: Services haven't created tables yet. Wait a few more seconds and try again.
- **"duplicate key"**: Data already exists. The scripts use `ON CONFLICT DO NOTHING` and `IF NOT EXISTS` to prevent duplicates.
- **Connection refused**: PostgreSQL container isn't running. Start it with `docker compose up -d postgres`.
- **"User service is unavailable"**: Auth service can't reach user service. Check service health with `docker compose ps` and ensure `user-service` is healthy.

