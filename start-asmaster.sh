#!/bin/bash
SCRIPTNAME=$(readlink -f "$0")
SCRIPTDIR=$(dirname $SCRIPTNAME)
DATA_ROOT=/data/devpi

sudo docker rm -f devpi
sudo docker run -d --name devpi \
    --restart=always \
    -p 3141:3141 \
    -e DEVPI_ROLE=master \
    -v /data/devpi/data:/devpi \
    -v /data/devpi/ldap.yml:/ldap.yml \
    registry-v2.forcity.io/platform/internal_tools/devpi:4.7.1 \
    --ldap-config=/ldap.yml --restrict-modify devpi-admins --role master --outside-url https://devpi.forcity.io

