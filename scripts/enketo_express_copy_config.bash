#!/usr/bin/env bash
set -e

echo "Copying the read-only configuration template into place at \`${ENKETO_SRC_DIR}/config/config.json\`."
cp /srv/tmp/enketo_express_config.json ${ENKETO_SRC_DIR}/config/config.json
