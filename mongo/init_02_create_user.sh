#!/bin/bash

echo "Creating user for ${MONGO_INITDB_DATABASE}..."

mongo=( mongo --host 127.0.0.1 --port 27017 --quiet )

_js_escape() {
	jq --null-input --arg 'str' "$1" '$str'
}

"${mongo[@]}" "$MONGO_INITDB_DATABASE" <<-EOJS
    db.createUser({
            user: $(_js_escape "$KOBO_MONGO_USERNAME"),
            pwd: $(_js_escape "$KOBO_MONGO_PASSWORD"),
            roles: [ { role: 'readWrite', db: $(_js_escape "$MONGO_INITDB_DATABASE") } ]
    })
EOJS

echo "Done!"
