#!/bin/bash

# We could read table from DB, but we need the order to be respected.
# Otherwise inserts may fail because of FK not present.

tables=(
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
 oauth2_provider_application
 django_session
 oauth2_provider_accesstoken
 oauth2_provider_grant
 django_digest_usernonce
 reversion_revision
 oauth2_provider_refreshtoken
 registration_registrationprofile
 reversion_version
 hook_hook
 hook_hooklog
)


MESSAGE="WARNING!!! This script will wipe all the data on target database:"
TARGET_DBNAME_LEN=${#KPI_POSTGRES_DB}
MESSAGE_LEN=${#MESSAGE}
LIMIT=$((MESSAGE_LEN-TARGET_DBNAME_LEN-1))

printf "╔═%s═╗\n" $(printf "═%.0s" $(seq 1 $MESSAGE_LEN))
printf "║ ${MESSAGE} ║\n"
printf "║ ${KPI_POSTGRES_DB} %s ║\n" $(printf ".%.0s" $(seq 1 $LIMIT))
printf "╚═%s═╝\n" $(printf "═%.0s" $(seq 1 $MESSAGE_LEN))

while true; do

    read -p "Do you want to continue [y/N]?" yn
    case $yn in
        [Yy]* ) break;;
        [Nn]* ) exit;;
        * ) echo "Please answer Y or N.";;
    esac
done


for table_name in "${tables[@]}"
do
    :
    echo "Truncating ${KPI_POSTGRES_DB}.public.${table_name}..."
    psql \
        -X \
        -U ${POSTGRES_USER} \
        -h localhost \
        -d ${KPI_POSTGRES_DB} \
        -c "TRUNCATE TABLE ${table_name} RESTART IDENTITY CASCADE"
    printf "\tDone!\n"
    sleep 5 # Use to let us read the output if there are any errors
    echo ""
done

for table_name in "${tables[@]}"
do
    :
    echo "Copying table ${KC_POSTGRES_DB}.public.${table_name} to ${KPI_POSTGRES_DB}.public.${table_name}..."
    psql \
        -X \
        -U ${POSTGRES_USER} \
        -h localhost \
        -d ${KC_POSTGRES_DB} \
        -c "\\copy ${table_name} to stdout" \
    | \
    psql \
        -X \
        -U ${POSTGRES_USER} \
        -h localhost \
        -d ${KPI_POSTGRES_DB} \
        -c "\\copy ${table_name} from stdin"
    sleep 5 # Use to let us read the output if there are any errors
    printf "\tDone!\n"

    echo "Updating sequence for table ${KPI_POSTGRES_DB}.public.${table_name}..."
    psql \
        -X \
        -U ${POSTGRES_USER} \
        -h localhost \
        -d ${KPI_POSTGRES_DB} \
        -c "SELECT setval('${table_name}_id_seq', (SELECT max(id) from ${table_name}))"
    sleep 1 # Use to let us read the output if there are any errors
    echo ""

done
