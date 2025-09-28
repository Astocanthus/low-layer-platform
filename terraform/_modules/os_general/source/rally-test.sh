#!/bin/bash

set -ex

: "${RALLY_ENV_NAME:="openstack-helm"}"
: "${OS_INTERFACE:="public"}"
: "${RALLY_CLEANUP:="true"}"

if [ "x$RALLY_CLEANUP" == "xtrue" ]; then
  function rally_cleanup {
    openstack user delete \
        --domain="${SERVICE_OS_USER_DOMAIN_NAME}" \
        "${SERVICE_OS_USERNAME}"
    VOLUMES=$(openstack volume list -f value | grep -e "^s_rally_" | awk '{ print $1 }')
    if [ -n "$VOLUMES" ]; then
      echo $VOLUMES | xargs openstack volume delete
    fi
  }
  trap rally_cleanup EXIT
fi

function create_or_update_db () {
  revisionResults=$(rally db revision)
  if [ $revisionResults = "None"  ]
  then
    rally db create
  else
    rally db upgrade
  fi
}

create_or_update_db

cat > /tmp/rally-config.json << EOF
{
  "openstack": {
    "auth_url": "${OS_AUTH_URL}",
    "region_name": "${OS_REGION_NAME}",
    "endpoint_type": "${OS_INTERFACE}",
    "admin": {
      "username": "${OS_USERNAME}",
      "password": "${OS_PASSWORD}",
      "user_domain_name": "${OS_USER_DOMAIN_NAME}",
      "project_name": "${OS_PROJECT_NAME}",
      "project_domain_name": "${OS_PROJECT_DOMAIN_NAME}"
    },
    "users": [{
      "username": "${SERVICE_OS_USERNAME}",
      "password": "${SERVICE_OS_PASSWORD}",
      "project_name": "${SERVICE_OS_PROJECT_NAME}",
      "user_domain_name": "${SERVICE_OS_USER_DOMAIN_NAME}",
      "project_domain_name": "${SERVICE_OS_PROJECT_DOMAIN_NAME}"
    }],
    "https_insecure": false,
    "https_cacert": "${OS_CACERT}"
  }
}
EOF

rally deployment create --file /tmp/rally-config.json --name
"${RALLY_ENV_NAME}"
rm -f /tmp/rally-config.json
rally deployment use "${RALLY_ENV_NAME}"
rally deployment check
rally task validate /etc/rally/rally_tests.yaml
rally task start /etc/rally/rally_tests.yaml
rally task sla-check
rally env cleanup
rally deployment destroy --deployment "${RALLY_ENV_NAME}"