#!/bin/sh

# set -x

SSH_USER_HOST=backupX@some.host
MNT_POINT=/mnt/sshfs_backupler
REMOTE_CMD=/backup/backupler.sh
CFG=`hostname -s`


function sshfs_umount() {
    fusermount -u "$MNT_POINT" > /dev/null 2>&1
}


REMOTE_RUN_FULL_PATH=${MNT_POINT}${REMOTE_CMD}
REMOTE_RUN_FULL_PATH_DIR=`dirname ${REMOTE_RUN_FULL_PATH}`

if [ ! -d "$MNT_POINT" ]; then
    mkdir -p "$MNT_POINT"
fi

sshfs_umount

CMD="sshfs $SSH_USER_HOST:/ $MNT_POINT"
echo "Trying to mount remote fs, run: $CMD"
${CMD}

if [ $? -eq 0 ]; then
    echo "Success"
else
    echo "Mount failed. Exit"
    exit 1
fi

OLD_PWD=`pwd`
cd "$REMOTE_RUN_FULL_PATH_DIR"
${REMOTE_RUN_FULL_PATH} "$CFG"

cd "$OLD_PWD"
sshfs_umount
