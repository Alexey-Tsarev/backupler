#!/bin/bash

# set -x

export GOAL="u1pro1"
export MPOINT="/mnt/${GOAL}"

US="$(id -un)"
export US

GR="$(id -gn)"
export GR

mkdir -p "${MPOINT}" || { echo "Directory create failed. Exit 1"; exit 1; }
umount "${MPOINT}" 2> /dev/null

set -e

mount -t cifs -o "uid=${US},gid=${GR},vers=1.0,credentials=$(readlink -f "$(dirname "$0")")/cfg/${GOAL}.smbcredentials" "//${GOAL}/root" "${MPOINT}"

script_dir=$(realpath "$(dirname "$0")")
su "${US}" -c "${script_dir}/backupler.sh ${GOAL}"

umount "${MPOINT}" || umount -f "${MPOINT}" || umount -f -l "${MPOINT}"
