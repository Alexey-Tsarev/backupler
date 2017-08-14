#!/usr/bin/env bash

export US=xxx
export GR=xxx
export MPOINT=/mnt/k3-note

mkdir -p "$MPOINT"
umount "$MPOINT"
mount -t cifs -o uid=${US},gid=${GR},credentials=$(readlink -f `dirname $0`)/cfg/k3-note.smbcredentials //k3.home.local/root "$MPOINT"
su "$US" -c "./backupler.sh k3-note"
umount "$MPOINT"
