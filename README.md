# Library System Docker Compose Setup

This docker-compose file sets up the entire library booking system with all microservices.

## Prerequisites

- Docker
- Docker Compose

## Services Included

### Infrastructure
- **postgres**: PostgreSQL database (port 5433)
- **redis**: Redis cache (port 6379)
- **rabbitmq**: RabbitMQ message broker (ports 5672, 15672 for management UI)

### Microservices
- **user-service**: User management (port 3001, gRPC 50051)
- **auth-service**: Authentication service (port 3002)
- **catalog-service**: Resource catalog service (port 3003)
- **booking-service**: Booking management (port 3004)
- **policy-service**: Policy enforcement (port 3005)
- **notification-service**: Notifications (port 3006)
- **analytics-service**: Analytics and reporting (port 3007)

### API Gateway
- **api-gateway**: Nginx reverse proxy (port 8080)
  - Routes all API requests to appropriate services
  - Handles CORS
  - Provides WebSocket support for realtime gateway
  - Authorization header validation

## Starting the System

From the `docker-compose` directory:

```bash
docker compose up -d
```

This will:
1. Start all infrastructure services (postgres, redis, rabbitmq)
2. Build and start all microservices
3. Start the nginx API gateway

## Initializing Dummy Data

After services are running, initialize dummy data:

**Recommended (automated):**
```powershell
powershell -ExecutionPolicy Bypass -File init-dummy-data-all.ps1
```

**Manual (per database):**
```powershell
# Resources (catalog_db)
docker cp init-dummy-data-catalog.sql library-postgres:/tmp/init-dummy-data-catalog.sql
docker exec -i library-postgres psql -U postgres -d catalog_db -f /tmp/init-dummy-data-catalog.sql

# Policies (policy_db)
docker cp init-dummy-data-policy.sql library-postgres:/tmp/init-dummy-data-policy.sql
docker exec -i library-postgres psql -U postgres -d policy_db -f /tmp/init-dummy-data-policy.sql

# Admin User (user_db - via API)
powershell -ExecutionPolicy Bypass -File setup-admin-user.ps1
```

**Files:**
- `init-dummy-data.sql` - **Merged file** containing all dummy data sections (catalog, policy, user)
- `init-dummy-data-catalog.sql` - Section 1 extract for catalog_db (convenience file)
- `init-dummy-data-policy.sql` - Section 2 extract for policy_db (convenience file)
- `setup-admin-user.ps1` - **Unified admin user script** (replaces multiple admin scripts)
- `init-dummy-data-all.ps1` - Automated script to run all initialization steps

**Admin User Script Usage:**
```powershell
# Full setup (create new or recreate existing)
powershell -ExecutionPolicy Bypass -File setup-admin-user.ps1

# Only approve existing user
powershell -ExecutionPolicy Bypass -File setup-admin-user.ps1 -ApproveOnly

# Force recreate (delete and create new)
powershell -ExecutionPolicy Bypass -File setup-admin-user.ps1 -Recreate
```

## Accessing Services

- **API Gateway**: http://localhost:8080
- **RabbitMQ Management**: http://localhost:15672 (admin/admin)
- **PostgreSQL**: localhost:5433 (postgres/postgres)

## API Endpoints (via Gateway)

All API calls should go through the gateway at `http://localhost:8080`:

- `POST /api/auth/register` - Register new user
- `POST /api/auth/login` - Login
- `GET /api/resources` - List resources (requires auth)
- `POST /api/bookings` - Create booking (requires auth)
- `GET /api/bookings` - List bookings (requires auth)
- `WS /ws/availability` - WebSocket for realtime updates (when realtime-gateway is available)

## Stopping the System

```bash
docker compose down
```

To also remove volumes (clears all data):

```bash
docker compose down -v
```

## Viewing Logs

View logs for all services:
```bash
docker compose logs -f
```

View logs for a specific service:
```bash
docker compose logs -f api-gateway
docker compose logs -f booking-service
```

## Rebuilding Services

After code changes, rebuild and restart:
```bash
docker compose up -d --build
```

## Health Checks

Check if services are running:
```bash
curl http://localhost:8080/health
curl http://localhost:8080/api/auth/health
curl http://localhost:8080/api/resources/health
```

## Notes

- The realtime-gateway service is commented out as it needs to be created separately
- All services use Docker service names for internal communication
- The API gateway (nginx) routes requests to services using service names
- Database connections use internal Docker network (port 5432, not 5433)
