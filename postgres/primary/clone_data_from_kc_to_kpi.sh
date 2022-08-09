#!/bin/bash
set -eEuo pipefail

SLEEP_TIME=0
HELP_PAGE='https://community.kobotoolbox.org/t/upgrading-to-separate-databases-for-kpi-and-kobocat/7202'
KPI_LAST_EXPECTED_MIGRATION='0022_assetfile'

if [ $# -gt 0 ] && [ "$1" = '--noinput' ]
then
    skip_prompts='yes'
else
    skip_prompts='no'
fi

function error_handler() {
    echo
    echo "Something went wrong. Please read the output above and visit $HELP_PAGE for assistance."
}

trap error_handler ERR

function prompt_to_continue() {
    if [ "$skip_prompts" = 'yes' ]; then return; fi
    while true
    do
        read -p "Do you want to continue [y/N]? " yn
        case $yn in
            [Yy] ) break;;
            [Nn] ) exit;;
            '' ) exit;;
            * ) echo "Please answer Y or N.";;
        esac
    done
}

function lines_to_dots() { while read trash; do echo -n '.'; done }

#KPI_TABLES=($(psql -U ${POSTGRES_USER} -d ${KPI_POSTGRES_DB} -t -c "SELECT tablename FROM pg_catalog.pg_tables where schemaname='public'"))
# We could read table from DB, but we need the order to be respected.
# Otherwise inserts may fail because of FK not present.
KPI_TABLES=(
 spatial_ref_sys
 django_migrations
 django_content_type
 auth_user
 auth_group
 auth_permission
 auth_group_permissions
 auth_user_groups
 auth_user_user_permissions
 constance_config
 django_celery_beat_periodictasks
 django_celery_beat_crontabschedule
 django_celery_beat_intervalschedule
 django_celery_beat_periodictask
 django_celery_beat_solarschedule
 django_admin_log
 authtoken_token
 django_digest_partialdigest
 taggit_tag
 taggit_taggeditem
 kpi_collection
 kpi_asset
 reversion_revision
 reversion_version
 kpi_assetversion
 kpi_importtask
 kpi_authorizedapplication
 kpi_taguid
 kpi_objectpermission
 kpi_assetsnapshot
 kpi_onetimeauthenticationkey
 kpi_usercollectionsubscription
 kpi_exporttask
 kpi_assetfile
 hub_sitewidemessage
 hub_configurationfile
 hub_formbuilderpreference
 hub_extrauserdetail
 hub_perusersetting
 oauth2_provider_application
 django_session
 oauth2_provider_accesstoken
 oauth2_provider_grant
 django_digest_usernonce
 oauth2_provider_refreshtoken
 registration_registrationprofile
 hook_hook
 hook_hooklog
 external_integrations_corsmodel
 help_inappmessage
 help_inappmessagefile
 help_inappmessageuserinteractions
)

