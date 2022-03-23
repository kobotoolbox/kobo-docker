#!/bin/bash
# Update users if database has been already created.
# Users creation on init is left to `init_02_create_user.sh`
BASE_DIR="$(readlink -f $(dirname "$BASH_SOURCE"))"
MONGO_CMD=( mongo --host 127.0.0.1 --port 27017 --quiet )
MONGO_ADMIN_DATABASE=admin
UPSERT_DB_USERS_TRIGGER_FILE=".upsert_db_users"

_js_escape() {
	jq --null-input --arg 'str' "$1" '$str'
}

create_root() {
    "${MONGO_CMD[@]}" "$MONGO_ADMIN_DATABASE" <<-EOJS
        db.createUser({
            user: $(_js_escape "$MONGO_INITDB_ROOT_USERNAME"),
            pwd: $(_js_escape "$MONGO_INITDB_ROOT_PASSWORD"),
            roles: [ { role: 'root', db: $(_js_escape "$MONGO_ADMIN_DATABASE") } ]
        })
EOJS
}

create_user() {
    "${MONGO_CMD[@]}" "$MONGO_INITDB_DATABASE" <<-EOJS
        db.createUser({
            user: $(_js_escape "$KOBO_MONGO_USERNAME"),
            pwd: $(_js_escape "$KOBO_MONGO_PASSWORD"),
            roles: [ { role: 'readWrite', db: $(_js_escape "$MONGO_INITDB_DATABASE") } ]
        })
EOJS
}

delete_old_users() {
    old_ifs="$IFS"
    while IFS=$'\t' read -r -a lines
    do
        old_user="${lines[0]}"
        db="${lines[1]}"
        delete_user $old_user $db
    done < "${BASE_DIR}/${UPSERT_DB_USERS_TRIGGER_FILE}"
    IFS="$old_ifs"
}

delete_user() {
    # Args:
    #       $1: username
    #       $2: database
    "${MONGO_CMD[@]}" "$2" <<-EOJS
        db.dropUser($(_js_escape "$1"))
EOJS
}

get_user() {
    # Args:
    #       $1: username
    #       $2: database
    "${MONGO_CMD[@]}" "$2" <<-EOJS
        db.getUser($(_js_escape "$1"))
EOJS
}

update_password() {
    # Args:
    #       $1: username
    #       $2: password
    #       $3: database
    "${MONGO_CMD[@]}" "$3" <<-EOJS
        db.updateUser($(_js_escape "$1"), {
            pwd: $(_js_escape "$2")
        })
EOJS
}

upsert_users() {
    user=$(get_user $KOBO_MONGO_USERNAME $MONGO_INITDB_DATABASE)
    if [[ "$user" == "null" ]]; then
        echo "Creating user for ${MONGO_INITDB_DATABASE}..."
        create_user
    else
        echo "Updating user's password..."
        update_password $KOBO_MONGO_USERNAME $KOBO_MONGO_PASSWORD $MONGO_INITDB_DATABASE
    fi

    root=$(get_user $MONGO_INITDB_ROOT_USERNAME $MONGO_ADMIN_DATABASE)
    if [[ "$root" == "null" ]]; then
        echo "Creating super user..."
        create_root
    else
        echo "Updating super user's password..."
        update_password $MONGO_INITDB_ROOT_USERNAME $MONGO_INITDB_ROOT_PASSWORD $MONGO_ADMIN_DATABASE
    fi
    echo 'Done!'
}

# Update credentials only if `data/db` is not empty and `.upsert_db_users` exists.
if [[ -d "${MONGO_DATA}/" ]] && [[ -n "$(ls -A ${MONGO_DATA})" ]]; then
    # `.upsert_db_users` is created by KoBoInstall if it has detected a
    # credentials change during setup.
    if [[ -f "${BASE_DIR}/${UPSERT_DB_USERS_TRIGGER_FILE}" ]]; then
        mongod --quiet &
        until (echo > /dev/tcp/127.0.0.1/27017) 2> /dev/null; do
            echo "Waiting for local MongoDB deamon to start...";
            sleep 5;
        done
        delete_old_users
        upsert_users
        mongod --quiet --shutdown
        rm -f "${BASE_DIR}/${UPSERT_DB_USERS_TRIGGER_FILE}"
    fi
fi
