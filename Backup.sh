#!/usr/bin/env bash

# Config
COMPOSE_FILE="./docker-compose.yaml"
TEMP_DIR="./cache"
TIMESTAMP=$(date +"%d-%m-%Y_%H-%M-%S")
VERSION="0.1.0"

# Load Environment variables
source .env
export RESTIC_REPOSITORY
export RESTIC_PASSWORD

# --- Get container name ---
CONTAINER_NAME=$(grep 'container_name:' "$COMPOSE_FILE" | awk '{print $2}')

if [ -z "$CONTAINER_NAME" ]; then
  echo "Geen container_name gevonden in $COMPOSE_FILE. ERROR"
  exit 1
fi

echo "Gebruik container: $CONTAINER_NAME"

# --- Check if container is running ---
CONTAINER_STATUS=$(docker inspect -f '{{.State.Running}}' "$CONTAINER_NAME" 2>/dev/null)

if [ "$CONTAINER_STATUS" != "true" ]; then
  echo "Container $CONTAINER_NAME is niet actief. Backup wordt niet uitgevoerd."
  exit 1
fi


sleep 3

# --- Notify players ---
docker exec "$CONTAINER_NAME" rcon-cli "title @a actionbar {\"text\":\"§6Backup maken...\"}"
sleep 3

# --- Start timer for cache creation ---
START_CACHE_TIME=$(date +%s)

# --- Safe saving ---
echo "Tijdelijk opslaan blokkeren op de server..."
docker exec "$CONTAINER_NAME" rcon-cli "save-off"
docker exec "$CONTAINER_NAME" rcon-cli "save-all"

echo "Wachten tot server heeft opgeslagen en IO is geflusht..."
sleep 5

# --- Copy world data contents directly to TEMP_DIR ---
rm -rf "$TEMP_DIR"
mkdir -p "$TEMP_DIR"
echo "Kopieer wereld data naar tijdelijke map..."
docker cp "$CONTAINER_NAME":/data/. "$TEMP_DIR/"

# --- Get cache size in bytes ---
CACHE_SIZE_BYTES=$(du -sb "$TEMP_DIR" | awk '{print $1}')

# --- End timer for cache creation ---
END_CACHE_TIME=$(date +%s)
CACHE_DURATION=$((END_CACHE_TIME - START_CACHE_TIME))

# --- Re-enable saving ---
echo "Opslaan weer inschakelen"
docker exec "$CONTAINER_NAME" rcon-cli "save-on"

docker exec "$CONTAINER_NAME" rcon-cli "title @a actionbar {\"text\":\"Cache gemaakt...\"}"

# --- Start timer for backup upload ---
START_UPLOAD_TIME=$(date +%s)

# --- Restic backup ---
echo "Backup maken naar Restic repository..."
restic backup "$TEMP_DIR/." --tag "minecraft-backup" --tag "$TIMESTAMP" --compression auto

# --- Forget old backups & prune ---
echo "Oude backups opruimen volgens beleid..."
restic forget $RESTIC_FORGET_ARGS --prune

# --- End timer for backup upload ---
END_UPLOAD_TIME=$(date +%s)
UPLOAD_DURATION=$((END_UPLOAD_TIME - START_UPLOAD_TIME))

# --- Get timezone offset ---
TZ_OFFSET=$(date +%z)
TZ_OFFSET="${TZ_OFFSET:0:3}:${TZ_OFFSET:3:2}"

# --- Get newest and oldest snapshots ---
NEWEST=$(restic snapshots --json | jq -r '.[].time' | sort | tail -n1)
OLDEST=$(restic snapshots --json | jq -r '.[].time' | sort | head -n1)

# Format for readability
NEWEST_FMT=$(date -d "$NEWEST" +"%d-%m-%Y %H:%M:%S (UTC$TZ_OFFSET)")
OLDEST_FMT=$(date -d "$OLDEST" +"%d-%m-%Y %H:%M:%S (UTC$TZ_OFFSET)")

echo "Nieuwste backup: $NEWEST_FMT"
echo "Oudste backup: $OLDEST_FMT"

# --- Get total size of restic repo ---
REPO_STATS_JSON=$(restic stats --mode raw-data --json)
TOTAL_SIZE_BYTES=$(echo "$REPO_STATS_JSON" | jq -r '.total_size')

# Format size helper function
format_size() {
  local size_bytes=$1
  if [ "$size_bytes" -ge 1073741824 ]; then
    awk "BEGIN {printf \"%.2f GB\", $size_bytes/1073741824}"
  else
    awk "BEGIN {printf \"%.2f MB\", $size_bytes/1048576}"
  fi
}

TOTAL_SIZE_FORMATTED=$(format_size "$TOTAL_SIZE_BYTES")
CACHE_SIZE_FORMATTED=$(format_size "$CACHE_SIZE_BYTES")

echo "Repository grootte: $TOTAL_SIZE_FORMATTED"
echo "Cache grootte: $CACHE_SIZE_FORMATTED"

# --- Notify players with chat summary ---
docker exec "$CONTAINER_NAME" rcon-cli tellraw @a "$(cat <<EOF
[
  {"text":" "},
  {"text":"-------- Backup Geyap -------","color":"gold","bold":true},
  {"text":"\Nieuwste backup: ","color":"yellow"},
  {"text":"$NEWEST_FMT","color":"white"},
  {"text":"\nOudste backup: ","color":"yellow"},
  {"text":"$OLDEST_FMT","color":"white"},
  {"text":"\nRepository grootte: ","color":"yellow"},
  {"text":"$TOTAL_SIZE_FORMATTED","color":"white"},
  {"text":"\nServer grootte: ","color":"yellow"},
  {"text":"$CACHE_SIZE_FORMATTED","color":"white"},
  {"text":"\nTijd voor cache maken: $CACHE_DURATION seconden","color":"green"},
  {"text":"\nTijd voor backup uploaden: $UPLOAD_DURATION seconden","color":"green"},
  {"text":"\nBackup systeem versie $VERSION","color":"green"},
  {"text":"\n-----------------------------","color":"gold","bold":true},
  {"text":" "}
]
EOF
)"

# --- Cleanup temp ---
rm -rf "$TEMP_DIR"

# --- Notify done ---
docker exec "$CONTAINER_NAME" rcon-cli "title @a actionbar {\"text\":\"§aBackup voltooid (:\"}"
echo "Backup voltooid en veilig opgeslagen in Restic repository."
