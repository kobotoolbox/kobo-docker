#!/bin/bash
# Create `_userform_id_id_` compound index in existing databases.
# Creation in new databases is handled by `init_01_add_index.sh`.

MONGO_CMD=( mongo --host 127.0.0.1 --port 27017 --quiet -u "$KOBO_MONGO_USERNAME" -p "$KOBO_MONGO_PASSWORD")
COLLECTION=instances

until (echo > /dev/tcp/127.0.0.1/27017) 2> /dev/null; do
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
