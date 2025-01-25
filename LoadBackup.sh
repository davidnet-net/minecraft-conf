#!/bin/bash
#? LoadBackup.sh

# Instellingen
CONTAINER_NAME="sigmasmp-mc-1"
BACKUP_DIR="Backups"
REMOTE_DIR="onedrive:Backups"

# Stap 1: Synchroniseer OneDrive-back-ups naar lokaal
echo "Synchroniseren van OneDrive-back-ups..."
rclone sync "$REMOTE_DIR" "$BACKUP_DIR" --progress

# Controleer of de back-up directory bestaat
if [ ! -d "$BACKUP_DIR" ]; then
    echo "Back-up directory ($BACKUP_DIR) bestaat niet!"
    exit 1
fi

# Lijst alle back-ups (gesorteerd van nieuw naar oud)
echo "Beschikbare back-ups:"
BACKUPS=($(ls -t "$BACKUP_DIR"))
for i in "${!BACKUPS[@]}"; do
    echo "$((i + 1)). ${BACKUPS[i]}"
done

# Vraag de gebruiker om een back-up te kiezen
read -p "Kies een back-up (nummer): " CHOICE

# Controleer of de keuze geldig is
if [[ "$CHOICE" -lt 1 || "$CHOICE" -gt "${#BACKUPS[@]}" ]]; then
    echo "Ongeldige keuze!"
    exit 1
fi

# Kies de geselecteerde back-up
SELECTED_BACKUP="${BACKUPS[$((CHOICE - 1))]}"
echo "Gekozen back-up: $SELECTED_BACKUP"

# Stap 2: Stop de Minecraft-server via RCON
docker exec -it "$CONTAINER_NAME" bash -c "rcon-cli kick @a Backup $SELECTED_BACKUP Laden"
docker exec -it "$CONTAINER_NAME" bash -c "rcon-cli stop"

# Stap 3: Wacht tot de container stopt
echo "Wachten tot de container stopt..."
while docker ps | grep -q "$CONTAINER_NAME"; do
    sleep 1
done
echo "Container gestopt."

# Stap 4: Overschrijven van de data-map
echo "Herstellen van back-up..."
rm -rf data
cp -r "$BACKUP_DIR/$SELECTED_BACKUP/data" data
echo "Back-up hersteld!"

# Stap 5: Start de Minecraft-server opnieuw
docker start "$CONTAINER_NAME"
echo "Server opnieuw gestart met de herstelde back-up!"
