#!/bin/bash
set -ex

keystone-manage --config-file=/etc/keystone/keystone.conf db_sync
keystone-manage --config-file=/etc/keystone/keystone.conf bootstrap \
    --bootstrap-username ${OS_USERNAME} \
    --bootstrap-password ${OS_PASSWORD} \
    --bootstrap-project-name ${OS_PROJECT_NAME} \
    --bootstrap-admin-url ${OS_BOOTSTRAP_ADMIN_URL} \
    --bootstrap-public-url ${OS_BOOTSTRAP_PUBLIC_URL} \
    --bootstrap-internal-url ${OS_BOOTSTRAP_INTERNAL_URL} \
    --bootstrap-region-id ${OS_REGION_NAME}

exec python /tmp/endpoint-update.py