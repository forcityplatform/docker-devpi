#!/usr/bin/env bash

function usage() {
    echo "Usage : "
    echo "setup_access.sh -u user ([-a ip/mask]|[-t ip/mask]|[-u user]|[-d database])+ [-r replication_user] [-p replication_password]"
    echo "Example : setup_access.sh -d all -u cimkit_user -a 123.123.123.123/32 -t 172.17.0.1/32 -a 10.10.10.10/32 -u todelete -d replication -u replicator -a 10.240.0.0/16 -r replicator"
    echo "          will create entries for :"
    echo "            host all cimkit_user 123.123.123.123/32 md5"
    echo "            host all cimkit_user 172.17.0.1/32 trust"
    echo "            host all cimkit_user 10.10.10.10/32 md5"
    echo "            host replicator replication 10.240.0.0/16 md5"
    echo "          delete all entries for user todelete"
    echo "          and setup replication for user replicator with default password"
    exit 0
}

if [ "$1" == "" ];then
    usage
fi

current_db='all'
datadir=/dbdata
declare -A users
while getopts ":b:u:a:d:r:p:" arg; do
    case $arg in
        b)
            datadir=${OPTARG}
            ;;
        a)
            source_ip=${OPTARG}
            if [ "$main_db_user" == "" ]; then
                usage
            fi
            accesses="$accesses""host $current_db $main_db_user $source_ip md5"$'\n'
            ;;
        t)
            source_ip=${OPTARG}
            if [ "$main_db_user" == "" ]; then
                usage
            fi
            accesses="$accesses""host $current_db $main_db_user $source_ip trust"$'\n'
            ;;
        u)
            main_db_user=${OPTARG}
            users["$main_db_user"]="$main_db_user"
            ;;
        d)
            current_db=${OPTARG}
            ;;
        r)
            repluser=${OPTARG}
            ;;
        p)
            replpassword=${OPTARG}
            ;;
    esac
done

if [ "$repluser" != "" ] || [ "$replpassword" != "" ]; then
    repluser=${repluser:-"replicator"}
    replpassword=${replpassword:-"a2V_7f696V2+E*ab"}

    sed -i "/^wal_level/d" ${datadir}/postgresql.conf
    sed -i "/^max_wal_senders/d" ${datadir}/postgresql.conf
    sed -i "/^wal_keep_segments/d" ${datadir}/postgresql.conf
    sed -i "/^hot_standby/d" ${datadir}/postgresql.conf

    echo "wal_level = hot_standby" >> ${datadir}/postgresql.conf
    echo "max_wal_senders = 3" >> /${datadir}/postgresql.conf
    echo "wal_keep_segments = 16" >> ${datadir}/postgresql.conf
    echo "hot_standby = on" >> ${datadir}/postgresql.conf

    sudo -u postgres psql -c "DROP USER IF EXISTS $repluser"
    sudo -u postgres psql -c "CREATE USER $repluser REPLICATION LOGIN ENCRYPTED PASSWORD '$replpassword';"
fi

if [ "$source_ip" == "" ]; then
    usage
fi
for user in ${users[@]};do
     sed -i "/^host\s*.*\s*$MAIN_DB_USER/d" ${datadir}/pg_hba.conf
done
echo "$accesses" >> ${datadir}/pg_hba.conf
sudo -u postgres psql -c "select pg_reload_conf();"
exit 0