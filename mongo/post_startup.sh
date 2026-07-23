#!/bin/bash
# Create/update the required indexes on `instances` in existing databases.
# Creation in new databases is handled by `init_01_add_index.sh`.

MONGO_CMD=( mongosh --host 127.0.0.1 --port 27017 --quiet -u "$KOBO_MONGO_USERNAME" -p "$KOBO_MONGO_PASSWORD")
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

# Primary submission list query + default sort by `_id`.
create_userform_id_and_id_index() {
    "${MONGO_CMD[@]}" "$MONGO_INITDB_DATABASE" <<-EOJS
        db.$COLLECTION.createIndex({
            _userform_id: 1,
            _id: -1,
        }, {
            background: true
        })
EOJS
}

# Sort submissions by submission date.
create_userform_id_and_submission_time_index() {
    "${MONGO_CMD[@]}" "$MONGO_INITDB_DATABASE" <<-EOJS
        db.$COLLECTION.createIndex({
            _userform_id: 1,
            _submission_time: -1,
        }, {
            background: true
        })
EOJS
}

# Lookup a submission by its root_uuid (edit links, permalinks).
create_root_uuid_index() {
    "${MONGO_CMD[@]}" "$MONGO_INITDB_DATABASE" <<-EOJS
        db.$COLLECTION.createIndex({
            'meta/rootUuid': 1,
            _id: 1,
        }, {
            name: 'rootUuid_id_idx',
            background: true
        })
EOJS
}

# Backfill scan for submissions still missing root_uuid (long-running migration 0028).
create_id_root_uuid_index() {
    "${MONGO_CMD[@]}" "$MONGO_INITDB_DATABASE" <<-EOJS
        db.$COLLECTION.createIndex({
            _id: 1,
            'meta/rootUuid': 1,
        }, {
            name: 'id_rootUuid_idx',
            background: true
        })
EOJS
}

# Fallback lookup by `_uuid` when root_uuid isn't set (legacy submissions).
create_userform_id_and_uuid_index() {
    "${MONGO_CMD[@]}" "$MONGO_INITDB_DATABASE" <<-EOJS
        db.$COLLECTION.createIndex({
            _userform_id: 1,
            _uuid: 1,
        }, {
            background: true
        })
EOJS
}

# The only code that queried these two (kobo/apps/trash_bin/utils/project.py::
# _delete_submissions) is dead (unreachable, raises before reaching that query).
# Drop them on existing deployments; do not recreate.
# create_formhub_uuid_index() {
#     "${MONGO_CMD[@]}" "$MONGO_INITDB_DATABASE" <<-EOJS
#         db.$COLLECTION.createIndex({
#             'formhub/uuid': 1,
#         }, {
#             background: true
#         })
# EOJS
# }
#
# create_xform_id_string_index() {
#     "${MONGO_CMD[@]}" "$MONGO_INITDB_DATABASE" <<-EOJS
#         db.$COLLECTION.createIndex({
#             _xform_id_string: 1,
#         }, {
#             background: true
#         })
# EOJS
# }

echo "Creating new indexes for ${MONGO_INITDB_DATABASE} in background..."
create_userform_id_and_id_index
create_userform_id_and_submission_time_index
create_root_uuid_index
create_id_root_uuid_index
create_userform_id_and_uuid_index
# create_formhub_uuid_index
# create_xform_id_string_index
