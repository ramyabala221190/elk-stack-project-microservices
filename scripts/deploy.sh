#!/bin/bash

# Set variables
STACK_NAME="elkStack"
COMPOSE_FILE="elk/swarm/docker-compose.stack.yml"
OVERRIDE_FILE="elk/swarm/docker-compose.stack.dev.override.yml"

# Deploy stack
echo "Deploying stack: $STACK_NAME"
docker stack rm "$STACK_NAME"
docker stack deploy -c "$COMPOSE_FILE" -c "$OVERRIDE_FILE" "$STACK_NAME"

