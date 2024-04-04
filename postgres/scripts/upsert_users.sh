#!/bin/bash
# Update users if database has been already created.
BASE_DIR="$(readlink -f $(dirname $(dirname "$BASH_SOURCE")))"
UPSERT_DB_USERS_TRIGGER_FILE=".upsert_db_users"
PSQL_CMD=""

create_user() {
    sql="CREATE USER $POSTGRES_USER WITH SUPERUSER CREATEDB CREATEROLE REPLICATION BYPASSRLS ENCRYPTED PASSWORD '$POSTGRES_PASSWORD';"
    "${PSQL_CMD[@]}" -q -c "$sql"
}

does_user_exist() {
    if "${PSQL_CMD[@]}" -t -c '\du' | cut -d \| -f 1 | grep -qw "$POSTGRES_USER"; then
        echo 1
    else
        echo 0
    fi
}

delete_user() {
    user="$1"
    echo "Deleting user \`$user\`..."
    sql="DROP USER \"$user\";"
    "${PSQL_CMD[@]}" -q -c "$sql"
}

get_old_user() {
    # `${BASE_DIR}/${UPSERT_DB_USERS_TRIGGER_FILE}` contains previous username
    # and a boolean for deletion.
    # Its format should be: `<user><TAB><boolean>`
    old_ifs="$IFS"
    IFS=$'\t' read -r -a line < "${BASE_DIR}/${UPSERT_DB_USERS_TRIGGER_FILE}"
    IFS="$old_ifs"
    echo "${line[0]}"  # echo OLD_USER
    if [[ "${line[1]}" == "true" ]]; then
        return 1
    else
        return 0
    fi
}

get_psql_command() {
    # We need to find the name of default DB created by `init_db` to be able
    # perform next commandsv
    known_dbs=( kobo postgres $OLD_USER $POSTGRES_USER )
    user="$1"
    for db in "${known_dbs[@]}"; do
        if psql -U "$user" -d "$db" -q -c "\du" | grep -vq "FATAL";  then
            PSQL_CMD=( psql -U "$user" -d "$db" )
            break
        fi
    done

    if [[ "$PSQL_CMD" == "" ]]; then
        echo "Could not connect with \`psql\`"
        exit
    fi
}

update_password() {
    sql="ALTER USER $POSTGRES_USER WITH ENCRYPTED PASSWORD '$POSTGRES_PASSWORD';"
    "${PSQL_CMD[@]}" -q -c "$sql"
}

upsert_users() {
    if [[ $(does_user_exist) == "0" ]]; then
        echo "Creating user..."
        create_user
    else
        echo "Updating user's password..."
        update_password
    fi
    echo 'Done!'
}

# Update credentials only if `/var/lib/postgresql/data` is empty and `.upsert_db_users` exists.
if [[ -d "${PGDATA}/" ]] && [[ ! -z "$(ls -A ${PGDATA})" ]]; then
    # `.upsert_db_users` is created by KoBoInstall if it has detected that
    # credentials changed during setup.
    if [[ -f "${BASE_DIR}/${UPSERT_DB_USERS_TRIGGER_FILE}" ]]; then
        OLD_USER=$(get_old_user)
        delete=$?
        get_psql_command "$OLD_USER"
        upsert_users
        if [[ "$delete" == "1" ]] && [[ "$POSTGRES_USER" != "$OLD_USER" ]]; then
            get_psql_command "$POSTGRES_USER"
            delete_user "$OLD_USER"
        fi
        rm -f "${BASE_DIR}/${UPSERT_DB_USERS_TRIGGER_FILE}"
    fi
fi
