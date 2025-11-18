# Docker Compose Configuration

This directory contains Docker Compose configuration for running all services locally.

## Quick Start

1. Make sure Docker and Docker Compose are installed
2. Navigate to this directory: `cd docker-compose`
3. Start infrastructure services (PostgreSQL, Redis):
   ```bash
   docker-compose up postgres redis
   ```
4. As you build each service, uncomment its section in `docker-compose.yml`
5. Start all services:
   ```bash
   docker-compose up
   ```

## Services

The `docker-compose.yml` file includes:
- PostgreSQL database
- Redis for caching and messaging
- All microservices (commented out until built)
- Frontend web application

## Development

For local development without Docker, you can:
- Run PostgreSQL and Redis via Docker Compose
- Run each service locally on its assigned port
- Update service URLs in environment variables to point to `localhost`

## Environment Variables

Each service requires environment variables. See `PROJECT_STRUCTURE.md` for details.