kpi_tables_single_quoted_csv=$(echo "${KPI_TABLES[@]}" | sed "s/^/'/;s/ /','/g;s/$/'/")
actual_kpi_tables_count=$(
    psql -Xqt -h localhost \
        -U "$POSTGRES_USER" \
        -d "$KC_POSTGRES_DB" \
        -c "SELECT COUNT(*) FROM pg_tables WHERE tablename in ($kpi_tables_single_quoted_csv);"
)
if [ "$actual_kpi_tables_count" -ne ${#KPI_TABLES[@]} ]
then
    echo -n "The source database, \`$KC_POSTGRES_DB\`, does not contain the needed KPI tables. "
    echo -n 'If this installation never used a single, shared database for both KPI and KoBoCAT, '
    echo 'then this script is not needed. Otherwise, the database configuration may be incorrect.'
    echo "For help, visit $HELP_PAGE."
    exit 1
fi

matching_dbs_count=$(
    psql -Xqt -h localhost \
        -U "$POSTGRES_USER" \
        -d postgres \
        -c 'SELECT COUNT(*) FROM pg_database WHERE datname='"'$KPI_POSTGRES_DB';"
)
if [ "$matching_dbs_count" -eq 0 ]
then
    echo "Safety check: the target database \`$KPI_POSTGRES_DB\` does not exist yet (OK)"
else
    echo -n "The target database \`$KPI_POSTGRES_DB\` already exists, and "
    matching_tables_count=$(
        psql -Xqt -h localhost \
            -U "$POSTGRES_USER" \
            -d "$KPI_POSTGRES_DB" \
            -c 'SELECT COUNT(*) FROM pg_tables WHERE tablename='"'kpi_asset';"
    )
    if [ "$matching_tables_count" -eq 0 ]
    then
        echo "it appears to be empty because it does not contain an assets table."
    else
        asset_count=$(
            psql -Xqt -h localhost \
                -U "$POSTGRES_USER" \
                -d "$KPI_POSTGRES_DB" \
                -c 'SELECT COUNT(*) FROM kpi_asset;' \
            | sed 's/ //g'
        )
        if [ $asset_count -eq 0 ]
        then
            echo "it appears to be empty because it contains no assets."
        else
            echo -n "it contains $asset_count "
            if [ $asset_count -gt 1 ]; then echo 'assets!'; else echo 'asset!'; fi
            if [ "$skip_prompts" = 'yes' ]
            then
                echo 'Re-run this script manually, without the `--noinput` option, if you want to proceed.'
                echo "For help, visit $HELP_PAGE."
                exit 1
            fi
            echo
            echo '*** IF YOU HAVE ALREADY RUN THIS SCRIPT SUCCESSFULLY, PLEASE EXIT NOW. ***'
            echo
            echo -n "While this script does not delete any data, the contents of \`$KPI_POSTGRES_DB\` "
            echo 'will NO LONGER BE ACCESSIBLE in the KoboToolbox application if you continue.'
            echo "For help, visit $HELP_PAGE."
            echo
        fi
    fi
    timestamp=$(date '+%s')
    new_db_name="${KPI_POSTGRES_DB}__RENAMED_BY_2DB_CLONE_SCRIPT_$timestamp"
    echo "In order to proceed, this existing KPI database will be renamed to \`$new_db_name\`."
    prompt_to_continue
    psql -Xqt -h localhost \
        -U "$POSTGRES_USER" \
        -d postgres \
        -c "ALTER DATABASE \"$KPI_POSTGRES_DB\" RENAME TO \"$new_db_name\";"
fi

kpi_last_actual_migration=$(
    psql -Xqt -h localhost \
        -U "$POSTGRES_USER" \
        -d "$KC_POSTGRES_DB" \
        -c "SELECT name FROM django_migrations WHERE app='kpi' ORDER BY id DESC LIMIT 1;" \
    | sed 's/ //g'
)
if [ "$kpi_last_actual_migration" = "$KPI_LAST_EXPECTED_MIGRATION" ]
then
    echo "Safety check: the last applied KPI migration matches what we expected (OK)"
else
    echo -n "Your source database's last KPI migration was \`$kpi_last_actual_migration\`, but "
    echo "this script requires \`$KPI_LAST_EXPECTED_MIGRATION\`."
    echo -n 'Upgrade to the last single-database release of KPI, `2.019.52-final-shared-database`, '
    echo "BEFORE running this script. Visit $HELP_PAGE if you need help."
    exit 1
fi

echo "Creating \`${KPI_POSTGRES_DB}\` with PostGIS extensions..."

psql \
    -X \
    -U "$POSTGRES_USER" \
    -h localhost \
    -d postgres <<EOF
CREATE DATABASE "$KPI_POSTGRES_DB" OWNER "$POSTGRES_USER";
\c "$KPI_POSTGRES_DB"
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS postgis_topology;
CREATE EXTENSION IF NOT EXISTS fuzzystrmatch;
CREATE EXTENSION IF NOT EXISTS postgis_tiger_geocoder;
EOF

echo
echo -e 'Done!'

sleep $SLEEP_TIME # To read the output for debugging
echo

echo -n "We are now copying KPI tables from \`$KC_POSTGRES_DB\` to \`$KPI_POSTGRES_DB\`"

pg_dump \
    -U ${POSTGRES_USER} \
    -h localhost \
    ${KPI_TABLES[@]/#/-t } \
    -d "$KC_POSTGRES_DB" \
| psql --single-transaction \
    -X \
    -U "$POSTGRES_USER" \
    -h localhost \
    -d "$KPI_POSTGRES_DB" \
| lines_to_dots

echo
echo
echo "The database upgrade finished successfully! Thanks for using KoboToolbox."
