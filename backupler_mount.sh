#!/bin/sh

# set -x

SSH_USER_HOST=backupX@some.host
MNT_POINT=/mnt/sshfs_backupler
REMOTE_CMD=/backup/backupler.sh
CFG=`hostname -s`

if [ -n "`env | grep TERM=`" ]; then
    LOG_ECHO=true
else
    LOG_ECHO=false
fi


log() {
    if [ "$LOG_ECHO" == true ]; then
        echo "$1"
    fi
}

sshfs_umount() {
    fusermount -u "$MNT_POINT" > /dev/null 2>&1
}


REMOTE_CMD_LOCALLY=${MNT_POINT}${REMOTE_CMD}
REMOTE_CMD_LOCAL_DIR=`dirname ${REMOTE_CMD_LOCALLY}`

if [ ! -d "$MNT_POINT" ]; then
    mkdir -p "$MNT_POINT"
fi

sshfs_umount

CMD="sshfs $SSH_USER_HOST:/ $MNT_POINT"
log "Trying to mount remote fs, run: $CMD"
${CMD}

if [ $? -eq 0 ]; then
    log "Success"
else
    log "Mount failed. Exit"
    exit 1
fi

OLD_PWD=`pwd`
cd "$REMOTE_CMD_LOCAL_DIR"
${REMOTE_CMD_LOCALLY} "$CFG"

cd "$OLD_PWD"
sshfs_umount
