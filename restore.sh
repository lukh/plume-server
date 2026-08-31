#!/bin/bash
# RUN THIS SCRIPT DIRECTLY FROM THE HOST MACHINE, NOT FROM WITHIN THE DOCKER CONTAINER!


if [ -z "$1" ]; then
    echo "Usage: $0 <backup-file.tar.gz>"
    exit 1
fi

BACKUP_FILE="$(realpath "$1")"

if [ ! -f "$BACKUP_FILE" ]; then
    echo "Backup file not found: $BACKUP_FILE"
    exit 1
fi

echo '---'
echo "Restoring SVN Server from $BACKUP_FILE"
echo 'WARNING: the current SVN data will be replaced!'
echo '---'

read -p "Continue? [yes/no]: " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Restore cancelled."
    exit 0
fi

echo '---'
echo 'Shutting down SVN Server...'

docker-compose down plume-proxy

echo "Restoring SVN Server from $BACKUP_FILE..."
echo 'This might take a while, perhaps go grab a coffee...'

docker run --rm \
    --volumes-from svn-server \
    -v "${BACKUP_FILE}":/backups/restored.tar.gz \
    ubuntu \
    bash -c '
        rm -rf /home/svn/*
        tar -zxvf "/backups/restored.tar.gz" --directory /home/svn
    '

echo '---'
echo 'SVN Server restore completed.'
echo '---'

echo 'Restarting SVN Server...'

docker-compose up -d plume-proxy
docker-compose down svn
docker-compose up -d svn
