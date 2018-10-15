#!/bin/bash
PGSQLVER=$(psql --version | awk '{print $3}' | cut -c 1-3)
echo "Postgres version: $PGSQLVER"
POSTGRES="/usr/lib/postgresql/$PGSQLVER/bin/postgres"

if [ -z "$DATADIR" ]; then
    DATADIR="/dbdata"
fi

if [ ! -f "$DATADIR/PG_VERSION" ];then
    cp -R /dbtemplate/* $DATADIR/
fi
if [ ! -d "/tmp/tmpfs/pgsql" ]; then
    mkdir -p /tmp/tmpfs/pgsql
fi

chown -R postgres.postgres $DATADIR /tmp/tmpfs/pgsql
chmod 0700 $DATADIR

CONF=$DATADIR/postgresql.conf
TUNED=cat $CONF | grep "pgtune"

if [ -z "$TUNED" ]; then
    echo "Tuning DB Engine..."
    pgtune -i $CONF -o $CONF.pgt
    sed -i "/^checkpoint_segments/d" $CONF.pgt
    cp $CONF.pgt $CONF
fi

sed -i "/^work_mem/d" /dbdata/postgresql.conf
sed -i "/^# work_mem/d" /dbdata/postgresql.conf
echo "work_mem = 128MB" >> /dbdata/postgresql.conf
sed -i "/^stats_temp_directory/d" /dbdata/postgresql.conf
echo "stats_temp_directory='/tmp/tmpfs/pgsql'" >> /dbdata/postgresql.conf
sed -i "/^#.*# pgtune/d" /dbdata/postgresql.conf

sed -i "/^tcp_keepalives_idle/d" /dbdata/postgresql.conf
echo "tcp_keepalives_idle = 60" >> /dbdata/postgresql.conf
sed -i "/^tcp_keepalives_interval/d" /dbdata/postgresql.conf
echo "tcp_keepalives_interval = 15" >> /dbdata/postgresql.conf
sed -i "/^tcp_keepalives_count/d" /dbdata/postgresql.conf
echo "tcp_keepalives_count = 5" >> /dbdata/postgresql.conf

if [ -f "/sys/fs/cgroup/memory/memory.limit_in_bytes" ]; then
    memory_limit=$(cat /sys/fs/cgroup/memory/memory.limit_in_bytes)
    effective_cache_size=$(echo ${memory_limit} | awk '{print int(($1/1048576)*2/3)}')
    shared_buffers=$(echo ${memory_limit} | awk '{print int(($1/1048576)/4)}')
    sed -i "/^default_statistics_target/d" /dbdata/postgresql.auto.conf
    sed -i "/^constraint_exclusion/d" /dbdata/postgresql.auto.conf
    sed -i "/^effective_cache_size/d" /dbdata/postgresql.auto.conf
    sed -i "/^shared_buffers/d" /dbdata/postgresql.auto.conf
    sed -i "/^work_mem/d" /dbdata/postgresql.auto.conf
    sed -i "/^checkpoint_timeout/d" /dbdata/postgresql.auto.conf
    sed -i "/^checkpoint_completion_target/d" /dbdata/postgresql.auto.conf
    sed -i "/^max_wal_size/d" /dbdata/postgresql.auto.conf
    sed -i "/^maintenance_work_mem/d" /dbdata/postgresql.auto.conf
    sed -i "/^wal_buffers/d" /dbdata/postgresql.auto.conf
    sed -i "/^synchronous_commit/d" /dbdata/postgresql.auto.conf
    sed -i "/^fsync/d" /dbdata/postgresql.auto.conf
    echo <<EOT >> /dbdata/postgresql.auto.conf
default_statistics_target = '100'
constraint_exclusion = 'partition'
effective_cache_size = '${effective_cache_size}MB'
shared_buffers = '${shared_buffers}MB'
work_mem = '1GB'
checkpoint_timeout = '5min'
checkpoint_completion_target = '0.9'
max_wal_size = '10GB'
maintenance_work_mem = '2GB'
wal_buffers = '32MB'
synchronous_commit = 'off'
fsync = 'on'
EOT
fi

/etc/init.d/ssh start
su - postgres -c "$POSTGRES -D $DATADIR -c config_file=$CONF"
