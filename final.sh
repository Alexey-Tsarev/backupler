#!/bin/sh

if [ "${PACKAGES_LIST_FLAG}" != "0" ]; then
    command -v rpm > /dev/null && rpm -qa
    command -v dpkg > /dev/null && dpkg -l
    echo
fi

if [ "${DOCKER_FLAG}" != "0" ]; then
    command -v docker > /dev/null && docker ps
    echo
fi
