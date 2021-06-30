#!/bin/bash
# Update users if database has been already created.
# Users creation on init is left to `init_02_create_user.sh`
BASE_DIR="$(readlink -f $(dirname "$BASH_SOURCE"))"
MONGO_CMD=( mongo --host 127.0.0.1 --port 27017 --quiet -u "$KOBO_MONGO_USERNAME" -p "$KOBO_MONGO_PASSWORD")
MONGO_ADMIN_DATABASE=admin
COLLECTION=instances

while [ "$((echo > /dev/tcp/127.0.0.1/27017) >/dev/null 2>&1 && echo "1" || echo "0")" == "0" ]; do
    echo "Waiting for MongoDB to start...";
    sleep 30;
done

# MongoDB will skip the creation if index already exists.
# It will return a note telling it already exists.
# {
#	"createdCollectionAutomatically" : false,
#	"numIndexesBefore" : 2,
#	"numIndexesAfter" : 2,
#	"note" : "all indexes already exist",
#	"ok" : 1
# }
create_compound_index() {
    "${MONGO_CMD[@]}" "$MONGO_INITDB_DATABASE" <<-EOJS
        db.$COLLECTION.createIndex({
            _userform_id: 1,
            _id: -1,
        }, {
            background: true
        })
EOJS
}

echo "Creating compound index for ${MONGO_INITDB_DATABASE} in background..."
create_compound_index
