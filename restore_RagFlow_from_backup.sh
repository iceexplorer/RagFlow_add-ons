#!/bin/bash

echo "=== RagFlow Restore Script ==="
echo ""

# Step 1: Ask for backup file
read -rp "Enter the full path to your RagFlow backup (.tar.gz): " BACKUP_FILE

if [[ ! -f "$BACKUP_FILE" ]]; then
    echo "Error: File '$BACKUP_FILE' does not exist."
    exit 1
fi

# Step 2: Ask where to restore
read -rp "Enter the path where you want to restore RagFlow (default: current directory): " RESTORE_DIR
RESTORE_DIR=${RESTORE_DIR:-$(pwd)}

# Step 3: Check for running docker containers in this folder
if docker compose ps --status=running &> /dev/null; then
    RUNNING_CONTAINERS=$(docker compose ps --status=running --services)
    if [[ -n "$RUNNING_CONTAINERS" ]]; then
        echo "Warning: The following RagFlow containers are still running:"
        echo "$RUNNING_CONTAINERS"
        echo "Please stop them first (e.g., with 'docker compose down') before restoring."
        exit 1
    fi
fi

# Step 4: Confirm if folder exists
TARGET_FOLDER="$RESTORE_DIR/Ragflow"
if [[ -d "$TARGET_FOLDER" ]]; then
    echo "Warning: '$TARGET_FOLDER' already exists."
    read -rp "Do you want to overwrite it? (yes/no): " CONFIRM
    if [[ "$CONFIRM" != "yes" ]]; then
        echo "Restore cancelled."
        exit 1
    fi
    echo "Removing existing '$TARGET_FOLDER'..."
    rm -rf "$TARGET_FOLDER"
fi

# Step 5: Extract the backup
echo "Extracting backup..."
mkdir -p "$RESTORE_DIR"
tar -xzf "$BACKUP_FILE" -C "$RESTORE_DIR"

if [[ $? -ne 0 ]]; then
    echo "Restore failed during extraction."
    exit 1
fi

echo ""
echo "Restore completed successfully!"
echo "Restored to: $TARGET_FOLDER"
echo ""
echo "Next steps:"
echo "1. cd into the restored directory: cd \"$TARGET_FOLDER\""
echo "2. Start your containers again: docker compose up -d"
