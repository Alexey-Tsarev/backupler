#!/bin/bash

#set -x

SSH_USER_HOST=backupX@some.host
SSH_PORT=2222
MNT_POINT=/mnt/sshfs_backupler
REMOTE_CMD=/backup/backupler.sh
CFG="$(hostname -s)"

if [ -n "${TERM}" ] && [ "${TERM}" != "dumb" ]; then
    LOG_ECHO=1
else
    LOG_ECHO=0
fi

log() {
    if [ "${LOG_ECHO}" == "1" ]; then
        echo "$1"
    fi
}

sshfs_umount() {
    fusermount -u "${MNT_POINT}" > /dev/null 2>&1
}

REMOTE_CMD_LOCALLY="${MNT_POINT}${REMOTE_CMD}"
REMOTE_CMD_LOCAL_DIR="$(dirname ${REMOTE_CMD_LOCALLY})"
export REMOTE_CMD_LOCAL_DIR

if [ ! -d "${MNT_POINT}" ]; then
    mkdir -p "${MNT_POINT}"
fi

sshfs_umount

CMD="sshfs -p ${SSH_PORT} -o StrictHostKeyChecking=no ${SSH_USER_HOST}:/ ${MNT_POINT}"
log "Trying to mount remote fs, run: ${CMD}"
${CMD}
CMD_ec="$?"

if [ "${CMD_ec}" -eq 0 ]; then
    log "Success"
else
    log "Mount failed. Exit ${CMD_ec}"
    exit "${CMD_ec}"
fi

cd "${REMOTE_CMD_LOCAL_DIR}" || exit 1
"${REMOTE_CMD_LOCALLY}" "${CFG}"

cd "${OLDPWD}" || exit 2
sshfs_umount
