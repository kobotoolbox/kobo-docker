#!/bin/bash
set -eEuo pipefail

HELP_PAGE='https://community.kobotoolbox.org/t/upgrading-to-separate-databases-for-kpi-and-kobocat/7202'

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


echo -e "\e[31m\e[1mWARNING! \e[21mThis script is destructive.\e[0m"
echo "It is STRONGLY recommended to backup your database \`$KC_POSTGRES_DB\` before proceeding."
prompt_to_continue


# Developers take note: make sure *none* of these tables appears in a
# freshly-created KoBoCAT database!
KPI_TABLES=(
 constance_config
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
 hub_extrauserdetail
 hub_perusersetting
 hook_hooklog
 hook_hook
 external_integrations_corsmodel
 help_inappmessageuserinteractions
 help_inappmessagefile
 help_inappmessage
)
kpi_tables_single_quoted_csv=$(echo "${KPI_TABLES[@]}" | sed "s/^/'/;s/ /','/g;s/$/'/")

# Some tables no longer exist in KPI; don't freak out about them
KPI_OBSOLETE_TABLES=(
 hub_formbuilderpreference
)
kpi_obsolete_tables_single_quoted_csv=$(echo "${KPI_OBSOLETE_TABLES[@]}" | sed "s/^/'/;s/ /','/g;s/$/'/")


kpi_tables_in_kobocat_db_count=$(
    psql -Xqt -h localhost \
        -U "$POSTGRES_USER" \
        -d "$KC_POSTGRES_DB" \
        -c "SELECT COUNT(*) FROM pg_tables WHERE tablename in ($kpi_tables_single_quoted_csv);" \
    | sed 's/ //g'
)
if [ "$kpi_tables_in_kobocat_db_count" -eq ${#KPI_TABLES[@]} ]
then
    echo "The KoBoCAT database, \`$KC_POSTGRES_DB\`, contains the expected KPI tables (OK)"
else
    echo -n "The KoBoCAT database, \`$KC_POSTGRES_DB\`, does not contain the expected KPI tables. "
    echo -n 'If this installation never used a single, shared database for both KPI and KoBoCAT, '
    echo 'then this script is not needed. Otherwise, the database configuration may be incorrect.'
    echo "For help, visit $HELP_PAGE."
    exit 1
fi

matching_dbs_count=$(
    psql -Xqt -h localhost \
        -U "$POSTGRES_USER" \
        -d postgres \
        -c 'SELECT COUNT(*) FROM pg_database WHERE datname='"'$KPI_POSTGRES_DB';" \
    | sed 's/ //g'
)
if [ "$matching_dbs_count" -eq 1 ]
then
    echo "Safety check: the KPI database \`$KPI_POSTGRES_DB\` exists (OK)"
else
    echo -n "The KPI database \`$KPI_POSTGRES_DB\` does not exist. "
    echo 'KPI must have its own database before this script can proceed.'
    echo "To avoid data loss, this script cannot continue. Visit $HELP_PAGE for help."
    exit 1
fi

kpi_tables_in_kpi_db_count=$(
    psql -Xqt -h localhost \
        -U "$POSTGRES_USER" \
        -d "$KPI_POSTGRES_DB" \
        -c "SELECT COUNT(*) FROM pg_tables WHERE tablename in ($kpi_tables_single_quoted_csv);" \
    | sed 's/ //g'
)
if [ "$kpi_tables_in_kpi_db_count" -eq ${#KPI_TABLES[@]} ]
then
    echo "Safety check: The KPI database, \`$KPI_POSTGRES_DB\`, contains the expected KPI tables (OK)"
else
    echo -n "The KPI database, \`$KPI_POSTGRES_DB\`, does not contain the expected tables. "
    echo 'This may indicate a failed migration from a single, shared database.'
    echo "To avoid data loss, this script cannot continue. Visit $HELP_PAGE for help."
    exit 1
fi

max_kpi_asset_id_in_kpi_db=$(
    psql -Xqt -h localhost \
        -U "$POSTGRES_USER" \
        -d "$KPI_POSTGRES_DB" \
        -c 'SELECT MAX(id) FROM kpi_asset;' \
    | sed 's/ //g'
)
if [ -z "$max_kpi_asset_id_in_kpi_db" ]
then
    # an empty `kpi_asset` table
    max_kpi_asset_id_in_kpi_db=0
fi

max_kpi_asset_id_in_kobocat_db=$(
    psql -Xqt -h localhost \
        -U "$POSTGRES_USER" \
        -d "$KC_POSTGRES_DB" \
        -c 'SELECT MAX(id) FROM kpi_asset;' \
    | sed 's/ //g'
)
if [ -z "$max_kpi_asset_id_in_kobocat_db" ]
then
    # an empty `kpi_asset` table
    max_kpi_asset_id_in_kobocat_db=0
fi

if [ "$max_kpi_asset_id_in_kpi_db" -ge "$max_kpi_asset_id_in_kobocat_db" ]
then
    echo -n 'Safety check: the `kpi_asset` table pending removal does not have '
    echo 'content more recent than the one being kept (OK)'
else
    echo -n "The \`kpi_asset\` table in the KoBoCAT database, \`$KC_POSTGRES_DB\`, "
    echo -n 'which we intend to remove, appears to have been updated more recently '
    echo -n "than the \`kpi_asset\` table in the KPI database, \`$KPI_POSTGRES_DB\`. "
    echo 'This probably indicates a database misconfiguration.'
    echo "To avoid data loss, this script cannot continue. Visit $HELP_PAGE for help."
    exit 1
fi


echo "We are now dropping KPI tables from \`$KC_POSTGRES_DB\`."
kpi_tables_unquoted_csv=$(echo "${KPI_TABLES[@]}" | sed 's/ /,/g')
psql -Xqt -h localhost \
    -U "$POSTGRES_USER" \
    -d "$KC_POSTGRES_DB" \
    -c "DROP TABLE $kpi_tables_unquoted_csv;"

echo "We are now dropping obsolete KPI tables (if any) from \`$KC_POSTGRES_DB\`."
kpi_obsolete_tables_unquoted_csv=$(echo "${KPI_OBSOLETE_TABLES[@]}" | sed 's/ /,/g')
psql -Xqt -h localhost \
    -U "$POSTGRES_USER" \
    -d "$KC_POSTGRES_DB" \
    -c "DROP TABLE IF EXISTS $kpi_obsolete_tables_unquoted_csv;"

echo
echo
echo "The KoBoCAT database clean-up finished successfully! Thanks for using KoboToolbox."
