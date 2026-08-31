#!/bin/bash
# RUN THIS SCRIPT DIRECTLY FROM THE HOST MACHINE, NOT FROM WITHIN THE DOCKER CONTAINER!

if [ -z "$BACKUP_DIR" ]; then
    echo "\$BACKUP_DIR must be set !"
    exit 1
fi

WD=`pwd`

echo '---'
echo 'Shutting down Proxy Server...'

# Temporarily shut down the SVN Server until the backup procedure has finished.
docker-compose down plume-proxy

echo "Backing up the entire SVN Server instance into $BACKUP_DIR"
echo 'This might take a while, perhaps go grab a coffee...'

# Ensure that the backup output directory exists.
mkdir -p "$BACKUP_DIR"

# Get the current time for the output file name.
TIMESTAMP=`date +"%Y-%m-%d-%H-%M-%S"`

# Construct the output file path using the timestamp.
OUTPUT_FILE=$TIMESTAMP-svn-server-backup.tar.gz

# Compress the entire SVN Server instance into a tar.gz archive.
docker run --rm --volumes-from svn-server -v "${BACKUP_DIR}":/backups ubuntu tar -zcvf /backups/$OUTPUT_FILE --directory /home/svn .

echo '---'
echo "SVN Server backup was exported into ${BACKUP_DIR}/${OUTPUT_FILE_PATH}"
echo 'Maybe consider encrypting the archive using a strong password + 7z (choose ENCRYPT FILE NAMES TOO  when asked).'
echo '---'
echo 'Restarting Proxy Server after backup...'

docker-compose up -d plume-proxy
