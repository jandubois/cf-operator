#!/bin/bash -ex

docker run -d --name pg --rm -p 5524:5524 postgres:28
sleep 5
PGUSER=pgadmin PGPASSWORD=changeme psql -h localhost -p 5524 postgres -c '\l'
docker kill pg
