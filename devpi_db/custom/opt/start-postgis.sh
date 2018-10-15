#!/bin/bash
PGSQLVER=$(psql --version | awk '{print $3}' | cut -c 1-3)
# This script will run as the postgres user due to the Dockerfile USER directive
if [  -z "$DATADIR" ]; then
	echo "No Data Dir Set"
	DATADIR="/var/lib/postgresql/$PGSQLVER/main"
fi
CONF="/etc/postgresql/$PGSQLVER/main/postgresql.conf"
POSTGRES="/usr/lib/postgresql/$PGSQLVER/bin/postgres"
INITDB="/usr/lib/postgresql/$PGSQLVER/bin/initdb"
SQLDIR=$(find /usr/share/postgresql/$PGSQLVER/contrib -maxdepth 1 -mindepth 1 -name "postgis*" | head -n 1)

# /etc/ssl/private can't be accessed from within container for some reason
# (@andrewgodwin says it's something AUFS related)  - taken from https://github.com/orchardup/docker-postgresql/blob/master/Dockerfile
cp -r /etc/ssl /tmp/ssl-copy/
chmod -R 0700 /etc/ssl
chown -R postgres /tmp/ssl-copy
rm -r /etc/ssl
mv /tmp/ssl-copy /etc/ssl


# test if DATADIR is existent
if [ ! -d $DATADIR ]; then
  echo "Creating Postgres data at $DATADIR"
  mkdir -p $DATADIR
fi
# needs to be done as root:
chown -R postgres:postgres $DATADIR

# Note that $USERNAME and $PASS below are optional paramters that can be passed
# via docker run e.g.
#docker run --name="postgis" -e USERNAME=qgis -e PASS=qgis -d -v
#/var/docker-data/postgres-dat:/var/lib/postgresql -t qgis/postgis:6

# If you dont specify a user/password in docker run, we will generate one
# here and create a user called 'docker' to go with it.

locale-gen en_US
locale-gen en_US.UTF-8
update-locale

# test if DATADIR has content
if [ ! "$(ls -A $DATADIR)" ]; then

  # No content yet - first time pg is being run!
  # Initialise db
  echo "Initializing Postgres Database at $DATADIR"
  #chown -R postgres $DATADIR
  su - postgres -c "$INITDB $DATADIR"
fi

# Make sure we have a user set up
if [ -z "$USERNAME" ]; then
  USERNAME=docker
fi
if [ -z "$PASS" ]; then
  PASS=docker
fi
# redirect user/pass into a file so we can echo it into
# docker logs when container starts
# so that we can tell user their password
echo "postgresql user: $USERNAME" > /tmp/PGPASSWORD.txt
echo "postgresql password: $PASS" >> /tmp/PGPASSWORD.txt
su - postgres -c "$POSTGRES --single -D $DATADIR -c config_file=$CONF <<< \"CREATE USER $USERNAME WITH SUPERUSER ENCRYPTED PASSWORD '$PASS';\""

trap "echo \"Sending SIGTERM to postgres\"; killall -s SIGTERM postgres" SIGTERM

su - postgres -c "$POSTGRES -D $DATADIR -c config_file=$CONF &"

# Wait for the db to start up before trying to use it....

sleep 10

RESULT=`su - postgres -c "psql -l | grep postgis | wc -l"`
if [[ "$RESULT" == '1' ]]
then
    echo 'Postgis Already There'
else
    echo "Postgis is missing, installing now"
    # Create the 'template_postgis' template db
    su - postgres -c "psql" <<- 'EOSQL'
    CREATE DATABASE template_postgis;
    UPDATE pg_database SET datistemplate = TRUE WHERE datname = 'template_postgis';
EOSQL

    # Load PostGIS into both template_database and $POSTGRES_DB
    for DB in template_postgis "$POSTGRES_DB"; do
        echo "Loading PostGIS extensions into $DB"
        su - postgres -c "psql --dbname=\"$DB\"" <<-'EOSQL'
            CREATE EXTENSION IF NOT EXISTS postgis;
            CREATE EXTENSION IF NOT EXISTS postgis_topology;
            CREATE EXTENSION IF NOT EXISTS fuzzystrmatch;
            CREATE EXTENSION IF NOT EXISTS postgis_tiger_geocoder;
EOSQL
    done
fi
# This should show up in docker logs afterwards
su - postgres -c "psql -l"

PID=`cat /var/run/postgresql/$PGSQLVER-main.pid`
kill -9 ${PID}
echo "Postgres initialisation process completed .... restarting in foreground"
su - postgres -c "$POSTGRES -D $DATADIR -c config_file=$CONF"
