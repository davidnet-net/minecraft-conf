#!/usr/bin/env bash

# Path to your docker-compose.yml
COMPOSE_FILE="./docker-compose.yaml"

# Extract container_name
CONTAINER_NAME=$(grep 'container_name:' "$COMPOSE_FILE" | awk '{print $2}')

# Fallback if no container_name found
if [ -z "$CONTAINER_NAME" ]; then
  echo "No container_name found in $COMPOSE_FILE."
  echo "Trying to detect running container from docker-compose..."

  # Use docker-compose ps to find the container name
  # Get the first container that matches the service name "minecraft"
  CONTAINER_NAME=$(docker-compose ps -q minecraft | xargs docker inspect --format '{{.Name}}' | sed 's|/||')

  if [ -z "$CONTAINER_NAME" ]; then
    echo "Could not detect a running container. Is it up?"
    exit 1
  fi
fi

echo "Connecting to container: $CONTAINER_NAME"

/usr/bin/docker exec -it "$CONTAINER_NAME" /bin/bash
