#!/bin/bash

# copyleft 2015 Serban Teodorescu <teodorescu.serban@gmail.com>
# creates the additional required index for kobo mongo

echo "Creating index for ${MONGO_INITDB_DATABASE}..."

COL=instances

# Primary submission list query + default sort by `_id`.
echo "db.$COL.createIndex( { _userform_id: 1, _id: -1 } )" | mongosh "$MONGO_INITDB_DATABASE"
# Sort submissions by submission date.
echo "db.$COL.createIndex( { _userform_id: 1, _submission_time: -1 } )" | mongosh "$MONGO_INITDB_DATABASE"
# Lookup a submission by its root_uuid (edit links, permalinks).
echo "db.$COL.createIndex( { \"meta/rootUuid\": 1, _id: 1 }, { name: \"rootUuid_id_idx\" } )" | mongosh "$MONGO_INITDB_DATABASE"
# Backfill scan for submissions still missing root_uuid (long-running migration 0028).
echo "db.$COL.createIndex( { _id: 1, \"meta/rootUuid\": 1 }, { name: \"id_rootUuid_idx\" } )" | mongosh "$MONGO_INITDB_DATABASE"
# Fallback lookup by `_uuid` when root_uuid isn't set (legacy submissions).
echo "db.$COL.createIndex( { _userform_id: 1, _uuid: 1 } )" | mongosh "$MONGO_INITDB_DATABASE"

# The only code that queried these two (kobo/apps/trash_bin/utils/project.py::
# _delete_submissions) is dead (unreachable, raises before reaching that query).
# Drop them on existing deployments; do not recreate.
# echo "db.$COL.createIndex( { \"formhub/uuid\": 1 } )" | mongosh "$MONGO_INITDB_DATABASE"
# echo "db.$COL.createIndex( { _xform_id_string: 1 } )" | mongosh "$MONGO_INITDB_DATABASE"

echo "Done!"
