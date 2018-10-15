#!/bin/bash

if [ "$1" != "" ];then
    DATADIR=$1
fi
if [ "$2" != "" ];then
    DBNAME=$2
fi
if [ "$3" != "" ];then
    DBUSER=$3
fi
if [ "$4" != "" ];then
    DBPASS=$4
fi

PGSQLVER=$(psql --version | awk '{print $3}' | cut -c 1-3)
if [  -z "$DATADIR" ]; then
    echo "No Data Dir Set"
    DATADIR="/dbdata"
    if [ ! -d "$DATADIR" ]; then
        mkdir -p $DATADIR
    fi
    DEFDIR=1
fi

echo "DATA DIR: $DATADIR"
CONF="/etc/postgresql/$PGSQLVER/main/postgresql.conf"
POSTGRES="/usr/lib/postgresql/$PGSQLVER/bin/postgres"
SQLDIR=$(find /usr/share/postgresql/$PGSQLVER/contrib -maxdepth 1 -mindepth 1 -name "postgis*" | head -n 1)
INITDB="/usr/lib/postgresql/$PGSQLVER/bin/initdb"
DBNAME=${DBNAME:-"forcity_platform_main_db"}
# test if DATADIR has content
DATACONTENT=""
if [ -z "$DEFDIR" ]; then
    DATACONTENT=$(ls $DATADIR)
    echo "dc:$DATACONTENT"
fi

if [ -z "$DATACONTENT" ]; then
    # No content yet - first time pg is being run! Initialise db
    echo "Initializing Postgres Database at $DATADIR"
    chown -R postgres $DATADIR
    su - postgres -c "$INITDB $DATADIR"
    echo "after initdb"
    sleep 4
fi

echo "Setting access from docker net"
CONF=$DATADIR/postgresql.conf
cp /etc/postgresql/$PGSQLVER/main/pg_hba.conf $DATADIR/pg_hba.conf
CUSTOM=`grep '# custom data conf' $CONF`
if [ -z "$CUSTOM" ]; then
    echo '# custom data conf' >> $CONF
    echo "port = 5432" >> $CONF
    echo "listen_addresses = '*'" >> $CONF
fi

# This script will run as the postgres user due to the Dockerfile USER directive
USERNAME=${DBUSER:-"core_api_master"}
PASS=${DBPASS:-"core_api_master"}
echo "Setup SSH"
cp -r /etc/ssl /tmp/ssl-copy/
chmod -R 0700 /etc/ssl
chown -R postgres /tmp/ssl-copy
rm -r /etc/ssl
mv /tmp/ssl-copy /etc/ssl
echo "Init User"
su - postgres -c "$POSTGRES --single -D $DATADIR -c config_file=$CONF <<< \"CREATE USER $USERNAME WITH SUPERUSER ENCRYPTED PASSWORD '$PASS';\""
# launch postgres server
echo "Launch PG"
su - postgres -c "$POSTGRES -D $DATADIR -c config_file=$CONF &"
# Wait for server to be up

until su - postgres -c pg_isready; do
    sleep 1
done;

RESULT=$(su - postgres -c "psql -l | grep postgis | wc -l")
if [ "$RESULT" == "1" ]; then
    echo 'Postgis Already There'
else
    echo "Postgis is missing, installing now"
    # Create the 'template_postgis' template db
    su - postgres -c "createdb template_postgis -E UTF8 -T template0"
    su - postgres -c "psql template1 -c \"UPDATE pg_database SET datistemplate = TRUE WHERE datname = 'template_postgis';\""

    # Load PostGIS into both template_database and $POSTGRES_DB
    DB=template_postgis
    #for DB in template_postgis "$POSTGRES_DB"; do
        echo "Loading PostGIS extensions into $DB"
        su - postgres -c "psql --dbname=\"$DB\"" <<-'EOSQL'
            CREATE EXTENSION IF NOT EXISTS postgis;
            CREATE EXTENSION IF NOT EXISTS postgis_topology;
            CREATE EXTENSION IF NOT EXISTS fuzzystrmatch;
            CREATE EXTENSION IF NOT EXISTS postgis_tiger_geocoder;
EOSQL
    #done
fi

RESULT=$(su - postgres -c "psql -c '\dx' template_postgis" | grep btree_gist | wc -l)
if [ "$RESULT" == "1" ]; then
    echo "Btree Gist already in template_postgis"
else
    su - postgres -c "psql template_postgis -c 'CREATE EXTENSION btree_gist;'"
fi

EXISTS=$(su - postgres -c "psql -l" | grep "$DBNAME" | wc -l)
if [ $EXISTS == "1" ]; then
    RESULT=$(su - postgres -c "psql -c '\dx' $DBNAME" | grep btree_gist | wc -l)
    if [ "$RESULT" == "1" ]; then
        echo "Btree Gist already in $DBNAME"
    else
        su - postgres -c "psql "$DBNAME" -c 'CREATE EXTENSION btree_gist;'"
    fi
else
    echo "Creating DB $DBNAME..."
    su - postgres -c "createdb --owner=$USERNAME -T template_postgis $DBNAME"
fi

su - postgres -c "psql "$DBNAME" -c 'CREATE EXTENSION tablefunc;'"

echo "Restarting Postgres"
kill -INT `head -1 $DATADIR/postmaster.pid`
sleep 2

echo "1" > "$DATADIR/createdb_complete"
