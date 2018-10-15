#!/usr/bin/env bash
SOURCE_IP=$1
SOURCE_IP=${SOURCE_IP:-"10.240.0.0/16"}
MAIN_DB_USER=$2
MAIN_DB_USER=${MAIN_DB_USER:-"core_api_master"}
sed -i "/^host\s*all\s*$MAIN_DB_USER/d" /dbdata/pg_hba.conf
sed -i '/^host\s*replication\s*replicator/d' /dbdata/pg_hba.conf

echo "host all $MAIN_DB_USER $SOURCE_IP md5" >> /dbdata/pg_hba.conf
echo "host replication replicator $SOURCE_IP md5" >> /dbdata/pg_hba.conf

sed -i "/^wal_level/d" /dbdata/postgresql.conf
sed -i "/^max_wal_senders/d" /dbdata/postgresql.conf
sed -i "/^wal_keep_segments/d" /dbdata/postgresql.conf
sed -i "/^hot_standby/d" /dbdata/postgresql.conf

echo "wal_level = hot_standby" >> /dbdata/postgresql.conf
echo "max_wal_senders = 3" >> /dbdata/postgresql.conf
echo "wal_keep_segments = 16" >> /dbdata/postgresql.conf
echo "hot_standby = on" >> /dbdata/postgresql.conf

sudo -u postgres psql -c "CREATE USER replicator REPLICATION LOGIN ENCRYPTED PASSWORD 'a2V_7f696V2+E*ab';"
sudo -u postgres psql -c "select pg_reload_conf();"
