#!/bin/bash
set -eEuo pipefail

SLEEP_TIME=0
HELP_PAGE='https://community.kobotoolbox.org/t/upgrading-to-separate-databases-for-kpi-and-kobocat/7202'
KPI_LAST_EXPECTED_MIGRATION='0024_alter_jsonfield_to_jsonbfield'
KPI_LATEST_RELEASE='master'

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


echo -e "\e[31m\e[1mWARNING! \e[21mThis script is destructive.\e[0m"
echo "It is STRONGLY recommended to backup your database \`$KC_POSTGRES_DB\` before proceeding."
prompt_to_continue


#KPI_TABLES=($(psql -U ${POSTGRES_USER} -d ${KPI_POSTGRES_DB} -t -c "SELECT tablename FROM pg_catalog.pg_tables where schemaname='public'"))
# We could read table from DB, but we need the order to be respected.
# Otherwise inserts may fail because of FK not present.
KPI_TABLES=(
 constance_config
 taggit_taggeditem
 taggit_tag
 kpi_objectpermission
 kpi_assetsnapshot
 kpi_assetfile
 kpi_assetversion
 kpi_asset
 kpi_collection
 kpi_importtask
 kpi_authorizedapplication
 kpi_taguid
 kpi_onetimeauthenticationkey
 kpi_usercollectionsubscription
 kpi_exporttask
 hub_sitewidemessage
 hub_configurationfile
 hub_formbuilderpreference
 hub_extrauserdetail
 hub_perusersetting
 registration_registrationprofile
 hook_hooklog
 hook_hook
 external_integrations_corsmodel
 help_inappmessageuserinteractions
 help_inappmessagefile
 help_inappmessage
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
    echo -n "The KoBoCAT database, \`$KC_POSTGRES_DB\`, does not contain the needed KPI tables. "
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
if [ "$matching_dbs_count" -eq 1 ]
then
    echo "Safety check: the KPI database \`$KPI_POSTGRES_DB\` exists (OK), "
    asset_count=$(
        psql -Xqt -h localhost \
            -U "$POSTGRES_USER" \
            -d "$KPI_POSTGRES_DB" \
            -c 'SELECT COUNT(*) FROM kpi_asset;' \
        | sed 's/ //g'
    )
    if [ $asset_count -eq 0 ]
    then
        echo "The KPI database \`$KPI_POSTGRES_DB\` appears to be empty because it contains no assets."
        echo "This script cannot continue with an empty assets table in KPI database \`$KPI_POSTGRES_DB\`."
        exit 1
    fi
else
    echo -n "The KPI database \`$KPI_POSTGRES_DB\` does not exist, or "
    matching_tables_count=$(
        psql -Xqt -h localhost \
            -U "$POSTGRES_USER" \
            -d "$KPI_POSTGRES_DB" \
            -c 'SELECT COUNT(*) FROM pg_tables WHERE tablename='"'kpi_asset';"
    )
    if [ "$matching_tables_count" -eq 0 ]
    then
        echo "it appears to be empty because it does not contain an assets table."
        echo "This script cannot continue with an empty KPI database \`$KPI_POSTGRES_DB\`."
        exit 1
    fi
fi

kpi_last_actual_migration=$(
    psql -Xqt -h localhost \
        -U "$POSTGRES_USER" \
        -d "$KPI_POSTGRES_DB" \
        -c "SELECT name FROM django_migrations WHERE app='kpi' ORDER BY id DESC LIMIT 1;" \
    | sed 's/ //g'
)
if [ "$kpi_last_actual_migration" = "$KPI_LAST_EXPECTED_MIGRATION" ]
then
    echo "Safety check: the last applied KPI migration matches what we expected (OK)"
else
    echo -n "Your KPI database's last KPI migration was \`$kpi_last_actual_migration\`, but "
    echo "this script requires \`$KPI_LAST_EXPECTED_MIGRATION\`."
    echo -n 'Upgrade to the latest release of KPI, `$KPI_LATEST_RELEASE`, '
    echo "BEFORE running this script. Visit $HELP_PAGE if you need help."
    exit 1
fi

sleep $SLEEP_TIME # To read the output for debugging
echo

echo "We are now dropping KPI tables from \`$KC_POSTGRES_DB\`."

for KPI_TABLE in "${KPI_TABLES[@]}"
do
    psql -Xqt -h localhost \
    -U "$POSTGRES_USER" \
    -d "$KC_POSTGRES_DB" \
    -c "DROP TABLE $KPI_TABLE CASCADE;"
done

echo
echo
echo "The KoBoCAT database clean-up finished successfully! Thanks for using KoBoToolbox."
