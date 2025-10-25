#!/bin/bash

echo "Running container using docker compose up"
docker compose -p elk -f docker-compose.yml  up -d --remove-orphans --no-build