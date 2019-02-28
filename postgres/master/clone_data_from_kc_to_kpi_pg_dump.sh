#!/bin/bash

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


MESSAGE="WARNING!!! This script will wipe all the data on target database:"
TARGET_DBNAME_LEN=${#KPI_POSTGRES_DB}
MESSAGE_LEN=${#MESSAGE}
LIMIT=$((MESSAGE_LEN-TARGET_DBNAME_LEN-1))

printf "╔═%s═╗\n" $(printf "═%.0s" $(seq 1 $MESSAGE_LEN))
printf "║ ${MESSAGE} ║\n"
printf "║ ${KPI_POSTGRES_DB} %s ║\n" $(printf ".%.0s" $(seq 1 $LIMIT))
printf "╚═%s═╝\n" $(printf "═%.0s" $(seq 1 $MESSAGE_LEN))

#while true; do
#
#    read -p "Do you want to continue [y/N]?" yn
#    case $yn in
#        [Yy]* ) break;;
#        [Nn]* ) exit;;
#        * ) echo "Please answer Y or N.";;
#    esac
#done

KPI_TABLES=($(psql -U ${POSTGRES_USER} -d ${KPI_POSTGRES_DB} -t -c "SELECT tablename FROM pg_catalog.pg_tables where schemaname='public'"))
KPI_SEQUENCES=($(psql -U ${POSTGRES_USER} -d ${KPI_POSTGRES_DB} -t -c "SELECT c.relname FROM pg_class c WHERE c.relkind = 'S';"))

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
    #sleep 1 # Use to let us read the output if there are any errors
    echo ""
done


PG_DUMP_COMMAND="pg_dump -U ${POSTGRES_USER} -h localhost -d ${KC_POSTGRES_DB} --disable-triggers"

for KPI_TABLE in "${KPI_TABLES[@]}"
do
    :
    PG_DUMP_COMMAND="${PG_DUMP_COMMAND} -t ${KPI_TABLE}"
    SEQUENCE_NAME="${KPI_TABLE}_id_seq"
    if [ $(contains "${KPI_SEQUENCES[@]}" "${SEQUENCE_NAME}") == "y" ]; then
        PG_DUMP_COMMAND="${PG_DUMP_COMMAND} -t ${SEQUENCE_NAME}"
    fi
done

#$PG_DUMP_COMMAND | pg_restore -a --verbose -U ${POSTGRES_USER} -h localhost -d ${KPI_POSTGRES_DB}
$PG_DUMP_COMMAND | psql -X -v ON_ERROR_STOP=0 -U ${POSTGRES_USER} -d ${KPI_POSTGRES_DB}
