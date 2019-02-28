#!/bin/bash

apt-get update
dpkg -i pg-bulkload95_3.1.9-1.rhel5_amd64.deb
ln -s /usr/pgsql-9.5/share/extension/pg_bulkload.control /usr/share/postgresql/9.5/extension/
ln -s /usr/pgsql-9.5/share/extension/pg_bulkload--1.0.sql /usr/share/postgresql/9.5/extension/pg_bulkload--1.0.sql
ln -s /usr/pgsql-9.5/share/extension/pg_bulkload--unpackaged--1.0.sql /usr/share/postgresql/9.5/extension/pg_bulkload--unpackaged--1.0.sql
ln -s /usr/pgsql-9.5/share/extension/pg_bulkload.sql /usr/share/postgresql/9.5/extension/pg_bulkload.sql
ln -s /usr/pgsql-9.5/share/extension/uninstall_pg_bulkload.sql /usr/share/postgresql/9.5/extension/uninstall_pg_bulkload.sql
ln -s /usr/pgsql-9.5/bin/pg_bulkload /usr/lib/postgresql/9.5/pg_bulkload
ln -s /usr/pgsql-9.5/lib/pg_bulkload.so /usr/lib/postgresql/9.5/lib/pg_bulkload.so
ln -s /usr/lib/x86_64-linux-gnu/libssl.so.1.1 /lib/x86_64-linux-gnu/libssl.so.6
ln -s /usr/lib/x86_64-linux-gnu/libcrypto.so.1.1 /lib/x86_64-linux-gnu/libcrypto.so.6
ln -s /lib/x86_64-linux-gnu/libreadline.so.7 /lib/x86_64-linux-gnu/libreadline.so.5
ln -s /lib/x86_64-linux-gnu/libncurses.so.5.9 /lib/x86_64-linux-gnu/libtermcap.so.2


# Thanks to https://stackoverflow.com/questions/3685970/check-if-a-bash-array-contains-a-value
function contains() {
    local n=$#
    local value=${!n}
    for ((i=1;i < $#;i++)) {
        if [ "${!i}" == "${value}" ]; then
            echo "y"
            return 0
        fi
    }
    echo "n"
    return 1
}

psql -U ${POSTGRES_USER} -d ${KPI_POSTGRES_DB} -c "CREATE EXTENSION pg_bulkload;"

KPI_TABLES=($(psql -U ${POSTGRES_USER} -d ${KPI_POSTGRES_DB} -t -c "SELECT tablename FROM pg_catalog.pg_tables where schemaname='public'"))

SLEEP_TIME=0
MESSAGE="WARNING!!! This script will wipe all the data on target database:"
TARGET_DBNAME_LEN=${#KPI_POSTGRES_DB}
MESSAGE_LEN=${#MESSAGE}
LIMIT=$((MESSAGE_LEN-TARGET_DBNAME_LEN-1))

printf "╔═%s═╗\n" $(printf "═%.0s" $(seq 1 $MESSAGE_LEN))
printf "║ ${MESSAGE} ║\n"
printf "║ ${KPI_POSTGRES_DB} %s ║\n" $(printf ".%.0s" $(seq 1 $LIMIT))
printf "╚═%s═╝\n" $(printf "═%.0s" $(seq 1 $MESSAGE_LEN))

while true; do

    read -p "Do you want to continue [y/N]?" yn
    case $yn in
        [Yy]* ) break;;
        [Nn]* ) exit;;
        * ) echo "Please answer Y or N.";;
    esac
done


for KPI_TABLE in "${KPI_TABLES[@]}"
do
    :
    echo "Truncating ${KPI_POSTGRES_DB}.public.${KPI_TABLE}..."
    psql \
        -X \
        -U ${POSTGRES_USER} \
        -h localhost \
        -d ${KPI_POSTGRES_DB} \
        -c "TRUNCATE TABLE ${KPI_TABLE} RESTART IDENTITY CASCADE"
    printf "\tDone!\n"
    sleep $SLEEP_TIME # Use to let us read the output if there are any errors
    echo ""
done

KPI_SEQUENCES=($(psql -U ${POSTGRES_USER} -d ${KPI_POSTGRES_DB} -t -c "SELECT c.relname FROM pg_class c WHERE c.relkind = 'S';"))

for KPI_TABLE in "${KPI_TABLES[@]}"
do
    :

    echo "OUTPUT = public.${KPI_TABLE}          # [<schema_name>.]table_name" > /tmp/kc2kpi.ctl
    echo "INPUT = stdin                         # Input data location (absolute path)" >> /tmp/kc2kpi.ctl
    echo "TYPE = CSV                            # Input file type" >> /tmp/kc2kpi.ctl
    echo 'QUOTE = "\""                          # Quoting character'  >> /tmp/kc2kpi.ctl
    echo "ESCAPE = \                            # Escape character for Quoting" >> /tmp/kc2kpi.ctl
    echo "DELIMITER = \",\"                       # Delimiter" >> /tmp/kc2kpi.ctl


    echo "Copying table ${KC_POSTGRES_DB}.public.${KPI_TABLE} to ${KPI_POSTGRES_DB}.public.${KPI_TABLE}..."

    psql \
        -X \
        -U ${POSTGRES_USER} \
        -h localhost \
        -d ${KC_POSTGRES_DB} \
        -c "\\copy ${KPI_TABLE} to stdout WITH DELIMITER ',' QUOTE '\"' ESCAPE '\\' CSV " \
    | \
    /usr/lib/postgresql/9.5/pg_bulkload /tmp/kc2kpi.ctl \
        -U ${POSTGRES_USER} \
        -h localhost \
        -d ${KPI_POSTGRES_DB} \
        -P /tmp/${KPI_TABLE}-bad-parsing.log \
        -u /tmp/${KPI_TABLE}-duplicate.log
    sleep $SLEEP_TIME # Use to let us read the output if there are any errors
    printf "\tDone!\n"

    SEQUENCE_NAME="${KPI_TABLE}_id_seq"
    if [ $(contains "${KPI_SEQUENCES[@]}" "${SEQUENCE_NAME}") == "y" ]; then
        echo "Updating sequence for table ${KPI_POSTGRES_DB}.public.${KPI_TABLE}..."
        psql \
            -X \
            -U ${POSTGRES_USER} \
            -h localhost \
            -d ${KPI_POSTGRES_DB} \
            -c "SELECT setval('${SEQUENCE_NAME}', (SELECT max(id) from ${KPI_TABLE}))"
        sleep $SLEEP_TIME # Use to let us read the output if there are any errors
        echo ""
    fi
done

psql -U ${POSTGRES_USER} -d ${KPI_POSTGRES_DB} -c "DROP EXTENSION pg_bulkload;"
