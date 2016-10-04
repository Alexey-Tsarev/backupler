#!/bin/sh

set -x

XMPP_URL=http://some.host/send_xmpp.php?pass=password
POST_DATA_VAR=mes
LINES=

if [ -n "$1" ]; then
    LINES=$1
else
    while read LINE; do
        LINES="${LINES}${LINE}
"
    done
fi

wget -O- --post-data "$POST_DATA_VAR=$LINES" "$XMPP_URL"
