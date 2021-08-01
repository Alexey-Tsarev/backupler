#!/bin/sh

msg="$(cat)"
SD="$(cd "$(dirname "$0")" && pwd)"
"${SD}/send_email.sh" "bck" "$1" "${msg}"
