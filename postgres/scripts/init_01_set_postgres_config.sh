#!/usr/bin/env bash

if [ ! -f "$POSTGRES_CONFIG_FILE.orig" ]; then
    echo "Let's keep a copy of current configuration file!"
    cp $POSTGRES_CONFIG_FILE "$POSTGRES_CONFIG_FILE.orig"
fi

echo "Applying new configuration..."
cp $KOBO_DOCKER_SCRIPTS_DIR/conf/postgres.conf $POSTGRES_CONFIG_FILE

if [ -f "$KOBO_DOCKER_SCRIPTS_DIR/conf/postgres.conf" ]; then
    echo "Appending role specific configuration..."
    cat $KOBO_DOCKER_SCRIPTS_DIR/conf/postgres.conf >> $POSTGRES_CONFIG_FILE

    if grep -q "\$PGDATA" "$POSTGRES_CONFIG_FILE"; then
        sed -i "s#\$PGDATA#"$PGDATA"#g" $POSTGRES_CONFIG_FILE
    fi
fi

if [ ! -f "$POSTGRES_CLIENT_AUTH_FILE.orig" ]; then
    echo "Let's keep a copy of current client authentication configuration file!"
    cp $POSTGRES_CLIENT_AUTH_FILE "$POSTGRES_CLIENT_AUTH_FILE.orig"
fi

echo "Applying new client authentication configuration file..."
cp $KOBO_DOCKER_SCRIPTS_DIR/config/pg_hba.conf "$POSTGRES_CLIENT_AUTH_FILE"
