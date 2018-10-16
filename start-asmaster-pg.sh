#!/bin/bash
SCRIPTNAME=$(readlink -f "$0")
SCRIPTDIR=$(dirname $SCRIPTNAME)
DATA_ROOT=/data/devpi

if [ -f "$DATA_ROOT/db/postmaster.pid" ]; then
    pg_version=$(sudo docker exec -t devpi_db psql --version | awk '{print $3}' | cut -c 1-3)
    sudo docker exec -t devpi_db su postgres -c "/usr/lib/postgresql/${pg_version}/bin/pg_ctl stop -m fast -D /dbdata"
    sudo rm -f $DATA_ROOT/db/postmaster.pid
fi

sudo docker rm -f devpi_db

sudo docker run -d --restart=unless-stopped --name devpi_db \
    -e DATADIR=/dbdata \
    -v $DATA_ROOT/db/tmpdata:/tmpdata \
    -v $DATA_ROOT/db/tmpshared:/tmpshared \
    -v $DATA_ROOT/db/dbdata:/dbdata \
    -v /tmp/devpi_db:/tmp \
    -m 14G \
    --oom-kill-disable \
    registry-v2.forcity.io/platform/internal_tools/devpi_db:latest

sudo docker exec -t devpi_db bash -c "until pg_isready -h 127.0.0.1 -p 5432; do sleep 1; done;"

sudo docker rm -f devpi
sudo docker run -d --name devpi \
    --restart=always \
    -p 3141:3141 \
    -e DEVPI_ROLE=master \
    -v /data/devpi/data:/devpi \
    -v /data/devpi/ldap.yml:/ldap.yml \
    --link devpi_db:devpi_db \
    registry-v2.forcity.io/platform/internal_tools/devpi:4.7.1 \
    --ldap-config=/ldap.yml --restrict-modify devpi-admins --role master --outside-url https://devpi.forcity.io \
    --storage pg8000:host=devpi_db,port=5432,database=devpi,user=devpi,password=devpi

