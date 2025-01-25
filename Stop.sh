#!/bin/bash

# Instellingen
CONTAINER_NAME=$(<"servername.txt")

# Stap 1: Verbind met de container en stop de Minecraft-server via RCON
docker exec -it "$CONTAINER_NAME" bash -c "rcon-cli stop"

# Stap 2: Wacht tot de container stopt
echo "Wachten tot de container stopt..."
while docker ps | grep -q "$CONTAINER_NAME"; do
    sleep 1
done
echo "Container gestopt."
