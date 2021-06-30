#!/bin/bash

# copyleft 2015 Serban Teodorescu <teodorescu.serban@gmail.com> 
# creates the additional required index for kobo mongo

echo "Creating index for ${MONGO_INITDB_DATABASE}..."

COL=instances

echo "db.$COL.createIndex( { _userform_id: 1 } )" | mongo ${MONGO_INITDB_DATABASE}
echo "db.$COL.createIndex( { _userform_id: 1, _id: -1 } )" | mongo ${MONGO_INITDB_DATABASE}

echo "Done!"
