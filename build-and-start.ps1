# Build and start all services with BuildKit enabled
$env:DOCKER_BUILDKIT = 1
docker compose up -d --build

