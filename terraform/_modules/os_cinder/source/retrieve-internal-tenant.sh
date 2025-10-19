#!/bin/bash

set -ex

USER_PROJECT_ID=$(openstack project show -f value -c id \
  "${INTERNAL_PROJECT_NAME}");

USER_ID=$(openstack user show -f value -c id \
  "${INTERNAL_USER_NAME}");

tee /tmp/pod-shared/internal_tenant.conf <<EOF
[DEFAULT]
cinder_internal_tenant_project_id = ${USER_PROJECT_ID}
cinder_internal_tenant_user_id = ${USER_ID}
EOF