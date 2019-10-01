#!/bin/bash

function prompt_to_continue() {
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

SLEEP_TIME=0
KPI_LAST_EXPECTED_MIGRATION='0022_assetfile'

if [ $(psql \
           -X \
           -U "$POSTGRES_USER" \
           -h localhost \
           -d postgres \
           -qt \
           -c 'SELECT COUNT(*) FROM pg_database WHERE datname='"'$KPI_POSTGRES_DB';"
       ) -eq 0 ]
then
    echo "Safety check: the target database $KPI_POSTGRES_DB does not exist yet (OK)"
else
    echo "Abort mission! The target database $KPI_POSTGRES_DB already exists."
    echo -n "This script will not destroy an existing database; please DROP it yourself "
    echo "if that's really what you desire."
    echo "For more help, visit https://community.kobotoolbox.org/c/kobo-install."
    exit 1
fi

kpi_last_actual_migration=$(
    psql \
        -X \
        -U "$POSTGRES_USER" \
        -h localhost \
        -d "$KC_POSTGRES_DB" \
        -qt \
        -c "SELECT name FROM django_migrations WHERE app='kpi' ORDER BY id DESC LIMIT 1;" \
    | sed 's/ //g'
)
if [ "$kpi_last_actual_migration" = "$KPI_LAST_EXPECTED_MIGRATION" ]
then
    echo "Safety check: the last applied KPI migration matches what we expected (OK)"
else
    echo -n "Your database's last KPI migration was $kpi_last_actual_migration, but "
    echo "this script requires $KPI_LAST_EXPECTED_MIGRATION."
    echo -n "Please make sure you are running the last single-database release of KPI, "
    echo "and visit https://community.kobotoolbox.org/c/kobo-install if you need help."
    exit 1
fi

echo "Creating ${KPI_POSTGRES_DB} with PostGIS extensions..."

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

if [ $? == 0 ]; then
    printf "\tDone!\n"
else
    echo "Something went wrong. Please read the output above."
    prompt_to_continue
fi

sleep $SLEEP_TIME # To read the output for debugging
echo ""

echo "We are now ready to copy KPI tables from $KC_POSTGRES_DB to $KPI_POSTGRES_DB."
echo "Press enter to start, and please expect lots of output!"
read trash

pg_dump \
    -U ${POSTGRES_USER} \
    -h localhost \
    ${KPI_TABLES[@]/#/-t } \
    -d "$KC_POSTGRES_DB" \
| psql \
    -X \
    -U "$POSTGRES_USER" \
    -h localhost \
    -d "$KPI_POSTGRES_DB" \

if [ $? == 0 ]; then
    printf "\tEverything finished successfully! Thanks for using KoBoToolbox.\n"
else
    echo "Something went wrong. Please read the output above."
fi
