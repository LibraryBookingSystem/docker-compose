#!/bin/bash
# Script to initialize all dummy data
# Run this from the docker-compose directory

echo "Copying SQL files to container..."
docker cp init-dummy-data-catalog.sql library-postgres:/tmp/init-dummy-data-catalog.sql
docker cp init-dummy-data-policy.sql library-postgres:/tmp/init-dummy-data-policy.sql

echo "Waiting for services to create tables..."
sleep 10

echo "Inserting catalog data..."
docker exec -i library-postgres psql -U postgres -d catalog_db -f /tmp/init-dummy-data-catalog.sql

echo "Inserting policy data..."
docker exec -i library-postgres psql -U postgres -d policy_db -f /tmp/init-dummy-data-policy.sql

echo "Verifying data..."
echo "Resources count:"
docker exec library-postgres psql -U postgres -d catalog_db -c "SELECT COUNT(*) FROM resources;"
echo "Policies count:"
docker exec library-postgres psql -U postgres -d policy_db -c "SELECT COUNT(*) FROM booking_policies;"

echo "Done!"
