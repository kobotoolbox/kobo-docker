#!/bin/bash

# copyleft 2015 Serban Teodorescu <teodorescu.serban@gmail.com> 

# creates the additional required index for kobo mongo

DB=formhub
COL=instances

echo "db.$COL.createIndex( { _userform_id: 1 } )" | mongo $DB
