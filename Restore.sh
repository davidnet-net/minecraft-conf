#!/usr/bin/env bash

# Config
COMPOSE_FILE="./docker-compose.yaml"
TEMP_DIR="./cache"
VERSION="0.1.0"

# Load Environment variables
source .env
export RESTIC_REPOSITORY
export RESTIC_PASSWORD

# --- Get container name ---
CONTAINER_NAME=$(grep 'container_name:' "$COMPOSE_FILE" | awk '{print $2}')

if [ -z "$CONTAINER_NAME" ]; then
  echo "Geen container_name gevonden in $COMPOSE_FILE? ERROR"
  exit 1
fi

echo "CONTAINER: $CONTAINER_NAME"

echo "Backups laden... (Even slapen)"

# --- Load snapshots into array ---
mapfile -t SNAPSHOTS < <(restic snapshots --json | jq -c '.[]')

if [ ${#SNAPSHOTS[@]} -eq 0 ]; then
  echo "Geen backups gevonden."
  exit 1
fi

echo "Beschikbare backups:"
for i in "${!SNAPSHOTS[@]}"; do
  SHORT_ID=$(echo "${SNAPSHOTS[$i]}" | jq -r '.short_id')
  TIME_RAW=$(echo "${SNAPSHOTS[$i]}" | jq -r '.time')

  # Format time
  TZ_OFFSET=$(date +%z)
  TZ_OFFSET="${TZ_OFFSET:0:3}:${TZ_OFFSET:3:2}"
  TIME_FMT=$(date -d "$TIME_RAW" +"%d-%m-%Y %H:%M:%S (UTC$TZ_OFFSET)")

  printf "  %d | %s | %s\n" $((i+1)) "$SHORT_ID" "$TIME_FMT"
done

echo ""
read -rp "Voer het nummer in van de backup die je wilt herstellen: " NUM

# Validate input
if ! [[ "$NUM" =~ ^[0-9]+$ ]] || [ "$NUM" -lt 1 ] || [ "$NUM" -gt "${#SNAPSHOTS[@]}" ]; then
  echo "Dat nummer heb ik nog nooit iemand horen yappen (Ongeldig)."
  exit 1
fi

SNAPSHOT_JSON="${SNAPSHOTS[$((NUM-1))]}"

SNAPSHOT_ID=$(echo "$SNAPSHOT_JSON" | jq -r '.id')
SNAPSHOT_TIME=$(echo "$SNAPSHOT_JSON" | jq -r '.time')
SHORT_ID=$(echo "$SNAPSHOT_JSON" | jq -r '.short_id')

# Format chosen backup time
TZ_OFFSET=$(date +%z)
TZ_OFFSET="${TZ_OFFSET:0:3}:${TZ_OFFSET:3:2}"
SNAPSHOT_TIME_FMT=$(date -d "$SNAPSHOT_TIME" +"%d-%m-%Y %H:%M:%S (UTC$TZ_OFFSET)")

# --- Restore ---
rm -rf "$TEMP_DIR"
mkdir -p "$TEMP_DIR"

echo "Backup laden. Naar temp toe."
restic restore "$SNAPSHOT_ID" --target "$TEMP_DIR"

if [ ! -f "$TEMP_DIR/cache/eula.txt" ]; then
  echo "Kan eula.txt niet vinden is de structuur van de backup in orde?"
  exit 1
fi

# --- Stop container if running ---
RUNNING=$(docker inspect --format='{{.State.Running}}' "$CONTAINER_NAME" 2>/dev/null || echo "false")
if [ "$RUNNING" == "true" ]; then
  # --- Kick players ---
  KICK_MSG="Server backup [$SHORT_ID] laden.\nTerug in de tijd naar: [$SNAPSHOT_TIME_FMT].\n\nDe server herstart meteen."
  docker exec "$CONTAINER_NAME" rcon-cli "kick @a $(echo -e "$KICK_MSG")"

  echo "Server container stoppen..."
  docker stop "$CONTAINER_NAME"

  while [ "$(docker inspect -f '{{.State.Running}}' "$CONTAINER_NAME")" == "true" ]; do
    echo "Server stoppen. Even slapen."
    sleep 2
  done
  echo "Server is gestopt."
else
  echo "Container is al gestopt."
fi

echo "Data veryappen(Kopieren) naar de server container..."
ls "$TEMP_DIR/"
docker cp "$TEMP_DIR/cache/." "$CONTAINER_NAME":/data

echo "Server container starten..."
docker start "$CONTAINER_NAME"

echo "Restore voltooid en server wordt herstart."

rm -rf "$TEMP_DIR"
echo "Cache opgeschoond. Klaar."
