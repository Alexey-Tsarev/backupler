#!/bin/sh

#1 - to
#2 - subj
#3 - mgs

msg="Subject: $2

$3"

# set -x
#echo "${msg}" | msmtp --debug "--from=$1" --host=127.0.0.1 mailer

echo "${msg}" | msmtp "--from=$1" --host=127.0.0.1 mailer
