#!/bin/bash
#? Backup.sh

# Instellingen
CONTAINER_NAME=$(<"servername.txt")
BACKUP_DIR="Backups"
REMOTE_DIR="onedrive:Samenwerken David En Papa/davidnet/BackupsV2/Minecraft/$CONTAINER_NAME"
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

# Stap 4: Kopieer de data-map naar de back-up directory
docker cp "$CONTAINER_NAME:/data" "$BACKUP_DIR/$TIMESTAMP/"
echo "Data gekopieerd naar $BACKUP_DIR/$TIMESTAMP"

# Stap 5: SynchroniseBackupser met OneDrive
echo "Synchroniseren met OneDrive..."
rclone copy "$BACKUP_DIR/$TIMESTAMP" "$REMOTE_DIR/$TIMESTAMP" --progress

# Stap 6: Houd alleen de 10 nieuwste back-ups op de server
echo "Beperk het aantal back-ups tot 10 op de server..."
BACKUPS_LOCAL=($(ls -t "$BACKUP_DIR"))
while [ "${#BACKUPS_LOCAL[@]}" -gt 10 ]; do
    OLDEST="${BACKUPS_LOCAL[-1]}"
    rm -rf "$BACKUP_DIR/$OLDEST"
    echo "Verwijderd: $OLDEST"
    BACKUPS_LOCAL=($(ls -t "$BACKUP_DIR"))
done

# Klaar!
echo "Backup succesvol gemaakt!"
docker-compose up -d
echo "Container opnieuw gestart!"
