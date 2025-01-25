#!/bin/bash
#? Backup.sh

# Instellingen
CONTAINER_NAME="sigmasmp-mc-1"
BACKUP_DIR="Backups"
TIMESTAMP=$(date +"%d-%m-%Y_%H-%M-%S")

# Stap 1: Verbind met de container en stop de Minecraft-server via RCON
docker exec -it "$CONTAINER_NAME" bash -c "rcon-cli kick @a backup!"
sleep 1
docker exec -it "$CONTAINER_NAME" bash -c "rcon-cli stop"

# Stap 2: Wacht tot de container stopt
echo "Wachten tot de container stopt..."
while docker ps | grep -q "$CONTAINER_NAME"; do
    sleep 1
done
echo "Container gestopt."

# Stap 3: Maak een back-up directory aan
mkdir -p "$BACKUP_DIR/$TIMESTAMP"

# Stap 4: Kopieer de data map naar de back-up directory
docker cp "$CONTAINER_NAME:/data" "$BACKUP_DIR/$TIMESTAMP/"
echo "Data gekopieerd naar $BACKUP_DIR/$TIMESTAMP"

# Klaar!
echo "Backup succesvol gemaakt!"
docker-compose up -d
echo "Container opnieuw gestart!"
