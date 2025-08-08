#!/bin/bash
set -euo pipefail

# --- CONFIG ---
MAIN_COMPOSE="./docker/docker-compose.yml"
BASE_COMPOSE="./docker/docker-compose-base.yml"
RAGFLOW_ROOT="$(pwd)"

echo "Starting RagFlow backup script..."

if [[ ! -f "$MAIN_COMPOSE" ]]; then
  echo "Error: $MAIN_COMPOSE not found. Please run this script from the RagFlow root directory."
  exit 1
fi
if [[ ! -f "$BASE_COMPOSE" ]]; then
  echo "Warning: $BASE_COMPOSE not found. Proceeding with main compose only."
  USE_BASE_COMPOSE=false
else
  USE_BASE_COMPOSE=true
fi

check_running_containers() {
  if $USE_BASE_COMPOSE; then
    RUNNING_CONTAINERS=$(docker compose -f "$MAIN_COMPOSE" -f "$BASE_COMPOSE" ps -q | xargs -r docker ps -q --no-trunc --filter "status=running" || true)
  else
    RUNNING_CONTAINERS=$(docker compose -f "$MAIN_COMPOSE" ps -q | xargs -r docker ps -q --no-trunc --filter "status=running" || true)
  fi
}

check_running_containers

if [[ -n "$RUNNING_CONTAINERS" ]]; then
  echo "RagFlow containers are currently running:"
  if $USE_BASE_COMPOSE; then
    docker compose -f "$MAIN_COMPOSE" -f "$BASE_COMPOSE" ps
  else
    docker compose -f "$MAIN_COMPOSE" ps
  fi
  echo ""

  while true; do
    echo "Choose an option:"
    echo "  1. Stop the containers for me"
    echo "  2. I will stop them manually"
    echo "  3. Retry backup detection"
    echo "  4. Exit backup"
    read -rp "Enter choice [1-4]: " USER_CHOICE

    case $USER_CHOICE in
      1)
        echo "Stopping containers..."
        if $USE_BASE_COMPOSE; then
          docker compose -f "$MAIN_COMPOSE" -f "$BASE_COMPOSE" down
        else
          docker compose -f "$MAIN_COMPOSE" down
        fi
        check_running_containers
        if [[ -z "$RUNNING_CONTAINERS" ]]; then
          echo "Containers stopped successfully."
          break
        else
          echo "Some containers are still running."
        fi
        ;;
      2)
        echo "Please stop containers manually, then press ENTER to retry detection."
        read -r
        check_running_containers
        if [[ -z "$RUNNING_CONTAINERS" ]]; then
          echo "Containers are stopped."
          break
        else
          echo "Containers are still running."
        fi
        ;;
      3)
        check_running_containers
        if [[ -z "$RUNNING_CONTAINERS" ]]; then
          echo "Containers are stopped."
          break
        else
          echo "Containers are still running."
          if $USE_BASE_COMPOSE; then
            docker compose -f "$MAIN_COMPOSE" -f "$BASE_COMPOSE" ps
          else
            docker compose -f "$MAIN_COMPOSE" ps
          fi
        fi
        ;;
      4)
        echo "Exiting backup script."
        exit 0
        ;;
      *)
        echo "Invalid choice. Try again."
        ;;
    esac
  done
else
  echo "Great! Your RagFlow containers are already stopped."
  echo "Proceeding with backup..."
  echo ""
fi

# Ask for username and suggest default path
read -rp "Enter your Linux username to suggest a backup path: " BACKUP_USER
DEFAULT_BACKUP_DIR="/home/${BACKUP_USER}/backups/Ragflow"

echo "Suggested backup path: $DEFAULT_BACKUP_DIR"
read -rp "Do you want to use the suggested path? (Y/n): " USE_DEFAULT_PATH

if [[ "$USE_DEFAULT_PATH" =~ ^([Nn][Oo]?|n)$ ]]; then
  read -rp "Enter full custom backup path (must be writable): " BACKUP_DIR
else
  BACKUP_DIR="$DEFAULT_BACKUP_DIR"
fi

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
ARCHIVE_NAME="ragflow_backup_${TIMESTAMP}.tar.gz"

if [[ ! -d "$BACKUP_DIR" ]]; then
  echo "Backup directory $BACKUP_DIR does not exist. Creating it..."
  mkdir -p "$BACKUP_DIR"
fi

echo "Backing up RagFlow folder from:"
echo "  $RAGFLOW_ROOT"
echo "to:"
echo "  $BACKUP_DIR"

echo "Copying files..."
rsync -a --info=progress2 "$RAGFLOW_ROOT/" "$BACKUP_DIR/ragflow_backup_${TIMESTAMP}/"

echo "Compressing backup to tar.gz archive..."
tar -czf "$BACKUP_DIR/$ARCHIVE_NAME" -C "$BACKUP_DIR" "ragflow_backup_${TIMESTAMP}"

echo "Cleaning up uncompressed backup folder..."
rm -rf "$BACKUP_DIR/ragflow_backup_${TIMESTAMP}"

echo "Backup completed successfully!"
echo "Backup archive created at:"
echo "  $BACKUP_DIR/$ARCHIVE_NAME"
echo "You can safely restart your containers after the backup."

exit 0
